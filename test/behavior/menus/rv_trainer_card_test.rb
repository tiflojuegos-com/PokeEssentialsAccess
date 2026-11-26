# The trainer card of the engine Reborn and Rejuvenation share (games/rv_common/trainer_card_rv.rb): after the front's
# painted lines, the level cap its badges set, which the game's own reader says and the card does not paint; capped at
# 100 plus the Extended_Max_Level variable, and left out on the back, on a card that is not the player's and on an engine
# with no LEVELCAPS.
Harness.load_common("rv_common")

class RvTrainerCardTest < PokeAccessTest
  test "the front is followed by the level cap the badges held set, queued" do
    said = with_caps([18, 25, 30, 35, 40, 45, 50, 55, 60]) { front }
    assert_equal [t(:rv_level_cap, :n => [18, 25, 30, 35, 40, 45, 50, 55, 60][$Trainer.numbadges]), false], said.last
    assert_equal 2, said.length, "the card's own line comes first"
  end

  test "the cap is held to 100 plus the extended cap's variable" do
    said = with_caps([150] * 9, :Extended_Max_Level => 20) { front }
    assert_equal t(:rv_level_cap, :n => 120), said.last[0]
  end

  test "no cap is said on the back, for a card that is not the player's, or on an engine with no LEVELCAPS" do
    back = with_caps([18] * 9) { said_by { PokeAccess::TrainerCard.read_face(PokemonTrainerCardScene.new, false) { nil } } }
    other = with_caps([18] * 9, {}, :NotPlayerCharacter => true) { front }
    none = with_caps(nil) { front }
    assert_equal [[], 1, 1], [back, other.length, none.length]
  end

  private

  # What the card's front says as it is drawn.
  def front
    said_by { PokemonTrainerCardScene.new(0).pbDrawTrainerCardFront }
  end

  def said_by
    SpeakCapture.clear
    yield
    SpeakCapture.log.dup
  end

  # Runs the block with rv_common's reader bound over core's card and the game's LEVELCAPS (none for nil), variables and
  # switches as given; all of it put back after.
  def with_caps(caps, variables = {}, switches = {})
    meta = PokeAccess::TrainerCard.singleton_class
    core = meta.instance_method(:read_face)
    had = [$game_variables, $game_switches]
    Object.const_set(:LEVELCAPS, caps) if caps
    $game_variables = variables
    $game_switches = switches
    PokeAccess::TrainerCardRV.bind
    yield
  ensure
    meta.send(:define_method, :read_face, core)
    Object.send(:remove_const, :LEVELCAPS) if Object.const_defined?(:LEVELCAPS)
    $game_variables, $game_switches = had
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
