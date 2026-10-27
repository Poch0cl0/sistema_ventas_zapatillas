import * as THREE from 'three';
import { GLTFLoader } from './vendor/GLTFLoader.js';
import { footTransform, smoothAngle } from './tracking.mjs';

const video = document.querySelector('#video'), canvas = document.querySelector('#canvas');
const status = document.querySelector('#status'), start = document.querySelector('#start');
const modeButton = document.querySelector('#mode'), manualControls = document.querySelector('#manualControls');
let renderer, scene, camera, detector, stream, shoes = [], stopped = false, manual = false;
let loadingDetector = false, lastVideoTime = -1, lastInference = 0;
let manualScale = 1, manualRotation = 0, drag = null;
let lastFootSeen = 0;
const message = text => { if (status.textContent !== text) status.textContent = text; };

function useManual(text = 'Modo manual · Arrastra las zapatillas sobre tus pies y ajusta tamaño y giro.') {
  manual = true;
  manualControls.style.display = 'block';
  modeButton.textContent = 'Probar seguimiento experimental';
  placeManual();
  message(text);
}

function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h);
  camera.left = -w/2; camera.right = w/2; camera.top = h/2; camera.bottom = -h/2;
  camera.updateProjectionMatrix();
  if (manual) placeManual();
}

function placeManual() {
  shoes.forEach((shoe, i) => {
    shoe.visible = true;
    if (!shoe.userData.moved) shoe.position.set((i ? 1 : -1)*innerWidth*.19, 0, 0);
    shoe.scale.setScalar(Math.min(innerWidth*.55, innerHeight*.35)*manualScale);
    shoe.rotation.z = Math.PI + manualRotation;
  });
}

async function prepareDetector() {
  if (loadingDetector || detector || stopped) return;
  loadingDetector = true;
  message('Cargando seguimiento experimental… Puedes usar el ajuste manual.');
  try {
    const { FilesetResolver, PoseLandmarker } = await import('./vendor/vision_bundle.mjs');
    const files = await FilesetResolver.forVisionTasks(new URL('./vendor', location.href).href);
    const result = await PoseLandmarker.createFromOptions(files, {
      baseOptions: { modelAssetPath: new URL('./vendor/pose_landmarker_lite.task', location.href).href },
      runningMode: 'VIDEO', numPoses: 1, minPoseDetectionConfidence: .5,
      minPosePresenceConfidence: .5, minTrackingConfidence: .5,
    });
    if (stopped) result.close(); else detector = result;
  } catch (_) {
    if (!stopped && !manual) useManual('Seguimiento no disponible · Coloca las zapatillas manualmente sobre tus pies.');
  } finally { loadingDetector = false; }
}

function track(now) {
  if (stopped) return;
  requestAnimationFrame(track);
  if (!stream) return;
  if (!manual && detector && video.readyState >= 2 && video.currentTime !== lastVideoTime && now-lastInference > 65) {
    lastVideoTime = video.currentTime; lastInference = now;
    try {
      const pose = detector.detectForVideo(video, now).landmarks[0];
      let count = 0;
      shoes.forEach((shoe, i) => {
        const transform = pose && footTransform(pose, i ? [28,30,32] : [27,29,31],
          [video.videoWidth, video.videoHeight, innerWidth, innerHeight]);
        if (!transform) { shoe.visible = false; return; }
        const blend = shoe.visible ? .4 : 1;
        shoe.position.lerp(new THREE.Vector3(transform.x-innerWidth/2, innerHeight/2-transform.y, 0), blend);
        shoe.rotation.z = smoothAngle(shoe.rotation.z, transform.angle, blend);
        shoe.scale.setScalar(THREE.MathUtils.lerp(shoe.scale.x, transform.length, blend));
        shoe.visible = true; count++;
      });
      if (count) lastFootSeen = now;
      message(count ? `${count === 2 ? 'Ambos pies detectados' : 'Un pie detectado'} · Mueve los pies despacio.`
        : 'Buscando pies… Encuadra pies, tobillos y parte de las piernas. Prueba el ajuste manual si no detecta.');
    } catch (_) {
      shoes.forEach(shoe => shoe.visible = false);
      detector.close(); detector = null;
      useManual('Se interrumpió el seguimiento · Puedes seguir ajustando las zapatillas manualmente.');
    }
  }
  if (!manual && now - lastFootSeen >= 6000) {
    useManual('No se detectaron los pies · Modo manual activado. Arrastra las zapatillas sobre tus pies.');
  }
  renderer.render(scene, camera);
}

function stop() {
  stopped = true;
  stream?.getTracks().forEach(track => track.stop()); stream = null;
  video.srcObject = null;
  detector?.close(); detector = null;
  shoes.forEach(s => { s.visible = false; });
  renderer?.dispose();
}
window.stopTryOn = stop;
window.addEventListener('pagehide', stop);
document.addEventListener('visibilitychange', () => { if (document.hidden) stop(); });

start.addEventListener('click', async () => {
  start.disabled = true;
  try {
    const granted = await new Promise(resolve => {
      const timeout = setTimeout(() => resolve(false), 45000);
      window.cameraPermissionResult = value => { clearTimeout(timeout); resolve(value); };
      if (window.TryOnBridge) TryOnBridge.postMessage('requestCamera'); else resolve(true);
    });
    if (!granted || stopped) throw new Error('permission');
    const nextStream = await navigator.mediaDevices.getUserMedia({ audio: false,
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 640 }, height: { ideal: 480 } } });
    if (stopped) { nextStream.getTracks().forEach(t => t.stop()); return; }
    stream = nextStream; video.srcObject = stream; await video.play();
    start.hidden = true; modeButton.hidden = false;
    useManual(); requestAnimationFrame(track);
  } catch (_) {
    stream?.getTracks().forEach(t => t.stop()); stream = null;
    message('No se pudo abrir la cámara. Revisa el permiso de cámara en Ajustes y vuelve a intentarlo.');
    start.disabled = false; start.textContent = 'Reintentar cámara';
  }
});

modeButton.addEventListener('click', () => {
  if (!manual) { useManual(); return; }
  manual = false;
  shoes.forEach(s => { s.visible = false; s.userData.moved = false; });
  manualControls.style.display = 'none';
  modeButton.textContent = 'Ajustar manualmente';
  lastFootSeen = performance.now();
  message('Buscando postura · Encuadra también las piernas. Si no detecta, volverás al modo manual.');
  if (!detector) prepareDetector();
});
document.querySelector('#scale').addEventListener('input', e => { manualScale = +e.target.value; placeManual(); });
document.querySelector('#rotation').addEventListener('input', e => { manualRotation = +e.target.value*Math.PI/180; placeManual(); });
canvas.addEventListener('pointerdown', e => {
  if (!manual) return;
  const p = new THREE.Vector2(e.clientX-innerWidth/2, innerHeight/2-e.clientY);
  const index = shoes[0].position.distanceTo(new THREE.Vector3(p.x,p.y,0)) < shoes[1].position.distanceTo(new THREE.Vector3(p.x,p.y,0)) ? 0 : 1;
  drag = shoes[index]; drag.userData.moved = true;
  canvas.setPointerCapture(e.pointerId); drag.position.set(p.x,p.y,0);
});
canvas.addEventListener('pointermove', e => { if (drag) drag.position.set(e.clientX-innerWidth/2,innerHeight/2-e.clientY,0); });
canvas.addEventListener('pointerup', () => drag = null);
canvas.addEventListener('pointercancel', () => drag = null);

try {
  const config = await fetch('./config.json').then(r => { if (!r.ok) throw Error(); return r.json(); });
  renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  scene = new THREE.Scene(); camera = new THREE.OrthographicCamera(-1,1,1,-1,.1,1000);
  camera.position.z = 500;
  scene.add(new THREE.HemisphereLight(0xffffff, 0x777777, 2.5));
  const light = new THREE.DirectionalLight(0xffffff, 2); light.position.set(-1,2,4); scene.add(light);
  const gltf = await new GLTFLoader().loadAsync(config.modelUrl);
  if (stopped) throw Error();
  const box = new THREE.Box3().setFromObject(gltf.scene), size = box.getSize(new THREE.Vector3());
  const length = size.z;
  if (!Number.isFinite(length) || length < .00001) throw Error();
  const center = box.getCenter(new THREE.Vector3());
  gltf.scene.position.sub(center); gltf.scene.scale.setScalar(1/length);
  gltf.scene.position.divideScalar(length);
  shoes = [false,true].map(mirror => {
    const group = new THREE.Group(), pivot = new THREE.Group();
    pivot.rotation.x = Math.PI/2; pivot.scale.x = mirror ? -1 : 1;
    pivot.add(gltf.scene.clone(true)); group.add(pivot); group.visible = false;
    scene.add(group); return group;
  });
  resize(); window.addEventListener('resize', resize);
  message('Modelo listo. Activa la cámara para colocar las zapatillas sobre tus pies.');
  start.disabled = false;
} catch (_) {
  message('No se pudo preparar el modelo 3D. Vuelve al producto y reintenta.');
  start.hidden = true;
}
