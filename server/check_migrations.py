"""Check all migration files for proper revision IDs using single or double quotes."""
import re, os

for f in sorted(os.listdir('migrations/versions')):
    if not f.endswith('.py'):
        continue
    content = open(f'migrations/versions/{f}', encoding='utf-8').read()
    rev = re.search(r"""revision\s*=\s*['"]([^'"]+)['"]""", content)
    down = re.search(r"""down_revision\s*=\s*['"]([^'"]+)['"]""", content)
    head = rev.group(1) if rev else '???'
    down_val = down.group(1) if down else '???'
    if head == '???' or down_val == '???':
        print(f'{f:55s} rev={head:30s} down={down_val:30s}')
