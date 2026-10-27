import * as THREE from 'three';
import { GLTFLoader } from './vendor/GLTFLoader.js';
import { footTransform, smoothAngle } from './tracking.mjs';

const video = document.querySelector('#video'), canvas = document.querySelector('#canvas');
const status = document.querySelector('#status'), start = document.querySelector('#start');
const modeButton = document.querySelector('#mode'), manualControls = document.querySelector('#manualControls');
let renderer, scene, camera, detector, stream, shoes = [], stopped = false, manual = false;
let loadingDetector = false, lastVideoTime = -1, lastInference = 0;
let selected = 0, drag = null, frozen = false;
const baseSize = () => Math.min(innerWidth * .55, innerHeight * .28);
let lastFootSeen = 0;
const message = text => { if (status.textContent !== text) status.textContent = text; };

function useManual(text = 'Modo manual · Arrastra las zapatillas sobre tus pies y ajusta tamaño y giro.') {
  manual = true;
  manualControls.style.display = 'block';
  modeButton.textContent = 'Activar tracking automático (experimental)';
  modeButton.setAttribute('aria-pressed', 'false');
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
    if (!shoe.userData.placed) {
      shoe.position.set((i ? 1 : -1)*innerWidth*.19, innerHeight*.18, 0);
      shoe.scale.setScalar(baseSize());
      shoe.rotation.z = Math.PI;
      shoe.userData.placed = true;
    }
  });
  syncControls();
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
        if (!transform) return; // Keep the last placement available for manual correction.
        const blend = shoe.visible ? .4 : 1;
        shoe.position.lerp(new THREE.Vector3(transform.x-innerWidth/2, innerHeight/2-transform.y, 0), blend);
        shoe.rotation.z = smoothAngle(shoe.rotation.z, transform.angle, blend);
        shoe.scale.setScalar(THREE.MathUtils.lerp(shoe.scale.x, transform.length, blend));
        shoe.visible = true; shoe.userData.placed = true; count++;
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
document.addEventListener('visibilitychange', () => { if (document.hidden && stream) stop(); });

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
  if (frozen) { frozen = false; video.play().catch(() => useManual()); }
  document.querySelector('#freeze').textContent = 'Congelar cámara';
  manualControls.style.display = 'none';
  modeButton.textContent = 'Desactivar tracking · Ajustar a mano';
  modeButton.setAttribute('aria-pressed', 'true');
  lastFootSeen = performance.now();
  message('Buscando postura · Encuadra también las piernas. Si no detecta, volverás al modo manual.');
  if (!detector) prepareDetector();
});
function syncControls() {
  const shoe = shoes[selected];
  if (!shoe) return;
  document.querySelector('#selected').value = String(selected);
  document.querySelector('#scale').value = shoe.scale.x / baseSize();
  const degrees = (shoe.rotation.z - Math.PI) * 180 / Math.PI;
  document.querySelector('#rotation').value = ((degrees + 180) % 360 + 360) % 360 - 180;
  document.querySelector('#tilt').value = (shoe.children[0].rotation.x - Math.PI/2) * 180 / Math.PI;
  document.querySelector('#positionX').value = shoe.position.x / innerWidth * 100;
  document.querySelector('#positionY').value = shoe.position.y / innerHeight * 100;
}
document.querySelector('#selected').addEventListener('change', e => { selected = +e.target.value; syncControls(); });
for (const [id, apply] of [
  ['scale', (shoe, v) => shoe.scale.setScalar(baseSize()*v)],
  ['rotation', (shoe, v) => { shoe.rotation.z = Math.PI + v*Math.PI/180; }],
  ['tilt', (shoe, v) => { shoe.children[0].rotation.x = Math.PI/2 + v*Math.PI/180; }],
  ['positionX', (shoe, v) => { shoe.position.x = innerWidth*v/100; }],
  ['positionY', (shoe, v) => { shoe.position.y = innerHeight*v/100; }],
]) document.querySelector('#'+id).addEventListener('input', e => {
  if (!manual) return;
  apply(shoes[selected], +e.target.value);
});
document.querySelector('#reset').addEventListener('click', () => {
  shoes.forEach(shoe => { shoe.userData.placed = false; shoe.children[0].rotation.x = Math.PI/2; });
  useManual('Zapatillas centradas · Selecciona izquierda o derecha para acomodarlas.');
});
document.querySelector('#freeze').addEventListener('click', async () => {
  if (!manual) return;
  if (frozen) {
    try { await video.play(); frozen = false; } catch (_) { message('No se pudo reanudar la cámara. Vuelve a entrar al probador.'); }
  } else { video.pause(); frozen = true; }
  document.querySelector('#freeze').textContent = frozen ? 'Reanudar cámara' : 'Congelar cámara';
});
canvas.addEventListener('pointerdown', e => {
  if (!manual || drag) return;
  const x = e.clientX-innerWidth/2, y = innerHeight/2-e.clientY;
  const shoe = shoes[selected];
  drag = { shoe, pointerId: e.pointerId, x: x-shoe.position.x, y: y-shoe.position.y };
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener('pointermove', e => {
  if (!drag || e.pointerId !== drag.pointerId) return;
  drag.shoe.position.set(
    THREE.MathUtils.clamp(e.clientX-innerWidth/2-drag.x, -innerWidth/2, innerWidth/2),
    THREE.MathUtils.clamp(innerHeight/2-e.clientY-drag.y, -innerHeight/2, innerHeight/2), 0);
  syncControls();
});
const endDrag = e => { if (drag?.pointerId === e.pointerId) drag = null; };
canvas.addEventListener('pointerup', endDrag);
canvas.addEventListener('pointercancel', endDrag);
canvas.addEventListener('lostpointercapture', endDrag);

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
  const normalized = new THREE.Group();
  normalized.add(gltf.scene);
  normalized.scale.setScalar(1/length);
  normalized.position.copy(center).multiplyScalar(-1/length);
  shoes = [false,true].map(mirror => {
    const group = new THREE.Group(), pivot = new THREE.Group();
    pivot.rotation.x = Math.PI/2; pivot.scale.x = mirror ? -1 : 1;
    pivot.add(normalized.clone(true)); group.add(pivot); group.visible = false;
    scene.add(group); return group;
  });
  resize(); window.addEventListener('resize', resize);
  message('Modelo listo. Activa la cámara para colocar las zapatillas sobre tus pies.');
  start.disabled = false;
} catch (_) {
  message('No se pudo preparar el modelo 3D. Vuelve al producto y reintenta.');
  start.hidden = true;
}
