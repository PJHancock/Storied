import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resetLayout,fieldsEqual} from '../src/pageLayout.ts';
const source={'week.dayOrder':'2026-11-16,2026-11-15','week.subtitle':'Our week','day.2026-11-15.title':'My headline','day.2026-11-15.style':'ticket','day.2026-11-15.photoPlacement':'beside','day.2026-11-15.photoSize':'large','day.2026-11-16.style':'photo'};
test('resetting one day keeps text, the other days, and order',()=>{
  const result=resetLayout(source,['2026-11-15'],false);
  assert.equal(result.fields['day.2026-11-15.style'],undefined);
  assert.equal(result.fields['day.2026-11-15.photoPlacement'],undefined);
  assert.equal(result.fields['day.2026-11-15.photoSize'],undefined);
  assert.equal(result.fields['day.2026-11-15.title'],'My headline');
  assert.equal(result.fields['day.2026-11-16.style'],'photo');
  assert.equal(result.fields['week.dayOrder'],source['week.dayOrder']);
  assert.deepEqual({...result.fields,...result.removed},source);
});
test('resetting week removes only layout overrides for selected days and can be undone',()=>{
  const result=resetLayout(source,['2026-11-15','2026-11-16'],true);
  assert.deepEqual(result.fields,{'week.subtitle':'Our week','day.2026-11-15.title':'My headline'});
  assert.ok(fieldsEqual({...result.fields,...result.removed},source));
  assert.equal(source['day.2026-11-15.style'],'ticket');
});
test('dirty comparison ignores key order but detects content changes',()=>{
  assert.ok(fieldsEqual({a:'one',b:'two'},{b:'two',a:'one'}));
  assert.ok(!fieldsEqual({a:'one'},{a:'two'}));
  assert.ok(!fieldsEqual({a:'one'},{a:'one',b:''}));
});
