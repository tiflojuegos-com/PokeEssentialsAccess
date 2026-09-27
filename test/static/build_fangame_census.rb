# Builds fangame_classes.txt (names one fangame alone defines, for coupling_spec), plugin_census.txt (plugins_spec)
# and all_classes.txt (hooked_classes_spec) from the decompiled dumps, which are absent on CI. Run by hand after
# adding or refreshing a dump: ruby test/static/build_fangame_census.rb ["path\to\decompiled Scripts"]
require File.expand_path("reader_sites", File.dirname(__FILE__))

DEFAULT_DUMPS = File.expand_path("../../../../decompiled Scripts", File.dirname(__FILE__))
OUT = File.join(File.dirname(__FILE__), "fangame_classes.txt")

dumps = ARGV[0] || ENV["PA_DUMPS"] || DEFAULT_DUMPS
unless File.directory?(dumps)
  puts "dumps folder not found: #{dumps}"
  puts "usage: ruby test/static/build_fangame_census.rb [path-to-decompiled-Scripts]"
  exit 1
end

games = Dir.glob(File.join(dumps, "*")).select { |d| File.directory?(d) }.map { |d| File.basename(d) }.sort
if games.empty?
  puts "no game folders under #{dumps}"
  exit 1
end

# Vanilla Essentials counts as a source: a name upstream defines is not one fangame's, even if only one backports it.
VANILLA = File.expand_path("../../../../pokemon-essentials/Data/Scripts", File.dirname(__FILE__))
vanilla = ENV["PA_VANILLA"] || VANILLA
sources_of = {}
games.each { |g| sources_of[g] = File.join(dumps, g) }
if File.directory?(vanilla)
  games = (games + ["vanilla"]).sort
  sources_of["vanilla"] = vanilla
else
  puts "note: vanilla Essentials tree not found at #{vanilla}"
end

# Read binary (the dumps carry Latin-1 in comments). Each class records its games and whether it came from a
# _PluginScripts/ folder; methods and attr_reader/accessor names are recorded as "Class#method" for the probes that
# name one, the owner by indentation; a def at column 0 is also recorded as "Object#name", the owner of a top-level
# function; =begin/=end blocks are skipped.
owners = {}
meth_owners = {}
games.each do |g|
  Dir.glob(File.join(sources_of[g], "**", "*.rb")).each do |f|
    from_plugin = f.tr("\\", "/").include?("/_PluginScripts/")
    stack = ReaderSites::ClassStack.new
    in_comment = false
    File.open(f, "rb") do |io|
      io.each_line do |line|
        if in_comment
          in_comment = false if line =~ /^=end\b/
          next
        end
        if line =~ /^=begin\b/
          in_comment = true
          next
        end
        if line =~ /^(\s*)(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/
          cur = stack.feed(line)
          rec = (owners[cur] ||= { :games => {}, :plugin => 0, :script => 0 })
          rec[:games][g] = true
          from_plugin ? rec[:plugin] += 1 : rec[:script] += 1
        else
          cur = stack.feed(line)
          ((meth_owners["Object##{$1}"] ||= {}))[g] = true if line =~ /^def\s+([a-z_][A-Za-z0-9_]*[?!]?)(?=[\s(;]|\z)/
          next unless cur
          if (m = line.match(/^(\s*)attr_(?:reader|accessor)\s+(.+)/))
            owner = stack.owner_at(m[1].length) || cur
            m[2].scan(/:([a-zA-Z_][A-Za-z0-9_]*[?!]?)/) { |a| ((meth_owners["#{owner}##{a[0]}"] ||= {}))[g] = true }
            next
          end
          next unless line =~ /^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_]*[?!]?)/
          owner = stack.owner_at($1.length) || cur
          ((meth_owners["#{owner}##{$2}"] ||= {}))[g] = true
        end
      end
    end
  end
end

# Exclusive means one fangame alone: a name vanilla defines is engine, never exclusive.
exclusive = {}
owners.each do |name, rec|
  next if rec[:games]["vanilla"]
  next unless rec[:games].length == 1
  origin = rec[:plugin] > 0 ? (rec[:script] > 0 ? "script+plugin" : "plugin") : "script"
  exclusive[name] = "#{rec[:games].keys[0]}, #{origin}"
end

File.open(OUT, "wb") do |io|
  io.print("# Census of fangame-EXCLUSIVE class names: each name is defined by exactly one of the surveyed\n")
  io.print("# script dumps, so a core/ file naming it is coupled to that one game. Read by coupling_spec;\n")
  io.print("# regenerate with test/static/build_fangame_census.rb (see its header). Do not edit by hand.\n")
  io.print("# format: <ClassName> = <game>, <plugin|script>  -- plugin means it arrived in that game's\n")
  io.print("# _PluginScripts/, i.e. it is a third-party class only this game installs, not a class of the game.\n")
  io.print("# surveyed games (#{games.length}): #{games.join(', ')}\n")
  io.print("# names seen: #{owners.length} / exclusive: #{exclusive.length}\n")
  exclusive.keys.sort.each { |name| io.print("#{name} = #{exclusive[name]}\n") }
end

puts "wrote #{OUT}: #{exclusive.length} exclusive names out of #{owners.length}, from #{games.length} games"

# Second census: which profiles ship each plugin, keyed by its detection probe (what the dumps contain), for
# plugins_spec to check the declarations against.
PROFILE_OF = ReaderSites::PROFILE_OF
PLUGIN_OUT = File.join(File.dirname(__FILE__), "plugin_census.txt")
mod_root = File.expand_path("../..", File.dirname(__FILE__))
# eval, as loader/boot.rb reads it: the manifest is a Ruby literal committed in this repo.
table = eval(File.read(File.join(mod_root, "plugins", "manifest.rb")))

rows = {}
table.each_value do |probe|
  p = probe.to_s
  if p.include?("#")
    cls, meth = p.split("#")
    key = "#{cls.split('::').last}##{meth}"
    next if rows.key?(key)
    rec = meth_owners[key]
    rows[key] = rec ? rec.keys.map { |g| PROFILE_OF[g] || g }.sort : []
  else
    key = p.split("::").last
    next if rows.key?(key)
    rec = owners[key]
    rows[key] = rec ? rec[:games].keys.map { |g| PROFILE_OF[g] || g }.sort : []
  end
end

File.open(PLUGIN_OUT, "wb") do |io|
  io.print("# Census of the classes that give a third-party plugin away: which surveyed games ship each one,\n")
  io.print("# by PROFILE name. Read by plugins_spec to check that every profile declaring a plugin has it and\n")
  io.print("# every profile having one declares it -- a forgotten declaration is a silent screen, and that is\n")
  io.print("# the failure this whole layer trades for. Regenerate with build_fangame_census.rb after adding a\n")
  io.print("# plugin or refreshing a dump. Do not edit by hand.\n")
  io.print("# format: <DetectionProbe> = <profile>, <profile>...   (empty = no surveyed game ships it)\n")
  io.print("# A probe is a class name, or Class#method for a plugin that brings no class of its own and is\n")
  io.print("# only given away by a method it adds to one the engine already has.\n")
  io.print("# surveyed profiles (#{games.length}): #{games.map { |g| PROFILE_OF[g] || g }.sort.join(', ')}\n")
  rows.keys.sort.each { |cls| io.print("#{cls} = #{rows[cls].join(', ')}\n") }
end

puts "wrote #{PLUGIN_OUT}: #{rows.length} detection classes"

# Third census: every class name any source defines, so a hooked class no game defines (a typo) is caught.
ALL_OUT = File.join(File.dirname(__FILE__), "all_classes.txt")
File.open(ALL_OUT, "wb") do |io|
  io.print("# GENERATED by test/static/build_fangame_census.rb -- do not edit by hand.\n")
  io.print("#\n")
  io.print("# Every class or module name defined by any surveyed source, with how many define it. Read by\n")
  io.print("# hooked_classes_spec: a class name the mod hooks by string must appear here, or it is a name\n")
  io.print("# nothing in any game answers to.\n")
  io.print("# surveyed sources (#{games.length}): #{games.map { |g| PROFILE_OF[g] || g }.sort.join(', ')}\n")
  io.print("# format: <ClassName> = <how many sources define it>\n")
  owners.keys.sort.each { |cls| io.print("#{cls} = #{owners[cls][:games].length}\n") }
end
puts "wrote #{ALL_OUT}: #{owners.length} class names"
