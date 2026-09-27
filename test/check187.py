import os, re, glob, subprocess, sys
# Ruby 1.8.7 checks for the code that loads in the 1.8.7 games: all of core/ (its manifest loads every file in
# both engines), loader/, plugins/ and every game profile except MODERN, whose games run Ruby 3.x (a common only
# those games import included).
MODERN = ("games/anil/", "games/fireash/", "games/royal/", "games/relict/", "games/soulstones2/",
          "games/infinitefusion_hoenn/", "games/infinitefusion/", "games/infinitefusion_common/",
          "games/emerald/", "games/skyflyer_common/")
def is_modern(path):
    p = path.replace("\\", "/")
    return any(m in p for m in MODERN)

# (1) A rescue whose owner is a do/brace block: valid in modern Ruby, a syntax error in 1.8.7.
def indent(s): return len(s) - len(s.lstrip(" "))
# The line without a trailing # comment (a #{ interpolation is kept).
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

# The line that owns the rescue at line i: the nearest opener above it at or below its indent; a plain
# statement at or below that indent lowers the bar and the walk goes on.
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

# (1b) A line that starts with a method-call dot: 1.9+, a syntax error in 1.8.7.
LEADING_DOT = re.compile(r"^\s*&?\.[A-Za-z_]")

# (1c) Shapes that do not parse in 1.8.7. Every entry of these lists carries a line it must flag and a
# 1.8.7-safe line it must not, checked by self_test before the scan.
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

# (2) Methods and constants that are missing or behave differently in 1.8.7.
RUNTIME = [
    (re.compile(r"\.(round|ceil|floor)\(\s*[^)\s]"), "round/ceil/floor with argument (1.8.7 takes none)",
     "n = x.round(2)", "n = x.round"),
    (re.compile(r"[A-Za-z0-9_)\]]&\."),              "safe navigation &. (Ruby 2.3+)",
     "n = a&.b", "n = a && a.b"),
    (re.compile(r"&:\w"),                            "Symbol#to_proc &:sym (1.8.7-p374 has it; kept out of shared code for consistency, use a block)",
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
    (re.compile(r"\[\s*0\s*\]\s*==\s*[\"']"),         "s[0] == \"x\" (1.8.7 devuelve un Fixnum, no un caracter)",
     'if line[0] == "#"', 'if line[0, 1] == "#"'),
    (re.compile(r"=>[^{}]*\}\s*\.each(?:_pair)?\s*(?:do|\{)\s*\|\w+,\s*\w+\|"),
     "Hash literal iterado en sitio: orden arbitrario en 1.8.7 (usa un Array de pares)",
     "{ :a => 1 }.each do |k, v|", "rows.each do |k, v|"),
    (re.compile(r"gsub\([^)]*\)\.to_sym\b"),
     "to_sym tras gsub: la cadena vacia lanza ArgumentError en 1.8.7 (guarda el vacio antes)",
     'raw.to_s.gsub(/\\s+/, "").to_sym', '"dir_#{key}".to_sym'),
    (re.compile(r"\.select\s*\{[^}]*\}\s*\.(?:keys|values|key\?|has_key\?|merge|each_key|each_value|each_pair)\b"),
     "Hash#select devuelve Array en 1.8.7: keys/values/merge sobre el resultado fallan",
     "h.select { |k, v| v }.keys", "h.select { |k, v| v }.map { |k, v| k }"),
    (re.compile(r"\.with_index\b"),
     "Enumerator#with_index tras map/each sin bloque (en 1.8.7 map sin bloque devuelve Array)",
     "a.map.with_index { |x, i| x }", "a.each_with_index { |x, i| x }"),
    (re.compile(r"\.(?:chars|lines|bytes)(?:\.(?:size|length|last|reverse|join|uniq)|\[)"),
     "String#chars/lines/bytes devuelven Enumerator en 1.8.7: sin size/last/[]/join (pasa por to_a)",
     "s.chars.size", "s.chars.to_a.size"),
    (re.compile(r"\.(?:sort_by!|select!)|\.cover\?"),
     "Array#sort_by!/select! y Range#cover? (Ruby 1.9+)",
     "a.sort_by! { |x| x }", "a = a.sort_by { |x| x }"),
    (re.compile(r"\.(?:min|max|min_by|max_by)\(\s*\d"),
     "min/max/min_by/max_by con cuenta (Ruby 2.2+; sort y first(n))",
     "a.min(2)", "a.sort.first(2)"),
    (re.compile(r"\bFile\.write\b|\bIO\.write\b|\bDir\.exists?\?"),
     "File.write/IO.write/Dir.exist? (1.9+): usa File.open(p, 'w') / File.directory?",
     "File.write(p, s)", 'File.open(p, "w")'),
    (re.compile(r"\\u[0-9A-Fa-f]{4}|\\u\{"),
     "escape \\u en cadena o regex: 1.8.7 lo deja como el texto 'u00e9'",
     '"\\u00e9"', '"\\xC3\\xA9"'),
    (re.compile(r"\(\?<[=!]|\(\?<\w+>|\\p\{"),
     "lookbehind, grupo con nombre o \\p{} en regex: 1.8.7 no los compila",
     "/(?<=a)b/", "/(?:a)b/"),
    (re.compile(r"\bKeyError\b|\bEncoding\b|\bRandom\.|\bFiddle\b|\bEnumerator\b"),
     "constante 1.9+ (NameError en 1.8.7; Hash#fetch lanza IndexError alli)",
     "rescue KeyError", "rescue IndexError"),
    (re.compile(r"^(?!.*\b(?:is_a|kind_of|instance_of)\?).*respond_to\?\(?\s*:id\b"),
     "respond_to?(:id) es true para TODO objeto en 1.8.7 (Object#id, alias de object_id): decide por clase",
     "tag = (tag.respond_to? :id) ? tag.id : tag", "if !t.is_a?(Integer) && t.respond_to?(:id)"),
]

# Cases for the two checks that are not a regex, in the same shape.
SHAPE_CASES = [
    ("leading-dot chain", lambda s: bool(LEADING_DOT.match(s)), "  .strip", "  x.strip"),
    ("block opener", lambda s: is_opener_block(s), "items.each do |i|", "n = 1"),
    ("block opener with a trailing comment", lambda s: is_opener_block(s),
     "items.each do |i|  # nota", "n = 1  # nota"),
    ("brace-block opener", lambda s: is_opener_block(s), "items.each { |i|", "h = { :a => 1 }"),
    ("safe opener", lambda s: is_opener_safe(s), "begin", "items.each do |i|"),
    ("def is a safe opener", lambda s: is_opener_safe(s), "def foo", "foo.each do"),
]

# Cases for the opener walk of rule (1): (label, snippet, whether a rescue in it is flagged).
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

# Stops the run when a pattern misses its own case or flags its 1.8.7-safe twin.
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
# The files given as arguments, else every file under core/, games/, plugins/ and loader/ of the repo.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def tree(pat):
    return glob.glob(os.path.join(REPO, pat), recursive=True)
paths = sys.argv[1:] or (tree("core/**/*.rb") + tree("games/**/*.rb") + tree("plugins/**/*.rb") + tree("loader/**/*.rb"))

# With no arguments, fails when a core/manifest.rb entry is not among the scanned files or a root matches
# no file.
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
        opener = block_rescue_at(lines, i)
        if opener is not None:
            flagged.append("%s:%d  block-rescue (1.8.7 syntax error) -> %r" % (f, i + 1, opener.strip()))
        if LEADING_DOT.match(ln):
            flagged.append("%s:%d  leading-dot chain (1.8.7 syntax error) -> %r" % (f, i + 1, s[:72]))
        for rx, label, _m, _n in SYNTAX19:
            if rx.search(ln):
                flagged.append("%s:%d  %s -> %r" % (f, i + 1, label, s[:72]))
        code = strip_comment(ln)
        for rx, label, _m, _n in RUNTIME:
            if rx.search(code):
                flagged.append("%s:%d  %s -> %r" % (f, i + 1, label, s[:72]))

if flagged:
    print("POTENTIAL 1.8.7 INCOMPATIBILITIES:")
    for x in flagged: print("  " + x)
    sys.exit(1)

# With a real 1.8.7 interpreter (RUBY187, or tools/ruby-1.8.7-*/bin/ruby.exe two levels up), every file is
# also parsed by it through check187_real.rb; without one the result is PARCIAL, with exit code 0.
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
    print("PARCIAL: sin errores de patron, pero NO verificado con un interprete 1.8.7 real "
          "(instala tools/ruby-1.8.7-*/bin/ruby.exe o exporta RUBY187).")
    sys.exit(0)
print("OK: 1.8.7-safe (patterns + real interpreter parse).")
