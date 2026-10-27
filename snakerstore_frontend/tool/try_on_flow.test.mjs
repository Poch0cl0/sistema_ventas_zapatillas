import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import * as THREE from '../assets/try_on/vendor/three.module.js';

test('camera shows both models immediately and restores manual mode after tracking failure', async () => {
  const elements = new Map();
  const element = selector => {
    if (!elements.has(selector)) elements.set(selector, {
      style: {}, events: {}, hidden: false, textContent: '',
      addEventListener(name, callback) { this.events[name] = callback; },
      play: async () => {}, pause() {}, setAttribute() {}, setPointerCapture() {},
    });
    return elements.get(selector);
  };
  let frame, renderedScene, renderer;
  class Renderer {
    constructor() { renderer = this; }
    setSize() {} setPixelRatio() {} dispose() {}
    render(scene) { renderedScene = scene; }
  }
  class Loader {
    async loadAsync() {
      const scene = new THREE.Mesh(new THREE.BoxGeometry(10, 10, 27), new THREE.MeshBasicMaterial());
      scene.scale.setScalar(.01);
      scene.position.set(2, 3, 4);
      return { scene };
    }
  }
  const context = vm.createContext({
    THREE: { ...THREE, WebGLRenderer: Renderer }, GLTFLoader: Loader,
    document: { querySelector: element, addEventListener() {} },
    window: { addEventListener() {} },
    navigator: { mediaDevices: { getUserMedia: async () => ({ getTracks: () => [] }) } },
    fetch: async () => ({ ok: true, json: async () => ({ modelUrl: 'demo.glb' }) }),
    innerWidth: 360, innerHeight: 800, devicePixelRatio: 1,
    requestAnimationFrame(callback) { frame = callback; },
    performance: { now: () => 100 },
    setTimeout: () => 1, clearTimeout() {},
  });
  const source = (await readFile(new URL('../assets/try_on/try_on.js', import.meta.url), 'utf8'))
    .replace(/^import .*;\r?\n/gm, '');
  await vm.runInContext(`(async () => { ${source}\n})()`, context);
  await element('#start').events.click();
  frame(100);
  const shoes = renderedScene.children.filter(item => item.isGroup);
  assert.equal(shoes.length, 2);
  assert.ok(shoes.every(shoe => shoe.visible && shoe.scale.x > 100));
  const bounds = new THREE.Box3().setFromObject(shoes[0]);
  assert.ok(Math.abs(bounds.getSize(new THREE.Vector3()).y - shoes[0].scale.x) < .001);
  assert.ok(bounds.getCenter(new THREE.Vector3()).distanceTo(shoes[0].position) < .001);
  assert.equal(element('#manualControls').style.display, 'block');
  assert.match(element('#status').textContent, /Manual/);
  assert.equal(renderer.toneMapping, THREE.ACESFilmicToneMapping);
  assert.equal(renderer.toneMappingExposure, .85);
  const initialTilt = shoes[0].children[0].rotation.x;
  element('#flip').events.click();
  assert.ok(Math.abs(shoes[0].children[0].rotation.x - initialTilt - Math.PI) < .001);
  assert.equal(shoes[1].children[0].rotation.x, initialTilt);
  element('#flip').events.click();
  assert.equal(shoes[0].children[0].rotation.x, initialTilt);
  const rightScale = shoes[1].scale.x;
  element('#scale').events.input({ target: { value: '1.5' } });
  assert.equal(shoes[0].scale.x, rightScale * 1.5);
  assert.equal(shoes[1].scale.x, rightScale);
  element('#rotation').events.input({ target: { value: '45' } });
  assert.equal(shoes[0].rotation.z, Math.PI * 1.25);
  element('#tilt').events.input({ target: { value: '30' } });
  assert.equal(shoes[0].children[0].rotation.x, Math.PI / 2 + Math.PI / 6);
  element('#selected').events.change({ target: { value: '1' } });
  element('#positionX').events.input({ target: { value: '25' } });
  assert.equal(shoes[1].position.x, 90);
  const leftPosition = shoes[0].position.clone();
  element('#canvas').events.pointerdown({ pointerId: 1, clientX: 270, clientY: 256 });
  element('#canvas').events.pointermove({ pointerId: 1, clientX: 290, clientY: 276 });
  element('#canvas').events.pointerup({ pointerId: 1 });
  assert.equal(shoes[1].position.x, 110);
  assert.ok(shoes[0].position.equals(leftPosition));
  await element('#freeze').events.click();
  assert.equal(element('#freeze').textContent, 'Reanudar cámara');
  await element('#freeze').events.click();
  assert.equal(element('#freeze').textContent, 'Congelar cámara');


  // Exercise the no-detection timeout without loading WASM in Node.
  const retrySource = source.replace(/if \(!detector\) prepareDetector\(\);/, '');
  await vm.runInContext(`(async () => { ${retrySource}\n})()`, context);
  await element('#start').events.click();
  element('#mode').events.click();
  frame(200);
  const automaticShoes = renderedScene.children.filter(item => item.isGroup);
  assert.ok(automaticShoes.every(shoe => shoe.visible));
  const before = automaticShoes.map(shoe => shoe.position.clone());
  element('#mode').events.click();
  assert.ok(automaticShoes.every((shoe, i) => shoe.position.equals(before[i])));
  element('#mode').events.click();
  frame(6100);
  assert.ok(renderedScene.children.filter(item => item.isGroup).every(shoe => shoe.visible));
  assert.equal(element('#manualControls').style.display, 'block');
  assert.match(element('#status').textContent, /No se detectaron/);
});
