(() => {
  'use strict';

  // Heuristic observer: ChatGPT does not publish a stable completion event to extensions.
  // Never store or transmit prompts or answers. Completion metadata only.
  const ASSISTANT = '[data-message-author-role="assistant"], [data-role="assistant"], [data-message-author="assistant"], article[data-turn="assistant"], .agent-turn';
  const RENDERED = 'main .markdown, main .prose, main [class*="markdown"], [role="main"] .markdown, [role="main"] .prose';
  const STOP_IDS = new Set(['stop-button', 'stop-generating-button']);
  const STOP_WORDS = /^(?:stop(?: generating| streaming| response)?|stop generation|生成を停止(?:する)?|回答を停止(?:する)?|応答を停止(?:する)?|ストリーミングを停止(?:する)?|停止(?:する)?|中止(?:する)?)$/i;
  const ERROR_WORDS = /something went wrong|network error|failed to (?:generate|respond)|エラーが発生|問題が発生|生成に失敗|応答できません/i;
  const MIN_STOP_OBSERVED_MS = 500;
  const SETTLE_MS = 1350;
  const QUIET_MS = 850;

  let phase = 'idle';
  let cycle = null;
  let sequence = 0;
  let checkPending = false;
  let samplePending = false;
  let confirmTimer = 0;
  let manualStopLock = false;
  let activePoll = 0;
  let lastVisitedPath = location.pathname;
  let lastEvidence = '未観測';
  let lastOutcome = '未観測';
  let lastSummary = null;
  const now = () => performance.now();

  function visible(el) {
    return !!el && el.isConnected !== false &&
      (typeof el.getClientRects !== 'function' || el.getClientRects().length > 0);
  }
  function stopButton(el) {
    if (!el || el.tagName !== 'BUTTON' || !visible(el)) return false;
    const id = (el.getAttribute('data-testid') || '').toLowerCase();
    if (STOP_IDS.has(id)) return true;
    const label = (el.getAttribute('aria-label') || el.getAttribute('title') || el.textContent || '').trim();
    return STOP_WORDS.test(label);
  }
  function findStop() {
    for (const el of document.querySelectorAll('button[data-testid], button[aria-label], button[title], button')) {
      if (stopButton(el)) return el;
    }
    return null;
  }
  function lastNode(selector) {
    const nodes = document.querySelectorAll(selector);
    return nodes.length ? nodes[nodes.length - 1] : null;
  }
  function assistantNode() { return lastNode(ASSISTANT); }
  function renderedNode() { return lastNode(RENDERED); }
  function answerNode() { return assistantNode() || renderedNode(); }
  function textLen(node) { return (node?.textContent || '').trim().length; }
  function pageRoot() {
    return document.querySelector('main') || document.querySelector('[role="main"]') ||
      document.querySelector('#__next') || document.body || document.documentElement;
  }
  function fingerprint(node) {
    const text = node?.textContent || '';
    // Including the end catches newly appended assistant output; hashing only the end caps CPU cost.
    const tail = text.slice(-24000);
    let hash = 2166136261;
    for (let i = 0; i < tail.length; ++i) {
      hash ^= tail.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return `${text.length}:${hash >>> 0}`;
  }
  function hasError() {
    for (const el of document.querySelectorAll('[role="alert"], [data-testid="toast"], [data-testid*="error"]')) {
      if (visible(el) && ERROR_WORDS.test((el.textContent || '').slice(0, 250))) return true;
    }
    return false;
  }
  // Metadata only: do not transmit the prompt, completion, or page body.
  function getChatTitle() {
    const pathname = location.pathname || '';
    const labels = [];
    const documentLabel = (document.title || '').replace(/\s*(?:[-|–—]\s*)?ChatGPT\s*$/i, '').trim();
    if (documentLabel && !/^(?:ChatGPT|New chat|新しいチャット)$/i.test(documentLabel)) {
      labels.push(documentLabel);
    }
    if (pathname.includes('/c/')) {
      const links = document.querySelectorAll('nav a[href], aside a[href]');
      for (const link of links) {
        try {
          const href = new URL(link.getAttribute('href'), location.origin);
          if (href.origin === location.origin && href.pathname === pathname) {
            const label = (link.getAttribute('aria-label') || link.textContent || '').trim();
            if (label) labels.push(label);
          }
        } catch (_) { /* malformed sidebar link */ }
      }
    }
    return (labels[0] || 'ChatGPTの会話').replace(/[\x00-\x1f\x7f]/g, ' ').slice(0, 120);
  }
  function send(type, extra = {}) {
    try { chrome.runtime.sendMessage({type, ...extra}).catch(() => {}); } catch (_) {}
  }
  function status(text) {
    lastEvidence = text; // In-memory state only; no per-event diagnostic writes.
  }
  function notifyViewed() {
    if (document.visibilityState === 'hidden') return;
    if (typeof document.hasFocus === 'function' && !document.hasFocus()) return;
    send('VIEWED', {url: location.href || location.origin + location.pathname});
  }
  function begin(t) {
    const answer = answerNode();
    cycle = {
      id: `${Date.now()}-${++sequence}`,
      start: t,
      lastStopSeen: t,
      settleStart: 0,
      pageInitial: fingerprint(pageRoot()),
      pageSnapshot: fingerprint(pageRoot()),
      answerInitial: fingerprint(answer),
      answerRef: answer,
      answerActivity: false,
      pageActivity: false,
      latestChange: t,
      manualStop: false
    };
    phase = 'generating';
    // The 450ms backup poll is active only during a generation cycle.
    if (!activePoll) activePoll = setInterval(() => { if (phase !== 'idle') evaluate(); }, 450);
    status('生成中を検知（停止ボタン）');
  }
  function end(outcome, state) {
    if (confirmTimer) clearTimeout(confirmTimer);
    confirmTimer = 0;
    lastOutcome = outcome;
    lastSummary = cycle ? {
      durationMs: Math.round(now() - cycle.start),
      pageActivity: cycle.pageActivity,
      answerActivity: cycle.answerActivity,
      usedFallback: !cycle.answerActivity,
      outcome
    } : lastSummary;
    phase = 'idle';
    cycle = null;
    if (activePoll) { clearInterval(activePoll); activePoll = 0; }
    if (state) status(state);
  }
  function sample(t) {
    if (!cycle) return;
    const s = fingerprint(pageRoot());
    const a = answerNode();
    const answerFingerprint = fingerprint(a);
    // Changes while the Stop control is present count as generation evidence.
    const stopPresent = !!findStop();
    if (stopPresent) {
      if (s !== cycle.pageSnapshot) {
        cycle.pageActivity = true;
        cycle.latestChange = t;
      }
      if (a && (a !== cycle.answerRef || answerFingerprint !== cycle.answerInitial)) {
        cycle.answerActivity = true;
        cycle.latestChange = t;
      }
    }
    cycle.pageSnapshot = s;
  }
  function scheduleSample() {
    if (samplePending) return;
    samplePending = true;
    setTimeout(() => {
      samplePending = false;
      if (cycle) sample(now());
    }, 100);
  }
  function scheduleEvaluate(delay = 80) {
    if (checkPending) return;
    checkPending = true;
    setTimeout(() => {
      checkPending = false;
      evaluate();
    }, delay);
  }
  function confirmAfter(delay) {
    if (confirmTimer) clearTimeout(confirmTimer);
    confirmTimer = setTimeout(() => {
      confirmTimer = 0;
      evaluate();
    }, Math.max(80, Math.ceil(delay)));
  }
  function evaluate() {
    if (location.pathname !== lastVisitedPath) {
      lastVisitedPath = location.pathname;
      notifyViewed();
    }
    const t = now();
    const stop = findStop();
    if (phase === 'idle') {
      if (manualStopLock) {
        if (!stop) manualStopLock = false;
        return;
      }
      if (stop) begin(t);
      return;
    }
    if (!cycle) return;
    if (cycle.manualStop) return end('cancelled', '手動停止（通知なし）');
    // Evaluate pending mutations BEFORE the Stop button disappears, including text-only activity.
    if (stop) {
      sample(t);
      cycle.lastStopSeen = t;
      if (phase === 'settling') {
        phase = 'generating';
        if (confirmTimer) clearTimeout(confirmTimer);
        confirmTimer = 0;
        status('停止ボタン再出現・生成継続');
      }
      return;
    }
    if (phase === 'generating') {
      phase = 'settling';
      cycle.settleStart = t;
      status('完了候補：停止ボタン消失（安定待ち）');
      confirmAfter(SETTLE_MS);
      return;
    }
    const remaining = Math.max(SETTLE_MS - (t - cycle.settleStart), QUIET_MS - (t - cycle.latestChange));
    if (remaining > 0) return confirmAfter(remaining + 50);
    if (hasError()) return end('error', 'エラー表示を検出（通知なし）');
    if (cycle.settleStart - cycle.start < MIN_STOP_OBSERVED_MS) {
      return end('insufficient', '停止ボタン観測が短すぎる（通知なし）');
    }
    const evidence = cycle.answerActivity ? '回答要素の更新' : cycle.pageActivity ? 'ページ本文の更新' : '停止ボタンの遷移（代替判定）';
    const id = cycle.id;
    end('completed', `回答完了を検知：${evidence}`);
    send('COMPLETE', {cycleId: id, evidence, chatTitle: getChatTitle()});
  }

  function onManualStop(event) {
    const el = event.target instanceof Element ? event.target.closest('button') : null;
    if (el && stopButton(el) && cycle) {
      cycle.manualStop = true;
      manualStopLock = true;
      end('cancelled', '手動停止（通知なし）');
    }
  }
  document.addEventListener('pointerdown', onManualStop, true);
  document.addEventListener('click', onManualStop, true);

  const observer = new MutationObserver((mutations) => {
    if (cycle && mutations.some(m => m.type === 'characterData' || m.type === 'childList')) scheduleSample();
    scheduleEvaluate();
  });
  function activate() {
    observer.observe(document.documentElement, {
      subtree: true, childList: true, characterData: true, attributes: true,
      attributeFilter: ['aria-label', 'title', 'data-testid', 'style', 'class', 'hidden']
    });
    evaluate();
  }
  chrome.runtime.onMessage.addListener((message, sender, reply) => {
    if (message?.type !== 'PROBE_CONTENT') return;
    const root = pageRoot();
    reply({
      ok: true, phase,
      stopVisible: !!findStop(),
      assistantPresent: !!assistantNode(),
      renderedFallbackPresent: !!renderedNode(),
      mainFound: !!document.querySelector('main'),
      answerLength: textLen(answerNode()),
      pageLength: textLen(root),
      bodyLength: textLen(document.body),
      activeMs: cycle ? Math.round(now() - cycle.start) : 0,
      pageActivity: !!cycle?.pageActivity,
      answerActivity: !!cycle?.answerActivity,
      lastEvidence, lastOutcome, lastSummary,
      locationHost: location.hostname
    });
  });

  // Foreground viewing is event-driven: no periodic focus polling.
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') notifyViewed(); });
  window.addEventListener('focus', notifyViewed);
  window.addEventListener('pageshow', notifyViewed);
  window.addEventListener('popstate', notifyViewed);
  if (document.documentElement) activate();
  else document.addEventListener('DOMContentLoaded', activate, {once: true});
  // Backup polling is created in begin() and stopped in end().
})();
