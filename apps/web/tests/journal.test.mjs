import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {weekDays,moveWeek,preview,daySummary,memoryInvitationHeading,weeklySummary,highlightEntry} from '../src/journal.ts';
import {appendDictation,recordingAccounts} from '../src/speech.ts';
import {normalizedMime} from '../src/mediaTypes.ts';
test('weeks keep real Sunday to Saturday dates across month and DST boundaries',()=>{
  assert.deepEqual(weekDays('2026-11-12'),['2026-11-08','2026-11-09','2026-11-10','2026-11-11','2026-11-12','2026-11-13','2026-11-14']);
  assert.equal(moveWeek('2026-11-01',-1),'2026-10-25');
  assert.deepEqual(weekDays('2027-01-01'),['2026-12-27','2026-12-28','2026-12-29','2026-12-30','2026-12-31','2027-01-01','2027-01-02']);
});
test('previews separate the heading from remaining text without inventing content',()=>{
  assert.deepEqual(preview('A small moment.\n\nA longer paragraph remains below.'),{title:'A small moment.',detail:'A longer paragraph remains below.'});
  assert.deepEqual(preview('Only a few words'),{title:'Only a few words',detail:''});
  const original='A long paragraph with many words to remember about a quiet afternoon and the walk through town that lasted longer than expected.';
  const result=preview(original);assert.equal(`${result.title} ${result.detail}`,original);
});
test('production fonts resolve inside the packaged web root without network URLs',()=>{
  const css=readFileSync('apps/web/dist/app.css','utf8');
  const fonts=[...css.matchAll(/url\(([^)]+\.ttf)\)/g)].map(m=>m[1]);
  assert.equal(fonts.length,2);
  for(const file of fonts){assert.ok(file.startsWith('./fonts/'));assert.ok(existsSync(resolve(dirname('apps/web/dist/app.css'),file)));}
  assert.ok(!css.includes('fonts.googleapis.com'));
  const html=readFileSync('apps/web/dist/index.html','utf8');
  const connect=html.match(/connect-src ([^;]+)/)?.[1].split(/\s+/)??[];
  const allowed=["'none'",'https://api.open-meteo.com','https://archive-api.open-meteo.com','https://geocoding-api.open-meteo.com'];
  assert.ok(connect.length>0&&connect.every(origin=>allowed.includes(origin)), 'Only the explicit weather endpoints may be contacted');
  assert.ok(html.includes("img-src 'self' data:"));
});

test('weekly excerpts honor per-memory inclusion preferences',()=>{
  const excluded={id:'private',allowsAI:false}, included={id:'included',allowsAI:true};
  assert.equal(highlightEntry([excluded]),undefined);
  assert.equal(highlightEntry([excluded,included]),included);
});

test('source previews honor every inclusion flag and include distinct account types',()=>{
  const summary=daySummary([
    {body:'We walked by the lake. We watched the sunset.',allowsAI:true},
    {body:'Private milestone excluded.',allowsAI:false},
    {body:'We cooked soup afterward.',allowsAI:true,transcriptSource:true},
    {body:'Trees and water.',allowsAI:true,visualSource:true},
  ],0,{photos:2,plans:['Dentist'],weather:'Denver: clear, 40–55°F'});
  assert.match(summary.detail,/lake/);
  assert.match(summary.detail,/I cooked soup/);
  assert.match(summary.detail,/My photos may show/);
  assert.match(summary.detail,/I had plans on my calendar/);
  assert.match(summary.detail,/In my selected city, the weather was Denver/);
  assert.ok(summary.detail.indexOf('lake')<summary.detail.indexOf('My photos may show'));
  assert.ok(summary.detail.indexOf('My photos may show')<summary.detail.indexOf('I had plans on my calendar'));
  assert.ok(summary.detail.indexOf('I had plans on my calendar')<summary.detail.indexOf('In my selected city'));
  assert.ok(!summary.detail.includes('Private milestone'));
  assert.notEqual(daySummary([{body:'Private memory',allowsAI:false}]).title,'');
  assert.equal(daySummary([{body:'Private memory',allowsAI:false}]).detail,'');
  assert.equal(daySummary([{body:'Excluded transcription',allowsAI:false,transcriptSource:true}]).detail,'');
});
test('context-only and empty days invite the user to add their account',()=>{
  const day='2026-11-12';
  const contextual=daySummary([],0,{day,plans:['event-1'],weather:'Denver: clear, 40–55°F'});
  assert.equal(contextual.title,memoryInvitationHeading(day));
  assert.equal(contextual.detail,'');
  const empty=daySummary([] ,0,{day});
  assert.equal(empty.title,contextual.title);
  assert.equal(empty.detail,'');
  assert.ok(new Set(Array.from({length:8},(_,i)=>memoryInvitationHeading(`2026-11-${String(10+i).padStart(2,'0')}`))).size>1);
});
test('connected photos provide a first-person qualified summary or count-only heading and subheading',()=>{
  const day='2026-11-12';
  const visual=daySummary([],0,{day,photos:1,photoClues:['A trail beside a lake with trees']});
  assert.match(visual.title,/My photos may show/);
  assert.match(visual.detail,/My photos may show: A trail beside a lake/);
  const inventory=daySummary([],0,{day,photos:2});
  assert.equal(inventory.title,'My day in photos');
  assert.match(inventory.detail,/I have 2 connected photos/);
  assert.notEqual(inventory.title,memoryInvitationHeading(day));
});
test('fallback previews remain compact and deduplicate identical accounts',()=>{
  const repeated={body:'A walk by the lake.',allowsAI:true};
  assert.equal(daySummary([repeated,repeated]).detail,'I remember: A walk by the lake.');
  const weAccount=daySummary([{body:'We walked by the lake with our friends.',allowsAI:true}]);
  assert.match(weAccount.title,/^I walked by the lake/);
  assert.match(weAccount.detail,/I walked by the lake with my friends/);
  const many=Array.from({length:100},(_,i)=>({body:`Memory ${i} with many details. `+'Extra detail '.repeat(100),allowsAI:true}));
  const summary=daySummary(many);
  assert.ok(summary.detail.length<=490);
  assert.ok(!summary.detail.includes('Extra detail'));
  assert.equal(daySummary([],2).detail,'');
});
test('weekly source previews consider all included days rather than copying one richest entry',()=>{
  const featured=weeklySummary([
    {id:'a',day:'2026-11-09',body:'We visited the lake.',allowsAI:true},
    {id:'b',day:'2026-11-12',body:'We cooked dinner together.',allowsAI:true},
    {id:'c',day:'2026-11-13',body:'Private milestone excluded.',allowsAI:false},
  ]);
  assert.equal(featured.entry.day,'2026-11-09');
  assert.match(featured.detail,/lake/);
  assert.match(featured.detail,/dinner/);
  assert.ok(!featured.detail.includes('Private'));
  assert.equal(weeklySummary([{id:'x',day:'2026-11-09',body:'private',allowsAI:false}]),undefined);
});

test('media MIME normalizing supports common camera, audio and video formats',()=>{
  assert.equal(normalizedMime({name:'voice.m4a',type:'audio/mp4;codecs=mp4a.40.2'}),'audio/mp4');
  assert.equal(normalizedMime({name:'clip.mov',type:'application/octet-stream'}),'video/quicktime');
  assert.equal(normalizedMime({name:'picture.heic',type:''}),'image/heic');
});

test('production policy permits local recording playback and only explicitly allowed weather connections',()=>{
  const html=readFileSync('apps/web/dist/index.html','utf8');
  assert.ok(html.includes("media-src 'self' blob:"));
  const connect=html.match(/connect-src ([^;]+)/)?.[1].split(/\s+/)??[];
  const allowed=["'none'",'https://api.open-meteo.com','https://archive-api.open-meteo.com','https://geocoding-api.open-meteo.com'];
  assert.ok(connect.length>0&&connect.every(origin=>allowed.includes(origin)), 'Only the explicit weather endpoints may be contacted');
  const composer=readFileSync('apps/web/src/MediaComposer.tsx','utf8');
  assert.ok(composer.includes('navigator.mediaDevices.getUserMedia'));
  assert.ok(composer.includes("onClick={()=>void startCapture('audio')}"));
  assert.ok(composer.includes("onClick={()=>void startCapture('video')}"));
});


test('recording transcripts contribute to daily and weekly summaries only while included',()=>{
  const asset={id:'voice',day:'2026-11-12',filename:'voice.m4a',mimeType:'audio/mp4',kind:'audio',byteCount:3,hasPreview:false,createdAt:'2026-11-12T12:00:00Z',allowsAI:true,transcript:'We watched the sunrise after hiking together by the lake.'};
  const accounts=recordingAccounts([asset]);
  assert.equal(accounts.length,1);
  assert.match(daySummary(accounts,1).detail,/I watched the sunrise/);
  assert.match(daySummary(accounts,1).detail,/sunrise/);
  assert.match(weeklySummary(accounts).detail,/sunrise/);
  assert.equal(recordingAccounts([{...asset,allowsAI:false}]).length,0);
  assert.equal(daySummary([{...accounts[0],allowsAI:false}],0).detail,'');
  assert.equal(recordingAccounts([{...asset,kind:'photo',transcript:undefined}])[0].originalMediaSource,true);
  assert.equal(asset.transcript,'We watched the sunrise after hiking together by the lake.');
});
test('deliberately added video and files count as original content, separate from connected photos',()=>{
  const video={id:'video',day:'2026-11-12',filename:'lake-walk.mov',mimeType:'video/quicktime',kind:'video',byteCount:3,hasPreview:true,createdAt:'2026-11-12T12:00:00Z',allowsAI:true,analysisText:'A person walks beside a lake.'};
  const videoAccount=recordingAccounts([video])[0];
  assert.equal(videoAccount.originalMediaSource,true);
  assert.match(daySummary([videoAccount],1,{day:video.day,photoClues:['A mountain']}).detail,/My video may show/);
  assert.match(daySummary([videoAccount],1,{day:video.day}).title,/My video may show/);
  const unprocessed={...video,id:'file',kind:'video',filename:'family.mov',analysisText:undefined};
  const fileAccount=recordingAccounts([unprocessed])[0];
  const summary=daySummary([fileAccount],1,{day:video.day});
  assert.equal(summary.title,'My video');
  assert.match(summary.detail,/I added a video named family.mov/);
  assert.notEqual(summary.title,memoryInvitationHeading(video.day));
  assert.equal(recordingAccounts([{...video,allowsAI:false}]).length,0);
});
test('dictation appends paragraphs and enforces the saved text limit',()=>{
  assert.equal(appendDictation('Typed words.',' Recognized words. '),'Typed words.\n\nRecognized words.');
  assert.equal(appendDictation('','Recognized words.'),'Recognized words.');
  assert.throws(()=>appendDictation('existing','  '));
  assert.throws(()=>appendDictation('a'.repeat(100000),'extra'));
});
test('all memory input controls are placed within the existing default text composer',()=>{
  const app=readFileSync('apps/web/src/App.tsx','utf8');
  const composer=app.slice(app.indexOf('<section className="composer">'),app.indexOf('<div className="section-heading"><h2>Original memories'));
  assert.ok(composer.indexOf('<textarea')<composer.indexOf('<MediaComposer'));
  assert.ok(composer.indexOf('<MediaComposer')<composer.indexOf('</section>'));
  const tools=readFileSync('apps/web/src/MediaComposer.tsx','utf8');
  assert.ok(tools.includes('Dictate text'));
  assert.ok(!tools.includes('Add a recording or file'));
});
