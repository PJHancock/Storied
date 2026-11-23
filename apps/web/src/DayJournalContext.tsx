import React,{useEffect,useState} from 'react';
import {call,isNative} from './bridge';
import type {JournalContextItem} from '../../../packages/contracts/bridge';

export default function DayJournalContext({day,refreshKey,changed}:{day:string;refreshKey:number;changed:()=>void}){
  const [library,setLibrary]=useState<JournalContextItem[]>([]),[linked,setLinked]=useState<JournalContextItem[]>([]),[selected,setSelected]=useState('');
  const [busy,setBusy]=useState(false),[error,setError]=useState('');
  useEffect(()=>{
    if(!isNative())return;
    let active=true;
    void Promise.all([call('context.items.list',{}),call('context.day.list',{day})]).then(([items,current])=>{if(active){setLibrary(items);setLinked(current);setSelected('');}}).catch(e=>{if(active)setError(e instanceof Error?e.message:'Could not load day context.');});
    return()=>{active=false;};
  },[day,refreshKey]);
  async function setLink(id:string,add:boolean){setBusy(true);setError('');try{await call('context.day.set',{day,id,linked:add});const [items,current]=await Promise.all([call('context.items.list',{}),call('context.day.list',{day})]);setLibrary(items);setLinked(current);setSelected('');changed();}catch(e){setError(e instanceof Error?e.message:'Could not update this day’s context.');}finally{setBusy(false);}}
  if(!isNative())return <section className="day-journal-context"><h2>People &amp; events</h2><p>Reusable journal context is available in the native app.</p></section>;
  const available=library.filter(item=>!linked.some(current=>current.id===item.id));
  return <section className="day-journal-context" aria-label="People and events for this day">
    <div className="context-library-heading"><div><span className="eyebrow">OPTIONAL SUMMARY CONTEXT</span><h2>People &amp; events</h2></div><span>{linked.length} linked</span></div>
    <p>Link saved context only when it helps explain a memory on this day. A link does not say someone attended or an event happened.</p>
    {linked.map(item=><article className="day-context-item" key={item.id}><div><span className="eyebrow">{item.kind.toUpperCase()}</span><strong>{item.title}</strong>{item.aliases&&<small>Also known as: {item.aliases}</small>}{item.details&&<p>{item.details}</p>}</div><button type="button" disabled={busy} aria-label={`Remove ${item.title} context from this day`} onClick={()=>void setLink(item.id,false)}>Remove</button></article>)}
    {available.length>0?<div className="day-context-add"><label htmlFor="day-context-picker">Add from your context library<select id="day-context-picker" value={selected} disabled={busy} onChange={event=>setSelected(event.target.value)}><option value="">Choose a person or event</option>{available.map(item=><option key={item.id} value={item.id}>{item.kind==='person'?'Person':'Event'} · {item.title}</option>)}</select></label><button type="button" disabled={busy||!selected} onClick={()=>void setLink(selected,true)}>Link to this day</button></div>:library.length===0?<p className="small-note">Add people or events in Workshop to link them here.</p>:null}
    {error&&<p role="alert" className="small-note context-error">{error}</p>}
  </section>;
}
