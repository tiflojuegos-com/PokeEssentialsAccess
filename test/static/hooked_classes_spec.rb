# Every class the mod hooks by name exists in at least one surveyed game.
#
# A hook is attached with a STRING, so a typo is not a NameError -- it binds nothing, logs nothing and the
# screen is simply silent. Nothing saw that: coupling_spec crosses names against the EXCLUSIVE census, so a
# name defined by zero games has no row and is skipped; the loop census only knows after-style sites, which
# is 198 of 260 registrations. Probed with three real typos at once (a before_hook, a SceneWatcher.reader
# and a def_extractor) and the suite stayed at 0 fail.
#
# Deliberately NOT a check that the METHOD exists too: cross-game method variance is the norm here and
# :optional exists for it, so the method question belongs to the census that already asks it per game. This
# one asks the cheaper question that has exactly one right answer -- does anything, anywhere, answer to this
# name at all?
Suite.define("static: every class the mod hooks by name exists in some game") do
  root = File.expand_path("../..", File.dirname(__FILE__))

  census = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "all_classes.txt")) { |k, v| census[k] = v.to_i }
  truthy "the class census loaded (#{census.length})", census.length > 2000

  # The registration shapes that take a class name as a literal string. scene_classes takes several at once.
  FORMS = [
    /\b(?:after|before|around)(?:_hook)?\(\s*"([A-Z][A-Za-z0-9_:]*)"/,
    /\bdef_extractor\(\s*"([A-Z][A-Za-z0-9_:]*)"/,
    /\b(?:reader|wire|screen_reader|override)\(\s*"([A-Z][A-Za-z0-9_:]*)"/
  ]
  MULTI = /\bscene_classes\(([^)]*)\)/

  seen = {}
  %w[core games plugins].each do |dir|
    Dir.glob(File.join(root, dir, "**", "*.rb")).sort.each do |f|
      src = File.read(f).gsub(/^\s*#.*/, "")
      rel = f.sub(root + "/", "").sub(root + "\\", "")
      FORMS.each { |re| src.scan(re) { |m| (seen[m[0]] ||= []).push(rel) } }
      src.scan(MULTI) do |m|
        m[0].scan(/"([A-Z][A-Za-z0-9_:]*)"/) { |c| (seen[c[0]] ||= []).push(rel) }
      end
    end
  end
  truthy "hooked class names found (#{seen.length})", seen.length > 80

  # The last segment is what a decompiled `class` line carries, so that is what the census is keyed by.
  ghosts = seen.keys.sort.reject { |c| census[c.split("::").last] }
  eq "no hook names a class no game defines", ghosts.map { |c| "#{c} (#{seen[c].uniq.first})" }, []
end

# The committed censuses were built from all fourteen sources.
#
# Regenerate from a tree without the sibling pokemon-essentials clone and the generators do not complain:
# they just survey thirteen and write a thinner file, and every check that reads it gets quieter without
# saying so. It happened during an audit -- no-dump rows went from 4 to 15 and only a tight ceiling caught
# it. Three of the files already stamp the source count in their header and nobody read it; loop_census now
# stamps one too.
Suite.define("static: every census was built from all fourteen sources") do
  dir = File.dirname(__FILE__)
  wrong = []
  %w[ivar_census.txt fangame_classes.txt plugin_census.txt all_classes.txt loop_census.txt].each do |f|
    head = File.read(File.join(dir, f)).split("\n").select { |l| l =~ /\A#/ }.join(" ")
    n = (head[/surveyed (?:profiles|games|sources) \((\d+)\)/, 1] || "none").to_s
    wrong.push("#{f}: #{n}") unless n == "14"
  end
  eq "each census header says 14", wrong, []
end
