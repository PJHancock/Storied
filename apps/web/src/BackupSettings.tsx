import {useEffect,useState} from 'react';
import {call,isNative} from './bridge';
import {Icon} from './Icons';

export default function BackupSettings(){
  const [available,setAvailable]=useState(false),[ready,setReady]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
  useEffect(()=>{if(isNative())void call('backup.status',{}).then(status=>{setAvailable(status.available);setReady(status.restoredReady);}).catch(()=>setMessage('Backup controls are unavailable.'));},[]);
  async function exportBackup(){setBusy(true);setMessage('Choose a location. Creating and verifying the backup may take a while…');try{
    const result=await call('backup.export',{});
    setMessage(result.cancelled?'Backup cancelled.':`Backup saved as “${result.name}” with ${result.mediaCount} media items.`);
  }catch(error){setMessage(error instanceof Error?error.message:'Backup failed. Please retry.');}finally{setBusy(false);}}
  async function restoreBackup(){setBusy(true);setMessage('Choose the backup folder, then where to create the restored journal. Files will be verified before it is opened.');try{
    const result=await call('backup.restore',{});
    if(result.cancelled)setMessage('Restore cancelled.');else{setReady(true);setMessage(`Restored “${result.name}” with ${result.mediaCount} media items. Open it in a separate window to review.`);}
  }catch(error){setMessage(error instanceof Error?error.message:'Restore failed. The open journal was not changed.');}finally{setBusy(false);}}
  async function openRestored(){setBusy(true);setMessage('Opening the restored journal…');try{await call('backup.openRestored',{});setMessage('Opened the restored journal in a separate app instance.');}catch(error){setMessage(error instanceof Error?error.message:'Could not open the restored journal.');}finally{setBusy(false);}}
  async function openFolder(){setBusy(true);setMessage('Choose a restored journal folder to open.');try{const result=await call('backup.openFolder',{});setMessage(result.cancelled?'Opening cancelled.':'Opened the restored journal in a separate app instance.');}catch(error){setMessage(error instanceof Error?error.message:'Could not open the restored journal.');}finally{setBusy(false);}}
  return <article className="settings-card"><div className="settings-heading"><Icon name="share"/><h2>Backup &amp; restore</h2><span className="connection-badge">{available?'On this Mac':'Unavailable'}</span></div>
    <p>Save a verified backup of your journal, including original uploads, drafts, page edits and saved summaries. Backups are ordinary folders and are not encrypted; keep them somewhere private.</p>
    <p className="small-note">The backup can include cached Photos previews and calendar details. OpenAI keys are kept in Keychain and are not included. Photos and Calendar need to be connected again in a restored journal. The default weather city is not included.</p>
    {available?<><div className="actions"><button type="button" disabled={busy} onClick={()=>void exportBackup()}>Create backup</button><button type="button" disabled={busy} onClick={()=>void restoreBackup()}>Restore backup</button>{ready&&<button type="button" disabled={busy} onClick={()=>void openRestored()}>Open restored journal</button>}<button type="button" disabled={busy} onClick={()=>void openFolder()}>Open a restored folder</button></div><p className="small-note">Restore creates a separate journal folder and opens it in a separate app instance. Your current journal remains available.</p></>:<p className="small-note">Backup and restore are available in the desktop Mac app.</p>}
    {message&&<p role="status" className="small-note">{message}</p>}
  </article>;
}
