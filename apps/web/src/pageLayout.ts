export const layoutProperties=['style','photoPlacement','photoSize'] as const;
export function dayLayoutKeys(day:string):string[]{return layoutProperties.map(property=>`day.${day}.${property}`);}
export function resetLayout(fields:Record<string,string>,days:string[],includeOrder:boolean){
  const updated={...fields},removed:Record<string,string>={};
  const keys=days.flatMap(dayLayoutKeys);if(includeOrder)keys.push('week.dayOrder');
  for(const key of keys)if(Object.hasOwn(updated,key)){removed[key]=updated[key];delete updated[key];}
  return {fields:updated,removed};
}
export function fieldsEqual(a:Record<string,string>,b:Record<string,string>):boolean{
  const keys=Object.keys(a);return keys.length===Object.keys(b).length&&keys.every(key=>a[key]===b[key]);
}
