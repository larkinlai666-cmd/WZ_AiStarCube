import re, glob, os, sys

root = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Administrator\.config\wezterm\workbench"
files = sorted(glob.glob(os.path.join(root, "*.lua")))
extra = r"C:\Users\Administrator\.wezterm.lua"
if os.path.isfile(extra):
    files.append(extra)

bad = 0
for f in files:
    opens = 0
    in_long_comment = False
    for raw in open(f, encoding="utf-8"):
        line = raw
        if in_long_comment:
            if "]]" in line:
                line = line.split("]]", 1)[1]
                in_long_comment = False
            else:
                continue
        if "--[[" in line:
            head, _, tail = line.partition("--[[")
            if "]]" in tail:
                line = head + tail.split("]]", 1)[1]
            else:
                line = head
                in_long_comment = True
        line = line.split("--", 1)[0]
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        n_func = len(re.findall(r"\bfunction\b", line))
        n_if = len(re.findall(r"\bif\b", line))
        n_for = len(re.findall(r"\bfor\b", line))
        n_while = len(re.findall(r"\bwhile\b", line))
        n_do = len(re.findall(r"\bdo\b", line))
        n_end = len(re.findall(r"\bend\b", line))
        opens += n_func + n_if + n_for + n_while + n_do - n_end
    name = os.path.basename(f)
    state = "OK" if opens == 0 else f"IMBALANCE {opens:+d}"
    if opens != 0:
        bad += 1
    print(f"{name:22} net={opens:+d} {state}")
print("files with imbalance:", bad)
sys.exit(1 if bad else 0)
