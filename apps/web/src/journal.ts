export function localDay(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}
export function dateFor(day: string) { return new Date(`${day}T12:00:00`); }
export function weekDays(anchor: string) {
  const start = dateFor(anchor); start.setDate(start.getDate() - start.getDay());
  return Array.from({ length: 7 }, (_, offset) => { const date = new Date(start); date.setDate(start.getDate() + offset); return localDay(date); });
}
export function moveWeek(anchor: string, offset: number) { const date = dateFor(anchor); date.setDate(date.getDate() + offset * 7); return localDay(date); }
export function weekLabel(days: string[]) {
  const first = dateFor(days[0]), last = dateFor(days[6]);
  return first.toLocaleDateString(undefined, {month:'short',day:'numeric'}) + '–' + last.toLocaleDateString(undefined, {month:first.getMonth()===last.getMonth()?undefined:'short',day:'numeric'});
}
export function formatEventTime(instant: string, timeZone?: string) {
  const date = new Date(instant);
  if (Number.isNaN(date.getTime())) return '';
  try {
    return new Intl.DateTimeFormat(undefined, {hour:'numeric', minute:'2-digit', ...(timeZone ? {timeZone} : {})}).format(date);
  } catch {
    return date.toLocaleTimeString(undefined, {hour:'numeric', minute:'2-digit'});
  }
}
export function preview(body: string) {
  const original = body.trim();
  const boundary = original.search(/[\n]|[.!?](?:\s|$)/);
  const cut = boundary >= 0 && boundary < 85 ? boundary + (original[boundary] === '\n' ? 0 : 1) : original.length <= 85 ? original.length : Math.max(1, original.lastIndexOf(' ', 78));
  return { title: original.slice(0, cut), detail: original.slice(cut).trim() };
}

function eventHeading(text: string) {
  const first = text.trim().split(/[.!?\n]/, 1)[0]?.trim() ?? '';
  let phrase = first;
  const conversational = /^(?:(?:today|yesterday)\s+)?(?:i|we|my family and i)\s+(?:(?:had|have|went to|did|attended|visited|was at)\s+)?/i;
  const hasLeadIn = conversational.test(phrase);
  phrase = phrase.replace(conversational, '');
  if (hasLeadIn) phrase = phrase.replace(/^(?:a|an|the)\s+/i, '');
  const fillers = new Set(['today', 'yesterday', 'then']);
  const words = phrase.split(/\s+and\s+/i, 1)[0].split(/\s+/).filter(Boolean)
    .map(word => word.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}'’-]+$/gu, ''))
    .filter(word => word && !fillers.has(word.toLocaleLowerCase()));
  const heading = words.slice(0, 5).join(' ').replace(/[,:;]+$/, '').trim();
  if (!heading) return 'A moment together';
  return heading.replace(/(^|\s)\p{L}/gu, letter => letter.toLocaleUpperCase());
}
function firstPersonText(text: string) {
  return text.replace(/\bwe are\b/gi,'I am').replace(/\bwe're\b/gi,"I'm")
    .replace(/\bwe were\b/gi,'I was').replace(/\bwe have\b/gi,'I have').replace(/\bwe've\b/gi,"I've")
    .replace(/\bwe had\b/gi,'I had').replace(/\bwe did\b/gi,'I did').replace(/\bwe do\b/gi,'I do')
    .replace(/\bwe\b/gi,'I').replace(/\bOur\b/g,'My').replace(/\bour\b/gi,'my').replace(/\bUs\b/g,'Me').replace(/\bus\b/gi,'me');
}
function firstPersonHeading(text: string) {
  const sentence=text.trim().match(/^.*?[.!?](?:\s|$)/)?.[0].trim()??text.trim();
  const personal=firstPersonText(sentence);
  if(/^I\b|^My\b/.test(personal))return personal.length>78?personal.slice(0,75).replace(/\s+\S*$/,'')+'…':personal;
  return `I remember: ${eventHeading(text)}`.slice(0,80);
}

export function highlightEntry<T extends {allowsAI: boolean}>(entries: T[]): T | undefined {
  return entries.find(entry => entry.allowsAI);
}

type SummaryAccount = {body: string; allowsAI: boolean; transcriptSource?: boolean; visualSource?: boolean; visualText?: string; originalMediaSource?: boolean; mediaKind?: string};
const memoryInvitations = [
  'Add a memory',
  "Tell this day's story",
  'What happened this day?',
  'Save a moment from this day',
  'Add a note to this day',
  'Capture a moment',
  'What would you like to remember?',
  'Start a memory here',
];
export function memoryInvitationHeading(day = '') {
  let index=0;
  for(const byte of new TextEncoder().encode(day))index=(index*31+byte)%memoryInvitations.length;
  return memoryInvitations[index];
}
/** A bounded, explicitly labeled source preview for devices without a generative model. */
export function daySummary<T extends SummaryAccount>(entries: T[], _mediaCount = 0,
  context: {day?:string;photos?: number; plans?: string[]; weather?: string; photoClues?: string[]} = {}) {
  const accounts = entries.filter(entry => entry.allowsAI && entry.body.trim());
  const seen = new Set<string>();
  const originalAccounts = accounts.filter(entry=>entry.originalMediaSource||!entry.visualSource||entry.transcriptSource);
  const snippets = originalAccounts.flatMap(entry => {
    const text = entry.body.trim().replace(/\s+/g,' ');
    const key = text.toLocaleLowerCase(); if(seen.has(key)) return []; seen.add(key);
    const sentence = text.match(/^.*?[.!?](?:\s|$)/)?.[0].trim() ?? text;
    const short = firstPersonText(sentence.length > 100 ? sentence.slice(0,97).replace(/\s+\S*$/,'')+'…' : sentence);
    if(entry.originalMediaSource&&entry.visualSource&&!entry.transcriptSource)return [`My ${entry.mediaKind??'media'} may show: ${short}`];
    const visualLabel=entry.originalMediaSource&&entry.visualSource?`My ${entry.mediaKind??'media'} may show: `:'';
    const personal=/^(?:I\b|My\b)/.test(short)?short:`I remember: ${short}`;
    return [visualLabel+personal];
  });
  const visualSnippets = accounts.filter(entry=>entry.visualSource&&(!entry.originalMediaSource||entry.transcriptSource)).flatMap(entry=>{
    const visual=(entry.visualText??entry.body).trim().replace(/^Visual clues \(may be incomplete\):\s*/i,'').replace(/\s+/g,' ');
    const label=entry.originalMediaSource?`My ${entry.mediaKind??'media'} may show: `:'My photos may show: ';
    return visual? [`${label}${visual.slice(0,180)}`]:[];
  });
  const support = [
    ...visualSnippets,
    ...(context.photoClues ?? []).map(clue=>`My photos may show: ${clue}`),
    context.photos ? `I have ${context.photos} connected photo${context.photos===1?'':'s'} for this day.` : '',
    ...(context.plans?.length ? ['I had plans on my calendar, but that does not show whether they happened.'] : []),
    context.weather ? `In my selected city, the weather was ${context.weather}.` : ''
  ].filter(Boolean);
  const parts = [...snippets,...support];
  if (originalAccounts.length) {
    const joined = parts.join(' · ');
    const detail = joined.length > 480 ? joined.slice(0,450).replace(/\s+\S*$/,'')+'… (open originals for all sources)' : joined;
    const lead=originalAccounts[0];
    if(lead.originalMediaSource&&!lead.transcriptSource&&!lead.visualSource){
      const label=lead.mediaKind==='video'?'video':lead.mediaKind==='audio'?'recording':'file';
      return {title:`My ${label}`,detail:`I added a ${label} named ${lead.body.match(/named (.+?) has not/)?.[1]??'to this day'}; its contents have not been extracted.`};
    }
    if(lead.originalMediaSource&&lead.visualSource&&!lead.transcriptSource)return {title:`My ${lead.mediaKind??'media'} may show: ${eventHeading(lead.visualText??lead.body)}`.slice(0,80),detail};
    return {title:firstPersonHeading(lead.body),detail};
  }
  const photoClue=context.photoClues?.find(clue=>clue.trim());
  if(photoClue){
    const title=eventHeading(photoClue);
    return {title:`My photos may show: ${title}`.slice(0,80),detail:`My photos may show: ${photoClue.trim()}`};
  }
  if(context.photos){
    return {title:'My day in photos',detail:`I have ${context.photos} connected photo${context.photos===1?'':'s'} for this day.`};
  }
  return {title:memoryInvitationHeading(context.day),detail:''};
}

/** Preview across all included days; actual synthesis is provided by the native model. */
export function weeklySummary<T extends SummaryAccount & {id: string; day: string}>(entries: T[]) {
  const eligible = entries.filter(entry=>entry.allowsAI && entry.body.trim());
  if(!eligible.length) return undefined;
  const summary = daySummary(eligible)!;
  return {entry:eligible[0],title:'My week in moments',detail:summary.detail};
}
