# Luka's Modular Menu (plugins/modular_menu.rb): the pause menu's focused entry by the name its panel paints, with its
# place, as @index moves; the Safari or contest box it paints on opening, queued before the entry, which is said once
# though the opening ends on an update; the entry again back from a screen it opened; nothing once it closes, nor in a
# game without the plugin.

# The stub's pause menu does what the plugin's scene does: its opening paints the Safari or contest box (@box, rows as
# pbDrawTextPositions takes them) and ends on an update, as the game's pbStartScene does; and it gains its frame and its
# close. The opening replaces the stub's, whose wrapper the harness bound at load, so that one wrapper is put back over
# it as after an F12 reset; the frame's and the close's hooks found no method at load and are evaluated again.
class PokemonPauseMenu_Scene
  def pbStartScene
    pbDrawTextPositions(nil, @box || [])
    update
  end

  def update; :frame; end
  def pbEndScene; :closed; end
end
pause_bound = PokeAccess::Hooks.instance_variable_get(:@bound)
pause_opener = pause_bound.select { |r| r[0] == PokemonPauseMenu_Scene && r[1] == :pbStartScene }
PokeAccess::Hooks.instance_variable_set(:@bound, pause_opener)
begin
  PokeAccess::Hooks.rebind
ensure
  PokeAccess::Hooks.instance_variable_set(:@bound, pause_bound)
end
pause_path = File.join(Harness::ROOT, "plugins", "modular_menu.rb")
pause_source = Harness.source(pause_path)
pause_source.scan(/^PokeAccess::Hooks\.(?:after|before)_hook\("PokemonPauseMenu_Scene", :(?:update|pbEndScene).*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, pause_path, pause_source[0, hook.begin(0)].count("\n") + 1)
end

class ModularMenuGdTest < PokeAccessTest
  # The plugin's entry table, as ModularMenu.name answers it: a registered entry's name, the trainer card's already
  # the player's own after the menu's refresh.
  NAMES = { :POKEDEX => "Pokédex", :POKEMON => "Pokémon", :BAG => "Bag", :TRAINER => "Red", :SAVE => "Save" }

  def setup
    super
    Object.const_set(:ModularMenu, Module.new) unless Object.const_defined?(:ModularMenu)
    ::ModularMenu.define_singleton_method(:name) { |key| NAMES[key] }
  end

  def teardown
    Object.send(:remove_const, :ModularMenu) if Object.const_defined?(:ModularMenu)
    PokeAccess::ModularPause.closed
    super
  end

  test "the opening says the box the menu paints, then the focused entry with its place once, both queued" do
    scene = menu(2)
    scene.instance_variable_set(:@box, [["Steps: 120/600", 16, 54, 0, nil, nil], ["Balls: 30", 16, 104, 0, nil, nil]])
    scene.pbStartScene
    scene.update
    scene.update
    assert_equal [["Steps: 120/600, Balls: 30", false], ["Bag, 3 de 5", false]], SpeakCapture.log
  end

  test "outside the Safari and the contest the opening says the focused entry alone, once" do
    scene = menu(0)
    scene.pbStartScene
    scene.update
    scene.update
    assert_equal [["Pokédex, 1 de 5", false]], SpeakCapture.log
  end

  test "opened again over the same scene, as a save given up does, the focused entry is said again, once" do
    scene = menu(4)
    scene.pbStartScene
    scene.update
    scene.pbEndScene
    SpeakCapture.clear
    scene.pbStartScene
    scene.update
    scene.update
    assert_equal [["Save, 5 de 5", false]], SpeakCapture.log
  end

  test "moving the cursor says each entry once, interrupting" do
    scene = menu(0)
    scene.pbStartScene
    scene.update
    SpeakCapture.clear
    scene.instance_variable_set(:@index, 3)
    scene.update
    scene.update
    assert_equal [["Red, 4 de 5", true]], SpeakCapture.log
  end

  test "back from a screen an entry opened, the focused entry is said again; not once the menu has closed" do
    scene = menu(1)
    scene.pbStartScene
    scene.update
    SpeakCapture.clear
    PokeAccess::MenuReturn.fire
    scene.update
    scene.pbEndScene
    PokeAccess::MenuReturn.fire
    scene.update
    assert_equal [["Pokémon, 2 de 5", false]], SpeakCapture.log
  end

  test "a game without the plugin hears nothing from it" do
    Object.send(:remove_const, :ModularMenu)
    scene = menu(0)
    scene.pbStartScene
    scene.update
    assert_nothing_spoken
  end

  private

  # The menu with its five entries and the cursor on index i.
  def menu(i)
    scene = PokemonPauseMenu_Scene.new
    scene.instance_variable_set(:@entries, NAMES.keys)
    scene.instance_variable_set(:@index, i)
    scene
  end
end
