import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildPhotoSpread, choosePhotoHeadlineDay} from '../src/photoSpread.ts';

const photo=(id,day,extra={})=>({id,day,createdAt:`${day}T12:00:00Z`,kind:'photo',source:'photos',...extra});

test('photo-rich days supply distinct extra images only when other days have none',()=>{
  const days=['2026-11-15','2026-11-16','2026-11-17','2026-11-18'];
  const spread=buildPhotoSpread(days,{
    [days[0]]:[photo('a1',days[0]),photo('a2',days[0]),photo('a3',days[0])],
    [days[1]]:[photo('b1',days[1])],
    [days[2]]:[],
    [days[3]]:[],
  });
  assert.deepEqual(spread[days[0]].map(item=>item.id),['a1','a2','a3']);
  assert.deepEqual(spread[days[1]].map(item=>item.id),['b1']);
  assert.deepEqual(spread[days[2]],[]);
  assert.deepEqual(spread[days[3]],[]);
  const shown=days.flatMap(day=>spread[day]);
  assert.equal(new Set(shown.map(item=>item.id)).size,shown.length);
  assert.ok(shown.every(item=>item.day===days[0]||item.day===days[1]));
});

test('a complete photo week shows one distinct lead image per day',()=>{
  const days=Array.from({length:7},(_,index)=>`2026-11-${String(15+index).padStart(2,'0')}`);
  const input=Object.fromEntries(days.map(day=>[day,[photo(`${day}-lead`,day),photo(`${day}-extra`,day)]]));
  const spread=buildPhotoSpread(days,input);
  assert.ok(days.every(day=>spread[day].length===1));
});

test('headline photo leads and video previews keep their date and type',()=>{
  const days=['2026-11-15','2026-11-16','2026-11-17'];
  const spread=buildPhotoSpread(days,{
    [days[0]]:[photo('recent',days[0]),photo('picked',days[0],{headline:true})],
    [days[1]]:[{...photo('clip',days[1],{kind:'video'}),source:'upload'}],
  },[days[2]]);
  assert.equal(spread[days[0]][0].id,'picked');
  assert.equal(spread[days[1]][0].kind,'video');
  assert.equal(spread[days[1]][0].day,days[1]);
  assert.equal(spread[days[2]].length,0);
});

test('duplicate photo identifiers are shown only once across the spread',()=>{
  const days=['2026-11-15','2026-11-16','2026-11-17'];
  const spread=buildPhotoSpread(days,{
    [days[0]]:[photo('same',days[0]),photo('extra',days[0])],
    [days[1]]:[photo('same',days[1])],
  });
  const shown=days.flatMap(day=>spread[day]);
  assert.equal(shown.filter(item=>item.id==='same').length,1);
});

test('the richest photo day becomes the image headline, with text-light tie breaking',()=>{
  const headline=choosePhotoHeadlineDay([
    {day:'2026-11-15',photoCount:1,sourceLength:0,detailLength:0},
    {day:'2026-11-16',photoCount:3,sourceLength:600,detailLength:140},
    {day:'2026-11-17',photoCount:3,sourceLength:50,detailLength:10},
  ]);
  assert.equal(headline,'2026-11-17');
});

test('image headline is omitted when there are no photos or every card has custom text/layout',()=>{
  assert.equal(choosePhotoHeadlineDay([{day:'2026-11-15',photoCount:0,sourceLength:0,detailLength:0}]),undefined);
  assert.equal(choosePhotoHeadlineDay([
    {day:'2026-11-15',photoCount:2,sourceLength:0,detailLength:0,eligible:false},
    {day:'2026-11-16',photoCount:1,sourceLength:0,detailLength:0,eligible:false},
  ]),undefined);
});
