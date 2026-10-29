# Sky's Damage Number Indicator (games/skyflyer_common/damage_numbers.rb), shown while DamageNumberSettings::ACTIVE
# and the "Indicador Daño" option is 0: a foe's change of hit points is then said in hit points, as painted, and a
# hit that paints more damage than the hit points it took (a knockout) says the damage painted too.
class SkyDamageNumbersGdTest < PokeAccessTest
  T = PokeAccess::I18n
  NUMBERS = PokeAccess::SkyDamageNumbers

  # The indicator's settings, switched on.
  module Settings
    ACTIVE = true
  end

  # The indicator's settings, switched off in the game's scripts.
  module SettingsOff
    ACTIVE = false
  end

  # The game's options as far as the indicator goes: damage_numbers is 0 while the numbers show.
  Options = Struct.new(:damage_numbers)

  # A battler with the damage its last hit computed (damageState.calcDamage), which the hit animation paints.
  class Struck < Battle::Battler
    attr_accessor :damageState
  end

  # A battler's damage state as far as the indicator reads it.
  DamageState = Struct.new(:calcDamage)

  test "with the numbers shown a foe's loss and heal are said in the hit points painted over it" do
    with_indicator(Settings, 0) do
      onix.pbReduceHP(30)
      onix.pbRecoverHP(16)
    end
    assert_equal [figures(:bt_lose, 30, 31), figures(:bt_gain, 16, 60)], SpeakCapture.lines
  end

  test "the foe seam says the numbers shown" do
    with_indicator(Settings, 0) { assert PokeAccess::Battle.foe_change_painted?(onix), "shown" }
    with_indicator(Settings, 1) { refute PokeAccess::Battle.foe_change_painted?(onix), "hidden" }
  end

  test "with the numbers hidden, switched off or missing a foe's loss is the change of its bar's percentage" do
    { "hidden" => [Settings, 1], "switched off" => [SettingsOff, 0], "missing" => [nil, 0] }.each do |what, (set, opt)|
      SpeakCapture.clear
      with_indicator(set, opt) { onix.pbReduceHP(30) }
      assert_equal [share(:bt_lose, 19, 31)], SpeakCapture.lines, what
    end
  end

  test "a knockout says the damage the move computed, painted past the hit points it took" do
    foe = struck(1, 50)
    mine = struck(0, 90)
    with_indicator(Settings, 0) { NUMBERS.say([[foe, 20, 0]]) }
    assert_nothing_spoken "before the hit points drop"
    foe.hp = 0
    mine.hp = 0
    with_indicator(Settings, 0) { NUMBERS.say([[foe, 20, 0], [mine, 20, 0]]) }
    assert_equal [[number(50), false], [number(90), false]], SpeakCapture.log
  end

  test "a hit whose damage the hit points covered, or that took none, says no number" do
    foe = struck(1, 15)
    foe.hp = 5
    calm = struck(1, 0)
    with_indicator(Settings, 0) { NUMBERS.say([[foe, 20, 0], [calm, 20, 0], nil]) }
    assert_nothing_spoken
  end

  test "with the numbers hidden a knockout says no number" do
    foe = struck(1, 50)
    foe.hp = 0
    with_indicator(Settings, 1) { NUMBERS.say([[foe, 20, 0]]) }
    assert_nothing_spoken
  end


  private

  # A battler at 20 of 160 hp at index whose last hit computed calc damage.
  def struck(index, calc)
    b = Struck.new("Onix", 20, 160, index)
    b.damageState = DamageState.new(calc)
    b
  end

  # A foe Onix at 80 of 160 hp.
  def onix
    Battle::Battler.new("Onix", 80, 160, 1)
  end

  # The line said for a damage number.
  def number(n)
    T.t(:zdmg_number, :n => n)
  end

  # The hp line for the foe in hit points, with the percentage left.
  def figures(verb, n, pct)
    T.t(:bt_hp_change, :name => "Onix", :verb => T.t(verb), :n => n, :rest => T.t(:bt_hp_pct, :n => pct))
  end

  # The hp line for the foe as the change of its percentage, with the percentage left.
  def share(verb, n, pct)
    T.t(:bt_hp_change_pct, :name => "Onix", :verb => T.t(verb), :n => n, :rest => T.t(:bt_hp_pct, :n => pct))
  end

  # Runs the block with the indicator's settings under their game name (none for nil) and the option at value.
  def with_indicator(settings, value)
    made = settings && !Object.const_defined?(:DamageNumberSettings)
    Object.const_set(:DamageNumberSettings, settings) if made
    was = $PokemonSystem
    $PokemonSystem = Options.new(value)
    yield
  ensure
    $PokemonSystem = was
    Object.send(:remove_const, :DamageNumberSettings) if made && Object.const_defined?(:DamageNumberSettings)
  end

end
