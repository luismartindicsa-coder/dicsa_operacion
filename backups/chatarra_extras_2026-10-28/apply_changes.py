"""Apply the reviewed movement plan with backups and optimistic concurrency."""

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

BACKUP = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKUP.parents[1] / 'tool'))
from mass_close_mayoreo_pending_cheques import resolve_bearer_token, supabase_request

plan_path = BACKUP / sys.argv[1]
companies = set(sys.argv[2:])
plan = [p for p in json.loads(plan_path.read_text()) if p['company'] in companies]
assert plan and {p['company'] for p in plan} == companies
before = {r['id']: r for r in json.loads((BACKUP / 'inventory_movements_v2_before.json').read_text())}
token = resolve_bearer_token()


def request(method, query, payload=None):
    status, _, body = supabase_request(
        method, 'inventory_movements_v2', token, query=query, payload=payload,
        extra_headers={'Prefer': 'return=representation'},
    )
    if status != 200:
        raise RuntimeError(f'{method} failed: HTTP {status}: {body}')
    rows = json.loads(body)
    assert isinstance(rows, list)
    return rows


def read_ids(ids):
    result = {}
    for start in range(0, len(ids), 40):
        chunk = ids[start:start + 40]
        rows = request('GET', {'select': '*', 'id': 'in.(' + ','.join(chunk) + ')'})
        result.update({r['id']: r for r in rows})
    assert set(result) == set(ids), 'Missing or inaccessible movements'
    return result


ids = [p['id'] for p in plan]
current = read_ids(ids)
for item in plan:
    assert current[item['id']] == before[item['id']], f"Concurrent edit: {item['id']}"

groups = defaultdict(list)
for item in plan:
    row = before[item['id']]
    assert row['flow'] == 'IN' and row['inventory_level'] == 'GENERAL'
    assert row['source_commercial_material_id'] == item['old_material_id']
    groups[(row['counterparty_site_id'], row['general_material_id'], item['old_material_id'], item['new_material_id'])].append(item)

expected = {}
for item in plan:
    expected[item['id']] = {
        **before[item['id']],
        'source_commercial_material_id': item['new_material_id'],
        **item.get('additional_patch', {}),
    }

for (company_id, general_id, old_material_id, new_material_id), items in groups.items():
    for start in range(0, len(items), 20):
        chunk = items[start:start + 20]
        extra_patches = [item.get('additional_patch', {}) for item in chunk]
        assert all(p == extra_patches[0] for p in extra_patches)
        conditions = ','.join(
            f"and(id.eq.{item['id']},updated_at.eq.{item['expected_updated_at']})"
            for item in chunk
        )
        changed = request('PATCH', {
            'or': '(' + conditions + ')',
            'counterparty_site_id': 'eq.' + company_id,
            'general_material_id': 'eq.' + general_id,
            'source_commercial_material_id': 'eq.' + old_material_id,
            'flow': 'eq.IN',
            'inventory_level': 'eq.GENERAL',
        }, {'source_commercial_material_id': new_material_id, **extra_patches[0]})
        with (BACKUP / 'applied_batches.jsonl').open('a') as journal:
            journal.write(json.dumps(changed, ensure_ascii=False) + '\n')
        assert {r['id'] for r in changed} == {p['id'] for p in chunk}, 'Concurrent edit or permission mismatch'
        for row in changed:
            assert {k: v for k, v in row.items() if k != 'updated_at'} == {
                k: v for k, v in expected[row['id']].items() if k != 'updated_at'
            }, f"Unexpected field change: {row['id']}"
        print(f"Applied {len(changed)} movements for {chunk[0]['company']}", flush=True)

after = read_ids(ids)
for row in after.values():
    assert {k: v for k, v in row.items() if k != 'updated_at'} == {
        k: v for k, v in expected[row['id']].items() if k != 'updated_at'
    }, f"Verification mismatch: {row['id']}"
report = {'verified': len(after), 'companies': dict(Counter(p['company'] for p in plan))}
with (BACKUP / 'verification_reports.jsonl').open('a') as journal:
    journal.write(json.dumps(report, ensure_ascii=False) + '\n')
print(json.dumps(report, ensure_ascii=False))
