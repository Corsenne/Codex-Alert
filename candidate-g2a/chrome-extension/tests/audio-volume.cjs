'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const code=fs.readFileSync(path.join(root,'offscreen.js'),'utf8');
let callback,created=[],played=[];
class AudioMock {
  constructor(url){this.url=url;this.volume=1;this.currentTime=0;created.push(this);}
  pause(){}
  addEventListener(){}
  async play(){played.push({url:this.url,volume:this.volume});}
}
vm.runInNewContext(code,{
  chrome:{runtime:{getURL:p=>'chrome-extension://unit-test/'+p,onMessage:{addListener:fn=>{callback=fn;}}}},
  Audio:AudioMock,Number,Object,Math,Promise
});
function send(soundId,volume){
  return new Promise(resolve=>{
    const keep=callback({target:'offscreen',type:'PLAY_SOUND',soundId,volume},{},resolve);
    assert.equal(keep,true);
  });
}
(async()=>{
  assert.equal((await send('female',35)).ok,true);
  assert.equal(played.at(-1).volume,.35);
  assert.match(played.at(-1).url,/assets\/female\.wav$/);
  assert.equal((await send('holo',100)).ok,true);
  assert.equal(played.at(-1).volume,1);
  assert.equal((await send('soft',0)).ok,true);
  assert.equal(played.length,2,'0% does not play audio');
  assert.equal((await send('pulse',500)).ok,true);
  assert.equal(played.at(-1).volume,1,'out of range volume clamped');
  for (const name of ['holo','soft','pulse','female']) {
    const b=fs.readFileSync(path.join(root,'assets',name+'.wav'));
    assert.equal(b.toString('ascii',0,4),'RIFF',name+' RIFF');
    assert.equal(b.toString('ascii',8,12),'WAVE',name+' WAVE');
    assert(b.length>20000,name+' contains audio');
  }
  console.log('PASS offscreen: female WAV playback, selected preview volume, zero-volume mute, PCM assets');
})().catch(err=>{console.error(err);process.exitCode=1;});
