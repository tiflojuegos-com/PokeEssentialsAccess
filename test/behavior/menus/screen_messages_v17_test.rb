# The item storage screen under its v17 name (ItemStorage_Scene, as in Soulstones and Awakening) on the gen-6 engine:
# its results and questions are said once, through the Toss subclass too, and the screen still gets its answers.
class ScreenMessagesV17Test < PokeAccessTest
  test "a result the Toss screen shows through its parent is said" do
    forget_dialogue
    TossItemScene.new.pbDisplay("Tiraste 2 Pociones.")
    assert_equal [["Tiraste 2 Pociones.", false]], SpeakCapture.log
  end

  test "a question is said" do
    forget_dialogue
    ItemStorage_Scene.new.pbConfirm("¿Tirar 2 Pociones?")
    assert_equal [["¿Tirar 2 Pociones?", false]], SpeakCapture.log
  end

  test "the screen still gets what its own methods answer" do
    forget_dialogue
    assert_equal ["Tiraste 3 Pociones.", true],
                 [TossItemScene.new.pbDisplay("Tiraste 3 Pociones."), ItemStorage_Scene.new.pbConfirm("¿Tirar 3 Pociones?")]
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
