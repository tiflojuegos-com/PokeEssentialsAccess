# Every class the mod hooks by name (a string, so a typo binds nothing silently) exists in at least one surveyed game
# (all_classes.txt) or in a reference copy of a plugin no surveyed game ships (reference_census.txt), whether the
# method exists being left to the per-game censuses; and every census was built from all the surveyed sources.
require File.expand_path("reference_names", File.dirname(__FILE__))

class HookedClassesTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  DIR = File.dirname(__FILE__)
  SOURCES = 28
  CENSUSES = %w[ivar_census.txt fangame_classes.txt plugin_census.txt all_classes.txt loop_census.txt
                arity_census.txt].freeze
  # The registration shapes that take a class name as a literal string; scene_classes takes several at once.
  FORMS = [
    /\b(?:after|before|around)(?:_hook)?\(\s*"([A-Z][A-Za-z0-9_:]*)"/,
    /\bdef_extractor\(\s*"([A-Z][A-Za-z0-9_:]*)"/,
    /\b(?:reader|wire|screen_reader|override)\(\s*"([A-Z][A-Za-z0-9_:]*)"/
  ].freeze
  MULTI = /\bscene_classes\(([^)]*)\)/

  test "hooks no class that no surveyed game or reference copy defines" do
    census = class_census
    assert_operator census.length, :>, 2000, "the class census loaded"
    tree = %w[core games plugins].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort.map do |f|
      [f.sub(ROOT + "/", ""), File.read(f)]
    end
    seen = hooked_names(tree)
    assert_operator seen.length, :>, 80, "the scan found the hooked class names"
    assert_equal [], ghosts(seen, own_modules(tree), census), "no hook names a class no source defines"
  end

  test "reports a hooked class no source defines, with the first file that hooks it" do
    tree = [["core/a.rb", "PokeAccess::Hooks.after_hook(\"PlantedGhostScene\", :pbStartScene) do |s, r, a|\nend\n"],
            ["games/x/b.rb", "override(\"PlantedGhostScene\", :pbEndScene)\n"]]
    assert_equal ["PlantedGhostScene (core/a.rb)"], ghosts(hooked_names(tree), {}, { "PokemonBag_Scene" => 3 })
  end

  test "reads the class of every registration shape, all of scene_classes' and none in a comment" do
    src = ['after("A1", :x)', 'before_hook("A2", :x)', 'around_hook("A3", :x)', 'def_extractor("A4", :x)',
           'reader("A5")', 'wire("A6", :x)', 'screen_reader("A7")', 'override("A8", :x)',
           'PokeAccess::Engine.scene_classes("A9", "A10")', '  # after("Commented", :x)', 'after(cname, :x)']
    assert_equal %w[A1 A10 A2 A3 A4 A5 A6 A7 A8 A9], hooked_names([["core/a.rb", src.join("\n")]]).keys.sort
  end

  test "takes a class some game defines by its last name segment, and a reference copy's class" do
    tree = [["core/a.rb", "after(\"Battle::Scene\", :pbStartBattle)\nafter(\"ActionData\", :refresh)\n"]]
    assert ReferenceNames.class?("ActionData"), "a class of a reference copy"
    assert_equal [], ghosts(hooked_names(tree), {}, { "Scene" => 12 })
  end

  test "takes a PokeAccess class the mod defines, and reports one it does not" do
    tree = [["core/a.rb", "module PlantedOwnPanel\nend\nafter(\"PokeAccess::Hooks\", :x)\n" \
                          "after(\"PokeAccess::PlantedOwnPanel\", :x)\nafter(\"PokeAccess::PlantedNoPanel\", :x)\n"]]
    assert_equal ["PokeAccess::PlantedNoPanel (core/a.rb)"], ghosts(hooked_names(tree), own_modules(tree), {})
  end

  test "every census was built from all twenty-eight sources" do
    counts = CENSUSES.map { |f| [f, surveyed(File.read(File.join(DIR, f)))] }
    assert_equal [], counts.reject { |_f, n| n == SOURCES.to_s }.map { |f, n| "#{f}: #{n}" }
  end

  test "reads a census's surveyed count from its header, under each name it gives its sources" do
    { "# surveyed sources (22): a, b" => "22", "# x\n# surveyed games (23): a" => "23",
      "# surveyed profiles (23): a" => "23", "# reference sources (85): a" => "none",
      "A = 1\n" => "none" }.each do |text, n|
      assert_equal n, surveyed(text), "for #{text.inspect}"
    end
  end

  private

  # { class name => sources defining it } from all_classes.txt.
  def class_census
    out = {}
    PokeAccess::KVFile.each(File.join(DIR, "all_classes.txt")) { |k, v| out[k] = v.to_i }
    out
  end

  # { class name => [path, ...] } the [path, text] sources hook by a literal name, full-line comments aside.
  def hooked_names(sources)
    seen = {}
    sources.each do |path, text|
      src = text.gsub(/^\s*#.*/, "")
      FORMS.each { |re| src.scan(re) { |m| (seen[m[0]] ||= []).push(path) } }
      src.scan(MULTI) { |m| m[0].scan(/"([A-Z][A-Za-z0-9_:]*)"/) { |c| (seen[c[0]] ||= []).push(path) } }
    end
    seen
  end

  # { module name => true } for each module the [path, text] sources define.
  def own_modules(sources)
    own = {}
    sources.each do |_path, text|
      text.gsub(/^\s*#.*/, "").scan(/^\s*module ([A-Z][A-Za-z0-9_]*)/) { |m| own[m[0]] = true }
    end
    own
  end

  # "Class (first path)" for each hooked name nothing defines: a PokeAccess:: name the loaded mod or its own modules
  # answer to, any other the census (by its last segment) or a reference copy.
  def ghosts(seen, own, census)
    missing = seen.keys.sort.reject do |c|
      if c.index("PokeAccess::") == 0
        PokeAccess.const_at(c) || own[c.split("::").last]
      else
        census[c.split("::").last] || ReferenceNames.class?(c)
      end
    end
    missing.map { |c| "#{c} (#{seen[c].uniq.first})" }
  end

  # The source count a census header gives ("surveyed sources|games|profiles (N)"), or "none".
  def surveyed(text)
    head = text.split("\n").select { |l| l =~ /\A#/ }.join(" ")
    head[/surveyed (?:profiles|games|sources) \((\d+)\)/, 1] || "none"
  end
end
