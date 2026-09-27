# Pokemon Z's MTS redefines Array#+ and Array#- as in-place mutators returning self, so `CONST + extra` or
# `@cache - other` corrupts the array for the session: every file that loads under Z is scanned for those shapes.
require File.expand_path("imports", File.dirname(__FILE__))

module MtsGuard
  ROOT = File.expand_path("../..", __dir__)

  # Path fragments that load only under the modern engine (Ruby 3.x, no MTS), out of scope; the suite below keeps
  # this list equal to check187.py's, check187_real.rb's and the catalog's.
  MODERN = ["games/anil/", "games/fireash/", "games/royal/", "games/relict/", "games/soulstones2/",
            "games/infinitefusion_hoenn/", "games/infinitefusion/", "games/infinitefusion_common/",
            "games/emerald/", "games/skyflyer_common/"]

  # The MODERN tuple check187.py declares, as path fragments, or nil when the declaration is not found.
  def self.modern_of_check187(root)
    src = File.read(File.join(root, "test", "check187.py"))
    m = src[/^MODERN\s*=\s*\((.*?)\)/m, 1]
    return nil unless m
    m.scan(/"([^"]+)"/).flatten
  end

  # The MODERN list check187_real.rb declares (the one that decides what the real 1.8.7 sweep parses), or nil.
  def self.modern_of_check187_real(root)
    src = File.read(File.join(root, "test", "check187_real.rb"))
    m = src[/^MODERN\s*=\s*\[(.*?)\]/m, 1]
    return nil unless m
    m.scan(/"([^"]+)"/).flatten
  end

  # The sorted "games/<key>/" fragments of the catalog's engine "gamedata" profiles and of the commons only they
  # import, or nil when it cannot be read.
  def self.modern_of_catalog(root)
    require "json"
    data = JSON.parse(File.read(File.join(root, "games", "catalog.json")))
    profs = data["profiles"]
    return nil unless profs.is_a?(Array)
    keys = profs.select { |p| p["engine"] == "gamedata" }.map { |p| p["key"] }
    commons = Imports.importers.select { |_c, games| (games - keys).empty? }.map { |c, _g| c }
    (keys + commons).map { |k| "games/#{k}/" }.sort
  rescue StandardError
    nil
  end

  # An uppercase constant of 3+ chars: the array constants that get corrupted (BUTTONS, TEXT_CODES, NUMERIC).
  CONST = '[A-Z][A-Z0-9_]{2,}'

  # Risk shape 1, `CONST + <rhs>` with an array literal, a constant or an identifier on the right; not after a `*`
  # or a digit (index arithmetic like `row * STRIDE + col`).
  PLUS_RE = Regexp.new('(?<![*\d])\b(' + CONST + ')\s*\+\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Risk shape 1b, `CONST[i] + [...]`: the stored element grows in place. Only an array-literal rhs, since with a
  # name on the right the element may be a number (`ROW[i] + col`).
  INDEXED_PLUS_RE = Regexp.new('\b(' + CONST + ')(\[[^\]]*\])+\s*\+\s*\[')

  # Risk shape 2, `<holder> - <rhs>`: an @ivar, a constant or a .keys/.values/.dup/.uniq/.to_a receiver minus a
  # non-numeric rhs, a set difference (`@index - 1` does not trip it).
  MINUS_RE = Regexp.new('(@[a-z_]\w*|\b' + CONST + '\b|\.(?:keys|values|dup|uniq|to_a)\b)\s*-\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Bare methods that return a memoized array, watched by name since a lowercase identifier minus something is
  # scalar math to a regex; never add a scalar getter.
  CACHE_ACCESSORS = %w[available_languages]

  # Risk shape 2b, a CACHE_ACCESSORS name minus MINUS_RE's rhs, as a bare call (not after `.` or `def `).
  WATCH_MINUS_RE = Regexp.new('(?<!\.)(?<!def )\b(?:' + CACHE_ACCESSORS.join('|') + ')\b\s*-\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # A numeric coercion right after a match (`(a - b).abs`, `.to_i`...) marks it as arithmetic, and drops it.
  NUMERIC_WRAP = /\A\s*\)?\.(abs|max|min|to_i|to_f|floor|ceil|round)\b/

  # "relative/path.rb" => [matched snippet, ...]: confirmed scalar arithmetic (a constant holding a stride), keyed
  # by snippet so an entry survives renumbering; never a real array `+`/`-`.
  ALLOW = {
    "core/field/minigames.rb" => ["VF_W + col", "VF_W + c"],
    "core/nav/pathfinder.rb"  => ["PKEY_STRIDE + y"]
  }

  # True if this path loads only under the modern engine and is therefore out of scope.
  def self.modern?(path)
    p = path.tr("\\", "/")
    MODERN.any? { |m| p.include?(m) }
  end

  # The files this guard scans: core/, games/, plugins/ and loader/, minus the modern-only subtrees.
  def self.scanned_files
    globs = Dir.glob(File.join(ROOT, "core", "**", "*.rb")) +
            Dir.glob(File.join(ROOT, "games", "**", "*.rb")) +
            Dir.glob(File.join(ROOT, "plugins", "**", "*.rb")) +
            Dir.glob(File.join(ROOT, "loader", "*.rb"))
    globs.reject { |f| modern?(f) }.sort
  end

  # The path relative to the repo root, forward-slashed, for allowlist lookup and readable output.
  def self.rel(path)
    path[(ROOT.length + 1)..-1].tr("\\", "/")
  end

  # The code portion of a line: everything before the first `#` outside a quoted string (escapes skipped).
  def self.code_of(line)
    out = ""
    instr = nil
    i = 0
    while i < line.length
      ch = line[i, 1]
      if instr
        out << ch
        if ch == "\\" && i + 1 < line.length
          out << line[i + 1, 1]
          i += 2
          next
        end
        instr = nil if ch == instr
      elsif ch == '"' || ch == "'"
        instr = ch
        out << ch
      elsif ch == "#"
        break
      else
        out << ch
      end
      i += 1
    end
    out
  end

  # Every risk match in the tree, as "relative/path.rb:line -> snippet" strings, excluding numeric-wrapped
  # matches and anything on the allowlist.
  def self.violations
    out = []
    scanned_files.each do |path|
      r = rel(path)
      allowed = ALLOW[r] || []
      text = (File.read(path) rescue "")
      text.split("\n").each_with_index do |line, idx|
        next if line.strip[0, 1] == "#"
        code = code_of(line)
        [PLUS_RE, INDEXED_PLUS_RE, MINUS_RE, WATCH_MINUS_RE].each do |re|
          pos = 0
          while (m = re.match(code, pos))
            snippet = m[0]
            tail = code[m.end(0)..-1] || ""
            pos = m.end(0)
            next if tail =~ NUMERIC_WRAP
            next if allowed.include?(snippet)
            out << "#{r}:#{idx + 1} -> #{snippet.strip}"
          end
        end
      end
    end
    out
  end
end

# The MODERN lists of check187.py, check187_real.rb and this guard name the same paths, derived from the catalog.
Suite.define("static/estilo: las tres listas MODERN coinciden") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  theirs = MtsGuard.modern_of_check187(root)
  real = MtsGuard.modern_of_check187_real(root)
  truthy "check187.py declara MODERN", !theirs.nil?
  truthy "check187_real.rb declara MODERN", !real.nil?
  eq "misma lista que el guard", (theirs || []).sort, MtsGuard::MODERN.sort
  eq "y la del parseo real tambien", (real || []).sort, MtsGuard::MODERN.sort
  catalog = MtsGuard.modern_of_catalog(root)
  truthy "games/catalog.json declara engines", !catalog.nil?
  eq "y las tres derivan del catalogo (engine=gamedata)", MtsGuard::MODERN.sort, (catalog || [])
end

Suite.define("static: no Array#+/#- mutator landmine in gen-6/Z-loaded files") do
  eq "no MTS array-mutator risks outside the allowlist", MtsGuard.violations, []
end

# True if the risk regexes flag this line, numeric-wrapped matches dropped and the path allowlist ignored.
def mts_flags?(line)
  code = MtsGuard.code_of(line)
  [MtsGuard::PLUS_RE, MtsGuard::INDEXED_PLUS_RE, MtsGuard::MINUS_RE, MtsGuard::WATCH_MINUS_RE].any? do |re|
    hit = false
    pos = 0
    while (m = re.match(code, pos))
      tail = code[m.end(0)..-1] || ""
      pos = m.end(0)
      hit = true unless tail =~ MtsGuard::NUMERIC_WRAP
    end
    hit
  end
end

# The detector flags the shapes that shipped as bugs, on synthetic lines.
Suite.define("static: MTS mutator detector catches the known bug shapes") do
  bug_shapes = [
    "EXAMINE_CODES = TEXT_CODES + SCRIPT_CODES + GOODS_CODES",
    "list = BUTTONS + extras.map { |s, i| [s, nil, i[1]] }",
    "kinds = NUMERIC + [:flag] + SYMS",
    "out = @langs - present",
    "remaining = CODES - [101]",
    "DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d] + [d] }",
    "rows = GRID[y][x] + [z]"
  ]
  bug_shapes.each { |line| truthy "detector flags: #{line}", mts_flags?(line) }
end

# The detector spares arithmetic that only looks like an array op; stride lines are the allowlist's, below.
Suite.define("static: MTS mutator detector spares scalar arithmetic") do
  scalars = [
    "@index = (@index - 1) % n",
    "@sel -= 3 if grid? && @sel - 3 >= 1",
    "return false unless (iter & (BUDGET_CHECK - 1)) == 0",
    "d = (ev.x - px).abs + (ev.y - py).abs",
    "return if @last && (now - @last) < 0.5",
    "x = STEPS[i] + 1",
    "x = ROW[i] + col",
    "DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d].dup.push(d) }"
  ]
  scalars.each { |line| falsy "detector spares scalar arithmetic: #{line}", mts_flags?(line) }
end

# Each allowlist entry: a real detector match on stride arithmetic, still in its swept file.
Suite.define("static: MTS mutator allowlist is live and scalar-only") do
  scanned = MtsGuard.scanned_files.map { |f| MtsGuard.rel(f) }
  MtsGuard::ALLOW.each do |path, snippets|
    truthy "allowlisted file is still inside the sweep: #{path}", scanned.include?(path)
    text = (File.read(File.join(MtsGuard::ROOT, path)) rescue "")
    snippets.each do |snip|
      truthy "allowed snippet is a real detector match: #{path} #{snip}", mts_flags?(snip)
      truthy "allowed snippet is stride arithmetic: #{path} #{snip}", (snip =~ /\A[A-Z][A-Z0-9_]{2,}\s*\+/ ? true : false)
      truthy "allowed snippet still occurs in its file: #{path} #{snip}", text.include?(snip)
    end
  end
end
