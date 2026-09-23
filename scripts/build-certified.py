#!/usr/bin/env python3
"""Build Sources/SkyCore/Resources/darksky/certified.json from Wikidata plus data/certified-curated.json."""
import json, re, sys, urllib.parse, urllib.request
UA = {'User-Agent': 'Nightwatch-data/0.2 (https://github.com/rsutcliffe/nightwatch)'}
SPARQL = '''SELECT ?item ?label ?coord ?type ?country ?iso WHERE {
  VALUES ?type { wd:Q3457162 wd:Q52216504 wd:Q72114283 }
  ?item wdt:P31 ?type ; wdt:P625 ?coord .
  OPTIONAL { ?item wdt:P17 ?country . OPTIONAL { ?country wdt:P297 ?iso } }
  OPTIONAL { ?item rdfs:label ?label FILTER(LANG(?label)="en") } }'''
KIND = {'Q52216504': 'park', 'Q72114283': 'reserve', 'Q3457162': 'park'}

def wikidata():
    url = 'https://query.wikidata.org/sparql?' + urllib.parse.urlencode({'query': SPARQL})
    req = urllib.request.Request(url, headers={**UA, 'Accept': 'application/sparql-results+json'})
    for attempt in (1, 2):
        try:
            rows = json.load(urllib.request.urlopen(req, timeout=170))['results']['bindings']
            break
        except Exception:
            if attempt == 2: raise
    out = {}
    for r in rows:
        qid = r['item']['value'].rsplit('/', 1)[1]
        m = re.match(r'Point\(([-\d.]+) ([-\d.]+)\)', r['coord']['value'])
        if not m: continue
        lon, lat = float(m.group(1)), float(m.group(2))
        out.setdefault(qid, {
            'id': 'wd-' + qid.lower(), 'name': r.get('label', {}).get('value', qid), 'kind': KIND[r['type']['value'].rsplit('/', 1)[1]],
            'country': r.get('iso', {}).get('value') or None,
            'latitude': round(lat, 4), 'longitude': round(lon, 4), 'designated': None, 'bortle': None,
            'source': 'https://www.wikidata.org/wiki/' + qid, 'wikidata': qid})
    return list(out.values())

def main():
    curated = json.load(open('data/certified-curated.json'))
    for c in curated:
        for k in ('id', 'name', 'kind', 'country', 'latitude', 'longitude', 'source'):
            if c.get(k) in (None, ''): sys.exit(f'curated entry missing {k}: {c}')
    wd = wikidata()
    curated_q = {c.get('wikidata') for c in curated if c.get('wikidata')}
    merged = curated + [w for w in wd if w['wikidata'] not in curated_q]
    merged.sort(key=lambda e: (e['country'] or '', e['name']))
    json.dump(merged, open('Sources/SkyCore/Resources/darksky/certified.json', 'w'), indent=1, ensure_ascii=False)
    print(f'{len(curated)} curated + {len(merged) - len(curated)} from Wikidata = {len(merged)} places')

if __name__ == '__main__':
    main()
