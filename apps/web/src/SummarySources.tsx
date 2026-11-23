import {useEffect,useState} from 'react';
import {call} from './bridge';
import type {SummarySource} from '../../../packages/contracts/bridge';
import {dateFor} from './journal';

const labels:Record<string,string>={reported_text:'Written memory',recognized_speech:'Recording transcript',user_media:'Uploaded memory',uncertain_visual:'Photo clue',photo_inventory:'Photos count',calendar_plan:'Calendar plan',selected_city_weather:'Weather',journal_context:'Linked person or event',summary_guidance:'Summary guidance'};
export default function SummarySources({id,scope,expected,onOpen}:{id:string;scope:string;expected:number;onOpen:(source:SummarySource)=>void}){
  const [open,setOpen]=useState(false),[sources,setSources]=useState<SummarySource[]>(),[error,setError]=useState('');
  useEffect(()=>{if(!open)return;let active=true;setSources(undefined);setError('');void call('summary.sources',{id,scope}).then(value=>{if(active)setSources(value);}).catch(error=>{if(active)setError(error instanceof Error?error.message:'Sources unavailable.');});return()=>{active=false;};},[id,scope,open]);
  return <details className="summary-sources" open={open} onToggle={event=>setOpen(event.currentTarget.open)}>
    <summary>View summary sources</summary>
    {error?<p role="alert">{error}</p>:!sources?<p role="status">Loading sources…</p>:<>
      <p className="small-note">These are the sources referenced by the generated summary. Photo descriptions are uncertain; calendar items are plans.</p>
      {sources.length<expected&&<p className="small-note">Some referenced sources are unavailable or no longer accessible.</p>}
      {sources.length?<ul>{sources.map(source=><li key={source.id}><div><strong>{labels[source.kind]??'Source'}</strong><span> · {dateFor(source.day).toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'})}</span></div><p>{source.text.length>350?source.text.slice(0,347)+'…':source.text}</p><button type="button" onClick={()=>onOpen(source)}>Open {labels[source.kind]??'source'}</button></li>)}</ul>:<p>No referenced sources are currently available.</p>}
    </>}
  </details>;
}
