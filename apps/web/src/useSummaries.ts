import {useEffect,useState} from 'react';
import {call,isNative} from './bridge';
import type {SummaryContext,SummaryJob} from '../../../packages/contracts/bridge';

/** Results are usable only for the exact displayed source snapshot. */
export function useSummaries(days: string[], contexts: SummaryContext[], sourceKey: string, ready: boolean) {
  const key=JSON.stringify([days,contexts,sourceKey]);
  const [result,setResult]=useState<{key:string;job:SummaryJob}>();
  useEffect(()=>{
    if(!ready||!isNative())return;
    let active=true,id:string|undefined,timer:ReturnType<typeof setTimeout>;
    const publish=(job:SummaryJob)=>{if(active)setResult({key,job});};
    const poll=async()=>{
      try {
        const job=await call('summary.status',{id:id!});
        if(!active)return;
        publish(job);
        if(job.state==='running')timer=setTimeout(()=>void poll(),600);
      } catch(error){if(active)setResult({key,job:{id:id??'',state:'failed',message:error instanceof Error?error.message:'Summary unavailable.',summaries:{}}});}
    };
    timer=setTimeout(()=>{void call('summary.start',{days,contexts}).then(job=>{
      id=job.id;
      if(!active)return;
      publish(job); if(job.state==='running')timer=setTimeout(()=>void poll(),600);
    }).catch(error=>{if(active)setResult({key,job:{id:'',state:'failed',message:error instanceof Error?error.message:'Summary unavailable.',summaries:{}}});});},100);
    return()=>{active=false;clearTimeout(timer);};
  },[key,ready]);
  return result?.key===key?result.job:undefined;
}
