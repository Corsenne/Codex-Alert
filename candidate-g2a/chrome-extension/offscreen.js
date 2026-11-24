'use strict';
const SOUNDS=Object.freeze({holo:'holo.wav',soft:'soft.wav',pulse:'pulse.wav',female:'female.wav'});
let currentSound=null;
function stopCurrent(){
  if(currentSound){currentSound.pause();currentSound.currentTime=0;currentSound=null;}
}
chrome.runtime.onMessage.addListener((message,sender,respond)=>{
  if(message?.target!=='offscreen'||!['PLAY_SOUND','STOP_SOUND'].includes(message.type))return;
  (async()=>{
    try{
      stopCurrent();
      if(message.type==='STOP_SOUND'){respond({ok:true});return;}
      const file=SOUNDS[message.soundId]||SOUNDS.holo;
      const audio=new Audio(chrome.runtime.getURL('assets/'+file));
      const volume=Number(message.volume);
      audio.volume=Number.isFinite(volume)?Math.min(100,Math.max(0,volume))/100:.85;
      currentSound=audio;
      audio.addEventListener('ended',()=>{if(currentSound===audio)currentSound=null;},{once:true});
      if(audio.volume>0)await audio.play();
      respond({ok:true});
    }catch(e){respond({ok:false,error:String(e.message)});}
  })();
  return true;
});
