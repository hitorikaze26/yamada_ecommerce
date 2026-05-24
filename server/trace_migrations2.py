"""Trace all migration revisions and dependencies."""
import re, os

migrations = {}
for f in sorted(os.listdir('migrations/versions')):
    if not f.endswith('.py'):
        continue
    path = os.path.join('migrations/versions', f)
    content = open(path, encoding='utf-8').read()
    rev = re.search(r"revision = '([^']+)'", content)
    down = re.search(r"down_revision = '([^']+)'", content)
    branch = re.search(r"branch_labels = '([^']+)'", content)
    head = rev.group(1) if rev else 'NO_REV'
    down_val = down.group(1) if down else 'NO_DOWN'
    desc_lines = content.split('\n')
    desc = desc_lines[1].strip(' "') if len(desc_lines) > 1 else ''
    print(f'{f:55s} rev={head:30s} down={down_val:30s} branch={branch.group(1) if branch else "-"}')
