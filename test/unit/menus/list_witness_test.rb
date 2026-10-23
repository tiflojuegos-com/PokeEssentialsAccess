# A command window speaks its focused row again when its list is replaced or changes size under a still cursor: queued
# when a line was said since its last read (the message the game shows with the change), else at once. The row count
# and the focused row are the witness it is keyed on.

class ListWitnessTest < PokeAccessTest
  STARTERS = ["Charmander", "Squirtle", "Bulbasaur"]
  # The PC's item storage rows as its list says them, a single Potion first.
  STORAGE = ["Potion: 1", "Antidote: 3", "CANCEL"]

  # The PC's item storage as the game hands it to Window_PokemonItemStorage: a PCItemStorage, no Array, whose
  # [item, count] slots live in @items.
  class StorageSlots
    def initialize(items); @items = items; end
    def length; @items.length; end
    def [](i); @items[i]; end
  end

  test "says the focused row queued as the window first updates" do
    window.update
    assert_equal [["Charmander", false]], SpeakCapture.log
  end

  test "says nothing more on an idle frame" do
    win = window
    win.update
    SpeakCapture.clear
    win.update
    assert_nothing_spoken
  end

  test "says nothing when the list is rebuilt with the same rows" do
    win = window
    win.update
    SpeakCapture.clear
    win.instance_variable_set(:@commands, STARTERS.map { |s| s.dup })
    win.update
    assert_nothing_spoken
  end

  test "says the new row at once when the list is replaced under the same index with nothing said since its read" do
    win = window
    win.update
    SpeakCapture.clear
    win.instance_variable_set(:@commands, ["Pidgey", "Rattata", "Caterpie"])
    win.update
    assert_equal [["Pidgey", true]], SpeakCapture.log
  end

  test "says the row again at once when the list loses a row under a still cursor with nothing said since its read" do
    win = window
    win.update
    SpeakCapture.clear
    win.instance_variable_set(:@commands, ["Charmander", "Squirtle"])
    win.update
    assert_equal [["Charmander", true]], SpeakCapture.log
  end

  test "the item storage's toss says the row that slides in queued behind the game's message" do
    win = window(STORAGE)
    win.update
    SpeakCapture.clear
    toss_first(win)
    win.update
    assert_equal [["Threw away 1 Potion.", false], ["Antidote: 3", false]], SpeakCapture.log
  end

  test "a change with nothing said since a queued read again says the row at once" do
    win = window(STORAGE)
    win.update
    toss_first(win)
    win.update
    SpeakCapture.clear
    win.instance_variable_set(:@commands, ["Antidote: 2", "CANCEL"])
    win.update
    assert_equal [["Antidote: 2", true]], SpeakCapture.log
  end

  test "says the row the cursor moves to, interrupting" do
    win = window
    win.update
    SpeakCapture.clear
    win.index = 1
    win.update
    assert_equal [["Squirtle", true]], SpeakCapture.log
  end

  test "a move right after a row changed under a still cursor still interrupts" do
    win = window
    win.update
    win.instance_variable_set(:@commands, ["Pidgey", "Rattata", "Caterpie"])
    win.update
    SpeakCapture.clear
    win.index = 1
    win.update
    assert_equal [["Rattata", true]], SpeakCapture.log
  end

  test "is the row count and the focused row, the row kept as it is" do
    win = Window_DrawableCommand.new(["a", :b])
    { 0 => [2, "a"], 1 => [2, :b], 9 => [2, nil] }.each do |row, witness|
      assert_equal witness, PokeAccess::Menus.list_witness(win, row), "row #{row}"
    end
  end

  test "takes a mart's stock where the window keeps no commands" do
    win = Window_DrawableCommand.new(nil)
    win.instance_variable_set(:@stock, [:TM01, :TM05])
    assert_equal [2, :TM05], PokeAccess::Menus.list_witness(win, 1)
  end

  test "keeps a copy of the item storage's slot, so a count taken from it in place is a change" do
    win = Window_DrawableCommand.new(nil)
    slots = [[:POTION, 5], [:ANTIDOTE, 3]]
    win.instance_variable_set(:@bag, slots)
    before = PokeAccess::Menus.list_witness(win, 0)
    slots[0][1] -= 1
    assert_equal [[2, [:POTION, 5]], [2, [:POTION, 4]]], [before, PokeAccess::Menus.list_witness(win, 0)]
  end

  test "takes the item storage's slots from the PCItemStorage the game hands its window" do
    win = Window_DrawableCommand.new(nil)
    slots = [[:POTION, 5], [:ANTIDOTE, 3]]
    win.instance_variable_set(:@bag, StorageSlots.new(slots))
    before = PokeAccess::Menus.list_witness(win, 0)
    slots[0][1] -= 1
    assert_equal [[2, [:POTION, 5]], [2, [:POTION, 4]]], [before, PokeAccess::Menus.list_witness(win, 0)]
  end

  test "is nothing for a window whose rows are no list of its own" do
    [nil, "a, b"].each do |rows|
      win = Window_DrawableCommand.new
      win.instance_variable_set(:@commands, rows)
      assert_nil PokeAccess::Menus.list_witness(win, 0), rows.inspect
    end
  end

  private

  # An active command window over a copy of rows with the cursor on the first row.
  def window(rows = STARTERS)
    win = Window_DrawableCommand.new(rows.dup)
    win.index = 0
    win.active = true
    win
  end

  # The toss of the item storage's only Potion as the game orders it (sevii/0138_PScreen_Bag.rb:448-452): its slot
  # deleted, then "Threw away..." said while the list waits.
  def toss_first(win)
    win.instance_variable_set(:@commands, STORAGE[1..-1])
    PokeAccess.say_screen_message(["Threw away 1 Potion."])
  end
end
