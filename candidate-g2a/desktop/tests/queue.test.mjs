import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const main=readFileSync(new URL('../src/main.tsx',import.meta.url),'utf8');
const queue=readFileSync(new URL('../src/queue.ts',import.meta.url),'utf8');
test('React is display only and receives exactly one active item',()=>{
  assert.match(main,/useState<ToastEvent\|null>\(null\)/);
  assert.match(main,/finish-alert:active/);
  assert.match(main,/<Toast key=\{active\.eventId\}/);
  assert.doesNotMatch(main,/visible\.map|visible\.length<3/);
  assert.doesNotMatch(queue,/waiting:|visible:/);
});
test('click, dismiss, timeout share native completion gateway',()=>{
  for(const action of ['click','dismiss','timeout'])assert.ok(main.includes(`'${action}'`));
  assert.match(main,/invoke\('complete_notification'/);
  assert.match(main,/invoke\('notification_visible'/);
});
