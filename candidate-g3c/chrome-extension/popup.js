'use strict';document.getElementById('send').addEventListener('click',async()=>{
 const status=document.getElementById('status');status.textContent='Sending…';
 try{
 const result=await chrome.runtime.sendMessage({type:'G3C_SEND_TEST'});
 status.textContent=result?.ok?'Test banner accepted. Click it to return to the exact chat.':('HOLD: '+(result?.error||'unknown'));
 }catch(_){status.textContent='HOLD: test communication unavailable';}
});