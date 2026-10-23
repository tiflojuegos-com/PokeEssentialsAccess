# Finds the screens of a game's scripts the mod may leave silent: a class whose methods (its self. ones included)
# loop, read Input and pump the frame (Graphics.update or pbWait), or a top-level function that does all three in one
# body, whose name no file the game loads (core, the plugin readers the loader would give it, its profile with the
# commons it imports) mentions; a nested class counts as named only by its full path.
# A name mentioned anywhere counts as read, so a reader bound to a window or a helper keeps its screen off the list;
# what remains is triaged by hand (what each shows, whether play reaches it), and what needs no reader goes to
# silent_screens_triaged.txt with the reason.
#   ruby tools/silent_screens.rb ["path\to\decompiled Scripts"]    # every dump: the screens still to check, by name
#   ruby tools/silent_screens.rb --dump <dump folder> <profile>     # one game, all of them
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

  # Every class body of a dump as { "Path::Name" => { :file, :defs => [features], :src, :names => { method => true } } }
  # and every top-level function (also those of Kernel and Object) as [name, file, features, source]. A class's defs
  # take its self. methods and those of its class << self too; :names holds its instance methods, for the probes.
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
      e = (classes[full] ||= { :file => file, :defs => [], :src => "", :names => {} })
      body = node.body ? node.body.compact_child_nodes : []
      methods_of(body, full, file, e, functions)
      body.each { |c| walk(c, full.split("::"), file, classes, functions) }
      return
    end
    if node.is_a?(Prism::DefNode) && path.empty?
      functions << [node.name.to_s, file, features(node), node.slice]
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
          functions << [c.name.to_s, file, features(c), c.slice]
          next
        end
        e[:defs] << features(c)
        e[:src] << c.slice << "\n"
        e[:names][c.name.to_s] = true unless singleton || c.receiver
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
    named = lambda { |n| text =~ /(?<!\w)(?<!\w::)#{Regexp.escape(n)}\b/ }
    scripts = Dir.glob(File.join(dir, "**", "*.rb")).map { |f| [File.basename(f), File.binread(f)] }
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

  def self.row(kind, name, file, arrows, src, scripts)
    word = /\b#{Regexp.escape(name.split("::").last)}\b/
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
  dumps = ARGV[0] || File.expand_path("../../decompiled Scripts", SilentScreens::ROOT)
  abort "dumps folder not found: #{dumps}" unless File.directory?(dumps)
  by_name = Hash.new { |h, k| h[k] = [] }
  Dir.glob(File.join(dumps, "*")).select { |d| File.directory?(d) }.sort.each do |d|
    game = File.basename(d)
    profile = ReaderSites::PROFILE_OF[game] || game
    SilentScreens.candidates(d, profile).each { |r| by_name[[r[:kind], r[:name]]] << [game, r] }
  end
  checked = SilentScreens.triaged
  fresh = []
  by_name.sort_by { |(_k, name), rows| [-rows.length, name] }.each do |(_kind, name), rows|
    games = rows.map { |g, _r| g }.uniq.reject { |g| SilentScreens.checked_why(name, g, checked) }
    fresh << "- #{SilentScreens.line(rows[0][1])} -- in #{games.join(', ')}" unless games.empty?
  end
  puts "To check (#{fresh.length}):"
  puts fresh
  puts "Checked before (tools/silent_screens_triaged.txt): #{by_name.length - fresh.length} of #{by_name.length}"
  listed = by_name.keys.map { |_kind, name| name }
  stale = checked.keys.reject { |name| listed.include?(name) }.sort
  puts "Triaged but no longer listed, to drop (a file names them now, or no dump has them): #{stale.length}"
  stale.each { |name| puts "- #{name}" }
end
