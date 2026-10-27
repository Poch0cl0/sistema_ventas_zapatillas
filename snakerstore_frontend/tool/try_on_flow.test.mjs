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
      play: async () => {},
    });
    return elements.get(selector);
  };
  let frame, renderedScene;
  class Renderer {
    setSize() {} setPixelRatio() {} dispose() {}
    render(scene) { renderedScene = scene; }
  }
  class Loader {
    async loadAsync() {
      return { scene: new THREE.Mesh(new THREE.BoxGeometry(.1, .1, .27), new THREE.MeshBasicMaterial()) };
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
  assert.equal(element('#manualControls').style.display, 'block');
  assert.match(element('#status').textContent, /Modo manual/);

  // Exercise the no-detection timeout without loading WASM in Node.
  const retrySource = source.replace(/if \(!detector\) prepareDetector\(\);/, '');
  await vm.runInContext(`(async () => { ${retrySource}\n})()`, context);
  await element('#start').events.click();
  element('#mode').events.click();
  frame(6100);
  assert.ok(renderedScene.children.filter(item => item.isGroup).every(shoe => shoe.visible));
  assert.equal(element('#manualControls').style.display, 'block');
  assert.match(element('#status').textContent, /No se detectaron/);
});
