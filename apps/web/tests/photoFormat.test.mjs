import {test} from 'node:test';
import assert from 'node:assert/strict';
import {photoFormat} from '../src/photoFormat.ts';
test('photo formats respect image orientation with a safe unknown fallback',()=>{
  assert.equal(photoFormat(0,0,0),'postcard');
  for(let i=0;i<8;i++){
    assert.ok(['print','postcard'].includes(photoFormat(600,1200,i)));
    assert.ok(['landscape','postcard'].includes(photoFormat(1800,600,i)));
    assert.ok(['square','postcard'].includes(photoFormat(900,900,i)));
  }
});
