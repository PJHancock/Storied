/** Estimate a two-column scrapbook spread without changing the user's day order. */
export type DayLayoutWeight={title:string;detail:string;sourceLength:number;hasPhoto:boolean;hasWeather?:boolean;photoCount?:number;photoHeadline?:boolean;photoSize?:string;photoPlacement?:string;sparse:boolean;future:boolean};
export function estimateDayCardHeight(day:DayLayoutWeight,fullWidth:boolean):number {
  const weatherSticker=day.hasWeather?34:0;
  if(day.sparse)return 112+weatherSticker;
  if(day.future)return 88+weatherSticker;
  const titleLines=Math.min(3,Math.max(1,Math.ceil(day.title.length/(fullWidth?48:25))));
  const detailLines=Math.min(day.sourceLength>220?5:4,Math.ceil(day.detail.length/(fullWidth?74:38)));
  const text=Math.max(day.sourceLength>220?220:190,78+titleLines*27+detailLines*21)+weatherSticker;
  if(!day.hasPhoto)return text;
  const image=day.photoSize==='small'?140:day.photoSize==='large'?360:day.photoSize==='medium'?240:300;
  const extraPhotos=Math.max(0,Math.min(3,(day.photoCount??1)-1));
  const photoStack=extraPhotos?extraPhotos*72+12:0;
  if(day.photoHeadline)return 540+photoStack+weatherSticker;
  if(day.photoPlacement==='beside')return Math.max(text,image+55)+photoStack;
  if(day.photoPlacement==='overlap')return text+Math.min(170,image*.65)+photoStack;
  return text+image+photoStack;
}
function gridHeight(days:DayLayoutWeight[],startIndex:number):number {
  let total=0,pending=0,occupied=false;
  for(let i=0;i<days.length;i++){
    const day=days[i],wide=(startIndex+i===2)||day.sourceLength>220;
    if(wide){if(occupied){total+=pending+22;pending=0;occupied=false;}total+=estimateDayCardHeight(day,true)+22;}
    else {const height=estimateDayCardHeight(day,false);if(!occupied){pending=height;occupied=true;}else{total+=Math.max(pending,height)+22;pending=0;occupied=false;}}
  }
  return total+(occupied?pending:0);
}
export function balanceWeek(days:DayLayoutWeight[]):number {
  if(days.length!==7)return 4;
  if(days.every(day=>day.sparse||day.future))return 4;
  return [3,4,5].map(split=>({split,score:Math.abs(gridHeight(days.slice(0,split),0)-gridHeight(days.slice(split),split))+Math.abs(split-4)*12}))
    .sort((a,b)=>a.score-b.score||Math.abs(a.split-4)-Math.abs(b.split-4)||a.split-b.split)[0].split;
}
