# A list row of nothing but dashes, dots, underscores or spaces (Awakening's empty autosave slots) is a placeholder,
# said as empty by the command-window reader; every other row, an empty one included, is not.
class RowPlaceholderGdTest < PokeAccessTest
  test "a row of nothing but dashes, dots, underscores or spaces is a placeholder" do
    ["----------", " . . . ", "____", "-", "-_. ", "   "].each do |row|
      assert_equal true, PokeAccess::Menus.placeholder?(row), "for #{row.inspect}"
    end
  end

  test "a row with any other character is not, nor an empty or missing one" do
    ["Ruta 1 - 12:00", "Poké-Ball", "...a", "-1", "", nil].each do |row|
      assert_equal false, PokeAccess::Menus.placeholder?(row), "for #{row.inspect}"
    end
  end

  test "a command window says a placeholder row as empty and a filled row as it is" do
    win = Window_CommandPokemon.new(["----------", "Ruta 1 - 12:00"])
    win.update
    win.index = 1
    win.update
    assert_equal [[PokeAccess::I18n.t(:row_empty), false], ["Ruta 1 - 12:00", true]], SpeakCapture.log
  end
end
