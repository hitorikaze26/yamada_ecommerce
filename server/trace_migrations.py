"""Trace migration dependency chain to find which depend on the ENUM migration."""
import re, os

migrations = {}
for f in os.listdir('migrations/versions'):
    if not f.endswith('.py'):
        continue
    path = os.path.join('migrations/versions', f)
    content = open(path, encoding='utf-8').read()
    rev = re.search(r"revision = '([^']+)'", content)
    down = re.search(r"down_revision = '([^']+)'", content)
    head = rev.group(1) if rev else '?'
    down_val = down.group(1) if down else None
    desc = content.split('\n')[1].strip(' "')
    migrations[head] = {'file': f, 'down': down_val, 'desc': desc}

enum_rev = '45d59a828979'
print(f"ENUM migration: {migrations[enum_rev]['file']} -> {migrations[enum_rev]['desc']}")
print(f"Down revision: {migrations[enum_rev]['down']}")

# Find all migrations that come after the ENUM migration
after_enum = [h for h, m in migrations.items() if m['down'] == enum_rev]
print(f"\nImmediate dependents of ENUM: {after_enum}")
for h in after_enum:
    print(f"  {h}: {migrations[h]['file']} -> {migrations[h]['desc']}")

# Trace all migrations
print("\n=== ALL MIGRATIONS BY DEPENDENCY ===")
# Find roots (migrations with no down_revision or down_revision=None)
roots = [h for h, m in migrations.items() if m['down'] is None or m['down'] == 'None']
print(f"Roots: {roots}")

# Build forward deps
children_of = {}
for h, m in migrations.items():
    d = m['down']
    if d:
        children_of.setdefault(d, []).append(h)

# Trace from roots
def trace(node, depth=0):
    prefix = "  " * depth
    m = migrations.get(node)
    if m:
        print(f"{prefix}{node}: {m['file']} - {m['desc'][:80]}")
    childs = children_of.get(node, [])
    for c in childs:
        trace(c, depth + 1)

for r in roots:
    trace(r)

print("\n=== Which important migrations depend on ENUM? ===")
# Check specific migrations
important = ['m9n0o1p2q3r4_user_archive_fields', 'fcbefc7fa534_', '021585b592d5_', 
             '7b12585dcf4b_add_refund_requests', 'a1b2c3d4_add_chat_tables',
             'add_cart_tables', 'abcd1234_add_notifications_table']
important_revs = {}
for h, m in migrations.items():
    for imp in important:
        if imp in m['file']:
            important_revs[imp] = h
            # Find ALL ancestors
            ancestors = []
            cur = m['down']
            while cur:
                ancestors.append(cur)
                cur_m = migrations.get(cur)
                cur = cur_m['down'] if cur_m else None
            depends_on_enum = enum_rev in ancestors
            print(f"{imp}: rev={h}, depends_on_ENUM={depends_on_enum}")
