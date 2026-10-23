# The modern summary's action menu on the GameData engine: PokemonSummary_Scene#pbShowCommands takes the command list
# first and no message, so nothing is read as a message and the repeat key keeps the last line.
class ScreenQuestionGdTest < PokeAccessTest
  test "the summary's action menu is not read as a message, and the repeat key keeps the last line" do
    forget_dialogue
    PokeAccess.say_dialogue("Chispa was deposited.")
    SpeakCapture.clear
    PokemonSummary_Scene.new.pbShowCommands(["Give item", "Take item", "View Pokedex", "Mark", "Cancel"])
    assert_nothing_spoken "the list is the command window's to name"
    assert_equal "Chispa was deposited.", PokeAccess.last_dialogue
  end

  private

  # Drops what the dialogue reader carries over from earlier lines (its half-second copy window, a promised head or
  # tail, the repeat key's line), so the line under test is said as it is.
  def forget_dialogue
    PokeAccess.take_head
    PokeAccess.take_tail
    [:@last_dialogue, :@last_say, :@last_say_t, :@last_led].each { |iv| PokeAccess.instance_variable_set(iv, nil) }
  end
end
