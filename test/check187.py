import re, glob, sys
# 1.8.7 compatibility checks. core/ loads in BOTH engines (gen-6 Ruby 1.8.7 and modern 3.1) and the
# gen-6 game adapters run on 1.8.7, so their code must be 1.8.7-safe. Files under a module's v21/, v22/
# or skyflyer/ subfolder (and games/anil/) load ONLY in the modern engine (Ruby 3.1+), so 1.9+
# syntax/APIs are fine there: skipped.
# Modern (Ruby 3.x) profiles are exempt; gen-6 (Ruby 1.8.7) games are NOT (their game code must stay
# 1.8.7-safe). MODERN: anil/royal/relict run on Ruby 3.x with the GameData API, and so does
# infinitefusion_hoenn (Essentials v18 on an mkxp-z built against Ruby 3.1). GEN-6 (linted): pokemon_z,
# opalo, armonia (Essentials 16.3), realidea, africanus, reminiscencia (PScreen_*/PB* pre-GameData), and
# generic/unknown (conservative).
MODERN = ("/v21/", "/v22/", "/skyflyer/", "games/anil/", "games/royal/", "games/relict/",
          "games/infinitefusion_hoenn/", "games/infinitefusion/")
def is_modern(path):
    p = path.replace("\\", "/")
    return any(m in p for m in MODERN)

# (1) block-level rescue: valid in modern Ruby, SYNTAX ERROR in 1.8.7. a `rescue` clause whose
# matching opener (same indentation) is a do/brace block, not a begin/def/class/module.
def indent(s): return len(s) - len(s.lstrip(" "))
def is_opener_block(line):
    s = line.strip()
    if re.search(r"\bdo\s*(\|[^|]*\|)?\s*$", s): return True
    if re.search(r"\{\s*(\|[^|]*\|)?\s*$", s): return True
    return False
def is_opener_safe(line):
    s = line.strip()
    return bool(re.match(r"(begin|def |class |module |ensure\b)", s)) or s == "begin"

# (2) runtime APIs that exist in Ruby 1.9+ but NOT 1.8.7 -> a missing-method / ArgumentError at
# runtime in gen-6 (e.g. Float#round(2) crashed the diag). curated and conservative to avoid noise.
RUNTIME = [
    (re.compile(r"\.(round|ceil|floor)\(\s*[^)\s]"), "round/ceil/floor with argument (1.8.7 takes none)"),
    (re.compile(r"[A-Za-z0-9_)\]]&\."),              "safe navigation &. (Ruby 2.3+)"),
    (re.compile(r"&:\w"),                            "Symbol#to_proc &:sym (Ruby 1.9+; use a block in gen-6)"),
    (re.compile(r"->\s*[({]"),                       "stabby lambda -> (Ruby 1.9+)"),
    (re.compile(r"%i[\[(]"),                         "%i symbol-array literal (Ruby 2.0+)"),
    (re.compile(r"\.each_with_object\b"),            "each_with_object (Ruby 1.9+)"),
    (re.compile(r"\.dig\("),                         "Hash/Array#dig (Ruby 2.3+)"),
    (re.compile(r"<<~"),                             "squiggly heredoc <<~ (Ruby 2.3+)"),
    (re.compile(r"\.clamp\("),                       "Comparable#clamp (Ruby 2.4+)"),
    (re.compile(r"\.transform_(keys|values)\b"),     "Hash#transform_keys/values (Ruby 2.4/2.5+)"),
    (re.compile(r"\.(then|yield_self)\b"),           "Kernel#then/yield_self (Ruby 2.6+)"),
    (re.compile(r"\.tally\b"),                        "Enumerable#tally (Ruby 2.7+)"),
    (re.compile(r"\.filter_map\b"),                   "Enumerable#filter_map (Ruby 2.7+)"),
]

flagged = []
# Lint the files passed as arguments, or the whole dual/gen-6 tree when none are given.
paths = sys.argv[1:] or (glob.glob("core/**/*.rb", recursive=True) + glob.glob("games/**/*.rb", recursive=True) + glob.glob("loader/*.rb"))
for f in paths:
    if is_modern(f): continue
    try:
        lines = open(f, encoding="utf-8").read().split("\n")
    except (IOError, OSError):
        print("skip (cannot read): " + f)
        continue
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s.startswith("#"): continue
        # (1) block-rescue
        if s == "rescue" or s.startswith("rescue "):
            n = indent(ln)
            for j in range(i - 1, -1, -1):
                p = lines[j]
                if p.strip() == "" or p.strip().startswith("#"): continue
                if indent(p) <= n: opener = p; break
            else:
                opener = ""
            if is_opener_block(opener) and not is_opener_safe(opener):
                flagged.append("%s:%d  block-rescue (1.8.7 syntax error) -> %r" % (f, i + 1, opener.strip()))
        # (2) 1.9+ runtime APIs
        for rx, label in RUNTIME:
            if rx.search(ln):
                flagged.append("%s:%d  %s -> %r" % (f, i + 1, label, s[:72]))

if flagged:
    print("POTENTIAL 1.8.7 INCOMPATIBILITIES:")
    for x in flagged: print("  " + x)
    sys.exit(1)
else:
    print("OK: 1.8.7-safe (no block-rescue, no 1.9+ runtime APIs in dual/gen-6 code).")
