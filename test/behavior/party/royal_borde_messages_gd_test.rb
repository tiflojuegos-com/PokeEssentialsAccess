# Royal's bordered PC messages (games/royal/borde_messages.rb): pbDisplayBorde, which the shared message net does not
# know, is read as dialogue, and the box still shows and answers as the game's own.

# The bordered message box Royal adds to the PC scene, defined before the profile file is evaluated over it so its
# hook binds.
class PokemonStorageScene
  def pbDisplayBorde(message); "#{message} (mostrado)"; end
end
royal_borde_path = File.join(Harness::ROOT, "games", "royal", "borde_messages.rb")
eval(Harness.source(royal_borde_path), TOPLEVEL_BINDING, royal_borde_path)

class RoyalBordeMessagesGdTest < PokeAccessTest
  test "a bordered PC message is read as dialogue, queued" do
    PokemonStorageScene.new.pbDisplayBorde("¡Adiós, Pikachu de la caja 3!")
    assert_equal [["¡Adiós, Pikachu de la caja 3!", false]], SpeakCapture.log
  end

  test "the message box still shows and answers as the game's own" do
    assert_equal "Pikachu ya no está (mostrado)", PokemonStorageScene.new.pbDisplayBorde("Pikachu ya no está")
  end

  test "a bordered box with no text says nothing" do
    PokemonStorageScene.new.pbDisplayBorde("")
    assert_nothing_spoken
  end
end
