import {test} from 'node:test';
import assert from 'node:assert/strict';
import {balanceWeek,estimateDayCardHeight} from '../src/spreadBalance.ts';
const empty=()=>({title:'',detail:'',sourceLength:0,hasPhoto:false,sparse:true,future:false});
const heavy=()=>({title:'A very full day',detail:'A'.repeat(180),sourceLength:300,hasPhoto:true,photoSize:'large',photoPlacement:'above',sparse:false,future:false});
test('empty and incomplete weeks use the familiar four-day split',()=>{
  assert.equal(balanceWeek(Array.from({length:7},empty),'',''),4);
  assert.equal(balanceWeek([empty()],'',''),4);
});
test('heavy days influence balance without changing the supplied order',()=>{
  const left=Array.from({length:7},empty);left[0]=heavy();
  const right=Array.from({length:7},empty);right[6]=heavy();
  const before=JSON.stringify(right);
  assert.equal(balanceWeek(left,'',''),3);
  assert.equal(balanceWeek(right,'',''),5);
  assert.equal(JSON.stringify(right),before);
});
test('layout is stable for the same content and handles different photo treatments',()=>{
  const days=Array.from({length:7},()=>({...empty(),sparse:false}));
  days[1]={...heavy(),photoPlacement:'beside',photoSize:'small'};
  const first=balanceWeek(days,'A full week','Summary '.repeat(30));
  assert.ok([3,4,5].includes(first));
  assert.equal(balanceWeek(days,'A full week','Summary '.repeat(30)),first);
});
test('an image headline is budgeted as a larger card so the other page gets room',()=>{
  const standard={...empty(),sparse:false,hasPhoto:true,photoCount:1};
  const headline={...standard,photoHeadline:true};
  assert.ok(estimateDayCardHeight(headline,false)>estimateDayCardHeight(standard,false));
  const days=Array.from({length:7},()=>({...empty(),sparse:false}));
  days[0]=headline;
  assert.ok([3,4,5].includes(balanceWeek(days)));
});
