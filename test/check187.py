import os, re, glob, subprocess, sys
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

# (1b) leading-dot method chaining: valid in 1.9+, SYNTAX ERROR in 1.8.7 (the dot must trail the
# previous line). Caught in the wild: a chained SCAN_CODES literal killed config_menu.rb, and with the
# module missing map_poll raised every frame -- muting footsteps, guide and locator keys in gen-6.
LEADING_DOT = re.compile(r"^\s*&?\.[A-Za-z_]")

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
# Anchored to the repo, not to the caller's directory. Relative globs scanned NOTHING when the suite was
# started from anywhere but the repo root, and said OK about it: the real-interpreter pass below is absolute
# and still ran, so the only thing silently lost was the pattern list -- the half that catches code which
# parses fine under 1.8.7 and behaves differently.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def tree(pat):
    return glob.glob(os.path.join(REPO, pat), recursive=True)
paths = sys.argv[1:] or (tree("core/**/*.rb") + tree("games/**/*.rb") + tree("plugins/**/*.rb") + tree("loader/*.rb"))
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
        # (1b) leading-dot chain
        if LEADING_DOT.match(ln):
            flagged.append("%s:%d  leading-dot chain (1.8.7 syntax error) -> %r" % (f, i + 1, s[:72]))
        # (2) 1.9+ runtime APIs
        for rx, label in RUNTIME:
            if rx.search(ln):
                flagged.append("%s:%d  %s -> %r" % (f, i + 1, label, s[:72]))

if flagged:
    print("POTENTIAL 1.8.7 INCOMPATIBILITIES:")
    for x in flagged: print("  " + x)
    sys.exit(1)

# When a REAL 1.8.7 interpreter is around (RUBY187 env var, or the tools/ checkout next to the repo),
# parse every dual/gen-6 file with it via check187_real.rb -- the parser knows ALL the syntax, the
# pattern list above only what it was taught. Absent interpreter (e.g. GitHub CI) just notes it.
here = os.path.dirname(os.path.abspath(__file__))
ruby187 = os.environ.get("RUBY187") or next(
    iter(glob.glob(os.path.join(here, "..", "..", "tools", "ruby-1.8.7-*", "bin", "ruby.exe"))), None)
if ruby187 and os.path.isfile(ruby187):
    real = subprocess.run([ruby187, os.path.join(here, "check187_real.rb"), os.path.join(here, "..")],
                          capture_output=True, text=True)
    print(real.stdout.strip())
    if real.returncode != 0:
        sys.exit(1)
else:
    print("OK: 1.8.7-safe by patterns (real 1.8.7 interpreter not found; set RUBY187 to add it).")
    sys.exit(0)
print("OK: 1.8.7-safe (patterns + real interpreter parse).")
