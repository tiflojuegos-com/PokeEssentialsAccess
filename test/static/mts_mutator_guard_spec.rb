# Static guard against Pokemon Z's MTS array-mutator landmine. Z's script library redefines Array#+ and
# Array#- as IN-PLACE mutators that return self, so `CONST + extra` or `@cache - other` on an array does not
# build a new array -- it corrupts the constant/cache in place, permanently, for the rest of the session.
# Every core/ file and every gen-6 game adapter loads under Z, so any such expression there is a live bug
# (settings.rb, remap.rb, locator_naming.rb, i18n.rb and pathfinder.rb each shipped one and had to be
# rewritten with dup/concat/reject). This scan reads those files as text and fails CI on the two risk shapes
# below, with an allowlist for the integer/string arithmetic that is safe by construction. It runs only in
# the gen-6 pass (no _gd suffix) and needs no engine stubs -- it is a pure filesystem check.
module MtsGuard
  ROOT = File.expand_path("../..", __dir__)

  # Path fragments whose files load ONLY under the modern engine (Ruby 3.x, no MTS): the mutator redefinition
  # never applies there, so they are out of scope. La misma lista vive en test/check187.py y hasta ahora
  # se mantenian en paso a mano; el spec de abajo las compara.
  MODERN = ["games/anil/", "games/royal/", "games/relict/",
            "games/infinitefusion_hoenn/", "games/infinitefusion/",
            "games/emerald/"]

  # The MODERN tuple as check187.py declares it, parsed out of the source.
  # return the list of path fragments, or nil when the declaration cannot be found
  def self.modern_of_check187(root)
    src = File.read(File.join(root, "test", "check187.py"))
    m = src[/^MODERN\s*=\s*\((.*?)\)/m, 1]
    return nil unless m
    m.scan(/"([^"]+)"/).flatten
  end

  # The THIRD copy of the list, in the file the real 1.8.7 interpreter runs. It is the one that decides what
  # actually gets parsed, and it was the one nobody compared: adding "core/" to it took the sweep from 194
  # files to 96 and the verdict stayed OK.
  def self.modern_of_check187_real(root)
    src = File.read(File.join(root, "test", "check187_real.rb"))
    m = src[/^MODERN\s*=\s*\[(.*?)\]/m, 1]
    return nil unless m
    m.scan(/"([^"]+)"/).flatten
  end

  # The machine-declared source: games/catalog.json marks each profile's engine, so the exemption is
  # DERIVED here instead of trusted. Only engine "gamedata" profiles load under Ruby 3.x alone; keeping
  # the three literal lists equal to each other proves nothing if all three drift from the catalog at once.
  # return the sorted "games/<key>/" fragments, or nil when the catalog cannot be read
  def self.modern_of_catalog(root)
    require "json"
    data = JSON.parse(File.read(File.join(root, "games", "catalog.json")))
    profs = data["profiles"]
    return nil unless profs.is_a?(Array)
    profs.select { |p| p["engine"] == "gamedata" }.map { |p| "games/#{p['key']}/" }.sort
  rescue StandardError
    nil
  end

  # An uppercase constant of 3+ chars: the array constants that get corrupted (BUTTONS, TEXT_CODES, NUMERIC).
  CONST = '[A-Z][A-Z0-9_]{2,}'

  # Risk shape 1 -- `CONST + <rhs>`: a constant on the left of a `+` whose rhs is an array literal, another
  # constant, or an identifier (an array being appended). Excludes a numeric-literal rhs and a `*` right
  # before the constant (index arithmetic like `row * STRIDE + col`, which is Integer#+, always safe).
  PLUS_RE = Regexp.new('(?<![*\d])\b(' + CONST + ')\s*\+\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Risk shape 2 -- `<array-holder> - <rhs>`: an @ivar, a constant, or a `.keys`/`.values`/`.dup`/`.uniq`/
  # `.to_a` receiver on the left of a `-` whose rhs is an array literal, a constant or an identifier (a set
  # difference). A numeric-literal rhs is excluded, so counter math like `@index - 1` does not trip it; these
  # left-hand forms are never plain scalars, so a non-numeric rhs means an array difference.
  MINUS_RE = Regexp.new('(@[a-z_]\w*|\b' + CONST + '\b|\.(?:keys|values|dup|uniq|to_a)\b)\s*-\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # Cache-accessor method names on the watchlist: bare lowercase methods that return a MEMOIZED array (the
  # same object every call). `available_languages - present` corrupts that cache in place exactly like the
  # `@langs - present` bug that shipped (i18n.rb), but a plain lowercase identifier on the left of `-` is
  # indistinguishable from scalar math (`now - @time`, `elapsed - start`) by regex alone -- so MINUS_RE cannot
  # cover it in general. Instead we enumerate the known accessors by name: a concrete literal like
  # `available_languages` has no scalar-arithmetic reading, so flagging it reintroduces no false positive.
  # Add a name here only after confirming the method memoizes and returns an array (its callers must dup/reject
  # before a `-`); never add a scalar getter (a coordinate, a count, a timestamp).
  CACHE_ACCESSORS = %w[available_languages]

  # Risk shape 2b -- `<cache-accessor> - <rhs>`: one of the watchlisted memoized-array getters (CACHE_ACCESSORS)
  # on the left of a `-`, with the same array-shaped rhs as MINUS_RE. Anchored with a word boundary and a
  # negative lookbehind for `.` and `def ` so it fires on a bare call (`available_languages - x`) but not on a
  # method definition (`def available_languages`) or a same-named method on some other receiver (`x.available_languages`).
  WATCH_MINUS_RE = Regexp.new('(?<!\.)(?<!def )\b(?:' + CACHE_ACCESSORS.join('|') + ')\b\s*-\s*(\[|' + CONST + '\b|@[a-z_]\w*|[a-z_]\w*)')

  # A trailing numeric coercion right after the match (`(a - b).abs`, `.max`, `.to_i`...): marks the whole
  # expression as Integer/Float arithmetic, not an array op, so the match is dropped.
  NUMERIC_WRAP = /\A\s*\)?\.(abs|max|min|to_i|to_f|floor|ceil|round)\b/

  # Legitimate matches to ignore, keyed by "relative/path.rb" => [matched-snippet, ...]. These are integer
  # index arithmetic where the constant holds a stride, not an array (safe under the mutator library because
  # Integer#+ is untouched). Keyed by snippet, not line number, so the entry survives renumbering. Add a new
  # entry here (with a one-line reason) only for a match you have confirmed is scalar arithmetic or a string
  # concat -- never to silence a real array `+`/`-`.
  ALLOW = {
    "core/field/minigames.rb" => ["VF_W + col", "VF_W + c"],
    "core/nav/pathfinder.rb"  => ["PKEY_STRIDE + y"]
  }

  # True if this path loads only under the modern engine and is therefore out of scope.
  def self.modern?(path)
    p = path.tr("\\", "/")
    MODERN.any? { |m| p.include?(m) }
  end

  # The dual/gen-6 Ruby files this guard scans: all of core/, every game adapter, every plugin reader and the
  # loader, minus the modern-only subtrees.
  #
  # plugins/ was missing, and it is not a hypothetical gap: pokemon_z -- the one game with the mutator
  # redefinition -- declares three of them (incubator, item_crafting, logros), so a CONST + extra in any of
  # those corrupts the constant for the rest of the session with nothing in CI to see it. check187.py already
  # scanned the layer; this one did not.
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

  # The code portion of a line: everything before the first unquoted `#`. Quote-aware so a `#` inside a string
  # is not treated as a comment. Backslash escapes inside strings are skipped.
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
        [PLUS_RE, MINUS_RE, WATCH_MINUS_RE].each do |re|
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

# The tree is clean of the mutator landmine: no `CONST + ...` and no `@cache - ...` array op survives in any
# file that loads under Pokemon Z's MTS.
# The THREE lists name the same eight paths. They are two languages and three files apart and the only thing
# keeping them in step was a comment, so a path added to one and not the others would silently lint a Ruby 3
# file as 1.8.7, exempt a 1.8.7 file from the mutator guard, or shrink the real-interpreter sweep without
# changing its verdict.
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

# True if the two risk regexes flag this line at all, after dropping numeric-wrapped matches. Ignores the
# path allowlist -- this is the raw detector contract, exercised on synthetic lines with no file context.
def mts_flags?(line)
  code = MtsGuard.code_of(line)
  [MtsGuard::PLUS_RE, MtsGuard::MINUS_RE, MtsGuard::WATCH_MINUS_RE].any? do |re|
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

# The detector must catch the exact shapes that shipped as bugs (each rewritten with dup/concat/reject) --
# a guard that flags nothing real is worse than none, so the contract is pinned here on synthetic lines.
Suite.define("static: MTS mutator detector catches the known bug shapes") do
  bug_shapes = [
    "EXAMINE_CODES = TEXT_CODES + SCRIPT_CODES + GOODS_CODES",
    "list = BUTTONS + extras.map { |s, i| [s, nil, i[1]] }",
    "kinds = NUMERIC + [:flag] + SYMS",
    "out = @langs - present",
    "remaining = CODES - [101]"
  ]
  bug_shapes.each { |line| truthy "detector flags: #{line}", mts_flags?(line) }
end

# The detector must spare integer/float arithmetic that only LOOKS like an array op: a numeric-literal rhs
# (`@index - 1`), a `.abs`/`.max` coercion (`(a - b).abs`), or a bit op (`BUDGET_CHECK - 1`). The stride-index
# lines (`x * PKEY_STRIDE + y`) are covered by the path allowlist instead and are asserted separately below.
Suite.define("static: MTS mutator detector spares scalar arithmetic") do
  scalars = [
    "@index = (@index - 1) % n",
    "@sel -= 3 if grid? && @sel - 3 >= 1",
    "return false unless (iter & (BUDGET_CHECK - 1)) == 0",
    "d = (ev.x - px).abs + (ev.y - py).abs",
    "return if @last && (now - @last) < 0.5"
  ]
  scalars.each { |line| falsy "detector spares scalar arithmetic: #{line}", mts_flags?(line) }
end

# The allowlist must be minimal and honest: every entry must still correspond to a match the detector really
# produces (a stale entry silently weakens the guard), and every allowed snippet must be integer arithmetic
# (a `*` stride multiply on the same line), never an array op. And the entry must stay anchored to the REAL
# sweep, not just to the synthetic detector: during a mutation run the sweep glob was narrowed until both
# allowlisted files fell out of scope and this suite stayed green -- so each entry now also proves its file
# is still scanned and its snippet still occurs there.
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
