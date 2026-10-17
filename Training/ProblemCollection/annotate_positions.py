#!/usr/bin/env python3
"""Generate auditable *provisional* task annotations from SGF setup stones.

No target group or answer is marked as verified by this script.
"""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BOARD_SIZE = 19
SECTION_TYPES = {
    1: 'live', 2: 'kill', 3: 'make_ko', 4: 'capturing_race',
    5: 'oiotoshi', 6: 'connect', 7: 'various',
}


def neighbours(p):
    x, y = ord(p[0]) - 97, ord(p[1]) - 97
    for xx, yy in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if 0 <= xx < BOARD_SIZE and 0 <= yy < BOARD_SIZE:
            yield chr(xx + 97) + chr(yy + 97)


def groups(stones, occupied, color):
    unseen = set(stones)
    found = []
    while unseen:
        component = {unseen.pop()}
        frontier = list(component)
        while frontier:
            for q in neighbours(frontier.pop()):
                if q in unseen:
                    unseen.remove(q)
                    component.add(q)
                    frontier.append(q)
        liberties = {q for p in component for q in neighbours(p) if q not in occupied}
        xs = [ord(p[0]) - 97 for p in component]
        ys = [ord(p[1]) - 97 for p in component]
        found.append({
            'color': color,
            'stones': sorted(component),
            'liberties': sorted(liberties),
            'liberty_count': len(liberties),
            'bbox_sgf': [chr(min(xs) + 97) + chr(min(ys) + 97),
                         chr(max(xs) + 97) + chr(max(ys) + 97)],
        })
    return sorted(found, key=lambda g: (-len(g['stones']), g['stones']))


manifest = json.loads((ROOT / 'source_manifest.json').read_text(encoding='utf-8'))
annotations = []
for item in manifest:
    sgf = (ROOT / item['sgf_path']).read_text(encoding='utf-8')
    # Each extracted SGF contains exactly one setup child and no moves.
    child = sgf.split('\n', 1)[1]
    ab = re.search(r'AB((?:\[[a-s]{2}\])+)', child)
    aw = re.search(r'AW((?:\[[a-s]{2}\])+)', child)
    black = re.findall(r'\[([a-s]{2})\]', ab.group(1)) if ab else []
    white = re.findall(r'\[([a-s]{2})\]', aw.group(1)) if aw else []
    if len(set(black + white)) != len(black + white):
        raise ValueError(f'Duplicate or overlapping stones: {item["id"]}')
    occupied = set(black + white)
    all_groups = groups(black, occupied, 'B') + groups(white, occupied, 'W')
    label = item['source_label']
    section_match = re.match(r'problem (\d+)-\d+,', label) if item['source_collection'] == 'gokyoshumyo.sgf' else None
    section = int(section_match.group(1)) if section_match else None
    task_type = SECTION_TYPES.get(section, 'unclassified')
    target_color = item['to_play'] if task_type == 'live' else ('W' if item['to_play'] == 'B' else 'B') if task_type == 'kill' else None
    candidate_groups = [g['stones'] for g in all_groups if g['color'] == target_color] if target_color else []
    annotations.append({
        'id': item['id'],
        'source_label': label,
        'to_play': item['to_play'],
        'task_type': task_type,
        'task_type_source': 'gokyoshumyo_section' if section else None,
        'task_type_review': 'pending',
        'setup': {'black': black, 'white': white},
        'groups': all_groups,
        'target_color_candidate': target_color,
        'target_group_candidates': candidate_groups,
        'target_group_verified': None,
        'search_region_verified': None,
        'human_review': 'pending',
        'solver_result': None,
        'katago_result': None,
        'solution_status': 'unsolved',
    })

path = ROOT / 'position_annotations.json'
path.write_text(json.dumps(annotations, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Annotated {len(annotations)} source positions')
print(Counter(a['task_type'] for a in annotations))
print('L&D target candidate counts:', Counter(len(a['target_group_candidates']) for a in annotations if a['task_type'] in ('live', 'kill')))
