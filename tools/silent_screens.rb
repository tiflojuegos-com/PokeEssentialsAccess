# Finds the screens of a game's scripts the mod may leave silent: a class whose methods (its self. ones included)
# loop, read Input and pump the frame (Graphics.update or pbWait), or a top-level function that does all three in one
# body, whose name no file the game loads (core, the plugin readers the loader would give it, its profile with the
# commons it imports) mentions; a nested class counts as named only by its full path.
# A name mentioned anywhere counts as read, so a reader bound to a window or a helper keeps its screen off the list;
# what remains is triaged by hand (what each shows, whether play reaches it), and what needs no reader goes to
# silent_screens_triaged.txt with the reason.
# With --painters it lists instead the methods that paint text (PAINTS) in the classes a loaded file names, and the
# functions, that no loaded hook reaches and whose own name no loaded file mentions: a class read through its other
# methods leaves these unread (the Battle Arena's judgment, painted by Battle::Scene#updateJudgment). They are named
# Class#method (Object#name for a function) and triaged in the same file.
#   ruby tools/silent_screens.rb ["path\to\decompiled Scripts"]    # every dump: the screens still to check, by name
#   ruby tools/silent_screens.rb --painters ["path\to\dumps"]      # every dump: the painting methods still to check
#   ruby tools/silent_screens.rb --dump <dump folder> <profile>     # one game, all of them
# A folder of stock trees (vanilla's tags, each in its own subfolder) can stand in for the dumps: one with no profile
# of that name is checked against core alone.
# Each row says how the screen moves (arrows read by the screen itself), what it shows (text it draws or sets, or a
# command window or message, which the mod reads by itself) and which other scripts call it: none means map events
# only, or dead code.
require "prism"
require File.expand_path("../test/static/reader_sites", File.dirname(__FILE__))

module SilentScreens
  ROOT = ReaderSites::ROOT
  INPUT_READS = %w[trigger? repeat? press? triggerex? repeatex? pressex?].freeze
  WIDGETS = /Window_CommandPokemon\w*|Window_AdvancedCommandPokemon|pbShowCommands\w*|pbMessage\w*|pbConfirmMessage|
             pbDisplay\w*|pbChooseNumber|Window_InputNumberPokemon|pbCommands\w*/x
  DRAWS = /pbDrawTextPositions|drawTextEx|draw_text|drawFormattedTextEx|\.text\s*=|pbDrawShadowText|pbDrawOutlineText/
  TOOLING = /Editor|Debug|Compiler|Tileset|_Main\.rb\z/
  # Engine plumbing that loops on input and draws nothing of its own to read.
  PLUMBING = %w[Interpreter EventScene Scene_Map Scene_Movie Game_Screen].freeze
  # The registrations that name a function by a string: Hooks.wrap_global/wrap_kernel and the profiles' kernel verb.
  FUNCTION_FORMS = /\b(?:wrap_global|wrap_kernel|kernel)\(\s*"(\w+)"/
  # The calls that paint text on a bitmap or set a window's text.
  PAINTS = %i[pbDrawTextPositions drawTextEx drawFormattedTextEx pbDrawShadowText pbDrawOutlineText draw_text text=].freeze

  # What a method body does: loops (:loop), reads the keys (:input, :arrows when it reads a direction) and pumps
  # the frame (:pump): Graphics.update, or pbWait, which runs it.
  def self.features(node, acc = {})
    case node
    when Prism::WhileNode, Prism::UntilNode then acc[:loop] = true
    when Prism::CallNode
      acc[:loop] = true if node.name == :loop && node.block
      if node.receiver && node.receiver.slice == "Input" && INPUT_READS.include?(node.name.to_s)
        acc[:input] = true
        acc[:arrows] = true if node.arguments && node.arguments.slice =~ /LEFT|RIGHT|UP|DOWN/
      end
      acc[:pump] = true if node.receiver && node.receiver.slice == "Graphics" && node.name == :update
      acc[:pump] = true if node.name == :pbWait && (node.receiver.nil? || node.receiver.slice == "Kernel")
    end
    node.compact_child_nodes.each { |c| features(c, acc) }
    acc
  end

  # What a method body paints (:paints, a call of PAINTS) and the methods it calls on its own object (:calls).
  def self.paint_calls(node, acc = { :paints => false, :calls => {} })
    if node.is_a?(Prism::CallNode)
      acc[:paints] = true if PAINTS.include?(node.name)
      acc[:calls][node.name.to_s] = true if node.receiver.nil? || node.receiver.is_a?(Prism::SelfNode)
    end
    node.compact_child_nodes.each { |c| paint_calls(c, acc) }
    acc
  end

  # Every class body of a dump as { "Path::Name" => { :file, :defs => [features], :src, :names => { method => true },
  # :paint => [[method, paint_calls, file, source]] } } and every top-level function (also those of Kernel and Object)
  # as [name, file, features, source, paint_calls]. A class's defs take its self. methods and those of its
  # class << self too; :names holds its instance methods, for the probes, and :paint their bodies.
  def self.scan(dir)
    classes = {}
    functions = []
    Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |f|
      src = File.binread(f).force_encoding("UTF-8")
      src = src.encode("UTF-8", "binary", :invalid => :replace, :undef => :replace) unless src.valid_encoding?
      walk(Prism.parse(src).value, [], File.basename(f), classes, functions)
    end
    [classes, functions]
  end

  def self.walk(node, path, file, classes, functions)
    if node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
      name = node.constant_path.slice.sub(/\A::/, "")
      full = (name.include?("::") ? [name] : path + [name]).join("::")
      e = (classes[full] ||= { :file => file, :defs => [], :src => "", :names => {}, :paint => [] })
      body = node.body ? node.body.compact_child_nodes : []
      methods_of(body, full, file, e, functions)
      body.each { |c| walk(c, full.split("::"), file, classes, functions) }
      return
    end
    if node.is_a?(Prism::DefNode) && path.empty?
      functions << [node.name.to_s, file, features(node), node.slice, paint_calls(node)]
      return
    end
    node.compact_child_nodes.each { |c| walk(c, path, file, classes, functions) }
  end

  # Records the methods of one class body in e: its defs, self. ones and a class << self block's included, and the
  # names of its instance methods (attr_* and aliases too). Kernel's and Object's methods are functions.
  def self.methods_of(body, full, file, e, functions, singleton = false)
    body.each do |c|
      case c
      when Prism::DefNode
        next unless c.receiver.nil? || c.receiver.is_a?(Prism::SelfNode)
        if %w[Kernel Object].include?(full)
          functions << [c.name.to_s, file, features(c), c.slice, paint_calls(c)]
          next
        end
        e[:defs] << features(c)
        e[:src] << c.slice << "\n"
        next if singleton || c.receiver
        e[:names][c.name.to_s] = true
        e[:paint] << [c.name.to_s, paint_calls(c), file, c.slice]
      when Prism::SingletonClassNode
        next unless c.expression.is_a?(Prism::SelfNode)
        methods_of(c.body ? c.body.compact_child_nodes : [], full, file, e, functions, true)
      when Prism::AliasMethodNode
        e[:names][c.new_name.slice.sub(/\A:/, "")] = true unless singleton
      when Prism::CallNode
        next if singleton || c.receiver || !%w[attr_accessor attr_reader alias_method].include?(c.name.to_s)
        args = c.arguments ? c.arguments.arguments : []
        args = args.first(1) if c.name == :alias_method
        args.each { |a| e[:names][a.slice.sub(/\A:/, "").delete("\"'")] = true }
      end
    end
  end

  # A manifest of games/ as a Hash, or {} when the profile has none.
  def self.manifest(profile)
    path = File.join(ROOT, "games", profile.to_s, "manifest.rb")
    m = File.file?(path) ? eval(File.read(path)) : {}
    m.is_a?(Hash) ? m : {}
  end

  # The plugin readers a profile loads, as the loader picks them: those its manifest and its commons' list, or, for
  # :auto (the generic profile), those whose probe the scripts define.
  def self.plugin_readers(m, classes, functions)
    return probed_plugins(classes, functions) if m[:plugins] == :auto
    lists = [m[:plugins]] + (m[:imports] || []).map { |c| manifest(c)[:plugins] }
    lists.select { |l| l.is_a?(Array) }.flatten.map { |n| n.to_s }.uniq
  end

  # The sources a game loads: core, its plugin readers (plugin_readers) and its profile with the commons it imports.
  def self.loaded_sources(profile, classes, functions)
    m = manifest(profile)
    dirs = [profile.to_s] + (m[:imports] || [])
    plugins = plugin_readers(m, classes, functions)
    ReaderSites.sources.select do |p, _b|
      p.start_with?("core/") || plugins.include?(p[%r{\Aplugins/(\w+)\.rb\z}, 1].to_s) ||
        dirs.any? { |d| p.start_with?("games/#{d}/") }
    end
  end

  # The plugin readers of plugins/manifest.rb whose probe the scripts define, as the engine checks it: a class by its
  # full name, "Class#method" with that instance method, "Object#name" a top-level function.
  def self.probed_plugins(classes, functions)
    table = eval(File.read(File.join(ROOT, "plugins", "manifest.rb")))
    table.select do |_name, probe|
      cls, meth = probe.to_s.split("#", 2)
      if cls == "Object" && meth
        functions.any? { |f| f[0] == meth }
      else
        e = classes[cls]
        e && (meth.nil? || e[:names][meth]) ? true : false
      end
    end.keys.map { |k| k.to_s }
  end

  # The game's screens no loaded file names, as rows { :kind, :name, :file, :arrows, :shows, :callers }.
  def self.candidates(dir, profile)
    classes, functions = scan(dir)
    text = loaded_sources(profile, classes, functions).values.join("\n")
    wrapped = text.scan(FUNCTION_FORMS).flatten
    named = lambda { |n| text =~ /(?<!\w)(?<!\w::)#{Regexp.escape(n)}(?!\w)/ }
    scripts = scripts(dir)
    rows = []
    classes.each do |full, e|
      last = full.split("::").last
      fs = e[:defs]
      next if e[:file] =~ TOOLING || PLUMBING.include?(last) || named.call(full.include?("::") ? full : last)
      next unless fs.any? { |f| f[:loop] } && fs.any? { |f| f[:input] } && fs.any? { |f| f[:pump] }
      rows << row(:class, full, e[:file], fs.any? { |f| f[:arrows] }, e[:src], scripts)
    end
    functions.each do |name, file, f, src|
      next if file =~ TOOLING || wrapped.include?(name) || named.call(name)
      next unless f[:loop] && f[:input] && f[:pump]
      rows << row(:function, name, file, f[:arrows], src, scripts)
    end
    rows
  end

  # The painting methods no loaded hook reaches and no loaded file names (see the header), as rows like candidates'.
  def self.painters(dir, profile)
    classes, functions = scan(dir)
    loaded = loaded_sources(profile, classes, functions)
    text = loaded.values.join("\n")
    named = lambda { |n| text =~ /(?<!\w)(?<!\w::)#{Regexp.escape(n)}(?!\w)/ }
    hooked = Hash.new { |h, k| h[k] = [] }
    ReaderSites.hooked_pairs(loaded).each_key do |pair|
      cls, meth = pair.split("#", 2)
      hooked[cls] << meth if meth
    end
    scripts = scripts(dir)
    rows = []
    classes.each do |full, e|
      last = full.split("::").last
      next if PLUMBING.include?(last) || !named.call(full.include?("::") ? full : last)
      reach = reached(hooked[full], e[:paint])
      e[:paint].each do |name, pc, file, src|
        next if !pc[:paints] || file =~ TOOLING || reach[name] || named.call(name)
        rows << row(:painter, "#{full}##{name}", file, false, src, scripts)
      end
    end
    defs = functions.map { |name, file, _f, src, pc| [name, pc, file, src] }
    reach = reached(text.scan(FUNCTION_FORMS).flatten, defs)
    defs.each do |name, pc, file, src|
      next if !pc[:paints] || file =~ TOOLING || reach[name] || named.call(name)
      rows << row(:painter, "Object##{name}", file, false, src, scripts)
    end
    rows.uniq { |r| r[:name] }
  end

  # The methods a hook reaches among defs ([method, paint_calls, ...]): the hooked ones and, through the calls each
  # makes on its own object, every one they run.
  def self.reached(hooked, defs)
    calls = Hash.new { |h, k| h[k] = {} }
    defs.each { |name, pc, _file, _src| calls[name].merge!(pc[:calls]) }
    reach = {}
    queue = hooked.dup
    until queue.empty?
      m = queue.shift
      next if reach[m]
      reach[m] = true
      queue.concat(calls[m].keys)
    end
    reach
  end

  # A name as a call writes it: a setter on a receiver or as a symbol (x.height = 1, send(:height=, 1)), its = with
  # any spaces before it and not an ==, =~ or =>; any other name with no letter right after it, one ending in ? or !
  # too.
  def self.call_re(name)
    return /[.:]#{Regexp.escape(name.chomp("="))}\s*=(?![=~>])/ if name.end_with?("=")
    /\b#{Regexp.escape(name)}(?!\w)/
  end

  # A dump's scripts as [file name, text], their comments (=begin blocks and # lines) left out, so a call in
  # commented-out code calls nothing.
  def self.scripts(dir)
    Dir.glob(File.join(dir, "**", "*.rb")).map do |f|
      [File.basename(f), File.binread(f).gsub(/^=begin\b.*?^=end\b[^\n]*/m, "").gsub(/^[ \t]*#[^\n]*/, "")]
    end
  end

  def self.row(kind, name, file, arrows, src, scripts)
    word = call_re(name.split("#").last.split("::").last)
    callers = scripts.reject { |f, _s| f == file }.select { |_f, s| s =~ word }.map { |f, _s| f }
    shows = [src =~ DRAWS ? :draws : nil, src =~ WIDGETS ? :widgets : nil].compact
    { :kind => kind, :name => name, :file => file, :arrows => arrows ? true : false, :shows => shows,
      :callers => callers }
  end

  # One row as the report prints it.
  def self.line(r)
    how = [r[:arrows] ? "its own arrows" : nil, r[:shows].include?(:draws) ? "draws or sets text" : nil,
           r[:shows].include?(:widgets) ? "command window or message" : nil].compact.join(", ")
    calls = r[:callers].empty? ? "called by no other script" : "called from #{r[:callers].first(3).join(', ')}"
    "#{r[:kind]} #{r[:name]} (#{r[:file]}): #{how.empty? ? 'loop only' : how}; #{calls}"
  end

  # The screens checked by hand (silent_screens_triaged.txt) as { name => [games, why] }; a malformed or repeated line
  # raises.
  def self.triaged
    path = File.join(File.dirname(__FILE__), "silent_screens_triaged.txt")
    out = {}
    File.readlines(path).each do |l|
      next if l =~ /\A\s*(#|\z)/
      name, games, why = l.split("|", 3).map { |s| s.strip }
      raise "silent_screens_triaged.txt: not 'name | games | why': #{l.strip}" if why.nil?
      raise "silent_screens_triaged.txt: #{name} twice; keep one line with all its games" if out.key?(name)
      out[name] = [games.split, why]
    end
    out
  end

  # Why a screen of game needs no reader, when it was checked there; else nil.
  def self.checked_why(name, game, table = triaged)
    row = table[name]
    row && row[0].include?(game) ? row[1] : nil
  end
end

if __FILE__ == $0
  if ARGV[0] == "--dump"
    SilentScreens.candidates(ARGV[1], ARGV[2]).each { |r| puts "- #{SilentScreens.line(r)}" }
    exit 0
  end
  painters = ARGV[0] == "--painters"
  dumps = (painters ? ARGV[1] : ARGV[0]) || File.expand_path("../../decompiled Scripts", SilentScreens::ROOT)
  abort "dumps folder not found: #{dumps}" unless File.directory?(dumps)
  by_name = Hash.new { |h, k| h[k] = [] }
  scanned = []
  Dir.glob(File.join(dumps, "*")).select { |d| File.directory?(d) }.sort.each do |d|
    game = File.basename(d)
    scanned << game
    profile = ReaderSites::PROFILE_OF[game] || game
    found = painters ? SilentScreens.painters(d, profile) : SilentScreens.candidates(d, profile)
    found.each { |r| by_name[[r[:kind], r[:name]]] << [game, r] }
  end
  checked = SilentScreens.triaged.select { |name, _row| name.include?("#") == painters }
  fresh = []
  by_name.sort_by { |(_k, name), rows| [-rows.length, name] }.each do |(_kind, name), rows|
    games = rows.map { |g, _r| g }.uniq.reject { |g| SilentScreens.checked_why(name, g, checked) }
    fresh << "- #{SilentScreens.line(rows[0][1])} -- in #{games.join(', ')}" unless games.empty?
  end
  puts "To check (#{fresh.length}):"
  puts fresh
  puts "Checked before (tools/silent_screens_triaged.txt): #{by_name.length - fresh.length} of #{by_name.length}"
  listed = by_name.keys.map { |_kind, name| name }
  stale = checked.select { |name, row| !listed.include?(name) && !(row[0] & scanned).empty? }.keys.sort
  puts "Triaged but no longer listed in a game checked here, to drop (a file names them now, or the game no longer " \
       "has them): #{stale.length}"
  stale.each { |name| puts "- #{name}" }
end
