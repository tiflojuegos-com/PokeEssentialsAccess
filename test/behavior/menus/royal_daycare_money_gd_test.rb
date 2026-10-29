# Royal's daycare level-up (games/royal_common/daycare_money.rb; World Frontier ships the function too): the money
# window the function builds itself is said, queued, as it is made and when the purchase repaints it, never twice for
# the same sum, and no other text window is. The window is the engine stubs' Window_UnformattedTextPokemon, whose
# constructor sizes it as the game's does.

# The level-up as the game runs it: the money window, sized again to fit; $royal_daycare_meanwhile, when set, opens
# whatever else comes up while it asks; then the purchase repaints the window (the new sum set twice).
def guarderia_subir_niveles_equipo
  gold = Window_UnformattedTextPokemon.newWithSize("Dinero:\n12.345$", 0, 0, 32, 32)
  gold.resizeToFit(gold.text, 512)
  $royal_daycare_meanwhile.call if $royal_daycare_meanwhile
  gold.text = "Dinero:\n11.945$"
  gold.text = "Dinero:\n11.945$"
  :leveled
end

daycare = File.join(Harness::ROOT, "games", "royal_common", "daycare_money.rb")
eval(Harness.source(daycare), TOPLEVEL_BINDING, daycare)

class RoyalDaycareMoneyGdTest < PokeAccessTest
  BEFORE = ["Dinero: 12.345$", false].freeze
  AFTER = ["Dinero: 11.945$", false].freeze

  test "says the money window queued as the level-up opens it, and its new sum once when the purchase repaints it" do
    guarderia_subir_niveles_equipo
    assert_equal [BEFORE, AFTER], SpeakCapture.log
  end

  test "says only the level-up's own money window, not a window made outside it or after it while it asks" do
    Window_UnformattedTextPokemon.new("Antes.").text = "Fuera."
    $royal_daycare_meanwhile = lambda do
      other = Window_UnformattedTextPokemon.new("Elige un Pokémon.")
      other.resizeToFit(other.text, 200)
      other.text = "Subir de nivel."
    end
    guarderia_subir_niveles_equipo
    Window_UnformattedTextPokemon.new("Después.").text = "Fuera otra vez."
    assert_equal [BEFORE, AFTER], SpeakCapture.log
  ensure
    $royal_daycare_meanwhile = nil
  end

  test "the level-up answers as the game's function does, its money said" do
    assert_equal :leveled, guarderia_subir_niveles_equipo
    assert_equal [BEFORE, AFTER], SpeakCapture.log
  end
end
