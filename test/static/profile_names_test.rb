# The first define a profile's own modules run (Game.define or a core wrapper of it) names the profile, and the files
# signed with that name: it names the profile's folder, while every define of a common names the common.
class ProfileNamesTest < PokeAccessTest
  NAMERS = %w[Game SpriteButtonMenu LocationBanner].freeze
  DEFINE = /\b(?:#{NAMERS.join('|')})\.define\("([^"]+)"/

  test "names every profile after its own folder and every common after itself" do
    profiles = profile_sources
    named = profiles.count { |_game, sources| sources.any? { |s| s =~ DEFINE } }
    defines = profiles.map { |_game, sources| sources.map { |s| s.scan(DEFINE).length } }.flatten.inject(0, :+)
    assert_operator named, :>=, 20, "the sweep read the profiles"
    assert_operator defines, :>, 250, "and every module of theirs"
    assert_equal [], misnamed(profiles)
  end

  test "flags a profile whose first define names another folder" do
    assert_equal ["royal: anil"], misnamed([["royal", [define("Game", "anil"), define("Game", "royal")]]])
  end

  test "takes the first define across the modules in load order, whichever namer runs it" do
    {
      [define("SpriteButtonMenu", "anil"), define("Game", "royal")] => ["royal: anil"],
      [define("LocationBanner", "anil"), define("Game", "royal")] => ["royal: anil"],
      ["x = 1", define("Game", "royal"), define("Game", "anil")] => [],
      ["#{define('Game', 'royal')}\n#{define('Game', 'anil')}"] => []
    }.each { |sources, want| assert_equal want, misnamed([["royal", sources]]), "for #{sources.inspect}" }
  end

  test "lets a profile none of whose modules define a name pass" do
    assert_equal [], misnamed([["generic", ["x = 1"]]])
  end

  test "flags a common with a define of any other name, each name once" do
    sources = [define("Game", "rv_common"), define("Game", "reborn"), define("Game", "rejuvenation"),
               define("Game", "reborn")]
    assert_equal ["rv_common: reborn, rejuvenation"], misnamed([["rv_common", sources]])
  end

  test "lets a common name itself as often as it defines" do
    assert_equal [], misnamed([["rv_common", [define("Game", "rv_common"), define("SpriteButtonMenu", "rv_common")]]])
  end

  test "knows every core wrapper that hands its define name on to Game.define" do
    assert_equal NAMERS.sort, (["Game"] + core_namers).sort
  end

  private

  # A module source whose define, made through namer, names name.
  def define(namer, name)
    "PokeAccess::#{namer}.define(\"#{name}\") do\nend"
  end

  # [folder, [each module's source, in load order]] of every games/*/manifest.rb.
  def profile_sources
    Dir.glob(File.join(Harness::ROOT, "games", "*", "manifest.rb")).sort.map do |mf|
      dir = File.dirname(mf)
      value = eval(Harness.source(mf), TOPLEVEL_BINDING, mf)
      mods = value.is_a?(Hash) ? value[:modules] : value
      paths = Array(mods).map { |m| File.join(dir, "#{m}.rb") }.select { |p| File.file?(p) }
      [File.basename(dir), paths.map { |p| Harness.source(p) }]
    end
  end

  # "folder: name" of each profile whose first define names another folder, and "folder: names" of each common with
  # defines of other names.
  def misnamed(profiles)
    profiles.map do |game, sources|
      names = sources.map { |s| s.scan(DEFINE).flatten }.flatten
      if game =~ /_common\z/
        others = names.uniq - [game]
        "#{game}: #{others.join(', ')}" unless others.empty?
      elsif !names.empty? && names.first != game
        "#{game}: #{names.first}"
      end
    end.compact
  end

  # The core modules whose define(name) passes its name straight to Game.define.
  def core_namers
    Dir.glob(File.join(Harness::ROOT, "core", "**", "*.rb")).sort.map do |f|
      src = Harness.source(f)
      at = src =~ /def self\.define\((\w+)[^)]*\)\s*\n\s*PokeAccess::Game\.define\(\1\)/
      at && src[0, at].scan(/^\s*module (\w+)/).flatten.last
    end.compact
  end
end
