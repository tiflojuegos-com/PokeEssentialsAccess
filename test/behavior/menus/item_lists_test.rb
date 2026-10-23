# The core's item lists and the returns to a list (core/menus/menus.rb, number_entry.rb, options.rb): a row that
# changes under a still cursor, the close rows and the info key, a bag move cancelled on another row, a quantity's first
# amount behind its question, and the row said again back from a subscreen.

Window_PokemonBag = Class.new(Window_DrawableCommand) unless defined?(Window_PokemonBag)
class Window_PokemonMart; end unless defined?(Window_PokemonMart)
class Window_PokemonItemStorage; end unless defined?(Window_PokemonItemStorage)

class ItemListsTest < PokeAccessTest
  T = PokeAccess::I18n
  NAMES = { :POCION => "Poción", :ANTIDOTO => "Antídoto", :REPEL => "Repelente" }

  # Clears the amount the number entry spoke last, module state the per-test reset leaves alone.
  def setup
    super
    PokeAccess::NumberEntry.forget
  end

  test "says the row that takes a bought row's place in a mart's stock, queued behind the game's message" do
    win = Window_DrawableCommand.new(nil)
    stock = [:TM01, :TM05, :TM07]
    win.instance_variable_set(:@stock, stock)
    win.index = 1
    win.update
    SpeakCapture.clear
    stock.delete(:TM05)
    PokeAccess.say_screen_message(["Here you are!\r\nThank you!"])
    win.update
    assert_equal [["Here you are! Thank you!", false], ["TM07", false]], SpeakCapture.log
  end

  test "the close row hands the info key its own label, not the item focused before it" do
    win = bag_window([[:POCION, 3]])
    PokeAccess::Menus.bag_row(win, 0)
    PokeAccess::Menus.bag_row(win, 1)
    assert_equal [T.t(:mn_close_bag), "#{T.t(:mn_close_bag)}, #{list_place(2, 2)}"],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "a bag row ends with its place among the pocket's rows, the close row counted as the bag's slider counts it" do
    win = bag_window([[:POCION, 3], [:ANTIDOTO, 2]])
    rows = (0..2).map { |i| PokeAccess::Menus.bag_row(win, i) }
    assert_equal ["Poción: 3, #{list_place(1, 3)}", "Antídoto: 2, #{list_place(2, 3)}",
                  "#{T.t(:mn_close_bag)}, #{list_place(3, 3)}"], rows
  end

  test "a bag row's place is said from medium, and Ctrl+T keeps it even in brief" do
    win = bag_window([[:POCION, 3]])
    assert_equal ["Poción: 3", "Poción: 3, #{list_place(1, 2)}", "Poción: 3, #{list_place(1, 2)}"],
                 vb_levels { PokeAccess::Menus.bag_row(win, 0) }
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Menus.bag_row(win, 0)
    assert_equal "Poción: 3, #{list_place(1, 2)}", PokeAccess::Info.row_text
  end

  test "the cancel rows of the mart and the item storage hand the info key their own label" do
    PokeAccess::Info.set_info(:item, :POCION, "Poción: 3")
    mart = cancel_row(Window_PokemonMart.new, :@stock, [:POCION])
    assert_equal [T.t(:pc_cancel), T.t(:pc_cancel), nil], [mart, PokeAccess::Info.info_text, PokeAccess::Info.row_text]
    PokeAccess::Info.set_info(:item, :POCION, "Poción: 3")
    storage = cancel_row(Window_PokemonItemStorage.new, :@bag, [[:POCION, 3]])
    assert_equal [T.t(:pc_cancel), T.t(:pc_cancel)], [storage, PokeAccess::Info.info_text]
  end

  test "a move cancelled with the cursor on another row says that row again at once" do
    win = bag_window([[:POCION, 3], [:ANTIDOTO, 2], [:REPEL, 1]])
    win.instance_variable_set(:@sortIndex, 0)
    win.update
    win.index = 2
    win.update
    SpeakCapture.clear
    win.instance_variable_set(:@sortIndex, -1)
    win.update
    assert_equal [["Repelente: 1, #{list_place(3, 4)}", true]], SpeakCapture.log
  end

  test "a new quantity window's first amount is queued behind its question, the next ones interrupt" do
    num = Window_AdvancedTextPokemon.new("")
    num.text = "x001"
    num.text = "x002"
    other = Window_AdvancedTextPokemon.new("")
    other.text = "x001"
    assert_equal [["1", false], ["2", true], ["1", false]], SpeakCapture.log
  end

  test "back on the dex list from a species entry on the same row, the row is said again, queued" do
    scene, win = dex_list
    scene.pbDexEntry(0)
    win.update
    assert_equal [["Bulbasaur", false]], SpeakCapture.log
  end

  test "back from the search on its results, the row is queued behind the header rather than cutting it" do
    scene, win = dex_list
    win.commands = ["Pikachu", "Raichu"]
    scene.pbDexSearch
    win.update
    assert_equal [["Pikachu", false]], SpeakCapture.log
  end

  test "cancelling the search and closing its results say the row again, queued" do
    scene, win = dex_list
    scene.pbDexSearch
    win.update
    scene.pbCloseSearch
    win.update
    assert_equal [["Bulbasaur", false], ["Bulbasaur", false]], SpeakCapture.log
  end

  test "back on the options from Set Controls, the focused row is said again" do
    win = Window_DrawableCommand.new(["Text Speed: Fast", "Set Controls", "Cancel"])
    win.index = 1
    win.update
    SpeakCapture.clear
    PokemonControlsScene.new(nil, nil).pbEndScene
    win.update
    assert_equal [["Set Controls", false]], SpeakCapture.log
  end

  private

  # An active bag window over one pocket of rows ([item, count]), its close row counted, named by NAMES.
  def bag_window(rows)
    bag = Object.new
    bag.define_singleton_method(:pockets) { { 1 => rows } }
    adapter = Object.new
    adapter.define_singleton_method(:getDisplayName) { |item| NAMES[item] }
    win = Window_PokemonBag.new([])
    win.define_singleton_method(:pocket) { 1 }
    win.define_singleton_method(:itemCount) { rows.length + 1 }
    win.instance_variable_set(:@bag, bag)
    win.instance_variable_set(:@adapter, adapter)
    win
  end

  # The focused text of win over rows kept in ivar, with the cursor on the row past them.
  def cancel_row(win, ivar, rows)
    win.instance_variable_set(ivar, rows)
    win.instance_variable_set(:@i, rows.length)
    def win.index; @i; end
    PokeAccess::Menus.focused_text(win)
  end

  # A gen-6 dex scene whose list has been read on its first row, the log cleared: [scene, list].
  def dex_list
    scene = PokemonPokedexScene.new
    win = Window_DrawableCommand.new(["Bulbasaur", "Ivysaur"])
    scene.sprites["pokedex"] = win
    win.update
    SpeakCapture.clear
    [scene, win]
  end
end
