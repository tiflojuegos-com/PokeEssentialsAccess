# The rv engine's own databox boxes (games/rv_common/battle_marks_rv.rb) said as marks through the gen-6 databox hook:
# PULSE, Rift and Perfection forms, Ultra Burst, Terastal, and the ball for a species caught in another form.
Harness.load_common("rv_common")

class RvDataboxMarksTest < PokeAccessTest
  # A foe as its databox shows it.
  Foe = Struct.new(:index, :name, :pokemon)

  test "says a PULSE form caught only as a species as it comes in" do
    box_for(magnezone, %w[Battle/battlePulseEvoBox Battle/battleBoxOwnedSpecies]).refresh
    marks = [t(:rv_mark_pulse), t(:rv_mark_owned_species)].join(", ")
    assert_equal [[t(:bt_marks_entry, :name => "Magnezone", :marks => marks), false]], SpeakCapture.log
  end

  test "names Rift, Perfection, Ultra Burst, Terastal and the stock caught ball, in the order drawn" do
    foe = magnezone
    box_for(foe, %w[Battle/battleRiftEvoBox Battle/battlePerfectionEvoBox Battle/battleUltraEvoBox
                    Battle/battleTerastalBox Battle/battleBoxOwned]).refresh
    assert_equal [t(:rv_mark_rift), t(:rv_mark_perfection), t(:bt_m_ultra), t(:bt_m_tera), t(:dex_caught)],
                 PokeAccess::Battle.shown_marks(foe)
  end

  private

  # A Magnezone across the field.
  def magnezone
    Foe.new(1, "Magnezone", Object.new)
  end

  # The foe's gen-6 databox, drawing the given Graphics/Pictures boxes of the engine's after the stock ones.
  def box_for(foe, boxes)
    box = PokemonDataBox.new(foe)
    box.extra = boxes
    box
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
