"""Generate original, self-contained glTF 2.0 demo sneakers (metres, toe +Z).

No downloaded product designs or trademarks. Re-run from any directory.
"""
import json
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'try_on' / 'models'


def sneaker(name, upper, accent, sporty=False):
    binary = bytearray()
    views, accessors, meshes, nodes = [], [], [], []
    materials = [
        {'name': key, 'pbrMetallicRoughness': {
            'baseColorFactor': color, 'metallicFactor': 0, 'roughnessFactor': .78},
         'doubleSided': True}
        for key, color in [('upper', upper), ('sole', [.92, .93, .91, 1]),
                           ('accent', accent), ('lace', [.98, .98, .97, 1]),
                           ('lining', [.045, .05, .06, 1])]
    ]

    def accessor(values, size, component=5126):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        flat = [x for row in values for x in row]
        binary.extend(struct.pack('<' + ('f' if component == 5126 else 'H') * len(flat), *flat))
        views.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary) - offset})
        value = {'bufferView': len(views)-1, 'componentType': component,
                 'count': len(values), 'type': {1: 'SCALAR', 3: 'VEC3'}[size]}
        if component == 5126:
            value.update(min=[min(v[i] for v in values) for i in range(size)],
                         max=[max(v[i] for v in values) for i in range(size)])
        accessors.append(value)
        return len(accessors)-1

    def surface(label, rings, material):
        positions, normals, indices = [], [], []
        segments = 32
        # Rings run from heel (-Z) to toe (+Z), each with x/y elliptical section.
        for z, width, cy, height in rings:
            for j in range(segments):
                a = j * math.tau / segments
                positions.append([width*math.cos(a), cy+height*math.sin(a), z])
                nx, ny = math.cos(a)/max(width, .001), math.sin(a)/max(height, .001)
                length = math.hypot(nx, ny)
                normals.append([nx/length, ny/length, 0])
        for i in range(len(rings)-1):
            for j in range(segments):
                a, b = i*segments+j, i*segments+(j+1)%segments
                indices.extend([[a], [b], [a+segments], [b], [b+segments], [a+segments]])
        for ring, reverse in [(0, True), (len(rings)-1, False)]:
            for j in range(1, segments-1):
                tri = [ring*segments, ring*segments+j, ring*segments+j+1]
                indices.extend([[v] for v in (tri[::-1] if reverse else tri)])
        meshes.append({'name': label, 'primitives': [{'attributes': {
            'POSITION': accessor(positions, 3), 'NORMAL': accessor(normals, 3)},
            'indices': accessor(indices, 1, 5123), 'material': material}]})
        nodes.append({'name': label, 'mesh': len(meshes)-1})

    profile = [(-.135, .022), (-.125, .039), (-.08, .043), (-.025, .042),
               (.035, .049), (.085, .05), (.12, .037), (.137, .009)]
    surface('Outsole', [(z, w, .012, .012) for z, w in profile], 4)
    surface('Midsole', [(z, w*1.015, .027, .015 if sporty else .011) for z, w in profile], 1)
    surface('Upper', [(z, w*.94, .047, h) for (z, w), h in zip(profile,
            [.019, .043, .049, .042, .024, .019, .013, .003])], 0)
    # Raised tongue, layered toe cap, heel accent and individual lace strips.
    surface('Tongue', [(z, w, y, .005) for z, w, y in
            [(-.075, .022, .091), (-.025, .024, .085), (.027, .026, .069)]], 2)
    surface('Toe panel', [(z, w*.95, .049, .020) for z, w in profile[4:]], 0)
    surface('Heel accent', [(-.129, .027, .069, .012), (-.119, .035, .072, .013)], 2)
    for i in range(5):
        z = -.055+i*.015
        y = .092-i*.004
        surface(f'Lace {i+1}', [(z-.002, .026, y, .0015), (z+.002, .026, y, .0015)], 3)
    while len(binary) % 4:
        binary.append(0)
    document = {'asset': {'version': '2.0', 'generator': 'SneakerStore original demo models'},
                'scene': 0, 'scenes': [{'nodes': list(range(len(nodes)))}],
                'nodes': nodes, 'meshes': meshes, 'materials': materials,
                'buffers': [{'byteLength': len(binary)}], 'bufferViews': views, 'accessors': accessors}
    metadata = json.dumps(document, separators=(',', ':')).encode()
    metadata += b' ' * ((-len(metadata)) % 4)
    result = struct.pack('<III', 0x46546C67, 2, 28+len(metadata)+len(binary))
    result += struct.pack('<II', len(metadata), 0x4E4F534A)+metadata
    result += struct.pack('<II', len(binary), 0x004E4942)+binary
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f'{name}.glb').write_bytes(result)
    print(f'{name}: {len(result):,} bytes')


if __name__ == '__main__':
    sneaker('urban_sand', [.73, .66, .53, 1], [.95, .28, .08, 1])
    sneaker('sport_night', [.055, .085, .13, 1], [.45, .95, .32, 1], True)
