# A command row painted as nothing but question marks (Desolation's quest log and field list, before a quest or a field
# is found) is said as the word for unknown, which a screen reader would leave unsaid; any other row is untouched.
class UnknownRowsTest < PokeAccessTest
  test "says a row of question marks as the word for unknown, queued as the window's first read" do
    Window_DrawableCommand.new(["???", "Back"]).update
    assert_equal [[unknown, false]], SpeakCapture.log
  end

  test "says a named row as painted" do
    win = Window_DrawableCommand.new(["???", "Back"])
    win.update
    SpeakCapture.clear
    win.index = 1
    win.update
    assert_equal [["Back", true]], SpeakCapture.log
  end

  test "turns into the word only a row of two or more marks, spaces around them allowed" do
    { "???" => unknown, "??" => unknown, "  ??? " => unknown, "?????" => unknown, "?" => "?", "? ?" => "? ?",
      "Who? ???" => "Who? ???", "Back" => "Back", "" => "" }.each do |row, want|
      assert_equal want, PokeAccess::Menus.unknown_row(row), "for #{row.inspect}"
    end
  end

  test "passes a row that is no text through untouched" do
    assert_nil PokeAccess::Menus.unknown_row(nil)
  end

  private

  def unknown
    PokeAccess::I18n.t(:pdx_unknown_short)
  end
end
