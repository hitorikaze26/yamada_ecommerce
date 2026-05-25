import re
from pathlib import Path

root = Path('server/app')
# Match exact buyer/seller/rider segments (followed by end, slash, or parameter)
pattern = re.compile(r"@(\w+_bp)\.(get|post|put|delete)\('\/(buyer|seller|rider)(?:'|/|<)")
role_map = {'buyer':'buyer_required', 'seller':'seller_required', 'rider':'rider_required'}

issues = []
for p in root.rglob('*.py'):
    try:
        text = p.read_text(encoding='utf-8')
    except Exception:
        continue
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = pattern.search(line)
        if m:
            role = m.group(3)
            # gather decorators preceding the function (up to 6 lines)
            has_role = False
            has_jwt = False
            for j in range(i+1, min(i+8, len(lines))):
                ln = lines[j].strip()
                if ln.startswith('@'):
                    if role_map[role] in ln:
                        has_role = True
                        break
                    if 'jwt_required' in ln:
                        has_jwt = True
                else:
                    # reached a non-decorator line (likely def)
                    break
            if not has_role:
                issues.append((str(p), i+1, line.strip(), has_jwt))

if not issues:
    print('No missing role decorators found for buyer/seller/rider routes.')
else:
    print('Potential missing role decorators:')
    for f,ln,text,has_jwt in issues:
        print(f"{f}:{ln} -> {text} | jwt_present={has_jwt}")
