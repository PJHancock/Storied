import React,{useEffect,useState} from 'react';
import {call,isNative} from './bridge';
import type {JournalContextItem} from '../../../packages/contracts/bridge';

export default function JournalContextSettings({changed}:{changed:()=>void}){
  const [guidance,setGuidance]=useState(''),[savedGuidance,setSavedGuidance]=useState('');
  const [items,setItems]=useState<JournalContextItem[]>([]),[editing,setEditing]=useState<JournalContextItem|null>(null),[formOpen,setFormOpen]=useState(false);
  const [kind,setKind]=useState<'person'|'event'>('person'),[title,setTitle]=useState(''),[aliases,setAliases]=useState(''),[details,setDetails]=useState('');
  const [busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[message,setMessage]=useState(''),[error,setError]=useState(''),[confirmDelete,setConfirmDelete]=useState('');
  async function load(){
    if(!isNative()){setLoading(false);return;}
    setLoading(true);
    try{const [profile,library]=await Promise.all([call('context.guidance.get',{}),call('context.items.list',{})]);setGuidance(profile.text);setSavedGuidance(profile.text);setItems(library);}
    catch(e){setError(e instanceof Error?e.message:'Could not load journal context.');}
    finally{setLoading(false);}
  }
  useEffect(()=>{void load();},[]);
  function resetForm(){setEditing(null);setFormOpen(false);setKind('person');setTitle('');setAliases('');setDetails('');setConfirmDelete('');}
  function editItem(item:JournalContextItem){setEditing(item);setFormOpen(true);setKind(item.kind);setTitle(item.title);setAliases(item.aliases);setDetails(item.details);setError('');setMessage('');}
  async function saveGuidance(){setBusy(true);setError('');setMessage('');try{const saved=await call('context.guidance.save',{text:guidance});setGuidance(saved.text);setSavedGuidance(saved.text);setMessage('Summary guidance saved. Automatic summaries will refresh.');changed();}catch(e){setError(e instanceof Error?e.message:'Could not save summary guidance.');}finally{setBusy(false);}}
  async function saveItem(event:React.FormEvent){event.preventDefault();setBusy(true);setError('');setMessage('');try{
    if(editing){await call('context.item.update',{id:editing.id,kind,title,aliases,details,expectedRevision:editing.revision});setMessage(`${kind==='person'?'Person':'Event'} context updated.`);}
    else {await call('context.item.create',{id:crypto.randomUUID(),kind,title,aliases,details});setMessage(`${kind==='person'?'Person':'Event'} context added.`);}
    resetForm();setItems(await call('context.items.list',{}));changed();
  }catch(e){setError(e instanceof Error?e.message:'Could not save this journal context.');}finally{setBusy(false);}}
  async function deleteItem(item:JournalContextItem){setBusy(true);setError('');setMessage('');try{await call('context.item.delete',{id:item.id,expectedRevision:item.revision});setItems(await call('context.items.list',{}));if(editing?.id===item.id)resetForm();setConfirmDelete('');setMessage('Context removed from the library and its linked days.');changed();}catch(e){setError(e instanceof Error?e.message:'Could not delete this context.');}finally{setBusy(false);}}

  return <article className="settings-card journal-context-settings">
    <div className="settings-heading"><h2>AI summary guidance &amp; journal context</h2></div>
    <p>Save preferences once, then link people or events to any day where they help explain an original memory. Only linked context is included in that day’s summaries. If OpenAI summaries are enabled, the saved guidance and linked notes are sent with the included summary text.</p>
    {!isNative()&&<p className="small-note">Journal context is available in the native app; browser preview is read-only.</p>}
    {error&&<p role="alert" className="small-note context-error">{error}</p>}
    <section className="journal-guidance-editor" aria-label="AI summary guidance">
      <label htmlFor="summary-guidance"><strong>How should summaries focus or sound?</strong><small>For example: keep them concise, focus on family time, or use a warm first-person voice. Factual grounding and your original memories remain the priority.</small><textarea id="summary-guidance" maxLength={2500} value={guidance} disabled={!isNative()||busy||loading} onChange={event=>setGuidance(event.target.value)} placeholder="Tell the summarizer what matters most to you…"/></label>
      <button type="button" disabled={!isNative()||busy||loading||guidance===savedGuidance} onClick={()=>void saveGuidance()}>{busy?'Saving…':'Save summary guidance'}</button>
    </section>
    <div className="context-library-heading"><h3>People &amp; events</h3><button type="button" disabled={!isNative()||busy||loading} onClick={()=>{resetForm();setFormOpen(true);setError('');setMessage('');}}>Add person or event</button></div>
    {formOpen&&<form className="context-item-form" onSubmit={event=>void saveItem(event)}>
      <label>Type<select value={kind} disabled={busy} onChange={event=>setKind(event.target.value as 'person'|'event')}><option value="person">Person</option><option value="event">Event</option></select></label>
      <label>{kind==='person'?'Name':'Event name'}<input maxLength={160} value={title} disabled={busy} onChange={event=>setTitle(event.target.value)} placeholder={kind==='person'?'Name this person':'Name this event'}/></label>
      <label>Other names or aliases <small>Optional; separate aliases with commas.</small><input maxLength={400} value={aliases} disabled={busy} onChange={event=>setAliases(event.target.value)} placeholder={kind==='person'?'Mom, Nana':'Family reunion'}/></label>
      <label>Reference notes <small>Optional context that can clarify a mention, such as who someone is or what an event means.</small><textarea maxLength={1500} value={details} disabled={busy} onChange={event=>setDetails(event.target.value)} placeholder="Add only details you want summaries to use when this context is linked to a day."/></label>
      <div className="actions"><button className="primary" type="submit" disabled={!isNative()||busy||!title.trim()}>{editing?'Save changes':'Add to context library'}</button><button type="button" disabled={busy} onClick={resetForm}>Cancel</button></div>
    </form>}
    {loading?<p className="small-note">Loading journal context…</p>:items.length>0?<div className="context-library-list">{items.map(item=><article className="context-library-item" key={item.id}><div><span className="eyebrow">{item.kind.toUpperCase()}</span><h4>{item.title}</h4>{item.aliases&&<p><strong>Also known as:</strong> {item.aliases}</p>}{item.details&&<p>{item.details}</p>}</div><div className="actions"><button type="button" disabled={busy} onClick={()=>editItem(item)}>Edit</button>{confirmDelete===item.id?<><button type="button" disabled={busy} onClick={()=>void deleteItem(item)}>Delete everywhere</button><button type="button" disabled={busy} onClick={()=>setConfirmDelete('')}>Cancel</button></>:<button type="button" disabled={busy} onClick={()=>setConfirmDelete(item.id)}>Delete</button>}</div></article>)}</div>:<p className="small-note">No people or events saved yet. Add context here, then link it to days from each day’s page.</p>}
    {message&&<p role="status" className="small-note">{message}</p>}
  </article>;
}
