# A toggle row ("[X] Option" or "[  ] Option": Soulstones 2's Randomizer X rules, mystery gift, debug lists) reads as
# its option, then its state as a word; every other row reads as it is.
class CheckboxRowGdTest < PokeAccessTest
  test "a checked box says its option, then that it is on" do
    { "[X] Randomize Trainer parties" => "Randomize Trainer parties", "[x] Randomize Items" => "Randomize Items",
      "[Y] Medalla 1" => "Medalla 1", "[ X ]Shiny" => "Shiny" }.each do |row, option|
      assert_equal "#{option}, #{on}", PokeAccess::Menus.checkbox_row(row), "for #{row.inspect}"
    end
  end

  test "an empty box says its option, then that it is off" do
    { "[  ] Randomize Wild encounters" => "Randomize Wild encounters", "[ ] Medalla 2" => "Medalla 2",
      "[] Medalla 3" => "Medalla 3" }.each do |row, option|
      assert_equal "#{option}, #{off}", PokeAccess::Menus.checkbox_row(row), "for #{row.inspect}"
    end
  end

  test "a row with no box, or a box with no option after it, is left as it is" do
    ["Done", "[Nuevo] Ruta 1", "[X]", "[  ]   ", "Medalla [X]", ""].each do |row|
      assert_equal row, PokeAccess::Menus.checkbox_row(row), "for #{row.inspect}"
    end
  end

  test "a row that is not text is handed back untouched" do
    assert_nil PokeAccess::Menus.checkbox_row(nil)
    assert_equal :DONE, PokeAccess::Menus.checkbox_row(:DONE)
  end

  test "the command reader says the toggle row it lands on as option and state, queued" do
    Window_CommandPokemon.new(["[  ] Randomize Trainer parties", "Done"]).update
    assert_equal [["Randomize Trainer parties, #{off}", false]], SpeakCapture.log
  end

  test "the command reader says a plain row it moves to as it is, cutting in" do
    win = Window_CommandPokemon.new(["[X] Randomize Trainer parties", "Done"])
    win.update
    SpeakCapture.clear
    win.index = 1
    win.update
    assert_equal [["Done", true]], SpeakCapture.log
  end

  private

  def on; PokeAccess::I18n.t(:val_on); end
  def off; PokeAccess::I18n.t(:val_off); end
end
