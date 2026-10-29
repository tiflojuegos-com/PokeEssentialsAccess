# World Frontier's cap on Sky's damage numbers (games/worldfrontier/damage_cap.rb): the indicator reader says the
# number as World Frontier paints it, never past the hit points the battler had, and for a hit its substitute takes,
# what the doll lost.
class WorldfrontierDamageCapGdTest < PokeAccessTest
  T = PokeAccess::I18n
  NUMBERS = PokeAccess::SkyDamageNumbers
  META = NUMBERS.singleton_class

  # The indicator's settings, switched on.
  module Settings
    ACTIVE = true
  end

  # The game's options as far as the indicator goes: damage_numbers is 0 while the numbers show.
  Options = Struct.new(:damage_numbers)

  # A battler with its last hit's damage state.
  class Struck < Battle::Battler
    attr_accessor :damageState
  end

  # A damage state as the cap reads it: the damage computed, whether a substitute took the hit, what the doll lost.
  State = Struct.new(:calcDamage, :substitute, :hpLost)

  # Evaluates the profile file once, as boot does, and answers the reading it puts on the common's indicator; the
  # common's is put back, with the lists of profiles and overrides, so the other tests of the process keep it.
  def self.load_profile
    common = META.instance_method(:painted)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    path = File.join(Harness::ROOT, "games", "worldfrontier", "damage_cap.rb")
    begin
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      META.instance_method(:painted)
    ensure
      META.send(:define_method, :painted, common)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  WF_PAINTED = load_profile

  test "a knockout paints no more than the hit points the foe had, which its hp line says: no number" do
    said { NUMBERS.say([[knocked_out(State.new(250, false, 0)), 20, 0]]) }
    assert_nothing_spoken
  end

  test "a hit the foe holds through paints the damage up to the hit points it had" do
    foe = struck(1, State.new(250, false, 0))
    said { NUMBERS.say([[foe, 20, 0]]) }
    assert_equal [number(20)], SpeakCapture.lines
  end

  test "a hit its substitute takes paints what the doll lost, though the foe's hit points stay" do
    foe = struck(20, State.new(40, true, 30))
    said { NUMBERS.say([[foe, 20, 0]]) }
    assert_equal [number(30)], SpeakCapture.lines
  end

  test "a hit whose damage the hit points covered paints no number past its hp line" do
    foe = struck(5, State.new(15, false, 0))
    said { NUMBERS.say([[foe, 20, 0]]) }
    assert_nothing_spoken
  end

  test "with the numbers hidden the cap says nothing" do
    foe = struck(1, State.new(250, false, 0))
    said(1) { NUMBERS.say([[foe, 20, 0]]) }
    assert_nothing_spoken
  end

  private

  # A foe at hp of 160 hit points, with its last hit's state.
  def struck(hp, state)
    b = Struck.new("Onix", hp, 160, 1)
    b.damageState = state
    b
  end

  # A foe the hit knocked out, with its last hit's state.
  def knocked_out(state)
    struck(0, state)
  end

  # The line said for a damage number.
  def number(n)
    T.t(:zdmg_number, :n => n)
  end

  # Runs the block with the profile's reading in place of the common's, the indicator on and its option at value; all
  # put back after.
  def said(value = 0)
    was = META.instance_method(:painted)
    META.send(:define_method, :painted, WF_PAINTED)
    made = !Object.const_defined?(:DamageNumberSettings)
    Object.const_set(:DamageNumberSettings, Settings) if made
    options = $PokemonSystem
    $PokemonSystem = Options.new(value)
    yield
  ensure
    $PokemonSystem = options
    Object.send(:remove_const, :DamageNumberSettings) if made && Object.const_defined?(:DamageNumberSettings)
    META.send(:define_method, :painted, was)
  end
end
