import re, sys, os

files = ["launch.lua", "layouts.lua", "resume.lua", "projects.lua", "help.lua",
         "desk.lua", "keys.lua", "status.lua", "options.lua", "hyperlinks.lua"]
base = os.path.join(os.path.expanduser("~"), ".config", "wezterm", "workbench")
bad = 0
for fn in files:
    p = os.path.join(base, fn)
    with open(p, encoding="utf-8") as fh:
        txt = fh.read()
    txt = re.sub(r"--\[\[[\s\S]*?\]\]", "", txt)
    opens = closes = 0
    for raw in txt.splitlines():
        ln = re.sub(r"--.*$", "", raw)
        ln = re.sub(r'"(?:[^"\\]|\\.)*"', '""', ln)
        ln = re.sub(r"'(?:[^'\\]|\\.)*'", "''", ln)
        t = ln.strip()
        for tok in re.findall(r"\b(function|if|for|while|repeat|do|end|until)\b", t):
            if tok in ("function", "if", "for", "while", "repeat"):
                opens += 1
            elif tok == "do":
                if not re.search(r"\b(for|while)\b", t):
                    opens += 1
            elif tok in ("end", "until"):
                closes += 1
    ok = (opens == closes)
    if not ok:
        bad += 1
    print(f"{fn}: open={opens} close={closes} {'OK' if ok else 'IMBALANCE'}")
sys.exit(1 if bad else 0)
