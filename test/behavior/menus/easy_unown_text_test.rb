# Easy Unown Text (plugins/easy_unown_text.rb, UnownMessage): a sign in the Unown font, its wrapped lines said back as
# one text before the wait for a key.
class EasyUnownTextTest < PokeAccessTest
  test "the sign's painted lines are said as one text, interrupting" do
    PokeAccess::UnownText.say([["EL TESORO", :positions, 256, 80], ["ESTA AQUI", :positions, 256, 112]])
    assert_equal [["EL TESORO ESTA AQUI", true]], SpeakCapture.log
  end

  test "a sign that painted nothing says nothing" do
    PokeAccess::UnownText.say([])
    PokeAccess::UnownText.say(nil)
    assert_nothing_spoken
  end
end
