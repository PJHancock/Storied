import React,{useEffect,useRef,useState} from 'react';
import {call} from './bridge';
import {saveMediaFile} from './media';
import {transcribeRecording} from './speech';
import {analyzeVisualMemory} from './visuals';
import type {LiveDictationStatus,MediaAsset} from '../../../packages/contracts/bridge';

type CaptureMode='dictation'|'audio'|'video';
export default function MediaComposer({day,existingText,allowsAI,disabled,busyChanged,onText,onAdded,onStatus,failure,reportSpeechError,onDictationBegin,onDictationText,onDictationCancel}:{day:string;existingText:string;allowsAI:boolean;disabled:boolean;busyChanged:(busy:boolean)=>void;onText:(text:string)=>void;onAdded:(asset:MediaAsset)=>void;onStatus:(status:string)=>void;failure:(error:unknown)=>void;reportSpeechError:(id:string,message?:string)=>void;onDictationBegin:()=>void;onDictationText:(text:string,final:boolean)=>void;onDictationCancel:()=>void}){
  const input=useRef<HTMLInputElement>(null),recorder=useRef<MediaRecorder|null>(null),chunks=useRef<Blob[]>([]),stream=useRef<MediaStream|null>(null),discard=useRef(false),previewRef=useRef<HTMLVideoElement>(null),uploadController=useRef<AbortController|null>(null),liveDictationID=useRef<string|null>(null),mounted=useRef(true);
  const [recording,setRecording]=useState<CaptureMode|null>(null),[cameraStream,setCameraStream]=useState<MediaStream|null>(null),[elapsed,setElapsed]=useState(0),[saving,setSaving]=useState(false),[starting,setStarting]=useState(false),[dictationFinishing,setDictationFinishing]=useState(false);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;discard.current=true;uploadController.current?.abort();if(liveDictationID.current)void call('dictation.cancel',{id:liveDictationID.current}).catch(()=>undefined);if(recorder.current&&recorder.current.state!=='inactive')recorder.current.stop();stream.current?.getTracks().forEach(track=>track.stop());};},[]);
  useEffect(()=>{if(recording!=='video'||!cameraStream||!previewRef.current)return;previewRef.current.srcObject=cameraStream;void previewRef.current.play().catch(()=>undefined);},[recording,cameraStream]);
  useEffect(()=>{if(!recording||dictationFinishing)return;const started=Date.now(),limit=recording==='video'?120:recording==='dictation'?120:900;const interval=window.setInterval(()=>{const seconds=Math.floor((Date.now()-started)/1000);setElapsed(seconds);if(seconds>=limit)stopCapture(false);},1000);const onHidden=()=>{if(document.hidden)stopCapture(false);};document.addEventListener('visibilitychange',onHidden);return()=>{window.clearInterval(interval);document.removeEventListener('visibilitychange',onHidden);};},[recording,dictationFinishing]);
  async function keepFile(file:File,controller:AbortController){
    let asset=await saveMediaFile(file,day,onStatus,controller.signal);
    let published=false;
    let stage:'saving'|'visual'|'speech'='saving';
    try{
      asset=await call('media.setAI',{id:asset.id,enabled:allowsAI});
      onAdded(asset);published=true;onStatus(`Saved ${file.name} to this day.`);
      if((asset.kind==='photo'||asset.kind==='video')&&allowsAI){
        stage='visual';
        const visual=await analyzeVisualMemory(asset,onStatus,controller.signal);
        if(visual.asset){asset=visual.asset;onAdded(asset);}
        onStatus(visual.message);
      }
      if(asset.kind!=='photo'&&allowsAI){
        stage='speech';
        const result=await transcribeRecording(asset,'summary',onStatus,controller.signal);
        if(result.asset)onAdded(result.asset);
        reportSpeechError(asset.id);
        onStatus('Recording saved and transcribed for summaries. Review recognized text below.');
      }
    }catch(error){
      // Failed recognition never discards an original; it remains playable and retryable.
      if(!published)onAdded(asset);
      if(error instanceof DOMException&&error.name==='AbortError')onStatus('Processing cancelled. Original media retained.');
      else if(stage==='speech'){
        const message=error instanceof Error?error.message:'Transcription failed. The original recording is still saved.';
        reportSpeechError(asset.id,message);onStatus('Transcription needs attention in this recording’s controls below.');
      }
      else {failure(error);onStatus(asset.kind==='photo'||asset.kind==='video'?'Original media saved. You can retry visual analysis below.':'Original recording saved. You can retry transcription below.');}
    }
  }
  async function storeFile(file:File){
    const controller=new AbortController();uploadController.current=controller;setSaving(true);busyChanged(true);
    try{await keepFile(file,controller);}catch(error){failure(error);}finally{uploadController.current=null;if(mounted.current){setSaving(false);busyChanged(false);}}
  }
  async function chooseFiles(files:FileList|null){
    if(!files?.length)return;const controller=new AbortController();uploadController.current=controller;setSaving(true);busyChanged(true);let currentText=existingText;
    try{for(const file of Array.from(files)){
      if(controller.signal.aborted)throw new DOMException('Cancelled','AbortError');
      if(/\.(txt|md)$/i.test(file.name)||file.type==='text/plain'||file.type==='text/markdown'){
        if(file.size>100_000)throw new Error(`${file.name} exceeds the 100 KB text limit.`);
        const imported=await file.text(),combined=currentText?`${currentText}\n\n${imported}`:imported;
        if(new TextEncoder().encode(combined).byteLength>100_000)throw new Error('Combined text exceeds 100 KB.');
        await call('draft.save',{day,body:combined});onText(combined);currentText=combined;onStatus(`Loaded ${file.name} into the saved text draft. Save memory to keep it.`);
      }else await keepFile(file,controller);
    }}catch(error){if(error instanceof DOMException&&error.name==='AbortError')onStatus('Upload cancelled.');else failure(error);}finally{uploadController.current=null;setSaving(false);busyChanged(false);if(input.current)input.current.value='';}
  }
  async function pollDictation(id:string){
    let lastTranscript='';
    try{
      while(mounted.current&&liveDictationID.current===id){
        const status:LiveDictationStatus=await call('dictation.status',{id});
        if(status.transcript!==lastTranscript){lastTranscript=status.transcript;onDictationText(status.transcript,status.state==='complete');}
        if(status.state==='complete'){
          liveDictationID.current=null;setRecording(null);setDictationFinishing(false);busyChanged(false);
          onStatus('Dictation complete. Review the text, then save your memory.');return;
        }
        if(status.state==='failed'||status.state==='cancelled'){
          liveDictationID.current=null;setRecording(null);setDictationFinishing(false);busyChanged(false);
          failure(new Error(status.message));onStatus(status.transcript?'Dictation stopped. Recognized text remains in your draft.':'Dictation stopped without recognized text.');return;
        }
        await new Promise(resolve=>setTimeout(resolve,250));
      }
    }catch(error){
      if(liveDictationID.current===id){liveDictationID.current=null;setRecording(null);setDictationFinishing(false);busyChanged(false);failure(error);onStatus('Dictation connection ended. Any recognized text remains in your draft.');}
    }
  }
  async function startDictation(){
    setStarting(true);busyChanged(true);onDictationBegin();onStatus('Starting on-device dictation…');
    try{
      const status:LiveDictationStatus=await call('dictation.start',{});
      if(!mounted.current){void call('dictation.cancel',{id:status.id}).catch(()=>undefined);return;}
      liveDictationID.current=status.id;setElapsed(0);setDictationFinishing(false);setRecording('dictation');
      onStatus('Listening. Recognized words will appear in your draft as you speak.');
      void pollDictation(status.id);
    }catch(error){onDictationCancel();busyChanged(false);failure(error);onStatus('Dictation could not start.');}
    finally{if(mounted.current)setStarting(false);}
  }
  async function startCapture(mode:CaptureMode){
    if(disabled||saving||starting)return;
    if(mode==='dictation'){await startDictation();return;}
    if(!navigator.mediaDevices?.getUserMedia||typeof MediaRecorder==='undefined'){failure(new Error('Recording is unavailable in this WebView. Upload a media file instead.'));return;}
    setStarting(true);busyChanged(true);onStatus(mode==='video'?'Waiting for camera and microphone access…':'Waiting for microphone access…');
    try{
      const captured=await navigator.mediaDevices.getUserMedia(mode==='video'?{audio:true,video:{facingMode:'environment'}}:{audio:true});
      if(!mounted.current){captured.getTracks().forEach(track=>track.stop());return;}
      stream.current=captured;chunks.current=[];discard.current=false;
      const kind=mode==='video'?'video':'audio';
      const candidates=kind==='audio'?['audio/mp4','audio/webm;codecs=opus','audio/webm']:['video/mp4','video/quicktime','video/webm;codecs=vp8,opus','video/webm'];
      const mimeType=candidates.find(candidate=>MediaRecorder.isTypeSupported(candidate));
      const active=mimeType?new MediaRecorder(captured,{mimeType}):new MediaRecorder(captured);recorder.current=active;
      active.ondataavailable=event=>{if(event.data.size)chunks.current.push(event.data);if(chunks.current.reduce((n,c)=>n+c.size,0)>78*1024*1024)stopCapture(false);};
      active.onerror=()=>{failure(new Error('Recording failed. Check device access and storage.'));stopCapture(true);};
      active.onstop=()=>{
        const actualMime=active.mimeType||chunks.current.find(part=>part.type)?.type||(kind==='audio'?'audio/mp4':'video/mp4');
        const blob=new Blob(chunks.current,{type:actualMime});captured.getTracks().forEach(track=>track.stop());stream.current=null;recorder.current=null;
        if(!mounted.current)return;setCameraStream(null);setRecording(null);
        if(discard.current){chunks.current=[];busyChanged(false);onStatus('Recording discarded.');return;}
        if(!blob.size){failure(new Error('Recording was empty. Check microphone access.'));busyChanged(false);return;}
        const extension=actualMime.includes('quicktime')?'mov':actualMime.includes('webm')?'webm':kind==='audio'?'m4a':'mp4';
        void storeFile(new File([blob],`${kind}-${new Date().toISOString().replace(/[:.]/g,'-')}.${extension}`,{type:actualMime}));
      };
      active.start(1000);setElapsed(0);setRecording(mode);if(mode==='video')setCameraStream(captured);
      onStatus(`Recording full ${kind}…`);
    }catch(error){stream.current?.getTracks().forEach(track=>track.stop());stream.current=null;setCameraStream(null);setRecording(null);busyChanged(false);failure(error);}finally{if(mounted.current)setStarting(false);}
  }
  function stopCapture(discardRecording:boolean){
    if(recording==='dictation'){
      const id=liveDictationID.current;
      if(!id)return;
      if(discardRecording){liveDictationID.current=null;void call('dictation.cancel',{id}).catch(()=>undefined);onDictationCancel();setRecording(null);setDictationFinishing(false);busyChanged(false);onStatus('Dictation discarded.');}
      else if(!dictationFinishing){setDictationFinishing(true);onStatus('Finishing dictation…');void call('dictation.stop',{id}).catch(error=>{setDictationFinishing(false);failure(error);});}
      return;
    }
    discard.current=discardRecording;const current=recorder.current;if(current&&current.state!=='inactive')current.stop();else{stream.current?.getTracks().forEach(track=>track.stop());stream.current=null;setCameraStream(null);setRecording(null);busyChanged(false);}
  }
  const label=(seconds:number)=>`${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;
  return <div className="composer-tools" aria-label="Memory input options"><div className="media-actions">
    <input ref={input} className="visually-hidden-file" type="file" accept="image/*,audio/*,video/*,.txt,.md" multiple disabled={disabled||saving||!!recording||starting} onChange={event=>void chooseFiles(event.target.files)}/>
    {recording?<><span className="recording-indicator" role="status">{recording==='dictation'?(dictationFinishing?'Finishing dictation':'Dictating text'):recording==='audio'?'Recording audio':'Recording video'} · {label(elapsed)}</span><button className="primary" disabled={dictationFinishing} onClick={()=>stopCapture(false)}>{recording==='dictation'?'Finish dictation':'Stop & save recording'}</button><button disabled={dictationFinishing} onClick={()=>stopCapture(true)}>Discard</button></>:<>
      <button disabled={disabled||saving||starting} onClick={()=>void startCapture('dictation')}>Dictate text</button>
      <button disabled={disabled||saving||starting} onClick={()=>void startCapture('audio')}>Record audio</button>
      <button disabled={disabled||saving||starting} onClick={()=>void startCapture('video')}>Record video</button>
      <button disabled={disabled||saving||starting} onClick={()=>input.current?.click()}>Upload a file</button>
    </>}
    {saving&&<button onClick={()=>uploadController.current?.abort()}>Cancel processing</button>}
  </div>{recording==='video'&&<video ref={previewRef} className="capture-preview" muted autoPlay playsInline/>}
    <p className="small-note">Type above or dictate into your draft. Dictated words appear as they are recognized and are inserted at the cursor or replace selected text. Dictation runs on this device and lasts up to 2 minutes. Photo/video clues use Apple’s on-device image model when supported, with local Vision labels and text recognition as fallback. If OpenAI visual understanding is enabled in Settings, resized uploaded photos or up to three sampled video frames are sent to OpenAI instead. Connected Photos-library images are not sent. Audio/video keep the full original; included recordings can also be transcribed locally for summaries. Audio recordings last up to 15 minutes; video lasts up to 2 minutes.</p>
  </div>;
}
