# Infinite Fusion's multi-select list (games/infinitefusion_common/multi_select.rb): each entry of the full list says
# whether it is chosen, which the game shows only by its colour; the confirm, select-all and cancel rows say their text.

# The full list as the game keeps it: its rows, the chosen flags and the indexes of its three action rows.
class Window_MultiSelectFilterList < Window_DrawableCommand
  attr_accessor :selected_flags, :confirm_index, :selall_index, :cancel_index
  def initialize(commands); super(commands); @selected_flags = []; end
end

# The scene: its full list under "option", repainted with the same rows after each toggle.
class MultiSelectOptionsScene
  def initialize(win); @sprites = { "option" => win }; end
  def refreshList; :refreshed; end
end

if_multi_path = File.join(Harness::ROOT, "games", "infinitefusion_common", "multi_select.rb")
eval(Harness.source(if_multi_path), TOPLEVEL_BINDING, if_multi_path)

class IfMultiSelectGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # The randomizer's list of reference categories, the second one chosen, with its action rows at the end.
  def list
    win = Window_MultiSelectFilterList.new(["Gen 1 (34)", "Anime (12)", "Confirm", "Select all", "Cancel"])
    win.selected_flags = [false, true]
    win.confirm_index = 2
    win.selall_index = 3
    win.cancel_index = 4
    win
  end

  def focused(win, i)
    win.index = i
    PokeAccess::Menus.focused_text(win)
  end

  test "says whether each entry is chosen" do
    assert_equal "Gen 1 (34), #{T.t(:if_ms_not_chosen)}", focused(list, 0)
    assert_equal "Anime (12), #{T.t(:if_ms_chosen)}", focused(list, 1)
  end

  test "says the confirm, select-all and cancel rows as they are painted" do
    assert_equal %w[Confirm Select\ all Cancel], [2, 3, 4].map { |i| focused(list, i) }
  end

  test "says an entry's new state when a toggle repaints it under a still cursor" do
    win = list
    win.index = 1
    scene = MultiSelectOptionsScene.new(win)
    SpeakCapture.clear
    win.update
    win.selected_flags = [false, false]
    win.update
    assert_equal ["Anime (12), #{T.t(:if_ms_chosen)}"], SpeakCapture.lines, "no repaint, no read"
    assert_equal :refreshed, scene.refreshList
    win.update
    assert_equal "Anime (12), #{T.t(:if_ms_not_chosen)}", SpeakCapture.last
  end

  test "takes an entry with no flag yet as not chosen" do
    win = list
    win.selected_flags = []
    assert_equal "Anime (12), #{T.t(:if_ms_not_chosen)}", focused(win, 1)
  end
end
