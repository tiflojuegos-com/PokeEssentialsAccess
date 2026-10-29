# Anil's damage numbers (games/anil/damage_numbers.rb), painted over a battler whose hp changes while its "Mostrar Nº
# de daño" option shows them: a foe's change is then said in hit points, as painted, and with the numbers hidden as the
# change of its bar's percentage. Sky's indicator, which the other v21 games paint, is core's
# (sky_damage_numbers_gd_test.rb).
class AnilDamageNumbersGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # Anil's options as far as its profile goes: show_damage_numbers is 0 while the numbers are shown.
  AnilOptions = Struct.new(:show_damage_numbers) do
    def show_damage_numbers?; show_damage_numbers == 0; end
  end

  class << self
    # The foe seam as the profile file overrides it: the file is evaluated once, over the seam as it stands then,
    # which is put back after.
    def painted_seam
      return @seam if @seam
      before = PokeAccess::Battle.method(:foe_change_painted?)
      file = File.join(Harness::ROOT, "games", "anil", "damage_numbers.rb")
      begin
        eval(Harness.source(file), TOPLEVEL_BINDING, file)
        @seam = PokeAccess::Battle.method(:foe_change_painted?)
      ensure
        PokeAccess::Battle.define_singleton_method(:foe_change_painted?, before)
      end
    end
  end

  test "with Anil's numbers shown a foe's loss is said in the hit points painted over it" do
    with_profile(AnilOptions.new(0)) { onix.pbReduceHP(30) }
    assert_equal [figures(:bt_lose, 30, 31)], SpeakCapture.lines
  end

  test "with Anil's numbers hidden a foe's loss is the change of its bar's percentage" do
    with_profile(AnilOptions.new(1)) { onix.pbReduceHP(30) }
    assert_equal [share(:bt_lose, 19, 31)], SpeakCapture.lines
  end

  private

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

  # Runs the block with the profile's override of the foe seam and the game's options as given, both put back after.
  def with_profile(options)
    seam = PokeAccess::Battle.method(:foe_change_painted?)
    PokeAccess::Battle.define_singleton_method(:foe_change_painted?, self.class.painted_seam)
    was = $PokemonSystem
    $PokemonSystem = options
    yield
  ensure
    $PokemonSystem = was
    PokeAccess::Battle.define_singleton_method(:foe_change_painted?, seam) if seam
  end
end
