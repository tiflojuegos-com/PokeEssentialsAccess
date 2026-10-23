# Text Sevii paints only in pictures, said from transcriptions: the title card before the title screen (intro1, in
# games/sevii/constants.rb), the load screen's background and the credits roll (games/sevii/pictures.rb).

# Sevii's load screen: pbStartScene draws the background and builds the panels.
class SeviiLoadStandIn
  def pbStartScene(_commands, _show_continue, _trainer, _framecount, _mapid); :built; end
end

# Sevii's credits scene: a user sprite of the map, updated every frame, whose roll rises and whose THE END pictures
# come up once the roll is over.
class SeviiCreditsStandIn
  attr_reader :sprites
  def initialize(y = 384); @sprites = { "credits" => SeviiRollSprite.new(y) }; end
  def update; :updated; end
end

# A sprite as the credits scene keeps it: where it stands and whether it is gone.
class SeviiRollSprite
  attr_accessor :y
  def initialize(y); @y = y; @disposed = false; end
  def disposed?; @disposed; end
  def dispose; @disposed = true; end
end

class SeviiPicturesTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "pictures.rb")
  CONSTANTS = File.join(Harness::ROOT, "games", "sevii", "constants.rb")
  # The scene classes pictures.rb hooks, bound afresh for each test.
  SCENES = { "PokemonLoadScene" => SeviiLoadStandIn, "HGSS_CreditsScene" => SeviiCreditsStandIn }
  BETA_TESTERS = "Beta Testers: TechSkylander1518, Fst, AlolanIvysaur, Foxowl, NocTurn, Brysoon, madmanjr, Trillzys, " \
                 "ADP9295"

  test "the title card before the title screen is said from its transcription, queued" do
    with_constants { PokeAccess::TitleScreen.splash(["intro1"]) }
    assert_equal [["Pokémon HGSS: Sevii Islands by PurpleZaffre. a Pokémon Fan Game", false]], SpeakCapture.log
  end

  test "the load screen says the title and the version its background paints, queued, as it opens" do
    with_pictures do
      assert_equal :built, PokemonLoadScene.new.pbStartScene([], false, nil, 0, 1), "the screen is built as it would"
    end
    assert_equal [["Pokémon HGSS: Sevii Islands. Version: Final 1.2.0", false]], SpeakCapture.log
  end

  test "the credits say nothing before the roll comes into view" do
    with_pictures { assert_equal :updated, HGSS_CreditsScene.new.update, "the frame runs as it would" }
    assert_nothing_spoken
  end

  test "the credits say each block of the roll, queued, as its first line comes into view" do
    with_pictures do
      credits = HGSS_CreditsScene.new(313)
      credits.update
      assert_equal [["Pokémon HGSS: Sevii Islands", false]], SpeakCapture.log
      SpeakCapture.clear
      credits.sprites["credits"].y = -103
      credits.update
    end
    assert_equal [["CREDITS", false], ["PurpleZaffre - Creator (FaperJr on PokéCommunity)", false],
                  [BETA_TESTERS, false]], SpeakCapture.log
  end

  test "the credits say a block once, however long it stays in view" do
    with_pictures do
      credits = HGSS_CreditsScene.new(313)
      3.times { credits.update }
    end
    assert_equal [["Pokémon HGSS: Sevii Islands", false]], SpeakCapture.log
  end

  test "a block reads its title, then each heading running into the names under it" do
    with_pictures do
      credits = HGSS_CreditsScene.new(-103)
      credits.update
      SpeakCapture.clear
      credits.sprites["credits"].y = -391
      credits.update
    end
    assert_equal [["Mega Johto Starters. Sprites and Concept: KajiAtsui. Sprite Animations: Antiant", false]],
                 SpeakCapture.log
  end

  test "the credits say THE END once, queued, as it comes up after the roll" do
    with_pictures do
      credits = HGSS_CreditsScene.new(-13442)
      credits.update
      SpeakCapture.clear
      credits.sprites["End"] = Object.new
      2.times { credits.update }
    end
    assert_equal [["THE END", false]], SpeakCapture.log
  end

  test "a roll that is gone says nothing" do
    with_pictures do
      credits = HGSS_CreditsScene.new(313)
      credits.sprites["credits"].dispose
      credits.update
    end
    assert_nothing_spoken
  end

  private

  # Runs the block with constants.rb evaluated, then puts back the transcriptions, the rule on surfing with company and
  # the profile list it changed.
  def with_constants
    texts = PokeAccess::PictureCues::TEXTS.dup
    company = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(CONSTANTS), TOPLEVEL_BINDING, CONSTANTS)
    yield
  ensure
    PokeAccess::PictureCues::TEXTS.replace(texts)
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, company)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end

  # Runs the block with a fresh subclass of each stand-in under its game name and pictures.rb evaluated over them; the
  # classes, their hook chains and the profile list are put back after.
  def with_pictures
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    ours = lambda { |key| SCENES.key?(key.split("#", 2)[0]) }
    kept_chains = chains.select { |key, _v| ours.call(key) }
    kept = SCENES.keys.map { |n| [n, Object.const_defined?(n, false) ? Object.const_get(n, false) : nil] }
    profiles = PokeAccess::Game.profiles.dup
    chains.delete_if { |key, _v| ours.call(key) }
    SCENES.each do |n, base|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, Class.new(base))
    end
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    yield
  ensure
    if kept_chains
      chains.delete_if { |key, _v| ours.call(key) }
      chains.update(kept_chains)
    end
    (kept || []).each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k) if k
    end
    PokeAccess::Game.instance_variable_set(:@profiles, profiles) if profiles
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
