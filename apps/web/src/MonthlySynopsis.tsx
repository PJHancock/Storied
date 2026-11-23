import {useEffect,useState} from 'react';
import {call,isNative} from './bridge';
import {daySummary,dateFor} from './journal';
import {recordingAccounts} from './speech';
import type {Day,DayPhoto,Entry,MediaAsset,MonthlySynopsisBullet} from '../../../packages/contracts/bridge';

type MonthPhoto={day:string;src:string;alt:string};
type Props={month:string;days:Day[];revision:number;today:string;photosEnabled:boolean;syncing:boolean};
type LoadedDay={day:string;entries:Entry[];assets:MediaAsset[];photos:DayPhoto[];photoCount:number;headlinePhotoID:string|null;override:{title:string;detail:string}|null};
async function sourceFingerprint(value:string){
  const bytes=new TextEncoder().encode(value);
  try{const digest=await crypto.subtle.digest('SHA-256',bytes);return Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('');}
  catch{const states=[0x811c9dc5,0x9e3779b9,0x85ebca6b,0xc2b2ae35,0x27d4eb2f,0x165667b1,0xd3a2646c,0xfd7046c5];for(let i=0;i<bytes.length;i++)for(let j=0;j<states.length;j++)states[j]=Math.imul(states[j]^(bytes[i]+j*17+i%251),0x01000193+j*2)>>>0;return states.map(state=>state.toString(16).padStart(8,'0')).join('');}
}

export default function MonthlySynopsis({month,days,revision,today,photosEnabled,syncing}:Props){
  const [bullets,setBullets]=useState<MonthlySynopsisBullet[]>([]),[photos,setPhotos]=useState<MonthPhoto[]>([]),[loading,setLoading]=useState(false),[message,setMessage]=useState('');
  useEffect(()=>{
    let active=true;
    if(syncing){setLoading(false);setMessage('Wait for this week’s sync to finish before refreshing the monthly synopsis.');return()=>{active=false;};}
    if(!isNative()){setBullets([]);setPhotos([]);setMessage('Monthly synopsis is available in the native app.');return()=>{active=false;};}
    if(!/^\d{4}-\d{2}$/.test(month)){setBullets([]);setPhotos([]);setMessage('Choose a month to create its synopsis.');return()=>{active=false;};}
    const [year,monthNumber]=month.split('-').map(Number);
    const numberOfDays=new Date(Date.UTC(year,monthNumber,0)).getUTCDate();
    const monthDays=Array.from({length:numberOfDays},(_,index)=>`${month}-${String(index+1).padStart(2,'0')}`).filter(day=>day<=today);
    const savedDays=new Map(days.filter(item=>item.day.startsWith(month+'-')).map(item=>[item.day,item]));
    setLoading(true);setMessage('');setBullets([]);setPhotos([]);
    void (async()=>{
      const loaded:LoadedDay[]=[];
      for(let offset=0;offset<monthDays.length;offset+=4){
        if(!active)return;
        const batch=monthDays.slice(offset,offset+4);
        setMessage(`Gathering memories and photos · ${Math.min(offset+batch.length,monthDays.length)} of ${monthDays.length} days`);
        const results=await Promise.all(batch.map(async day=>{
          const hasSavedDay=savedDays.has(day);
          const [entries,assets,context,override]=await Promise.all([
            hasSavedDay?call('journal.getDay',{day}):Promise.resolve([]),
            hasSavedDay?call('media.list',{day}):Promise.resolve([]),
            photosEnabled?call('resources.day',{day,previewLimit:1}):Promise.resolve({photos:[],photoCount:0,headlinePhotoID:null}),
            hasSavedDay?call('journal.getSummaryOverride',{day}):Promise.resolve(null),
          ]);
          return {day,entries,assets,photos:context.photos,photoCount:context.photoCount,headlinePhotoID:context.headlinePhotoID,override};
        }));
        loaded.push(...results);
      }
      const sourceSnapshot=loaded.map(item=>({
        day:item.day,
        entries:item.entries.map(entry=>[entry.id,entry.revision,entry.allowsAI]),
        assets:item.assets.map(asset=>[asset.id,asset.kind,asset.contentDigest??'',asset.analysisRevision??0,asset.allowsAI??false,asset.transcript??'',asset.analysisText??'']),
        photos:[item.photoCount,item.headlinePhotoID,...item.photos.map(photo=>[photo.id,photo.createdAt,photo.analysisText??''])],
        override:item.override?[item.override.title,item.override.detail]:null,
      }));
      const fingerprint=await sourceFingerprint(JSON.stringify(sourceSnapshot));
      const cached=await call('journal.monthlySynopsis.get',{month,fingerprint});
      let savedBullets=cached?.bullets;
      if(!savedBullets){
        savedBullets=loaded.flatMap(item=>{
          const photoClues=item.photos.flatMap(photo=>photo.analysisText?[photo.analysisText]:[]);
          const accountPhotos=item.assets.filter(asset=>asset.kind==='photo'&&asset.analysisText).map(asset=>({body:asset.analysisText!,allowsAI:asset.allowsAI===true,visualSource:true,visualText:asset.analysisText,originalMediaSource:true,mediaKind:'photo'}));
          const summary=item.override??daySummary([...item.entries,...recordingAccounts(item.assets),...accountPhotos],item.assets.length,{day:item.day,photos:item.photoCount,photoClues});
          if(!summary||!summary.detail.trim())return [];
          const date=dateFor(item.day).toLocaleDateString(undefined,{month:'short',day:'numeric'});
          const text=`${date}: ${summary.title} — ${summary.detail}`.slice(0,420);
          return [{day:item.day,text}];
        });
        if(savedBullets.length){
          const saved=await call('journal.monthlySynopsis.save',{month,fingerprint,bullets:savedBullets});
          savedBullets=saved.bullets;
        }
      }
      const monthPhotos:MonthPhoto[]=[];
      for(const item of loaded){
        const connected=item.photos.find(photo=>photo.id===item.headlinePhotoID)??item.photos[0];
        if(connected){monthPhotos.push({day:item.day,src:connected.thumbnail,alt:`Photo from ${dateFor(item.day).toLocaleDateString(undefined,{month:'long',day:'numeric'})}`});if(monthPhotos.length>=12)break;continue;}
        const uploaded=item.headlinePhotoID?item.assets.find(asset=>asset.id===item.headlinePhotoID&&asset.kind==='photo'&&asset.hasPreview):item.assets.find(asset=>asset.kind==='photo'&&asset.hasPreview);
        if(uploaded){try{const image=await call('media.preview',{id:uploaded.id});monthPhotos.push({day:item.day,src:`data:image/jpeg;base64,${image.base64}`,alt:`Uploaded photo from ${dateFor(item.day).toLocaleDateString(undefined,{month:'long',day:'numeric'})}`});}catch{}}
        if(monthPhotos.length>=12)break;
      }
      if(active){setBullets(savedBullets??[]);setPhotos(monthPhotos.slice(0,12));setMessage(savedBullets?.length?'':'Add memories or photos during this month to build its synopsis.');}
    })().catch(error=>{if(active)setMessage(error instanceof Error?error.message:'Could not create this month’s synopsis.');}).finally(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[month,days,revision,today,photosEnabled,syncing]);
  return <section className="monthly-synopsis" aria-labelledby="monthly-synopsis-title">
    <header><h3 id="monthly-synopsis-title">My month in moments</h3><span>{loading?'Preparing…':bullets.length?`${bullets.length} highlights`:''}</span></header>
    {photos.length>0&&<div className="monthly-photo-strip" aria-label="Representative photos from this month">{photos.map(photo=><figure key={photo.day}><img src={photo.src} alt={photo.alt}/><figcaption>{dateFor(photo.day).toLocaleDateString(undefined,{month:'short',day:'numeric'})}</figcaption></figure>)}</div>}
    {loading&&<p role="status" className="small-note">{message}</p>}
    {!loading&&bullets.length>0&&<ul>{bullets.map(item=><li key={item.day}>{item.text}</li>)}</ul>}
    {!loading&&!bullets.length&&message&&<p className="small-note">{message}</p>}
    {!loading&&photos.length===0&&!message&&<p className="small-note">{photosEnabled?'No photo previews are available for this month yet.':'Connect Photos in Workshop to include automatic photo previews; uploaded photos are included when available.'}</p>}
  </section>;
}
