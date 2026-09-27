# Every class the mod hooks by name (a string, so a typo binds nothing silently) exists in at least one surveyed
# game, per all_classes.txt; whether the method exists is left to the per-game censuses.
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
  own = {}
  %w[core games plugins].each do |dir|
    Dir.glob(File.join(root, dir, "**", "*.rb")).sort.each do |f|
      src = File.read(f).gsub(/^\s*#.*/, "")
      src.scan(/^\s*module ([A-Z][A-Za-z0-9_]*)/) { |m| own[m[0]] = true }
      rel = f.sub(root + "/", "").sub(root + "\\", "")
      FORMS.each { |re| src.scan(re) { |m| (seen[m[0]] ||= []).push(rel) } }
      src.scan(MULTI) do |m|
        m[0].scan(/"([A-Z][A-Za-z0-9_:]*)"/) { |c| (seen[c[0]] ||= []).push(rel) }
      end
    end
  end
  truthy "hooked class names found (#{seen.length})", seen.length > 80

  ghosts = seen.keys.sort.reject do |c|
    c.index("PokeAccess::") == 0 ? (PokeAccess.const_at(c) || own[c.split("::").last]) : census[c.split("::").last]
  end
  eq "no hook names a class no game defines", ghosts.map { |c| "#{c} (#{seen[c].uniq.first})" }, []
end

# Every committed census was built from all twenty-two sources (a run without the vanilla tree, or without the loose
# scripts of Reborn, Rejuvenation and Desolation or the Insurgence, Uranium and Soulstones dumps copied into
# decompiled Scripts, surveys fewer, silently).
Suite.define("static: every census was built from all twenty-two sources") do
  dir = File.dirname(__FILE__)
  wrong = []
  %w[ivar_census.txt fangame_classes.txt plugin_census.txt all_classes.txt loop_census.txt
     arity_census.txt].each do |f|
    head = File.read(File.join(dir, f)).split("\n").select { |l| l =~ /\A#/ }.join(" ")
    n = (head[/surveyed (?:profiles|games|sources) \((\d+)\)/, 1] || "none").to_s
    wrong.push("#{f}: #{n}") unless n == "22"
  end
  eq "each census header says 22", wrong, []
end
