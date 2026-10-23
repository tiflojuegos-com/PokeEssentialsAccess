# Infinite Fusion 2's fusion chooser (games/infinitefusion_hoenn/fusion_family.rb): the row of dots Up brings up, one
# per fusion of the evolution lines, custom sprite or not and the shown one marked, said once for the side pointed at.

# The chooser screen, reduced to its family row: drawEvolutionIcons asks, for each fusion of the row, whether it has a
# custom sprite; the row comes up and goes away with Up.
class DoublePreviewScreen
  attr_accessor :family
  def drawEvolutionIcons(_dex_number, _viewport, _x, _y, _window_position)
    (@family || []).each { |species| customSpriteExistsSpecies(species) }
  end
  def showAllEvoIcons; @evo_icons_visible = true; end
  def hideAllEvoIcons; @evo_icons_visible = false; end
end

# The game's custom sprite test, answered from $if_customs (fusion ids with a custom sprite).
unless Object.private_method_defined?(:customSpriteExistsSpecies)
  def customSpriteExistsSpecies(species); ($if_customs || []).include?(species); end
end

class IfhFusionFamilyGdTest < PokeAccessTest
  SPECIES = GameData::Species.singleton_class
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "fusion_family.rb")
  # The two sides' rows as fusion ids (B<body>H<head>): Pichu's line under Bulbasaur's head, then under Charmander's.
  LEFT = [:B172H1, :B25H1, :B26H1]
  RIGHT = [:B172H4, :B25H4, :B26H4]

  # Evaluates the profile file once, as boot does, its hooks bound to the stand-ins above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # Two fusions of the left row have a custom sprite, none of the right row's.
  def setup
    super
    $if_customs = [:B25H1, :B26H1]
  end

  # Takes the custom sprites back.
  def teardown
    $if_customs = nil
    super
  end

  test "the row under the arrow says its fusions, how many have a custom sprite and which is shown" do
    screen = chooser(1)
    screen.showAllEvoIcons
    assert_equal [[t(:if2_family, :n => 3, :m => 0, :k => 2), true]], SpeakCapture.log
  end

  test "the row is said once while Up stays held" do
    screen = chooser(1)
    screen.showAllEvoIcons
    screen.showAllEvoIcons
    assert_equal [t(:if2_family, :n => 3, :m => 0, :k => 2)], SpeakCapture.lines
  end

  test "held again on the other side, the row says that side's" do
    screen = chooser(1)
    screen.showAllEvoIcons
    screen.hideAllEvoIcons
    screen.instance_variable_set(:@selected, 0)
    SpeakCapture.clear
    screen.showAllEvoIcons
    assert_equal [t(:if2_family, :n => 3, :m => 2, :k => 1)], SpeakCapture.lines
  end

  test "a side whose row was never drawn says nothing" do
    screen = DoublePreviewScreen.allocate
    screen.instance_variable_set(:@selected, 1)
    screen.family = LEFT
    with_fusion_ids { screen.drawEvolutionIcons(:B172H1, nil, 0, 0, 0) }
    screen.showAllEvoIcons
    assert_nothing_spoken
  end

  test "an empty row says nothing" do
    screen = DoublePreviewScreen.allocate
    screen.instance_variable_set(:@selected, 0)
    screen.family = []
    with_fusion_ids { screen.drawEvolutionIcons(:B172H1, nil, 0, 0, 0) }
    screen.showAllEvoIcons
    assert_nothing_spoken
  end

  test "the game's custom sprite check outside the row answers as before and leaves the row alone" do
    screen = chooser(1)
    answers = [customSpriteExistsSpecies(:B25H1), customSpriteExistsSpecies(:B172H1)]
    screen.showAllEvoIcons
    assert_equal [true, false], answers, "outside the row"
    assert_equal [t(:if2_family, :n => 3, :m => 0, :k => 2)], SpeakCapture.lines, "the row drawn before, as it was"
  end

  test "a row that does not hold the shown fusion counts the first as the one shown" do
    screen = DoublePreviewScreen.allocate
    screen.instance_variable_set(:@selected, 0)
    screen.family = LEFT
    with_fusion_ids { screen.drawEvolutionIcons(:B133H1, nil, 0, 0, 0) }
    screen.showAllEvoIcons
    assert_equal [t(:if2_family, :n => 3, :m => 2, :k => 1)], SpeakCapture.lines
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The chooser with both rows drawn, Pichu's fusion shown on the left and Pikachu's on the right, the arrow on side.
  def chooser(side)
    screen = DoublePreviewScreen.allocate
    screen.instance_variable_set(:@selected, side)
    with_fusion_ids do
      screen.family = LEFT
      screen.drawEvolutionIcons(:B172H1, nil, 0, 0, 0)
      screen.family = RIGHT
      screen.drawEvolutionIcons(:B25H4, nil, 0, 0, 1)
    end
    screen
  end

  # Runs the block with GameData::Species answering a fusion id ("B<body>H<head>") with data that names it, as the
  # game's does; the stub's get is put back afterwards.
  def with_fusion_ids
    SPECIES.send(:alias_method, :ifh_family_plain_get, :get)
    SPECIES.send(:define_method, :get) do |id|
      id.to_s =~ /\AB\d+H\d+\z/ ? Struct.new(:species).new(id) : ifh_family_plain_get(id)
    end
    yield
  ensure
    SPECIES.send(:alias_method, :get, :ifh_family_plain_get)
    SPECIES.send(:remove_method, :ifh_family_plain_get)
  end
end
