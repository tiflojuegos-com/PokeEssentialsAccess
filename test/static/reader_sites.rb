# The extractor shared by the census builders and the specs that check them: the ivars readers take off game
# objects (only the symbol form of PokeAccess.ivar* and instance_variable_get), the after hooks, and every hook
# registration with its loops expanded.
require File.expand_path("imports", File.dirname(__FILE__))

module ReaderSites
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  LAYERS = ["core", "games", "plugins"]

  # The innermost class or module a line sits in, across one file. A class displaces open ones at its indent or
  # deeper; nothing closes on `end`, on purpose, since decompiled class bodies may sit at column 0; a def belongs
  # to the innermost class indented less than it, else the innermost of all.
  class ClassStack
    def initialize
      @stack = []
    end

    # Feeds one line and answers the innermost open class/module name, or nil at file scope.
    def feed(line)
      if line =~ /^(\s*)(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/
        ind = $1.length
        @stack.pop while !@stack.empty? && @stack.last[0] >= ind
        @stack.push([ind, $2.split("::").last, $2])
      end
      current
    end

    # The owner of a def at this indent as a full path, the open frames down to it joined as the game wrote them
    # ("Battle::Scene::MenuBase", nested or opened by its qualified name).
    def owner_path_at(def_indent)
      frames = frames_to_owner(def_indent)
      frames.empty? ? nil : frames.map { |f| f[2] }.join("::")
    end

    # How many frames enclose that owner, itself included; 1 is a top-level class.
    def owner_depth_at(def_indent)
      frames_to_owner(def_indent).length
    end

    def frames_to_owner(def_indent)
      i = @stack.rindex { |ind, _n, _d| ind < def_indent }
      i = @stack.length - 1 if i.nil?
      i < 0 ? [] : @stack[0..i]
    end

    # The innermost open class/module name, or nil.
    def current
      @stack.empty? ? nil : @stack.last[1]
    end

    # The indent of the innermost open class/module, or nil.
    def indent
      @stack.empty? ? nil : @stack.last[0]
    end

    # The class a def at this indent belongs to: the innermost one indented less than the def, else the
    # innermost of all (a class whose body is not indented at all).
    def owner_at(def_indent)
      hit = @stack.reverse.find { |ind, _n| ind < def_indent }
      hit ? hit[1] : current
    end
  end

  # A dump folder is named after the game; a few do not match the profile that reads them.
  PROFILE_OF = { "africanvs" => "africanus", "z218" => "pokemon_z" }

  # Reads through PokeAccess.ivar* (the object first, the symbol after a comma) and instance_variable_get (the
  # symbol alone), either wrapped across lines.
  READ_FORMS = [
    /PokeAccess\.ivar\w*\(.{0,160}?:@([A-Za-z_]\w*)/m,
    /\.instance_variable_get\(\s*:@([A-Za-z_]\w*)/m
  ]
  WRITE_FORM = /\.instance_variable_set\(\s*:@([A-Za-z_]\w*)/m

  # Ivars the mod sets on a game object itself (instance_variable_set), which no game has to carry.
  def self.mod_owned(sources)
    owned = {}
    sources.each_value { |body| body.scan(WRITE_FORM) { owned[$1] = true } }
    owned
  end

  # { relative path => file body } for every Ruby file in the layers that hook game code.
  def self.sources
    out = {}
    LAYERS.each do |layer|
      Dir.glob(File.join(ROOT, layer, "**", "*.rb")).sort.each do |path|
        out[path[ROOT.length + 1..-1].tr("\\", "/")] = File.read(path)
      end
    end
    out
  end

  # { relative path => [ivar name, ...] }, mod-owned names removed.
  def self.ivars_by_file(sources = nil)
    sources ||= self.sources
    owned = mod_owned(sources)
    out = {}
    sources.each do |path, body|
      stripped = body.gsub(/^\s*#.*$/, "")
      names = {}
      READ_FORMS.each { |re| stripped.scan(re) { names[$1] = true unless owned[$1] } }
      out[path] = names.keys.sort unless names.empty?
    end
    out
  end

  # Which profiles a file's readers can run in. core/ and the generic profile run everywhere; a game profile
  # runs in its own game, a common in the games that import it; a plugin reader runs wherever a profile declares it.
  def self.profiles_for(path, declarations)
    return :all if path.start_with?("core/")
    if path =~ %r{\Agames/([^/]+)/}
      game = $1
      return :all if game == "generic"
      return Imports.common?(game) ? (Imports.importers[game] || []) : [game]
    end
    return (declarations[$1] || :all) if path =~ %r{\Aplugins/([^/]+)\.rb\z}
    :all
  end

  # { plugin name => [profile, ...] } from the profile manifests (evaluated as the loader does), a common's plugins
  # going to the games that import it; a plugin only :auto reaches has no entry, so profiles_for answers :all for it.
  def self.declarations
    out = {}
    Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).sort.each do |mf|
      value = eval(File.read(mf))
      next unless value.is_a?(Hash) && value[:plugins].is_a?(Array)
      profile = File.basename(File.dirname(mf))
      games = Imports.common?(profile) ? (Imports.importers[profile] || []) : [profile]
      value[:plugins].each { |n| games.each { |g| (out[n.to_s] ||= []).push(g) unless (out[n.to_s] || []).include?(g) } }
    end
    out
  end

  # The after-style registrations, which run once their method returns; the trailing =? keeps a setter's name
  # whole (Class#selected=).
  HOOK_FORMS = [
    /after_hook\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/,
    /^\s*after\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/,
    /read_on_open\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!]*=?)(.*)/
  ]

  # An after-style registration, and one whose class and method are literal: the rest (a loop variable, a constant,
  # an era_scene call) cannot be resolved from the text, and are counted against a ceiling instead.
  ANY_AFTER = /(?:Hooks\.after_hook|^\s*after|read_on_open)\(/
  RESOLVED_AFTER = /(?:after_hook|^\s*after|read_on_open)\(\s*"[A-Za-z_:][\w:]*"\s*,\s*:\w[\w?!]*=?/

  # { relative path => ["Class#method", ...] } for the after hooks, less a read_on_open with :before, a
  # :hook_container and a hook marked blocks-on-purpose on its line or in the comment run just above it.
  def self.after_hooks_by_file(sources = nil)
    sources ||= self.sources
    out = {}
    sources.each do |path, body|
      sites = {}
      excused = false
      body.each_line do |line|
        if line =~ /\A\s*#/
          excused = true if line.include?("blocks-on-purpose")
          next
        end
        if line.strip.empty?
          excused = false
          next
        end
        HOOK_FORMS.each_with_index do |re, i|
          m = re.match(line)
          next unless m
          rest = m[3].to_s
          next if i == 2 && rest.include?(":before")
          next if rest.include?(":hook_container")
          next if excused || rest.include?("blocks-on-purpose")
          sites["#{m[1]}##{m[2]}"] = true
        end
        excused = false
      end
      out[path] = sites.keys.sort unless sites.empty?
    end
    out
  end

  # { relative path => [line, ...] } for after-style registrations the forms above cannot resolve. The DSL
  # definitions in core/foundation/game.rb are the declarations of after/read_on_open themselves, not uses.
  def self.unresolved_after_sites(sources = nil)
    sources ||= self.sources
    out = {}
    sources.each do |path, body|
      next if path == "core/foundation/game.rb"
      lines = []
      body.each_line do |line|
        next if line =~ /\A\s*#/
        next unless line =~ ANY_AFTER
        next if line =~ RESOLVED_AFTER
        next if line.include?(":hook_container")
        lines.push(line.strip)
      end
      out[path] = lines unless lines.empty?
    end
    out
  end

  # The class argument of a registration: a quoted name, a loop variable, or a constant such as
  # PokeAccess::SummaryGen6::SCENE (assigned from Engine.era_scene, resolved through constant_rows).
  CLS_ARG = '(?:"(?<cls_lit>[A-Z][A-Za-z0-9_:]*)"|(?<cls_var>[a-z_]\w*)|(?<cls_const>[A-Z][A-Za-z0-9_:]*))'
  METH_ARG = '(?::(?<m_lit>[a-zA-Z_][A-Za-z0-9_?!]*=?)|"(?<m_str>[a-zA-Z_][A-Za-z0-9_?!]*=?)"|(?<m_var>[a-z_]\w*)(?:\.to_sym)?)'
  REG_FORM = /\b(?:after|before|around)(?:_hook)?\(\s*#{CLS_ARG}\s*,\s*#{METH_ARG}/
  ONE_ARG_FORMS = [
    /\bread_on_open\(\s*#{CLS_ARG}\s*(?:,\s*#{METH_ARG})?/,
    /\bframe_hook\(\s*#{CLS_ARG}\s*,\s*#{METH_ARG}/
  ]
  # A loop header on one line: what it runs over (a literal, a constant, scene_classes(...) or the list of
  # Hooks.variants) and its block variables, one or several.
  LOOP_HEAD = /\A\s*(?:PokeAccess::Hooks\.variants\(\s*\[([^\]]*)\]\s*,\s*:\w+[^)]*\)|(%w\[[^\]]*\]|\[.*\]|\{.*\}|[A-Z][A-Za-z0-9_:]*|PokeAccess::Engine\.scene_classes\(([^)]*)\))\.each)\s*(?:do|\{)\s*\|([^|]+)\|/
  # The line that closes a literal opened some lines above and runs the loop over it.
  LOOP_TAIL = /[\]\}]\.each\s*(?:do|\{)\s*\|([^|]+)\|/

  # Literal names inside one literal: "strings", 'strings' and :symbols (ivar-named ones included, so a
  # tuple's positions stay where the loop variables expect them).
  def self.literal_names(text)
    text.scan(/"([^"]+)"|'([^']+)'|:(@?[a-zA-Z_][A-Za-z0-9_?!]*=?)/).map { |a, b, c| a || b || c }
  end

  # The rows a literal yields to its loop: one name per row for a flat array or a %w list, one row per inner
  # array for an array of tuples, one [key, value] row per pair for a hash.
  def self.literal_rows(lit)
    lit = lit.strip
    return lit[3..-2].split.map { |w| [w] } if lit.start_with?("%w[")
    if lit.start_with?("{")
      return lit.scan(/("[^"]+"|:@?[a-zA-Z_][\w?!]*=?)\s*=>\s*("[^"]+"|:@?[a-zA-Z_][\w?!]*=?)/).map { |k, v| [literal_names(k)[0], literal_names(v)[0]] }
    end
    return lit.scan(/\[([^\[\]]*)\]/).flatten.map { |t| literal_names(t) }.reject { |r| r.empty? } if lit =~ /\A\[\s*\[/
    literal_names(lit).map { |n| [n] }
  end

  # The bracketed literal starting at pos, brackets balanced across lines, or nil when it never closes.
  def self.balanced(text, pos)
    depth = 0
    i = pos
    while i < text.length
      ch = text[i, 1]
      depth += 1 if ch == "[" || ch == "{"
      depth -= 1 if ch == "]" || ch == "}"
      return text[pos..i] if depth == 0
      i += 1
    end
    nil
  end

  # { constant => rows } for every array or hash literal, or Engine.era_scene/scene_class spelling, assigned to a
  # constant: keyed by its path inside PokeAccess, and by the bare name while only one definition carries it.
  def self.constant_rows(sources)
    out = {}
    seen = {}
    sources.each_value do |body|
      code = body.gsub(/^\s*#.*$/, "")
      stack = ClassStack.new
      offset = 0
      code.each_line do |line|
        stack.feed(line)
        if (m = line.match(/\A(\s*)([A-Z][A-Z0-9_]*)\s*=\s*(\S.*)\z/m))
          rhs = m[3]
          rows = nil
          if rhs =~ /\A(%w\[|\[|\{)/
            prefix = rhs.start_with?("%w[") ? "%w" : ""
            lit = balanced(code, offset + m.begin(3) + prefix.length)
            rows = literal_rows(prefix + lit) if lit
          elsif (e = rhs.match(/\bEngine\.(?:era_scene|scene_class|scene_classes)\(([^)]*)\)/))
            rows = literal_names(e[1]).select { |n| n =~ /\A[A-Z]/ }.map { |n| [n] }
          end
          if rows && !rows.empty?
            path = stack.owner_path_at(m[1].length)
            name = m[2]
            full = (path ? "#{path}::#{name}" : name).sub(/\APokeAccess::/, "")
            out[full] = rows
            seen[name] = (seen[name] || 0) + 1
            seen[name] == 1 ? (out[name] ||= rows) : out.delete(name)
            out[full] = rows
          end
        end
        offset += line.length
      end
    end
    out
  end

  # The rows behind a constant path as a registration writes it, or nil.
  def self.const_lookup(constants, path)
    p = path.sub(/\APokeAccess::/, "")
    constants[p] || constants[p.split("::").last]
  end

  # The rows a one-line loop header runs over, or nil when they cannot be read from the text.
  def self.head_rows(m, constants)
    return literal_names(m[1]).map { |n| [n] } if m[1]
    return literal_names(m[3]).map { |n| [n] } if m[3]
    expr = m[2].to_s
    return literal_rows(expr) if expr =~ /\A(%w\[|\[|\{)/
    const_lookup(constants, expr)
  end

  # The body of the block that follows a registration line, and only that body: a brace block that closes on
  # the line is that line; a do-block runs to the `end` at the line's own indent.
  def self.block_body(lines, i)
    line = lines[i]
    if line =~ /\{/ && line.rindex("}").to_i > line.index("{").to_i
      return line[line.index("{")..line.rindex("}")]
    end
    return "" unless line =~ /\bdo\s*(\|[^|]*\|)?\s*\z/
    indent = line[/\A\s*/].length
    out = []
    j = i + 1
    while j < lines.length
      l = lines[j]
      break if l.strip =~ /\Aend\b/ && l[/\A\s*/].length == indent
      out.push(l)
      j += 1
    end
    out.join("\n")
  end

  # A literal that opens on this line and reaches its `.each do |...|` a few lines down: the header text and
  # the index of its last line, or nil.
  def self.spanning_head(lines, i)
    return nil unless lines[i] =~ /\A\s*[\[\{]/ && lines[i] !~ /\.each\b/
    chunk = []
    (i...[i + 16, lines.length].min).each do |j|
      chunk.push(lines[j].sub(/\s#(?!\{).*\z/, ""))
      return [chunk.join("\n"), j] if lines[j] =~ LOOP_TAIL
    end
    nil
  end

  # Every (class, method) pair a hook registration binds, loops included, as { :path, :line, :site, :cname, :meth,
  # :body }; the pairs one line expands to share its :site ("path:line"), and :body is its block.
  def self.registrations(sources = nil)
    sources ||= self.sources
    constants = constant_rows(sources)
    out = []
    sources.each do |path, body|
      next if path == "core/foundation/game.rb"
      lines = body.split("\n")
      loops = []
      skip_to = -1
      lines.each_with_index do |raw, i|
        next if i <= skip_to || raw =~ /\A\s*#/
        line = raw.sub(/\s#(?!\{).*\z/, "")
        indent = line[/\A\s*/].length
        loops.pop while !loops.empty? && line.strip =~ /\Aend\b/ && loops.last[0] == indent
        temp = false
        if (span = spanning_head(lines, i))
          head, last = span
          vars = head[LOOP_TAIL, 1].split(",").map { |v| v.strip }
          lit = balanced(head, head.index(/[\[\{]/))
          rows = lit ? literal_rows(lit) : nil
          loops.push([indent, vars, rows]) if rows && !rows.empty?
          skip_to = last
          next
        elsif (h = LOOP_HEAD.match(line))
          rows = head_rows(h, constants)
          if rows && !rows.empty?
            loops.push([indent, h[4].split(",").map { |v| v.strip }, rows])
            temp = line.count("{") > 0 && line.count("{") <= line.count("}")
          end
          next unless line =~ /\{/
        end
        find = lambda do |ident|
          loops.reverse_each do |_ind, vars, rows|
            k = vars.index(ident)
            return [rows, k] if k
          end
          nil
        end
        (ONE_ARG_FORMS + [REG_FORM]).each do |re|
          next unless (m = re.match(line))
          cls_lit = m[:cls_lit]
          crows = m[:cls_const] ? const_lookup(constants, m[:cls_const]) : nil
          cb = m[:cls_var] ? find.call(m[:cls_var]) : nil
          next if cls_lit.nil? && crows.nil? && cb.nil?
          meth_lit = m[:m_lit] || m[:m_str]
          meth_var = m[:m_var]
          meth_lit = "pbStartScene" if !re.equal?(REG_FORM) && meth_lit.nil? && meth_var.nil?
          mb = meth_var ? find.call(meth_var) : nil
          next if meth_lit.nil? && mb.nil?
          pairs = []
          if cb && mb && cb[0].equal?(mb[0])
            cb[0].each { |row| pairs.push([row[cb[1]], row[mb[1]]]) }
          else
            classes = cls_lit ? [cls_lit] : (crows ? crows.map { |row| row[0] } : cb[0].map { |row| row[cb[1]] })
            meths = meth_lit ? [meth_lit] : mb[0].map { |row| row[mb[1]] }
            classes.compact.uniq.each { |c| meths.compact.uniq.each { |mt| pairs.push([c, mt]) } }
          end
          text = block_body(lines, i)
          pairs.each do |c, mt|
            next unless c.to_s =~ /\A[A-Z]/ && mt
            out.push(:path => path, :line => i + 1, :site => "#{path}:#{i + 1}", :cname => c, :meth => mt.to_s, :body => text)
          end
          break
        end
        loops.pop if temp
      end
    end
    out
  end

  # { "Class#method" => [relative path, ...] } over every registration, loops expanded.
  def self.hooked_pairs(sources = nil)
    pairs = {}
    registrations(sources).each do |r|
      key = "#{r[:cname]}##{r[:meth]}"
      (pairs[key] ||= []).push(r[:path]) unless (pairs[key] || []).include?(r[:path])
    end
    pairs
  end
end
