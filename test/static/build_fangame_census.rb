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
owners = {}
games.each do |g|
  Dir.glob(File.join(dumps, g, "**", "*.rb")).each do |f|
    from_plugin = f.tr("\\", "/").include?("/_PluginScripts/")
    File.open(f, "rb") do |io|
      io.each_line do |line|
        next unless line =~ /^\s*(?:class|module)\s+([A-Z][A-Za-z0-9_]*)/
        rec = (owners[$1] ||= { :games => {}, :plugin => 0, :script => 0 })
        rec[:games][g] = true
        from_plugin ? rec[:plugin] += 1 : rec[:script] += 1
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
