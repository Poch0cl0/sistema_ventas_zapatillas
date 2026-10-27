import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = new URL('../assets/try_on/', import.meta.url);
const three = new URL('vendor/three.module.js', root).href;
const moduleUrl = source => `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
const utils = moduleUrl((await readFile(new URL('vendor/BufferGeometryUtils.js', root), 'utf8')).replaceAll("from 'three'", `from '${three}'`));
const loaderSource = (await readFile(new URL('vendor/GLTFLoader.js', root), 'utf8'))
  .replaceAll("from 'three'", `from '${three}'`).replaceAll("'./BufferGeometryUtils.js'", JSON.stringify(utils));
const { GLTFLoader } = await import(moduleUrl(loaderSource));
for (const name of ['urban_sand', 'sport_night']) {
  const file = new URL(`models/${name}.glb`, root);
  const bytes = await readFile(file);
  const gltf = await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset+bytes.byteLength), '');
  const { Box3, Vector3 } = await import(three);
  const size = new Box3().setFromObject(gltf.scene).getSize(new Vector3());
  if (!(size.z > .25 && size.z < .30 && size.x > .08 && size.y > .07)) throw Error(`Invalid dimensions: ${name}`);
  let count = 0;
  gltf.scene.traverse(node => { if (node.isMesh) count++; });
  console.log(`${fileURLToPath(file)}: ${count} meshes, ${size.x.toFixed(3)} × ${size.y.toFixed(3)} × ${size.z.toFixed(3)} m`);
}
