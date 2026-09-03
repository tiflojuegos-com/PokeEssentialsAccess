import os, re, glob, subprocess, sys
# 1.8.7 compatibility checks. core/ loads in BOTH engines (gen-6 Ruby 1.8.7 and modern 3.1) and the
# gen-6 game profiles run on 1.8.7, so their code must be 1.8.7-safe. Only the profiles of games that RUN
# on Ruby 3.x are exempt -- MODERN below: anil, royal, relict, emerald, infinitefusion and
# infinitefusion_hoenn (GameData-era engines on an mkxp-z built against Ruby 3.1). GEN-6 (linted):
# pokemon_z, opalo, armonia (Essentials 16.3), realidea, africanus, reminiscencia (PScreen_*/PB*
# pre-GameData), and generic/unknown (conservative).
# The version folders of core/ are deliberately NOT exempt: core/manifest.rb is a flat list with no engine
# condition, so every one of them is loaded in the 1.8.7 games too, and a file that does not parse there
# lands in loader_error.txt on every boot. Exempting them assumed a gate that does not exist.
MODERN = ("games/anil/", "games/royal/", "games/relict/",
          "games/infinitefusion_hoenn/", "games/infinitefusion/",
          "games/emerald/")
def is_modern(path):
    p = path.replace("\\", "/")
    return any(m in p for m in MODERN)

# (1) block-level rescue: valid in modern Ruby, SYNTAX ERROR in 1.8.7. a `rescue` clause whose
# matching opener (same indentation) is a do/brace block, not a begin/def/class/module.
def indent(s): return len(s) - len(s.lstrip(" "))
# The trailing comment goes first: the opener is recognised by what it ENDS with, so `items.each do |i| # x`
# read as "not a block" and the rescue under it went unflagged.
def strip_comment(s):
    return re.sub(r"\s+#(?!\{).*$", "", s)
def is_opener_block(line):
    s = strip_comment(line.strip())
    if re.search(r"\bdo\s*(\|[^|]*\|)?\s*$", s): return True
    if re.search(r"\{\s*(\|[^|]*\|)?\s*$", s): return True
    return False
def is_opener_safe(line):
    s = line.strip()
    return bool(re.match(r"(begin|def |class |module |ensure\b)", s)) or s == "begin"

# The owner of a rescue at line i: walk upward for the nearest OPENER line. A plain statement found at
# <= the current indent is not the owner -- it lowers the bar and the walk continues, which is what
# catches the orphan shape (a rescue indented like the block BODY, whose owner is the block itself) that
# the old "first line at <= indent wins" rule read as harmless.
def find_opener(lines, i):
    n = indent(lines[i])
    for j in range(i - 1, -1, -1):
        p = lines[j]
        if p.strip() == "" or p.strip().startswith("#"): continue
        if indent(p) <= n:
            if is_opener_block(p) or is_opener_safe(p):
                return p
            n = indent(p)
    return ""

# (1b) leading-dot method chaining: valid in 1.9+, SYNTAX ERROR in 1.8.7 (the dot must trail the
# previous line). Caught in the wild: a chained SCAN_CODES literal killed config_menu.rb, and with the
# module missing map_poll raised every frame -- muting footsteps, guide and locator keys in gen-6.
LEADING_DOT = re.compile(r"^\s*&?\.[A-Za-z_]")

# (1c) shapes that do not PARSE in 1.8.7. Unlike the runtime list below, one of these anywhere in core/
# means the whole mod fails to load in the seven gen-6 games -- total silence, not a degraded screen. They
# were missing because the system Ruby that runs the suite accepts all three happily.
#
# Every entry carries the line it MUST flag and a 1.8.7-safe line it must NOT, checked by self_test below
# before anything is scanned. A blacklist whose entries are never exercised is a list of hopes: nulling all
# of these with (?!) once gave numbers identical to a clean pass, so a typo in any one would have disarmed
# it for good without a single test going red.
SYNTAX19 = [
    (re.compile(r"[{,(]\s*[a-z_]\w*:\s"),          "1.9 hash literal key: value (use :key => value)",
     "h = { foo: 1 }", "h = { :foo => 1 }"),
    (re.compile(r"^\s*[a-z_]\w*:\s"),              "1.9 hash key on its own line (use :key => value)",
     "  foo: 1,", "  :foo => 1,"),
    (re.compile(r"^\s*def\s+[^(\n]*\([^)]*\b[a-z_]\w*:\s*[^:\s]"), "keyword argument in def (Ruby 2.0+)",
     "def f(a, b: 1)", "def f(a, b = 1)"),
    (re.compile(r"^\s*def\s+[^(\n]*\(\s*\*\*"),  "double-splat **opts in def (Ruby 2.0+)",
     "def f(**opts)", "def f(*args)"),
]

# (2) runtime APIs that exist in Ruby 1.9+ but NOT 1.8.7 -> a missing-method / ArgumentError at
# runtime in gen-6 (e.g. Float#round(2) crashed the diag). curated and conservative to avoid noise.
RUNTIME = [
    (re.compile(r"\.(round|ceil|floor)\(\s*[^)\s]"), "round/ceil/floor with argument (1.8.7 takes none)",
     "n = x.round(2)", "n = x.round"),
    (re.compile(r"[A-Za-z0-9_)\]]&\."),              "safe navigation &. (Ruby 2.3+)",
     "n = a&.b", "n = a && a.b"),
    (re.compile(r"&:\w"),                            "Symbol#to_proc &:sym (Ruby 1.9+; use a block in gen-6)",
     "a.map(&:to_s)", "a.map { |x| x.to_s }"),
    (re.compile(r"->\s*[({]"),                       "stabby lambda -> (Ruby 1.9+)",
     "f = ->(x) { x }", "f = lambda { |x| x }"),
    (re.compile(r"%i[\[(]"),                         "%i symbol-array literal (Ruby 2.0+)",
     "a = %i[one two]", "a = [:one, :two]"),
    (re.compile(r"\.each_with_object\b"),            "each_with_object (Ruby 1.9+)",
     "a.each_with_object({}) { |x, h| }", "h = {}; a.each { |x| }"),
    (re.compile(r"\.dig\("),                         "Hash/Array#dig (Ruby 2.3+)",
     "h.dig(:a, :b)", "h[:a] && h[:a][:b]"),
    (re.compile(r"<<~"),                             "squiggly heredoc <<~ (Ruby 2.3+)",
     "s = <<~TXT", "s = <<-TXT"),
    (re.compile(r"\.clamp\("),                       "Comparable#clamp (Ruby 2.4+)",
     "n = v.clamp(0, 9)", "n = [[v, 0].max, 9].min"),
    (re.compile(r"\.transform_(keys|values)\b"),     "Hash#transform_keys/values (Ruby 2.4/2.5+)",
     "h.transform_values { |v| v }", "h.each { |k, v| }"),
    (re.compile(r"\.(then|yield_self)\b"),           "Kernel#then/yield_self (Ruby 2.6+)",
     "x.then { |v| v }", "x.tap { |v| v }"),
    (re.compile(r"\.tally\b"),                        "Enumerable#tally (Ruby 2.7+)",
     "a.tally", "a.uniq"),
    (re.compile(r"\.filter_map\b"),                   "Enumerable#filter_map (Ruby 2.7+)",
     "a.filter_map { |x| x }", "a.map { |x| x }.compact"),
    # Cada una de estas se probo antes contra el interprete 1.8.7 real (NoMethodError alli) y se midio
    # contra el arbol actual: 0 coincidencias, asi que ninguna nace gritando. Tres candidatas se quedaron
    # FUERA por ruidosas, y conviene saber cuales: .sample choca con Recorder.sample, .key( con metodos
    # propios llamados key, y .select no distingue un Hash de un Array por el receptor -- ese ultimo
    # importa, porque Hash#select devuelve Array en 1.8.7 y Hash desde 1.9 (los 18 sitios del arbol son
    # Array o Range, comprobados uno a uno).
    (re.compile(r"\.flat_map\b"),                     "Enumerable#flat_map (Ruby 1.9+)",
     "a.flat_map { |x| x }", "a.map { |x| x }.flatten(1)"),
    (re.compile(r"\.rotate\b"),                       "Array#rotate (Ruby 1.9+)",
     "a.rotate", "a[1..-1] + a[0, 1]"),
    (re.compile(r"\.keep_if\b"),                      "Array/Hash#keep_if (Ruby 1.9+)",
     "a.keep_if { |x| x }", "a = a.select { |x| x }"),
    (re.compile(r"\.define_singleton_method\b"),      "define_singleton_method (Ruby 1.9+)",
     "o.define_singleton_method(:z) { 1 }", "class << o; def z; 1; end; end"),
    (re.compile(r"\.public_send\b"),                  "Object#public_send (Ruby 1.9+)",
     "o.public_send(:z)", "o.send(:z)"),
    (re.compile(r"\.force_encoding\b"),               "String#force_encoding (Ruby 1.9+)",
     "s.force_encoding('UTF-8')", "s"),
    (re.compile(r"\.each_entry\b"),                   "Enumerable#each_entry (Ruby 1.9+)",
     "a.each_entry { |x| x }", "a.each { |x| x }"),
    (re.compile(r"\.default_proc\s*="),               "Hash#default_proc= (Ruby 1.9+)",
     "h.default_proc = lambda { |hh, k| 1 }", "h = Hash.new { |hh, k| 1 }"),
    (re.compile(r"\.prepend\b"),                      "String/Module#prepend (Ruby 1.9/2.0+)",
     "s.prepend('a')", "s = 'a' + s"),
    (re.compile(r"\.lazy\b"),                         "Enumerable#lazy (Ruby 2.0+)",
     "a.lazy.map { |x| x }", "a.map { |x| x }"),
    (re.compile(r"\.to_h\b"),                         "Array#to_h (Ruby 2.1+)",
     "pairs.to_h", "h = {}; pairs.each { |k, v| h[k] = v }"),
    (re.compile(r"\.bsearch\b"),                      "Array#bsearch (Ruby 2.0+)",
     "a.bsearch { |x| x >= 2 }", "a.find { |x| x >= 2 }"),
    (re.compile(r"\.unpack1\b"),                      "String#unpack1 (Ruby 2.4+)",
     "s.unpack1('C')", "s.unpack('C')[0]"),
    (re.compile(r"\.sum\b"),                          "Enumerable#sum (Ruby 2.4+)",
     "a.sum", "a.inject(0) { |t, x| t + x }"),
    (re.compile(r"\.digits\b"),                       "Integer#digits (Ruby 2.4+)",
     "n.digits", "n.to_s.reverse.split('').map { |c| c.to_i }"),
    (re.compile(r"\.chunk_while\b"),                  "Enumerable#chunk_while (Ruby 2.3+)",
     "a.chunk_while { |x, y| true }", "a.inject([]) { |acc, x| acc }"),
    (re.compile(r"keyword_init"),                     "Struct keyword_init (Ruby 2.5+)",
     "Struct.new(:a, :keyword_init => true)", "Struct.new(:a)"),
    # Devuelve el BYTE en 1.8.7 y el caracter desde 1.9: no lanza, contesta false para siempre.
    (re.compile(r"\[\s*0\s*\]\s*==\s*[\"']"),         "s[0] == \"x\" (1.8.7 devuelve un Fixnum, no un caracter)",
     'if line[0] == "#"', 'if line[0, 1] == "#"'),
]

# The two rules that are not a regex get their cases here, in the same shape.
SHAPE_CASES = [
    ("leading-dot chain", lambda s: bool(LEADING_DOT.match(s)), "  .strip", "  x.strip"),
    ("block opener", lambda s: is_opener_block(s), "items.each do |i|", "n = 1"),
    ("block opener with a trailing comment", lambda s: is_opener_block(s),
     "items.each do |i|  # nota", "n = 1  # nota"),
    ("brace-block opener", lambda s: is_opener_block(s), "items.each { |i|", "h = { :a => 1 }"),
    ("safe opener", lambda s: is_opener_safe(s), "begin", "items.each do |i|"),
    ("def is a safe opener", lambda s: is_opener_safe(s), "def foo", "foo.each do"),
]

# The WALK itself, on whole snippets: which line owns a rescue. This is the only part of rule (1) the
# per-line cases above cannot reach, and the mutation sweep showed it was defended by the shape of the
# tree, not by a test (flipping `<=` to `<` only failed by turning eight legitimate nested begins into
# false positives). Each case is (label, snippet, does rule (1) flag it).
WALK_CASES = [
    ("rescue in a do-block is flagged",
     "items.each do |i|\n  risky\nrescue\nend", True),
    ("rescue owned by begin is not",
     "begin\n  risky\nrescue\nend", False),
    ("begin/rescue NESTED in a block is not (the <= mutation breaks this)",
     "items.each do |i|\n  begin\n    risky\n  rescue\n  end\nend", False),
    ("an orphan rescue at the block BODY's indent is flagged too",
     "items.each do |i|\n  risky\n  rescue\nend", True),
    ("a method body rescue is not",
     "def foo\n  x\nrescue\nend", False),
]

def block_rescue_at(lines, i):
    s = lines[i].strip()
    if not (s == "rescue" or s.startswith("rescue ")):
        return None
    opener = find_opener(lines, i)
    if is_opener_block(opener) and not is_opener_safe(opener):
        return opener
    return None

def walk_flags(snippet):
    lines = snippet.split("\n")
    return any(block_rescue_at(lines, i) is not None for i in range(len(lines)))

# Runs every pattern against the line it exists to catch and against a 1.8.7-safe twin. A pattern that stops
# matching its own case, or starts matching the safe one, fails HERE -- loudly and before the scan, instead
# of quietly passing every file for the rest of the project's life.
def self_test():
    bad = []
    for rx, label, must, must_not in SYNTAX19 + RUNTIME:
        if not rx.search(must):
            bad.append("%s: no longer catches %r" % (label, must))
        if rx.search(must_not):
            bad.append("%s: now flags the 1.8.7-safe %r" % (label, must_not))
    for label, fn, must, must_not in SHAPE_CASES:
        if not fn(must):
            bad.append("%s: no longer recognises %r" % (label, must))
        if fn(must_not):
            bad.append("%s: now recognises %r" % (label, must_not))
    for label, snippet, expected in WALK_CASES:
        if walk_flags(snippet) != expected:
            bad.append("opener walk: %s" % label)
    if bad:
        print("CHECK187 ROTO: los patrones no hacen lo que dicen hacer.")
        for b in bad: print("  " + b)
        sys.exit(2)
self_test()

flagged = []
# Lint the files passed as arguments, or the whole dual/gen-6 tree when none are given.
# Anchored to the repo, not to the caller's directory. Relative globs scanned NOTHING when the suite was
# started from anywhere but the repo root, and said OK about it: the real-interpreter pass below is absolute
# and still ran, so the only thing silently lost was the pattern list -- the half that catches code which
# parses fine under 1.8.7 and behaves differently.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def tree(pat):
    return glob.glob(os.path.join(REPO, pat), recursive=True)
paths = sys.argv[1:] or (tree("core/**/*.rb") + tree("games/**/*.rb") + tree("plugins/**/*.rb") + tree("loader/**/*.rb"))

# Floor for the sweep itself: every core/manifest.rb entry must be among the scanned files, and none of
# the roots may match zero files. A glob that goes quiet must fail here, not report a smaller OK.
if not sys.argv[1:]:
    _man = os.path.join(REPO, "core", "manifest.rb")
    try:
        with open(_man, encoding="utf-8") as _fh:
            _entries = re.findall(r'^\s+([a-z0-9_/]+)\s*$', _fh.read(), re.M)
    except OSError:
        _entries = []
    _required = set(os.path.normpath(os.path.join(REPO, "core", _e + ".rb")) for _e in _entries)
    _have = set(os.path.normpath(_p) for _p in paths)
    _missing = sorted(_required - _have)
    _thin = [_name for _name, _pat in (("plugins", "plugins/**/*.rb"), ("games", "games/**/*.rb"),
                                       ("loader", "loader/*.rb")) if not tree(_pat)]
    if not _entries or _missing or _thin:
        print("1.8.7 SWEEP INCOMPLETE:")
        if not _entries:
            print("  core/manifest.rb missing or unreadable")
        for _m in _missing[:10]:
            print("  manifest entry never scanned: " + os.path.relpath(_m, REPO))
        for _t in _thin:
            print("  zero files matched under " + _t + "/")
        sys.exit(1)

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
        opener = block_rescue_at(lines, i)
        if opener is not None:
            flagged.append("%s:%d  block-rescue (1.8.7 syntax error) -> %r" % (f, i + 1, opener.strip()))
        # (1b) leading-dot chain
        if LEADING_DOT.match(ln):
            flagged.append("%s:%d  leading-dot chain (1.8.7 syntax error) -> %r" % (f, i + 1, s[:72]))
        # (1c) shapes that do not parse in 1.8.7 at all
        for rx, label, _m, _n in SYNTAX19:
            if rx.search(ln):
                flagged.append("%s:%d  %s -> %r" % (f, i + 1, label, s[:72]))
        # (2) 1.9+ runtime APIs
        for rx, label, _m, _n in RUNTIME:
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
    # Not "OK". The patterns are a curated blacklist and a blacklist is never complete: a probe of twenty
    # 1.8.7-hostile constructs put eight of them past this file, three of those hard SyntaxErrors. Saying OK
    # here claimed a guarantee only a real parse can give, and the runner printed "ruby187: OK" on the back
    # of it. The exit code stays 0 so the absence of an optional tool does not block the suite -- but the
    # word is PARCIAL, and run_all prints it verbatim.
    #
    # Locally this branch is NOT the one that runs: the interpreter lives in the SIBLING of the mod root,
    # tiflojuegos/tools/ruby-1.8.7-p374-i386-mingw32 (the glob climbs two levels, not one), and 194 files
    # parse under it. Copy the mod root alone to a scratch folder and you land here instead -- worth knowing
    # before concluding from a copy that the real parse never happens.
    print("PARCIAL: sin errores de patron, pero NO verificado con un interprete 1.8.7 real "
          "(instala tools/ruby-1.8.7-*/bin/ruby.exe o exporta RUBY187).")
    sys.exit(0)
print("OK: 1.8.7-safe (patterns + real interpreter parse).")
