# What a game changes in Ruby's own classes (Array, Hash, String, NilClass...), taken from its scripts, and the suite
# run under it. Utility scripts like Marin's or Luka's redefine core methods (an in-place Array#+, a has_key? false
# for nil values, an Array#to_hash that Hash[] picks up), and the mod runs on top of them in that game only.
#   ruby tools/game_overrides.rb <scripts folder>                # lists each redefined core method
#   ruby tools/game_overrides.rb <scripts folder> --run [filter] # runs the suite with them applied to the mod
#   ruby tools/game_overrides.rb <scripts folder> --write out.rb  # writes the preload (RUBYOPT=-rout.rb)
# The scripts folder holds the game's scripts as .rb files (tools/dump_scripts.rb writes one). Under --run, a
# redefined method answers the game's way only when the mod's own code (core/, games/, plugins/) calls it, so the
# test framework and the stubs keep Ruby's behavior.
require "prism"
require "tmpdir"

ROOT = File.expand_path("..", File.dirname(__FILE__))
CORE = %w[Object Kernel BasicObject Module Class Comparable Enumerable Array Hash String Symbol Integer Fixnum Bignum
          Numeric Float NilClass TrueClass FalseClass Range Struct Proc Regexp MatchData Time].freeze

def const_name(node)
  case node
  when Prism::ConstantReadNode then node.name.to_s
  when Prism::ConstantPathNode then node.parent.nil? ? node.name.to_s : nil
  end
end

# Every core class body of the scripts: [class name, [def nodes with their source], file].
def redefinitions(dir)
  out = []
  Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |f|
    src = File.binread(f).force_encoding("UTF-8")
    src = src.encode("UTF-8", "binary", :invalid => :replace, :undef => :replace) unless src.valid_encoding?
    stack = [Prism.parse(src).value]
    until stack.empty?
      n = stack.pop
      if (n.is_a?(Prism::ClassNode) || n.is_a?(Prism::ModuleNode)) && CORE.include?(const_name(n.constant_path))
        body = n.body ? n.body.body : []
        defs = body.select { |d| d.is_a?(Prism::DefNode) && d.receiver.nil? }
        aliases = body.select { |d| d.is_a?(Prism::AliasMethodNode) }
        out << [const_name(n.constant_path), defs, aliases, File.basename(f)] unless defs.empty? && aliases.empty?
        next
      end
      stack.concat(n.compact_child_nodes) unless n.is_a?(Prism::DefNode)
    end
  end
  out
end

# A method's source with its name changed to name.
def renamed(defn, name)
  src = defn.slice
  head = defn.name_loc.start_offset - defn.location.start_offset
  src.byteslice(0, head) + name + src.byteslice(head + defn.name_loc.length, src.bytesize)
end

# The preload: each redefined method dispatches to the game's body when the mod calls it, to Ruby's otherwise. On
# Object, Kernel, Module and Class only Ruby's own methods are taken (the rest is the game's API, which the stubs
# stand in for); Fixnum and Bignum, gone from modern Ruby, are taken as Integer. A body this Ruby cannot parse is
# left out and named.
def preload(found, skipped)
  only_native = %w[Object Kernel Module Class BasicObject]
  lines = ['MOD_SITE = %r{[/\\\\](core|games|plugins)[/\\\\][^:]*\.rb}']
  found.each do |klass, defs, aliases, file|
    klass = "Integer" if klass == "Fixnum" || klass == "Bignum"
    kind = %w[Kernel Comparable Enumerable].include?(klass) ? "module" : "class"
    lines << "# #{file}" << "#{kind} ::#{klass}"
    defs.each do |d|
      name = d.name.to_s
      safe = name.gsub("?", "_q").gsub("!", "_b").gsub("=", "_e").gsub(/[^A-Za-z0-9_]/) { |c| "_#{c.ord}" }
      body = renamed(d, "__pa_game_#{safe}")
      unless Prism.parse(body).errors.empty?
        skipped << "#{klass}##{name} (#{file})"
        next
      end
      sym = name.to_sym.inspect
      native = "method_defined?(#{sym}) || private_method_defined?(#{sym})"
      lines << "  if #{native}" if only_native.include?(klass)
      lines << body
      lines << "  if #{native}"
      lines << "    alias_method :__pa_ruby_#{safe}, #{sym}"
      lines << "    define_method(#{sym}) do |*a, &b|"
      lines << "      loc = caller_locations(1, 1)[0]"
      lines << "      loc && loc.path =~ MOD_SITE ? __pa_game_#{safe}(*a, &b) : __pa_ruby_#{safe}(*a, &b)"
      lines << "    end"
      lines << "  else"
      lines << "    alias_method #{sym}, :__pa_game_#{safe}"
      lines << "  end"
      lines << "  end" if only_native.include?(klass)
    end
    aliases.each { |a| lines << "  (#{a.slice} rescue nil)" } unless only_native.include?(klass)
    lines << "end"
  end
  lines.join("\n") + "\n"
end

# Each redefined core class with the methods the scripts give it, one line per class body.
def summary_lines(found)
  found.map do |klass, defs, aliases, file|
    names = defs.map { |d| d.name.to_s } + aliases.map { |a| a.new_name.slice.sub(/\A:/, "") }
    "#{klass} (#{file}): #{names.join(', ')}"
  end
end

if __FILE__ == $PROGRAM_NAME
  dir = ARGV[0]
  abort "usage: ruby tools/game_overrides.rb <scripts folder> [--run [filter]]" unless dir && File.directory?(dir)
  found = redefinitions(dir)
  puts summary_lines(found)
  if (w = ARGV.index("--write"))
    skipped = []
    File.binwrite(ARGV[w + 1], preload(found, skipped))
    puts "wrote #{ARGV[w + 1]}#{skipped.empty? ? '' : "; left out: #{skipped.join(', ')}"}"
  end
  exit 0 unless ARGV.include?("--run")

  filter = ARGV[ARGV.index("--run") + 1]
  Dir.mktmpdir("pa-overrides") do |tmp|
    path = File.join(tmp, "game_overrides.rb")
    skipped = []
    File.binwrite(path, preload(found, skipped))
    puts "left out (unparsable here): #{skipped.join(', ')}" unless skipped.empty?
    bad = `ruby -c "#{path}" 2>&1`
    abort "the preload does not parse (a game method in Ruby older than this one?):\n#{bad}" unless $?.success?
    env = { "RUBYOPT" => "-r#{path.tr('\\', '/')}" }
    ok = system(env, "ruby", File.join(ROOT, "test", "run_all.rb"), *[filter].compact)
    exit(ok ? 0 : 1)
  end
end
