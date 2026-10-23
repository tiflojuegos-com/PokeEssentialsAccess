# The v22 PC (UI::PokemonStorageVisuals): cursor index -1 names the box, -2 the party button (Back in the party panel),
# -3 close, and 0 and up a slot, read with its row and column; paging boxes leads the line with the new box's name.
class StorageV22GdTest < PokeAccessTest
  MALE = "\xE2\x99\x82"
  T = PokeAccess::I18n

  test "opening the PC reads the slot under the cursor with its row, column and panel" do
    UI::PokemonStorageVisuals.new(pc)
    assert_equal [[slot("Bulba", 12, 1, 1), true]], SpeakCapture.log
  end

  test "the slot the cursor is already on, asked again, says nothing" do
    vis = UI::PokemonStorageVisuals.new(pc)
    SpeakCapture.clear
    vis.set_index(0)
    assert_nothing_spoken
  end

  test "a reopened PC reads the slot under the cursor again" do
    storage = pc
    UI::PokemonStorageVisuals.new(storage)
    SpeakCapture.clear
    UI::PokemonStorageVisuals.new(storage)
    assert_equal [[slot("Bulba", 12, 1, 1), true]], SpeakCapture.log
  end

  test "an empty slot says it is empty, with its row and column" do
    assert_equal [[T.t(:pc_empty) + pos(1, 2), true]], moved_to(1)
  end

  test "a fainted Pokemon is flagged after its name and level" do
    assert_equal [[T.t(:pc_slot, :name => "Fainty #{MALE}", :level => 9) + ", " + T.t(:pk_fainted) + pos(1, 3) + ", " + panel,
                   true]], moved_to(2)
  end

  test "a slot past the first row says its row and column, six slots to a row" do
    assert_equal [[T.t(:pc_empty) + pos(2, 2), true]], moved_to(7)
  end

  test "in brief a slot says its name and level alone" do
    vis = UI::PokemonStorageVisuals.new(pc, :normal, 1)
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    vis.set_index(0)
    assert_equal [[T.t(:pc_slot, :name => "Bulba", :level => 12), true]], SpeakCapture.log
  end

  test "the info key's row keeps the whole slot line whatever the verbosity" do
    vis = UI::PokemonStorageVisuals.new(pc, :normal, 1)
    PokeAccess::Config.verbosity = :brief
    vis.set_index(0)
    assert_equal slot("Bulba", 12, 1, 1), PokeAccess::Info.row_text
  end

  test "the box row and the control buttons name themselves" do
    vis = UI::PokemonStorageVisuals.new(pc)
    { -1 => box_row("Alpha"), -3 => T.t(:pc_close), -2 => T.t(:pc_team) }.each do |index, want|
      SpeakCapture.clear
      vis.set_index(index)
      assert_equal [[want, true]], SpeakCapture.log, "index #{index}"
    end
  end

  test "with key hints left out the box row is the box's name alone" do
    vis = UI::PokemonStorageVisuals.new(pc)
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    vis.set_index(-1)
    assert_equal [[T.t(:pc_box, :name => "Alpha"), true]], SpeakCapture.log
  end

  test "paging boxes from the box row names the new box once" do
    vis = UI::PokemonStorageVisuals.new(pc)
    vis.set_index(-1)
    SpeakCapture.clear
    vis.go_to_next_box
    assert_equal [[box_row("Beta"), true]], SpeakCapture.log, "the next box"
    SpeakCapture.clear
    vis.set_index(-1)
    assert_nothing_spoken "the box row asked again after the page"
  end

  test "paging back names the previous box" do
    vis = UI::PokemonStorageVisuals.new(pc)
    vis.set_index(-1)
    vis.go_to_next_box
    SpeakCapture.clear
    vis.go_to_previous_box
    assert_equal [[box_row("Alpha"), true]], SpeakCapture.log
  end

  test "paging boxes from a slot leads the slot's line with the new box's name" do
    vis = UI::PokemonStorageVisuals.new(pc)
    SpeakCapture.clear
    vis.go_to_next_box
    assert_equal [["#{T.t(:pc_box, :name => 'Beta')}. #{slot('Char', 25, 1, 1)}", true]], SpeakCapture.log
  end

  test "paging onto a box with no name says the slot's line alone" do
    [nil, ""].each do |name|
      storage = pc
      storage[1].name = name
      vis = UI::PokemonStorageVisuals.new(storage)
      SpeakCapture.clear
      vis.go_to_next_box
      assert_equal [[slot("Char", 25, 1, 1), true]], SpeakCapture.log, "a box named #{name.inspect}"
    end
  end

  test "a slot that cannot be read is said as empty" do
    storage = pc
    def (storage[0]).[](_index); raise "the slot is unreadable"; end
    assert_equal [[T.t(:pc_empty) + pos(1, 1), true]], moved_to(0, UI::PokemonStorageVisuals.new(storage, :normal, 1))
  end

  test "paging boxes while the cursor's index cannot be read names the new box alone" do
    vis = UI::PokemonStorageVisuals.new(pc)
    def vis.index; raise "no cursor yet"; end
    SpeakCapture.clear
    vis.go_to_next_box
    assert_equal [[T.t(:pc_box, :name => "Beta"), true]], SpeakCapture.log
  end

  test "the party panel reads its members with no row or column" do
    vis = UI::PokemonStorageVisuals.new(pc)
    SpeakCapture.clear
    vis.show_party_panel
    assert_equal [[T.t(:pc_slot, :name => "Squir #{MALE}", :level => 30) + ", " + panel, true]], SpeakCapture.log
  end

  test "the party button reads Back in the party panel and Team again back in the box" do
    vis = UI::PokemonStorageVisuals.new(pc)
    vis.show_party_panel
    SpeakCapture.clear
    vis.set_index(-2)
    assert_equal [[T.t(:pc_back), true]], SpeakCapture.log, "in the party panel"
    SpeakCapture.clear
    vis.hide_party_panel
    assert_equal [[T.t(:pc_team), true]], SpeakCapture.log, "back in the box"
  end

  test "a held Pokemon turns an occupied slot into a swap and an empty one into a placement" do
    vis = UI::PokemonStorageVisuals.new(pc, :normal, 2)
    vis.hold_pokemon(Poke.build(:name => "Pika", :level => 15))
    assert_equal [[T.t(:pc_swap, :name => "Bulba", :held => "Pika") + pos(1, 1), true]], moved_to(0, vis), "over Bulba"
    assert_equal [[T.t(:pc_place, :held => "Pika") + pos(1, 2), true]], moved_to(1, vis), "over the empty slot"
  end

  test "in brief a swap leaves out its row and column and a placement keeps them" do
    vis = UI::PokemonStorageVisuals.new(pc, :normal, 2)
    vis.hold_pokemon(Poke.build(:name => "Pika", :level => 15))
    PokeAccess::Config.verbosity = :brief
    assert_equal [[T.t(:pc_swap, :name => "Bulba", :held => "Pika"), true]], moved_to(0, vis), "over Bulba"
    assert_equal [[T.t(:pc_place, :held => "Pika") + pos(1, 2), true]], moved_to(1, vis), "over the empty slot"
  end

  private

  # Two boxes and a party column; the first box's slot 1 is empty and slot 2 holds a fainted Pokemon.
  def pc
    alpha = TestBox.new("Alpha", [Poke.build(:name => "Bulba", :level => 12), nil,
                                  Poke.build(:name => "Fainty", :level => 9, :hp => 0)])
    beta = TestBox.new("Beta", [Poke.build(:name => "Char", :level => 25)])
    TestStorage.new([alpha, beta], [Poke.build(:name => "Squir", :level => 30)])
  end

  # What moving the cursor to index says, as [text, interrupt] pairs, on vis or on a PC just opened.
  def moved_to(index, vis = UI::PokemonStorageVisuals.new(pc))
    SpeakCapture.clear
    vis.set_index(index)
    SpeakCapture.log.dup
  end

  # The row and column tail the box grid adds to a slot's line.
  def pos(row, col)
    T.t(:pc_pos, :row => row, :col => col)
  end

  # The rest of a stored stub Pokemon's panel line: its ability and no item.
  def panel
    [T.t(:pc_ability, :a => "Ability1"), T.t(:pc_no_item)].join(", ")
  end

  # A box slot's full line for a healthy male stub Pokemon.
  def slot(name, level, row, col)
    T.t(:pc_slot, :name => "#{name} #{MALE}", :level => level) + pos(row, col) + ", " + panel
  end

  # The box row: its name and the keys that turn it.
  def box_row(name)
    [T.t(:pc_box, :name => name), T.t(:pc_box_hint)].join(". ")
  end
end
