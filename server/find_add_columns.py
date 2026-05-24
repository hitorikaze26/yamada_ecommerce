"""Find all add_column operations in migrations."""
import re, os

for f in sorted(os.listdir('migrations/versions')):
    if not f.endswith('.py'):
        continue
    content = open(f'migrations/versions/{f}', encoding='utf-8').read()
    lines = content.split('\n')
    
    in_alter = None
    for i, line in enumerate(lines):
        s = line.strip()
        
        # Track batch_alter_table context
        m = re.search(r"with op\.batch_alter_table\('([^']+)'", s)
        if m:
            in_alter = m.group(1)
            continue
        
        # op.add_column('table', ...)
        m = re.search(r"op\.add_column\(\s*'([^']+)'", s)
        if m:
            table = m.group(1)
            print(f"  OUTSIDE_BATCH: {table}")
            continue
        
        # Inside batch_alter_table add_column
        if in_alter and 'add_column' in s:
            col_match = re.search(r"add_column\(sa\.Column\('([^']+)'", s)
            if col_match:
                col = col_match.group(1)
                print(f"{f:55s} ADD TO {in_alter:25s} col={col}")
        
        # Check if leaving the with block
        if s == '':  # empty line might indicate end of block
            pass
