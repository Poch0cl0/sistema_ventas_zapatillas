import { test } from 'node:test';
import assert from 'node:assert/strict';
import { footTransform, videoPoint, smoothAngle } from '../assets/try_on/tracking.mjs';

test('landmarks match the centre crop of portrait video', () => {
  assert.deepEqual(videoPoint({x:.5,y:.5},640,480,360,800), {x:180,y:400});
  assert.ok(videoPoint({x:0,y:.5},640,480,360,800).x < 0);
});
test('hides occluded, missing, or cropped feet', () => {
  const points = [{x:.5,y:.5,visibility:1}, {x:.5,y:.6,visibility:1}, {x:.5,y:.8,visibility:1}];
  assert.ok(footTransform(points,[0,1,2],[640,480,360,800]));
  points[1].visibility = .2;
  assert.equal(footTransform(points,[0,1,2],[640,480,360,800]),null);
  assert.equal(footTransform([],[0,1,2],[640,480,360,800]),null);
  points[1] = {x:0,y:.6,visibility:1};
  assert.equal(footTransform(points,[0,1,2],[640,480,360,800]),null);
});
test('smooths rotation across the -pi/pi boundary without a full turn', () => {
  const current = Math.PI-.01;
  assert.ok(Math.abs(smoothAngle(current,-Math.PI+.01,.4)-current)<.02);
});
