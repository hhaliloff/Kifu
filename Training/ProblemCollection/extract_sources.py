#!/usr/bin/env python3
"""Split Tasuki SGF collections into individual unsolved source positions."""
import hashlib
import json
import re
from pathlib import Path

base = Path(__file__).resolve().parent
source_dir = base / 'sources'
problem_dir = base / 'problems'
problem_dir.mkdir(exist_ok=True)
manifest = []
for source in sorted(source_dir.glob('*.sgf')):
    data = source.read_text(encoding='utf-8')
    header, body = data.split('\n', 1)
    root = header.removeprefix('(')
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    count = 0
    for line in body.splitlines():
        line = line.strip()
        if not line.startswith('(;C[problem '):
            continue
        count += 1
        title = re.search(r'^\(;C\[(problem [^\]]+)\]', line)
        turn = re.search(r'PL\[([BW])\]', line)
        if title is None or turn is None or not line.endswith(')'):
            raise ValueError(f'Malformed source problem {source.name} #{count}')
        identifier = f'{source.stem}-{count:03d}'
        sgf = '(' + root + '\n' + line + '\n)\n'
        (problem_dir / f'{identifier}.sgf').write_text(sgf, encoding='utf-8')
        manifest.append({
            'id': identifier,
            'source_collection': source.name,
            'source_sha256': source_hash,
            'source_label': title.group(1),
            'to_play': turn.group(1),
            'sgf_path': f'problems/{identifier}.sgf',
            'validation': 'pending',
            'solution': None,
        })
    print(f'{source.name}: {count} positions')
(base / 'source_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Total: {len(manifest)} positions')
