import React,{useEffect,useRef,useState} from 'react';
import {call,isNative} from './bridge';
import {transcribeRecording} from './speech';
import {analyzeVisualMemory} from './visuals';
import {loadMediaBlob} from './media';
import {localDay} from './journal';
import type {MediaAsset} from '../../../packages/contracts/bridge';

function contentTitle(asset:MediaAsset){
  const content=asset.kind==='audio'?asset.transcript:(asset.analysisText||asset.transcript);
  if(!content?.trim())return asset.filename;
  const firstLine=content
    .replace(/Possible detailed visual description\s*\([^)]*\);?\s*/gi,'')
    .replace(/(?:Visual clues|Text seen|Recognized speech):\s*/gi,'')
    .split(/\r?\n/)[0]
    .replace(/\s+/g,' ')
    .trim();
  if(!firstLine)return asset.filename;
  const sentence=firstLine.match(/^.{1,180}?[.!?](?=\s|$)/)?.[0]??firstLine;
  const words=sentence.match(/\S+/g)??[];
  let title=words.slice(0,9).join(' ');
  if(words.length>9)title+='…';
  if(title.length>72)title=title.slice(0,68).replace(/\s+\S*$/,'')+'…';
  return title||asset.filename;
}

export default function MediaAttachment({asset,updated,remove,failure,progress,headlineSelected,selectHeadline,speechError,reportSpeechError,changed,moved}:{asset:MediaAsset;updated:(asset:MediaAsset)=>void;remove:(id:string)=>Promise<void>;failure:(error:unknown)=>void;progress:(message:string)=>void;headlineSelected:boolean;selectHeadline:()=>void;speechError?:string;reportSpeechError:(id:string,message?:string)=>void;changed:()=>Promise<void>;moved:(day:string)=>void}){
  const [preview,setPreview]=useState(''),[source,setSource]=useState(''),[busy,setBusy]=useState(false),[confirm,setConfirm]=useState(false),[moving,setMoving]=useState(false),[moveToDay,setMoveToDay]=useState(localDay(new Date())),[editingTranscript,setEditingTranscript]=useState(false),[transcriptDraft,setTranscriptDraft]=useState(asset.transcript??'');
  const [processing,setProcessing]=useState(false),[analysisMessage,setAnalysisMessage]=useState('');
  const controller=useRef<AbortController|null>(null);
  useEffect(()=>()=>controller.current?.abort(),[]);
  useEffect(()=>{setTranscriptDraft(asset.transcript??'');},[asset.transcript]);
  useEffect(()=>{if(speechError)setAnalysisMessage(speechError);},[speechError]);
  async function include(enabled:boolean){setBusy(true);try{const next=await call('media.setAI',{id:asset.id,enabled});updated(next);if(enabled&&(asset.kind==='photo'||asset.kind==='video'))await analyzeVisual(next);}catch(error){if(!(error instanceof DOMException&&error.name==='AbortError'))failure(error);}finally{setBusy(false);}}
  async function analyzeVisual(source:MediaAsset=asset){const work=new AbortController();controller.current=work;setProcessing(true);try{const result=await analyzeVisualMemory(source,message=>{setAnalysisMessage(message);progress(message);},work.signal);if(result.asset)updated(result.asset);setAnalysisMessage(result.message);}catch(error){setAnalysisMessage(error instanceof DOMException&&error.name==='AbortError'?'Analysis cancelled. Original media retained.':'Analysis did not finish. Original media retained; retry when ready.');if(!(error instanceof DOMException&&error.name==='AbortError'))failure(error);}finally{controller.current=null;setProcessing(false);progress('');}}
  async function process(){const work=new AbortController();controller.current=work;reportSpeechError(asset.id);setAnalysisMessage('');setProcessing(true);try{
    const result=await transcribeRecording(asset,'summary',message=>{setAnalysisMessage(message);progress(message);},work.signal);
    if(result.asset)updated(result.asset);reportSpeechError(asset.id);setAnalysisMessage('Recognized speech included in summaries. Review it for mistakes.');
  }catch(error){const message=error instanceof Error?error.message:'Transcription failed. The original recording is still saved.';setAnalysisMessage(error instanceof DOMException&&error.name==='AbortError'?'Transcription cancelled. Original recording retained.':message);if(!(error instanceof DOMException&&error.name==='AbortError'))reportSpeechError(asset.id,message);}finally{controller.current=null;setProcessing(false);progress('');}}
  useEffect(()=>{let active=true;if(asset.kind==='photo'&&asset.hasPreview)void call('media.preview',{id:asset.id}).then(result=>{if(active)setPreview(`data:image/jpeg;base64,${result.base64}`);}).catch(failure);return()=>{active=false;};},[asset.id,asset.kind,asset.hasPreview]);
  useEffect(()=>()=>{if(source)URL.revokeObjectURL(source);},[source]);
  async function load(){setBusy(true);try{const blob=await loadMediaBlob(asset,progress);setSource(URL.createObjectURL(blob));progress('');}catch(error){failure(error);}finally{setBusy(false);}}
  async function deleteAsset(){setBusy(true);try{await remove(asset.id);setConfirm(false);}catch(error){failure(error);}finally{setBusy(false);}}
  async function moveAsset(){setBusy(true);controller.current?.abort();try{await call('media.move',{id:asset.id,toDay:moveToDay});await changed();moved(moveToDay);setMoving(false);}catch(error){failure(error);}finally{setBusy(false);}}
  async function saveTranscript(){setBusy(true);try{const next=await call('media.updateTranscript',{id:asset.id,transcript:transcriptDraft,expectedRevision:asset.analysisRevision??0});updated(next);setEditingTranscript(false);setAnalysisMessage('Transcript saved and included in AI features.');}catch(error){failure(error);}finally{setBusy(false);}}
  const size=asset.byteCount<1024*1024?`${Math.max(1,Math.round(asset.byteCount/1024))} KB`:`${(asset.byteCount/1024/1024).toFixed(1)} MB`;
  const title=contentTitle(asset);
  return <article id={`source-media-${encodeURIComponent(asset.id)}`} tabIndex={-1} className="media-memory note-paper"><header><span className="eyebrow">{asset.kind.toUpperCase()} MEMORY · {size}</span><div className="memory-actions"><button type="button" disabled={busy} aria-expanded={confirm} onClick={()=>{setConfirm(!confirm);setMoving(false);}}>Delete</button><button type="button" disabled={busy||!isNative()} aria-expanded={moving} onClick={()=>{setMoving(!moving);setConfirm(false);setMoveToDay(localDay(new Date()));}}>Move</button>{asset.transcript&&<button type="button" disabled={busy||processing||!asset.allowsAI} onClick={()=>{setTranscriptDraft(asset.transcript??'');setEditingTranscript(!editingTranscript);}}>{editingTranscript?'Cancel edit':'Edit transcript'}</button>}<label className="use-ai-toggle"><span>Use for AI features</span><input aria-label={`Use ${title} for AI features`} type="checkbox" checked={asset.allowsAI===true} disabled={busy||processing||editingTranscript} onChange={event=>void include(event.target.checked)}/></label></div></header>{moving&&<div className="move-memory-controls"><label>Move to day<input aria-label={`Destination day for ${title}`} type="date" value={moveToDay} max={localDay(new Date())} disabled={busy} onChange={event=>setMoveToDay(event.target.value)}/></label><button type="button" className="primary" disabled={busy||!isNative()||!moveToDay||moveToDay===asset.day} onClick={()=>void moveAsset()}>Move memory</button><button type="button" disabled={busy} onClick={()=>setMoving(false)}>Cancel</button></div>}<h3>{title}</h3>{title!==asset.filename&&<small className="source-file-name">Original file: {asset.filename}</small>}
    {asset.kind==='photo'?(<>{preview?<img className="attachment-photo" src={preview} alt={`Photo preview: ${title}`}/>:<p className="quiet-note">Photo preview unavailable.</p>}<button disabled={busy||!!source} onClick={()=>void load()}>{source?'Original loaded':busy?'Loading original…':'View original photo'}</button><button type="button" className="headline-photo-choice" aria-pressed={headlineSelected} disabled={!asset.hasPreview} onClick={selectHeadline}>{headlineSelected?'Day headline photo':'Use as headline photo'}</button>{source&&<img className="attachment-photo" src={source} alt={`Original photo: ${title}`}/>}</>):null}
    {asset.kind==='audio'?(source?<audio controls preload="metadata" src={source}/>:<button className="primary" disabled={busy} onClick={()=>void load()}>{busy?'Loading audio…':'Load audio'}</button>):null}
    {asset.kind==='video'?(source?<video controls playsInline preload="metadata" src={source}/>:<button className="primary" disabled={busy} onClick={()=>void load()}>{busy?'Loading video…':'Load video'}</button>):null}
    <section className="media-analysis" aria-label="Memory analysis">
      {(asset.transcript||editingTranscript)&&asset.allowsAI&&<details open={editingTranscript}><summary>{asset.transcript?'Transcript · may contain mistakes':'Add transcript manually'}</summary>{editingTranscript?<><label className="transcript-edit-label" htmlFor={`transcript-${asset.id}`}>Transcript text<textarea id={`transcript-${asset.id}`} className="transcript-editor" maxLength={100000} value={transcriptDraft} onChange={event=>setTranscriptDraft(event.target.value)} disabled={busy}/></label><div className="actions"><button className="primary" type="button" disabled={busy||!transcriptDraft.trim()} onClick={()=>void saveTranscript()}>Save transcript</button><button type="button" disabled={busy} onClick={()=>{setTranscriptDraft(asset.transcript??'');setEditingTranscript(false);}}>Cancel</button></div></>:<p className="recording-transcript">{asset.transcript}</p>}</details>}
      {asset.analysisText&&asset.allowsAI&&<details><summary>Visual clues · may be incomplete</summary><p className="recording-transcript">{asset.analysisText}</p></details>}
      {(asset.kind==='photo'||asset.kind==='video')&&asset.allowsAI===true&&(processing?<button onClick={()=>controller.current?.abort()}>Cancel visual analysis</button>:<button disabled={busy} onClick={()=>void analyzeVisual()}>{asset.analysisText?'Improve visual description':'Analyze visual details'}</button>)}
      {asset.kind!=='photo'&&asset.allowsAI===true&&(processing?<button onClick={()=>controller.current?.abort()}>Cancel transcription</button>:<button disabled={busy} onClick={()=>void process()}>{asset.transcript?'Retry transcription':'Transcribe for summaries and Find'}</button>)}
      {asset.kind!=='photo'&&asset.allowsAI===true&&!asset.transcript&&!editingTranscript&&<button disabled={busy||processing} onClick={()=>{setTranscriptDraft('');setEditingTranscript(true);}}>Add transcript manually</button>}
      <p className="small-note" role={speechError?'alert':'status'}>{analysisMessage||(asset.kind==='audio'?'Speech is transcribed and embedded locally when available.':asset.analysisText?'The selected provider adds a detailed description when available; local Vision labels and visible text are also included. Review visual clues for mistakes.':'No visual analysis has run yet. The original stays saved.')}</p>
    </section>
    <small>Added {new Date(asset.createdAt).toLocaleString()}</small>
    {confirm&&<div className="confirmation"><p>Delete this uploaded {asset.kind} permanently from this journal?</p><button disabled={busy} onClick={()=>void deleteAsset()}>Delete permanently</button> <button disabled={busy} onClick={()=>setConfirm(false)}>Keep it</button></div>}
  </article>;
}
