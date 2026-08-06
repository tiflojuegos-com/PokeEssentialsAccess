# Regenerates test/static/fangame_classes.txt, the census coupling_spec uses to tell a vanilla Essentials
# class from one that belongs to a single fangame. NOT a spec (no _spec suffix, so the runner ignores it):
# it reads the decompiled script dumps, which live OUTSIDE the repo and are absent on CI, which is exactly
# why the census is a committed file instead of a live scan -- a check that quietly disappears when its
# input is missing is the hole this whole block is closing.
# Run by hand after adding or refreshing a dump:
#   ruby test/static/build_fangame_census.rb ["path\to\decompiled Scripts"]
# Only names defined in EXACTLY ONE surveyed game are written: those are the ones core/ must not know
# about. A name defined in two or more games is a shared/third-party class and its treatment is the open
# doctrine question (PENDIENTE 6.4), not something to decide from here.
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

# Read binary: the dumps carry Latin-1 accents in comments, and a UTF-8 String would raise on the match.
# Each name records its games and whether it ever came from a _PluginScripts/ folder: "only in royal" and
# "only in royal, and only because royal installs that third-party plugin" call for different fixes (move
# the reader to games/royal/ vs. move it to plugins/), so the census says which it is.
# Methods are collected alongside classes, qualified as "Class#method", for the detection probes that name
# one. A plugin does not always bring a class: the multi-save one only REOPENS the engine's save scene, so
# the only thing that gives it away is a method appearing there. Qualifying by the enclosing class matters --
# a bare method name like `main` says nothing.
#
# The enclosing class is the last class/module line seen, PLUS an indent test: a def indented no deeper than
# its supposed class line is outside that class's body. Without it, every top-level function after the first
# class in a file was filed under that class, which across these dumps invented thousands of Class#method
# pairs that do not exist -- harmless while no probe happened to name one, and a silent wrong answer the day
# one did. Tracking indentation is not a full parser, but it is what separates "inside the body" from "after
# the end" in every dump here, and unlike a name-only rule it fails closed: an unusual layout drops a real
# method rather than inventing a false one, and a dropped probe fails its check loudly.
owners = {}
meth_owners = {}
games.each do |g|
  Dir.glob(File.join(dumps, g, "**", "*.rb")).each do |f|
    from_plugin = f.tr("\\", "/").include?("/_PluginScripts/")
    cur = nil
    cur_indent = nil
    File.open(f, "rb") do |io|
      io.each_line do |line|
        if line =~ /^(\s*)(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/
          cur_indent = $1.length
          cur = $2.split("::").last
          rec = (owners[cur] ||= { :games => {}, :plugin => 0, :script => 0 })
          rec[:games][g] = true
          from_plugin ? rec[:plugin] += 1 : rec[:script] += 1
        elsif cur && line =~ /^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_]*[?!]?)/
          ((meth_owners["#{cur}##{$2}"] ||= {}))[g] = true if $1.length > cur_indent
        end
      end
    end
  end
end

exclusive = {}
owners.each do |name, rec|
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

# --- second census: which PROFILE ships each plugin, so a forgotten declaration cannot stay silent.
#
# Moving a reader from core/ to plugins/ trades one risk for another. In core it ran everywhere, right or
# wrong; in plugins/ it runs only where a profile declares it, and forgetting a declaration costs that game
# the screen -- no error, no missing hook, nothing but a line in the diagnostic that helps only if somebody
# reads a recording. This census lets a spec check the declarations against the dumps instead.
#
# Keyed by the DETECTION CLASS rather than the plugin name: the class is what the dumps contain, and the
# name a plugin has in our table is ours to change.
PROFILE_OF = { "africanvs" => "africanus", "z218" => "pokemon_z" }
PLUGIN_OUT = File.join(File.dirname(__FILE__), "plugin_census.txt")
mod_root = File.expand_path("../..", File.dirname(__FILE__))
# eval, not a parser: the manifest is a Ruby literal committed in THIS repo and is read here exactly as
# loader/boot.rb reads it at runtime, because RGSS ships no JSON. No external input reaches it, and this
# generator runs by hand on a developer machine, never in the game.
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
