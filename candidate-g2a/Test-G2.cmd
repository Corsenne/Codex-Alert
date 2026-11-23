@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo === Codex + ChatGPT Finish Alert G2A / OFFLINE SOURCE TESTS ===
echo Current installed Finish Alert is NOT modified.
echo.
where node >nul 2>&1
if errorlevel 1 (
  echo HOLD: Node.js is not available in PATH.
  pause
  exit /b 2
)
node --check "chrome-extension\background.js" || goto :failed
node --check "chrome-extension\offscreen.js" || goto :failed
node "chrome-extension\tests\audio-volume.cjs" || goto :failed
node "chrome-extension\tests\background-desktop.cjs" || goto :failed
node "chrome-extension\tests\content-regression.cjs" || goto :failed
node "chrome-extension\tests\popup-lite.cjs" || goto :failed
node --experimental-strip-types --test "tests\serial-queue.test.mjs" || goto :failed
node --test "desktop\tests\queue.test.mjs" || goto :failed
node "tests\check-source.cjs" || goto :failed
echo.
echo G2A_NODE_SOURCE_TESTS_PASS
echo.
where cargo >nul 2>&1
if errorlevel 1 (
  echo HOLD: cargo not found. Rust Windows compile/tests still required before any installation.
  pause
  exit /b 2
)
echo.
echo Testing Native Messaging bridge (uses local Cargo cache / may download crates)...
cargo test --manifest-path "native-host\Cargo.toml" || goto :failed
echo Testing Tauri Windows receiver (uses local Cargo cache / may download crates)...
cargo test --manifest-path "desktop\src-tauri\Cargo.toml" || goto :failed
echo.
echo G2A_WINDOWS_RUST_TESTS_PASS
pause
exit /b 0
:failed
echo.
echo G2A_TEST_FAIL - no installed applications or settings changed.
pause
exit /b 1
