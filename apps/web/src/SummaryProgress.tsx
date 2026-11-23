import {useEffect,useState} from 'react';
import type {SummaryJob} from '../../../packages/contracts/bridge';

export default function SummaryProgress({job,cancel,retry,paused=false}:{job?:SummaryJob;cancel:()=>void;retry:()=>void;paused?:boolean}){
  const [seconds,setSeconds]=useState(0);
  const phase=paused?'paused':job?.state??'preparing';
  useEffect(()=>{
    setSeconds(0);
    if(phase!=='running'&&phase!=='preparing')return;
    const started=Date.now();
    const timer=setInterval(()=>setSeconds(Math.floor((Date.now()-started)/1000)),1000);
    return()=>clearInterval(timer);
  },[job?.id,phase]);
  if(paused)return <aside className="summary-progress summary-progress--paused" role="status"><span className="summary-spinner" aria-hidden="true"/><strong>Summary generation paused while this week syncs.</strong></aside>;
  if(phase==='complete')return null;
  const pending=phase==='preparing'||phase==='running';
  return <aside className="summary-progress" role="status" aria-live="polite" aria-atomic="true">
    {pending&&<span className="summary-spinner" aria-hidden="true"/>}
    <div><strong>{phase==='preparing'?'Loading sources for summaries…':job?.message}</strong>
      {pending&&<p>{phase==='preparing'?'Waiting for memories, Photos, calendar, and weather.':'Saved summaries stay visible while updates finish. Generation can take up to 3 minutes.'}</p>}
    </div>
    {pending&&<span className="summary-elapsed" aria-live="off">{Math.floor(seconds/60)}:{String(seconds%60).padStart(2,'0')} elapsed</span>}
    {(phase==='failed'||phase==='cancelled')&&<button type="button" onClick={retry}>Retry summary</button>}
    {phase==='running'&&<button type="button" onClick={cancel}>Cancel</button>}
  </aside>;
}
