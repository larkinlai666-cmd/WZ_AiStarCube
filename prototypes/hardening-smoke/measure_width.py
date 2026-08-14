import sys, unicodedata

def ps_width(s):
    w = 0
    for ch in s:
        code = ord(ch)
        if code <= 0x1F:
            continue
        wide = False
        if code >= 0x1100:
            if code <= 0x115F or code in (0x2329, 0x232A):
                wide = True
            elif 0x2E80 <= code <= 0xA4CF:
                wide = True
            elif 0xAC00 <= code <= 0xD7A3:
                wide = True
            elif 0xF900 <= code <= 0xFAFF:
                wide = True
            elif 0xFE10 <= code <= 0xFE6F:
                wide = True
            elif 0xFF00 <= code <= 0xFF60:
                wide = True
            elif 0xFFE0 <= code <= 0xFFE6:
                wide = True
            elif code >= 0x20000:
                wide = True
        w += 2 if wide else 1
    return w

path = sys.argv[1]
with open(path, encoding='utf-8-sig', errors='replace') as f:
    lines = [l.rstrip('\r\n') for l in f]

rows = []
for i, l in enumerate(lines, 1):
    r = l.rstrip(' ')
    if not r:
        continue
    rows.append((i, ps_width(r), len(r), r))

if not rows:
    print('(no content lines)')
    sys.exit(0)

widths = {}
for i, pw, rw, r in rows:
    widths.setdefault(pw, []).append(i)

print('distinct trailing-trimmed display widths:', sorted(widths))
for pw in sorted(widths):
    print(f'  psw={pw}: {len(widths[pw])} lines -> {widths[pw][:12]}{"..." if len(widths[pw])>12 else ""}')

base = max(widths, key=lambda k: len(widths[k]))
bad = [(i, pw, r) for i, pw, rw, r in rows if pw != base]
print(f'modal width psw={base}; deviations={len(bad)}')
for i, pw, r in bad[:40]:
    print(f'  L{i} psw={pw}: {r[:100]}')
