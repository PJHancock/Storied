import {call} from './bridge.ts';
import type {SpeechJob, MediaAsset, Entry} from '../../../packages/contracts/bridge';
export function appendDictation(existing: string, spoken: string) {
  const text=spoken.trim(); if(!text)throw new Error('No speech recognized.');
  const combined=existing.trim()?`${existing}\n\n${text}`:text;
  if(new TextEncoder().encode(combined).byteLength>100_000)throw new Error('Combined text exceeds 100 KB. The audio has been kept so you can retry.');
  return combined;
}
export function insertDictation(existing: string, spoken: string, start: number, end: number) {
  const text=spoken.trim(); if(!text) return {text:existing,caret:start};
  const from=Math.max(0,Math.min(start,existing.length)),to=Math.max(from,Math.min(end,existing.length));
  const before=existing.slice(0,from),after=existing.slice(to);
  const prefix=before&&!/\s$/.test(before)?' ':'';
  const suffix=after&&!/^\s/.test(after)?' ':'';
  const combined=before+prefix+text+suffix+after;
  if(new TextEncoder().encode(combined).byteLength>100_000)throw new Error('Combined text exceeds 100 KB.');
  return {text:combined,caret:before.length+prefix.length+text.length};
}
export function recordingAccounts(assets: MediaAsset[]): Array<Entry & {transcriptSource?: boolean; visualSource?: boolean; visualText?: string; originalMediaSource?: boolean; mediaKind?: string}> {
  return assets.filter(a=>a.allowsAI===true).map(a=>({
    id:`recording:${a.id}`,day:a.day,body:[a.transcript?.trim(),a.analysisText?.trim(),!a.transcript?.trim()&&!a.analysisText?.trim()?`A user-added ${a.kind} file named ${a.filename} has not had its contents extracted.`:undefined].filter(Boolean).join('\n\n'),timezone:'',allowsAI:true,revision:a.analysisRevision??0,
    createdAt:a.createdAt,updatedAt:a.createdAt,transcriptSource:Boolean(a.transcript?.trim()),visualSource:Boolean(a.analysisText?.trim()),visualText:a.analysisText?.trim(),originalMediaSource:true,mediaKind:a.kind,
  }));
}
export async function transcribeRecording(asset: MediaAsset, purpose: 'dictation'|'summary', progress: (message:string)=>void, signal?:AbortSignal): Promise<SpeechJob> {
  if(signal?.aborted)throw new DOMException('Cancelled','AbortError');
  const job=await call('speech.start',{id:asset.id,purpose});
  const cancel=()=>{void call('speech.cancel',{id:job.id}).catch(()=>undefined);};
  signal?.addEventListener('abort',cancel,{once:true});
  if(signal?.aborted)cancel();
  try{
    let state=job;
    const deadline=Date.now()+30*60*1000;
    while(state.state==='running'){
      progress(state.message);
      if(signal?.aborted)throw new DOMException('Cancelled','AbortError');
      if(Date.now()>deadline){cancel();throw new Error('Processing timed out. Original recording retained.');}
      await new Promise(resolve=>setTimeout(resolve,600));
      state=await call('speech.status',{id:job.id});
    }
    if(state.state!=='complete')throw new Error(state.message);
    return state;
  }catch(error){cancel();throw error;}finally{signal?.removeEventListener('abort',cancel);}
}
