# The v21 field-move menu (plugins/advanced_items.rb, over the gen-6 stub of SelectMoveMenu_Scene): the option focused
# as the menu opens and each one the pbShowCommands loop moves to, read by the refresh_buttons hook, which the
# before-hook on pbShowCommands must not silence; rows sharing a move are told apart by their party member.
class FieldmovesV21Test < PokeAccessTest
  MOVES = [[:CUT, "Corte", 0, 0], [:SURF, "Surf", 0, 1], [:FLY, "Vuelo", 0, 2]]

  test "reads the option focused as the menu opens, then each one the cursor moves to, cutting in" do
    SelectMoveMenu_Scene.new(MOVES, [1, 2]).pbShowCommands
    assert_equal [["Corte", true], ["Surf", true], ["Vuelo", true]], SpeakCapture.log
  end

  test "an option stays said while the cursor rests on it" do
    SelectMoveMenu_Scene.new(MOVES, [1, 1, 1]).pbShowCommands
    assert_equal ["Corte", "Surf"], SpeakCapture.lines
  end

  test "opening the menu again reads its focused option again" do
    scene = SelectMoveMenu_Scene.new(MOVES, [])
    2.times { scene.pbShowCommands }
    assert_equal ["Corte", "Corte"], SpeakCapture.lines
  end

  test "rows sharing a move are told apart by the party member each belongs to" do
    with_party(["Lapras", "Vaporeon"]) do
      SelectMoveMenu_Scene.new([[:SURF, "Surf", 0, 0], [:SURF, "Surf", 1, 1]], [1]).pbShowCommands
    end
    assert_equal ["Surf, Lapras", "Surf, Vaporeon"], SpeakCapture.lines
  end

  test "a row whose member cannot be named says the move alone" do
    { "no party slot" => [nil, ["Lapras"]], "a slot past the party" => [3, ["Lapras"]],
      "a member with no name" => [0, [""]], "no party" => [0, nil] }.each do |what, (slot, names)|
      SpeakCapture.clear
      with_party(names) { SelectMoveMenu_Scene.new([[:SURF, "Surf", slot, 0]], []).pbShowCommands }
      assert_equal ["Surf"], SpeakCapture.lines, what
    end
  end

  test "a row with no name, or a cursor past the rows, says nothing" do
    SelectMoveMenu_Scene.new([[:SURF, "", 0, 0]], []).pbShowCommands
    SelectMoveMenu_Scene.new(MOVES, [5]).pbShowCommands
    assert_equal ["Corte"], SpeakCapture.lines, "only the second menu's first row"
  end

  private

  # Runs the block with the gen-6 trainer's party named names (no party at all for nil), taken away after.
  def with_party(names)
    party = names && names.map { |n| Poke.build(:name => n) }
    $Trainer.define_singleton_method(:party) { party }
    yield
  ensure
    $Trainer.singleton_class.send(:remove_method, :party) if $Trainer.singleton_class.method_defined?(:party, false)
  end
end
