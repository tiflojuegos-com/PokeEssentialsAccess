# The damage numbers two v21 games paint over a battler whose hp changes, while their option shows them (Anil's
# "Mostrar Nº de daño", games/anil/damage_numbers.rb; Royal's "Indicador Daño", games/royal/damage_numbers.rb): a foe's
# change is then said in hit points, as painted, and with the numbers hidden as the change of its bar's percentage;
# Royal's hit that paints more damage than the hp it took (a knockout) says the damage painted too.

# Royal's hit animation as far as its damage numbers go, there before the profile file binds its hook to it.
class Battle::Scene
  def pbHitAndHPLossAnimation(targets); targets; end
end

class DamageNumbersGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # A battler with the damage its last hit computed (damageState.calcDamage), which Royal's hit animation paints.
  class Struck < Battle::Battler
    attr_accessor :damageState
  end

  # A battler's damage state as far as Royal's indicator reads it.
  DamageState = Struct.new(:calcDamage)

  # Anil's options as far as its profile goes: show_damage_numbers is 0 while the numbers are shown.
  AnilOptions = Struct.new(:show_damage_numbers) do
    def show_damage_numbers?; show_damage_numbers == 0; end
  end

  # Royal's options as far as its profile goes: damage_numbers is 0 while the numbers are shown.
  RoyalOptions = Struct.new(:damage_numbers)

  # Royal's Damage Number Indicator settings, switched on.
  module RoyalSettings
    ACTIVE = true
  end

  class << self
    # The foe seam as a profile file overrides it: the file is evaluated once, over the seam as it stands then, which
    # is put back after.
    def painted_seam(path)
      @seams ||= {}
      return @seams[path] if @seams.key?(path)
      before = PokeAccess::Battle.method(:foe_change_painted?)
      file = File.join(Harness::ROOT, "games", path)
      begin
        eval(Harness.source(file), TOPLEVEL_BINDING, file)
        @seams[path] = PokeAccess::Battle.method(:foe_change_painted?)
      ensure
        PokeAccess::Battle.define_singleton_method(:foe_change_painted?, before)
      end
    end
  end

  test "with Anil's numbers shown a foe's loss is said in the hit points painted over it" do
    with_profile("anil/damage_numbers.rb", AnilOptions.new(0)) { onix.pbReduceHP(30) }
    assert_equal [figures(:bt_lose, 30, 31)], SpeakCapture.lines
  end

  test "with Anil's numbers hidden a foe's loss is the change of its bar's percentage" do
    with_profile("anil/damage_numbers.rb", AnilOptions.new(1)) { onix.pbReduceHP(30) }
    assert_equal [share(:bt_lose, 19, 31)], SpeakCapture.lines
  end

  test "with Royal's numbers shown a foe's heal is said in the hit points painted over it" do
    with_royal_settings do
      with_profile("royal/damage_numbers.rb", RoyalOptions.new(0)) { onix.pbRecoverHP(16) }
    end
    assert_equal [figures(:bt_gain, 16, 60)], SpeakCapture.lines
  end

  test "with Royal's numbers hidden, or its indicator missing, a foe's heal is the change of its bar's percentage" do
    cases = { "hidden" => [RoyalOptions.new(1), true], "no indicator" => [RoyalOptions.new(0), false] }
    cases.each do |what, (options, settings)|
      SpeakCapture.clear
      run = lambda { with_profile("royal/damage_numbers.rb", options) { onix.pbRecoverHP(16) } }
      settings ? with_royal_settings(&run) : run.call
      assert_equal [share(:bt_gain, 10, 60)], SpeakCapture.lines, what
    end
  end

  test "with Royal's numbers shown a knockout says the damage painted over the battler after its hp line" do
    foe = struck("Onix", 1, 50)
    mine = struck("Pikachu", 0, 50)
    with_royal_settings { with_profile("royal/damage_numbers.rb", RoyalOptions.new(0)) { hit(foe, 50); hit(mine, 50) } }
    pikachu = T.t(:bt_hp_change, :name => "Pikachu", :verb => T.t(:bt_lose), :n => 20,
                                 :rest => T.t(:bt_hp_exact, :hp => 0, :tot => 160))
    assert_equal [figures(:bt_lose, 20, 0), number(50), pikachu, number(50)], SpeakCapture.lines
  end

  test "with Royal's numbers shown a hit whose damage the hp covered, or that took none, says no number" do
    foe = struck("Onix", 1, 15)
    with_royal_settings do
      with_profile("royal/damage_numbers.rb", RoyalOptions.new(0)) do
        hit(foe, 15)
        Battle::Scene.new.pbHitAndHPLossAnimation([[foe, foe.hp, 0]])
      end
    end
    assert_equal [figures(:bt_lose, 15, 3)], SpeakCapture.lines
  end

  test "with Royal's numbers hidden, or its indicator missing, a knockout says its hp line alone" do
    cases = { "hidden" => [RoyalOptions.new(1), true], "no indicator" => [RoyalOptions.new(0), false] }
    cases.each do |what, (options, settings)|
      SpeakCapture.clear
      foe = struck("Onix", 1, 50)
      run = lambda { with_profile("royal/damage_numbers.rb", options) { hit(foe, 50) } }
      settings ? with_royal_settings(&run) : run.call
      assert_equal [share(:bt_lose, 12, 0)], SpeakCapture.lines, what
    end
  end

  private

  # A battler at 20 of 160 hp at index whose last hit computed calc damage.
  def struck(name, index, calc)
    b = Struck.new(name, 20, 160, index)
    b.damageState = DamageState.new(calc)
    b
  end

  # The hit of a move on battler as Royal's battle runs it: the hp it takes, then the hit animation over it.
  def hit(battler, damage)
    old = battler.hp
    battler.pbReduceHP(damage)
    Battle::Scene.new.pbHitAndHPLossAnimation([[battler, old, 0]])
  end

  # The line said for a damage number.
  def number(n)
    T.t(:zdmg_number, :n => n)
  end

  # A foe Onix at 80 of 160 hp.
  def onix
    Battle::Battler.new("Onix", 80, 160, 1)
  end

  # The hp line for the foe in hit points, with the percentage left.
  def figures(verb, n, pct)
    T.t(:bt_hp_change, :name => "Onix", :verb => T.t(verb), :n => n, :rest => T.t(:bt_hp_pct, :n => pct))
  end

  # The hp line for the foe as the change of its percentage, with the percentage left.
  def share(verb, n, pct)
    T.t(:bt_hp_change_pct, :name => "Onix", :verb => T.t(verb), :n => n, :rest => T.t(:bt_hp_pct, :n => pct))
  end

  # Runs the block with a profile file's override of the foe seam and the game's options as given, both put back after.
  def with_profile(path, options)
    seam = PokeAccess::Battle.method(:foe_change_painted?)
    PokeAccess::Battle.define_singleton_method(:foe_change_painted?, self.class.painted_seam(path))
    was = $PokemonSystem
    $PokemonSystem = options
    yield
  ensure
    $PokemonSystem = was
    PokeAccess::Battle.define_singleton_method(:foe_change_painted?, seam) if seam
  end

  # Runs the block with Royal's indicator settings under their game name, taken away after.
  def with_royal_settings
    made = !Object.const_defined?(:DamageNumberSettings)
    Object.const_set(:DamageNumberSettings, RoyalSettings) if made
    yield
  ensure
    Object.send(:remove_const, :DamageNumberSettings) if made && Object.const_defined?(:DamageNumberSettings)
  end
end
