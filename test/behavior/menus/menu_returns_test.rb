# Back in a menu that runs its options inline (the classic pause menu's command loop, Voltseon's carousel), the
# focused option is said again; within one pass of the menu it is said once.
class MenuReturnsTest < PokeAccessTest
  test "the classic pause menu says the focused option on each entry to its command loop" do
    scene = PokemonMenu_Scene.new
    scene.pbShowCommands([])
    assert_equal [["Pokédex", false]], SpeakCapture.log, "the opening"
    SpeakCapture.clear
    scene.pbShowCommands([])
    assert_equal [["Pokédex", false]], SpeakCapture.log, "the loop entered again after an option"
  end

  test "within one pass of the classic pause menu's loop the option is said once" do
    scene = PokemonMenu_Scene.new
    scene.pbShowCommands([])
    SpeakCapture.clear
    PokeAccess.sprite(scene, "cmdwindow").update
    assert_nothing_spoken
  end

  test "with Voltseon's carousel up, an option's return says the entry again" do
    carousels.each do |what, (menu, scene)|
      SpeakCapture.clear
      PokeAccess::VoltseonMenu.read(menu)
      PokeAccess::VoltseonMenu.read(menu)
      assert_equal [["Bolsa", false]], SpeakCapture.log, "#{what}: the entry once while it stays"
      SpeakCapture.clear
      held_by(scene) { option_returns }
      PokeAccess::VoltseonMenu.read(menu)
      assert_equal [["Bolsa", false]], SpeakCapture.log, "#{what}: the refresh after the option says it again"
    end
  end

  test "a return while Voltseon's carousel is not up, or once its loop has ended, changes nothing" do
    { "never up" => false, "its loop ended" => true }.each do |what, was_up|
      menu, scene = carousels["1.x"]
      held_by(scene) {} if was_up
      PokeAccess::VoltseonMenu.read(menu)
      SpeakCapture.clear
      option_returns
      PokeAccess::VoltseonMenu.read(menu)
      assert_nothing_spoken what
    end
  end

  private

  # Voltseon's two shapes, each [menu, scene holding it]: 1.x's entry objects under @currentSelection and
  # @pauseMenu, 2.x's entry hashes under @current_selection and @pause_menu.
  def carousels
    v1 = World.stub_scene(:@entries => [Struct.new(:name).new("Bolsa")], :@currentSelection => 0)
    v2 = World.stub_scene(:@entries => [{ :name => "Bolsa" }], :@current_selection => 0)
    { "1.x" => [v1, World.stub_scene(:@pauseMenu => v1)], "2.x" => [v2, World.stub_scene(:@pause_menu => v2)] }
  end

  # Runs the block with scene's loop held, as the hook on the menu scene's update holds it.
  def held_by(scene)
    PokeAccess::VoltseonMenu.watch(scene)
    yield
  ensure
    PokeAccess::VoltseonMenu.unwatch
  end

  # An option's screen closing back to the menu, no other subscreen open: the outermost return seam fires its
  # listeners. The return nesting is put at rest before and after.
  def option_returns
    PokeAccess::MenuReturn.reset_nesting
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  ensure
    PokeAccess::MenuReturn.reset_nesting
  end
end
