# The v22 in-screen messages every screen inherits from UI::BaseScreen (show_message and its three siblings): each is
# said and still answers what the screen answers; an empty one, the screen clearing its box, says nothing.
class ScreenV22MessagesGdTest < PokeAccessTest
  MESSAGES = { :show_message => "Un mensaje normal", :show_confirm_message => "¿Seguro que quieres?",
               :show_confirm_serious_message => "Esto no se puede deshacer", :show_choice_message => "Elige una opción" }

  test "each of the four messages a screen inherits is said" do
    screen = Class.new(UI::BaseScreen).new
    MESSAGES.each do |meth, text|
      forget_dialogue
      SpeakCapture.clear
      screen.send(meth, text)
      assert_equal [[text, false]], SpeakCapture.log, "#{meth}"
    end
  end

  test "each still answers what the screen answers" do
    screen = Class.new(UI::BaseScreen).new
    MESSAGES.each { |meth, text| assert_equal text, screen.send(meth, text), "#{meth}" }
  end

  test "an empty message says nothing" do
    Class.new(UI::BaseScreen).new.show_message("")
    assert_nothing_spoken
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
