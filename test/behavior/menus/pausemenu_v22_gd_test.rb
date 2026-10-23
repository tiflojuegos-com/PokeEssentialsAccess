# The v22 pause menu (UI::PauseMenuVisuals): set_commands claims its command window from the generic reader, and each
# frame reads the focused command's name once, by the window's cursor.
class PausemenuV22GdTest < PokeAccessTest
  COMMANDS = [[:pokedex, :pokemon, :bag], ["Pokedex", "Pokemon", "Bolsa"]].freeze

  test "the command window it claims is not read when it updates on its own" do
    win = menu.sprites[:commands]
    win.index = 1
    win.update
    assert_nothing_spoken
  end

  test "the first frame reads the focused command once, interrupting" do
    menu.update_visuals
    assert_equal [["Pokedex", true]], SpeakCapture.log
  end

  test "a frame with the cursor unmoved says nothing" do
    opened_menu.update_visuals
    assert_nothing_spoken
  end

  test "moving the cursor reads the new command" do
    vis = opened_menu
    vis.sprites[:commands].index = 2
    vis.update_visuals
    assert_equal [["Bolsa", true]], SpeakCapture.log
  end

  test "a reopened pause menu reads its focused command again" do
    opened_menu
    menu.update_visuals
    assert_equal [["Pokedex", true]], SpeakCapture.log
  end

  test "a frame with no command focused says nothing" do
    vis = menu
    vis.sprites[:commands].index = -1
    vis.update_visuals
    assert_nothing_spoken
  end

  test "a frame before the commands are set says nothing" do
    UI::PauseMenuVisuals.new.update_visuals
    assert_nothing_spoken
  end

  private

  # A pause menu with COMMANDS set, its cursor on the first.
  def menu
    vis = UI::PauseMenuVisuals.new
    vis.set_commands(COMMANDS)
    vis
  end

  # A pause menu whose first frame was read, the speech cleared.
  def opened_menu
    vis = menu
    vis.update_visuals
    SpeakCapture.clear
    vis
  end
end
