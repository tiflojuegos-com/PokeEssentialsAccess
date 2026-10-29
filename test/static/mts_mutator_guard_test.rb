# Pokemon Z's MTS redefines Array#+ and Array#- as in-place mutators returning self, so `CONST + extra` or
# `@cache - other` corrupts the array for the session: every file that loads under Z is scanned for those shapes.
require "json"
require File.expand_path("imports", File.dirname(__FILE__))

class MtsMutatorGuardTest < PokeAccessTest
  ROOT = File.expand_path("../..", __dir__)

  # Path fragments that load only under the modern engine (Ruby 3.x, no MTS), out of scope; kept equal to
  # check187.py's, check187_real.rb's and the catalog's.
  MODERN = ["games/anil/", "games/fireash/", "games/royal/", "games/relict/", "games/soulstones2/",
            "games/infinitefusion_hoenn/", "games/infinitefusion/", "games/infinitefusion_common/",
            "games/emerald/", "games/skyflyer_common/", "games/gruelinggold/", "games/goldencrown/",
            "games/revival/", "games/darkhorizon/", "games/royal_common/", "games/worldfrontier/"]

  # An uppercase constant of 3+ chars: the array constants that get corrupted (BUTTONS, TEXT_CODES, NUMERIC).
  CONST = '[A-Z][A-Z0-9_]{2,}'

  # Risk shape 1, `CONST + <rhs>` with an array literal, a constant or an identifier on the right; not right after a
  # `*` (`row*STRIDE + col`). Spaced stride arithmetic does match, and is the allowlist's.
  PLUS_RE = Regexp.new('(?<![*\d])\b(' + CONST + ')\s*\+\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Risk shape 1b, `CONST[i] + [...]`: the stored element grows in place. Only an array-literal rhs, since with a
  # name on the right the element may be a number (`ROW[i] + col`).
  INDEXED_PLUS_RE = Regexp.new('\b(' + CONST + ')(\[[^\]]*\])+\s*\+\s*\[')

  # Risk shape 1c, `@ivar + @ivar` or `@ivar + [...]`: the receiver is kept, so it grows in place; a number plus an
  # array literal cannot be, and no two numeric ivars are added in this code.
  IVAR_PLUS_RE = Regexp.new('@[a-z_]\\w*\\s*\\+\\s*(@[a-z_]\\w*|\\[)')

  # Risk shape 2, `<holder> - <rhs>`: an @ivar, a constant or a .keys/.values/.dup/.uniq/.to_a receiver minus a
  # non-numeric rhs, a set difference (`@index - 1` does not trip it).
  MINUS_RE = Regexp.new('(@[a-z_]\w*|\b' + CONST + '\b|\.(?:keys|values|dup|uniq|to_a)\b)\s*-\s*(\[|' + CONST +
                        '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Bare methods that return a memoized array, watched by name since a lowercase identifier minus something is
  # scalar math to a regex; never add a scalar getter.
  CACHE_ACCESSORS = %w[available_languages]

  # Risk shape 2b, a CACHE_ACCESSORS name minus MINUS_RE's rhs, as a bare call (not after `.` or `def `).
  WATCH_MINUS_RE = Regexp.new('(?<!\.)(?<!def )\b(?:' + CACHE_ACCESSORS.join('|') + ')\b\s*-\s*(\[|' + CONST +
                              '\b|@[a-z_]\w*|[a-z_]\w*)')

  RISKS = [PLUS_RE, INDEXED_PLUS_RE, IVAR_PLUS_RE, MINUS_RE, WATCH_MINUS_RE]

  # A numeric coercion right after a match (`(a - b).abs`, `.to_i`...) marks it as arithmetic, and drops it.
  NUMERIC_WRAP = /\A\s*\)?\.(abs|max|min|to_i|to_f|floor|ceil|round)\b/

  # "relative/path.rb" => [matched snippet, ...]: confirmed scalar arithmetic (a constant holding a stride), keyed
  # by snippet so an entry survives renumbering; never a real array `+`/`-`.
  ALLOW = {
    "core/field/minigames.rb" => ["VF_W + col", "VF_W + c"],
    "core/routes/routes.rb"   => ["PKEY_STRIDE + y"],
    "core/world/events.rb"    => ["STRIDE + y"]
  }

  test "check187.py skips the same modern-only paths as this guard" do
    theirs = modern_declared("check187.py", /^MODERN\s*=\s*\((.*?)\)/m)
    refute_nil theirs, "check187.py declares MODERN"
    assert_equal MODERN.sort, theirs.sort
  end

  test "check187_real.rb skips the same modern-only paths as this guard" do
    theirs = modern_declared("check187_real.rb", /^MODERN\s*=\s*\[(.*?)\]/m)
    refute_nil theirs, "check187_real.rb declares MODERN"
    assert_equal MODERN.sort, theirs.sort
  end

  test "the modern-only paths are the catalog's gamedata profiles and the commons only they import" do
    assert_equal MODERN.sort, modern_of_catalog
  end

  test "no file that loads under Z adds or subtracts arrays the MTS way" do
    assert_equal [], violations(swept_sources), "no MTS array-mutator risk outside the allowlist"
  end

  test "flags the shapes that shipped as bugs" do
    {
      "EXAMINE_CODES = TEXT_CODES + SCRIPT_CODES + GOODS_CODES" => ["TEXT_CODES + SCRIPT_CODES"],
      "list = BUTTONS + extras.map { |s, i| [s, nil, i[1]] }" => ["BUTTONS + extras"],
      "kinds = NUMERIC + [:flag] + SYMS" => ["NUMERIC + ["],
      "out = @langs - present" => ["@langs - present"],
      "remaining = CODES - [101]" => ["CODES - ["],
      "left = list.keys - shown" => [".keys - shown"],
      "DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d] + [d] }" => ["DIR_DELTA[d] + ["],
      "rows = GRID[y][x] + [z]" => ["GRID[y][x] + ["],
      "loose = (@arrival_rules + @leave_rules).any?" => ["@arrival_rules + @leave_rules"],
      "@seen + [x]" => ["@seen + ["],
      "rest = available_languages - [cur]" => ["available_languages - ["]
    }.each { |line, want| assert_equal want, flagged(line), "for #{line}" }
  end

  test "spares arithmetic and calls that only look like an array operation" do
    [
      "@index = (@index - 1) % n",
      "@sel -= 3 if grid? && @sel - 3 >= 1",
      "return false unless (iter & (BUDGET_CHECK - 1)) == 0",
      "d = (ev.x - px).abs + (ev.y - py).abs",
      "return if @last && (now - @last) < 0.5",
      "x = STEPS[i] + 1",
      "x = ROW[i] + col",
      "i = row*STRIDE + col",
      "DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d].dup.push(d) }",
      "x = obj.available_languages - [cur]",
      "def available_languages - x"
    ].each { |line| assert_equal [], flagged(line), "for #{line}" }
  end

  test "drops a match a numeric coercion follows" do
    assert_equal [], flagged("gap = (@to - @from).abs"), "coerced to a number"
    assert_equal ["@to - @from"], flagged("gap = (@to - @from)"), "the same difference left as it is"
  end

  test "reads a line's code up to its comment, past a # inside a string" do
    {
      "x = LIST + [1] # LIST - [2]" => "x = LIST + [1] ",
      "# LIST + [1]" => "",
      's = "a # b" + c' => 's = "a # b" + c',
      "s = 'a # b' + c # d" => "s = 'a # b' + c ",
      's = "a\" # b" + c' => 's = "a\" # b" + c'
    }.each { |line, want| assert_equal want, code_of(line), "for #{line}" }
  end

  test "reports a risky line of a swept file by its path and line number, past comment lines" do
    src = "a = 1\n# kept = LIST + [1]\nb = LIST + [2]\n"
    assert_equal ["core/x.rb:3 -> LIST + ["], violations("core/x.rb" => src)
  end

  test "spares an allowlisted snippet in its own file only" do
    line = "k = x * STRIDE + y\n"
    assert_equal ["core/other.rb:1 -> STRIDE + y"], violations("core/world/events.rb" => line, "core/other.rb" => line)
  end

  test "tells the paths that load only under the modern engine, either slash" do
    {
      "games/anil/menus.rb" => true,
      "games\\soulstones2\\raid_den.rb" => true,
      "games/infinitefusion_common/fusion.rb" => true,
      "games/pokemon_z/puzzles.rb" => false,
      "core/foundation/config.rb" => false,
      "plugins/dbk_battle.rb" => false
    }.each { |path, want| assert_equal want, modern?(path), "for #{path}" }
  end

  test "sweeps core, games, plugins and loader, the modern-only paths aside" do
    sources = swept_sources
    assert_equal %w[core games loader plugins], sources.keys.map { |r| r.split("/").first }.uniq.sort
    assert_equal [], sources.keys.select { |r| modern?(r) }
  end

  test "each allowlist entry is a live stride match in a swept file" do
    sources = swept_sources
    ALLOW.each do |path, snippets|
      assert_includes sources.keys, path, "the allowlisted file is inside the sweep"
      snippets.each do |snip|
        assert_equal [snip], flagged(snip), "#{path}: the allowed snippet is a detector match"
        assert_match(/\A#{CONST}\s*\+/, snip, "#{path}: the allowed snippet is stride arithmetic")
        assert_includes sources[path], snip, "#{path}: the allowed snippet still occurs in its file"
      end
    end
  end

  private

  # The MODERN fragments test/<file> declares, matched by re, or nil when the declaration is not found.
  def modern_declared(file, re)
    m = File.read(File.join(ROOT, "test", file))[re, 1]
    m && m.scan(/"([^"]+)"/).flatten
  end

  # The sorted "games/<key>/" fragments of the catalog's engine "gamedata" profiles and of the commons only they
  # import.
  def modern_of_catalog
    profs = JSON.parse(File.read(File.join(ROOT, "games", "catalog.json")))["profiles"]
    keys = profs.select { |p| p["engine"] == "gamedata" }.map { |p| p["key"] }
    commons = Imports.importers.select { |_c, games| (games - keys).empty? }.map { |c, _g| c }
    (keys + commons).map { |k| "games/#{k}/" }.sort
  end

  # True if this path loads only under the modern engine and is therefore out of scope.
  def modern?(path)
    p = path.tr("\\", "/")
    MODERN.any? { |m| p.include?(m) }
  end

  # { relative path => text } of the files this guard scans: core/, games/, plugins/ and loader/, minus the
  # modern-only subtrees.
  def swept_sources
    files = %w[core games plugins].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten +
            Dir.glob(File.join(ROOT, "loader", "*.rb"))
    files.reject { |f| modern?(f) }.sort.each_with_object({}) do |f, out|
      out[f[(ROOT.length + 1)..-1].tr("\\", "/")] = File.read(f)
    end
  end

  # The code portion of a line: everything before the first `#` outside a quoted string (escapes skipped).
  def code_of(line)
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

  # The risk matches in a line's code, stripped, in the order of RISKS; a numeric-wrapped match is dropped.
  def flagged(line)
    code = code_of(line)
    RISKS.each_with_object([]) do |re, out|
      pos = 0
      while (m = re.match(code, pos))
        pos = m.end(0)
        out << m[0].strip unless (code[m.end(0)..-1] || "") =~ NUMERIC_WRAP
      end
    end
  end

  # Every risk match in sources ({ relative path => text }) as "path:line -> snippet", each file's allowlisted
  # snippets skipped (a comment has no code, so it flags nothing).
  def violations(sources)
    out = []
    sources.keys.sort.each do |r|
      allowed = ALLOW[r] || []
      sources[r].split("\n").each_with_index do |line, idx|
        flagged(line).each { |snip| out << "#{r}:#{idx + 1} -> #{snip}" unless allowed.include?(snip) }
      end
    end
    out
  end
end
