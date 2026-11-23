export type PhotoFormat='print'|'landscape'|'square'|'postcard';
/** Choose a format that respects the picture's proportions; use a stable seed to vary layouts. */
export function photoFormat(width:number,height:number,seed:number):PhotoFormat {
  if(!Number.isFinite(width)||!Number.isFinite(height)||width<=0||height<=0)return 'postcard';
  const ratio=width/height;
  const options:PhotoFormat[]=ratio<0.8?['print','postcard']:ratio>1.35?['landscape','postcard']:['square','postcard'];
  return options[Math.abs(Math.trunc(seed))%options.length];
}
