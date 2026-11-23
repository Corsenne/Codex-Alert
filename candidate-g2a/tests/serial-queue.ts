/**
 * Design-only pure reducer for a single-banner/single-audio queue.
 * No external calls, no Codex hook modifications, no production integration.
 * Final Windows implementation must make the native audio/queue actor authoritative.
 */
export type Source = 'chatgpt' | 'codex';
export type Alert = Readonly<{
  eventId: string;
  source: Source;
  title: string;
  completedAt: string;
}>;
export type State = Readonly<{
  active: Alert | null;
  waiting: readonly Alert[];
  recent: readonly string[];
}>;
export type Effect = Readonly<
  | {type:'show'; event:Alert}
  | {type:'play'; event:Alert}
  | {type:'stop'; eventId:string}
  | {type:'hide'; eventId:string}
  | {type:'open'; event:Alert}
>;
export type Outcome = Readonly<{state:State; effects:readonly Effect[]; result:'started'|'queued'|'duplicate'|'full'|'finished'|'ignored'}>;
export const initialState:State = {active:null,waiting:[],recent:[]};
const MAX_WAITING = 64;
const MAX_RECENT = 256;
function key(e:Alert):string {return `${e.source}:${e.eventId}`;}
function has(state:State,e:Alert):boolean {return state.recent.includes(key(e));}
export function enqueue(state:State, event:Alert):Outcome {
  if (!event.eventId || !['chatgpt','codex'].includes(event.source)) return {state,effects:[],result:'ignored'};
  if (has(state,event)) return {state,effects:[],result:'duplicate'};
  if (state.active && state.waiting.length >= MAX_WAITING) return {state,effects:[],result:'full'};
  const recent=[...state.recent,key(event)].slice(-MAX_RECENT);
  if (state.active) {
    return {state:{...state,waiting:[...state.waiting,event],recent},effects:[],result:'queued'};
  }
  return {state:{active:event,waiting:state.waiting,recent},effects:[{type:'show',event},{type:'play',event}],result:'started'};
}
export function complete(state:State,eventId:string,reason:'click'|'dismiss'|'timeout'):Outcome {
  const current=state.active;
  if (!current || current.eventId!==eventId) return {state,effects:[],result:'ignored'};
  const next=state.waiting[0] ?? null;
  const effects:Effect[] = [{type:'stop',eventId},{type:'hide',eventId}];
  if (reason==='click')effects.push({type:'open',event:current});
  if (next) effects.push({type:'show',event:next},{type:'play',event:next});
  return {
    state:{active:next,waiting:state.waiting.slice(1),recent:state.recent},
    effects,
    result:'finished'
  };
}
