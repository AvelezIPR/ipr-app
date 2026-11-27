"""Genera assets/map/colombia_map.json a partir de la geometría de la web.

Fuente: ipr-frontend/src/features/sedes/colombia-map-data.ts (límites
departamentales del DANE, MGN 2018, proyectados y simplificados; sin San
Andrés). Uso:

    python tool/gen_colombia_map.py ../ipr-frontend/src/features/sedes/colombia-map-data.ts

La geometría no se edita a mano: si la web la regenera, se vuelve a ejecutar.
"""

import json
import re
import sys

src = sys.argv[1] if len(sys.argv) > 1 else '../ipr-frontend/src/features/sedes/colombia-map-data.ts'
text = open(src, encoding='utf-8').read()

viewbox = re.search(r'COLOMBIA_MAP_VIEWBOX\s*=\s*\{\s*width:\s*(\d+),\s*height:\s*(\d+)', text)
assert viewbox, 'no se encontró el viewBox'

departments = []
for code, name, d in re.findall(r'\{\s*code:\s*"([^"]+)",\s*name:\s*"([^"]+)",\s*d:\s*"([^"]+)"\s*\}', text):
    # Solo M, L y Z absolutos: así el lector de la app es trivial y exacto.
    assert set(re.findall(r'[A-Za-z]', d)) <= {'M', 'L', 'Z'}, f'comandos no soportados en {name}'
    departments.append({'code': code, 'name': name, 'd': d})

cities = {}
block = text[text.index('CIUDADES_MAPA'):]
for name, dept, x, y in re.findall(
    r'"([^"]+)":\s*\{\s*dept:\s*"([^"]+)",\s*x:\s*([\d.]+),\s*y:\s*([\d.]+)\s*\}', block
):
    cities[name] = {'dept': dept, 'x': float(x), 'y': float(y)}

out = {
    'source': 'ipr-frontend/src/features/sedes/colombia-map-data.ts (DANE MGN 2018, proyectado y simplificado)',
    'viewBox': {'width': int(viewbox.group(1)), 'height': int(viewbox.group(2))},
    'departments': departments,
    'cities': cities,
}
with open('assets/map/colombia_map.json', 'w', encoding='utf-8', newline='\n') as f:
    json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
print(len(departments), 'departamentos,', len(cities), 'ciudades')
