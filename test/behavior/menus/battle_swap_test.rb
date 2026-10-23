# The frontier rental list (BattleSwapScene): each row as the game names it, a rented one (painted red) with its chosen
# mark, which only the list whose loop runs carries; the title once, and each new help line after the next row read. A
# row rented or dropped through the popup is said again queued behind the popup's rows.
class BattleSwapTest < PokeAccessTest
  RED = "<c3=E82010,F8A8B8>"
  ROWS = ["Pikachu - Raton Pokemon", "Bulbasaur - Semilla Pokemon", "Eevee - Evolucion Pokemon"]

  test "says the focused row as the game names it, queued as the list opens" do
    choose(BattleSwapScene.new(ROWS.dup, []))
    assert_equal [[ROWS[0], false]], SpeakCapture.log
  end

  test "says a rented row with its chosen mark" do
    choose(BattleSwapScene.new([RED + ROWS[0], ROWS[1]], [0]))
    assert_equal [["#{ROWS[0]}, #{chosen}", false]], SpeakCapture.log
  end

  test "says a row not rented without the mark" do
    scene = BattleSwapScene.new([RED + ROWS[0], ROWS[1]], [0])
    choose(scene)
    SpeakCapture.clear
    choose(scene, 1)
    assert_equal [[ROWS[1], true]], SpeakCapture.log
  end

  test "says the row again with its mark once the popup rents it, queued behind the popup's rows" do
    scene = BattleSwapScene.new(ROWS.dup, [])
    choose(scene)
    SpeakCapture.clear
    popup("RENT")
    scene.pbUpdateChoices([0], [RED + ROWS[0], ROWS[1], ROWS[2]])
    choose(scene)
    assert_equal [["SUMMARY", false], ["RENT", true], ["#{ROWS[0]}, #{chosen}", false]], SpeakCapture.log
  end

  test "a row the popup drops from the choices loses the mark, queued behind the popup's rows" do
    scene = BattleSwapScene.new([RED + ROWS[0], ROWS[1]], [0])
    choose(scene)
    SpeakCapture.clear
    popup("DESELECT")
    scene.pbUpdateChoices([], ROWS.dup)
    choose(scene)
    assert_equal [["SUMMARY", false], ["DESELECT", true], [ROWS[0], false]], SpeakCapture.log
  end

  test "marks nothing where the scene keeps no choices" do
    choose(BattleSwapScene.new([RED + ROWS[0]], nil))
    assert_equal [[ROWS[0], false]], SpeakCapture.log
  end

  test "another window of the list's class, read while the loop runs, gets neither the mark nor the prompt" do
    scene = BattleSwapScene.new([RED + ROWS[0]], [0])
    scene.pbStartSwapScene(nil, nil)
    other = Window_AdvancedCommandPokemonEx.new([RED + "Rojo"])
    scene.on_choose = lambda { other.update }
    scene.pbChoosePokemon(false)
    assert_equal [["POKéMON SWAP", false], ["Rojo", false]], SpeakCapture.log
  end

  test "a prompt due while another window is read waits for the list's own row" do
    scene = BattleSwapScene.new([RED + ROWS[0]], [0])
    scene.pbStartSwapScene(nil, nil)
    other = Window_AdvancedCommandPokemonEx.new(["Rojo"])
    scene.on_choose = lambda { other.update }
    scene.pbChoosePokemon(false)
    SpeakCapture.clear
    choose(scene)
    assert_equal [["#{ROWS[0]}, #{chosen}. Select Pokémon to swap.", false]], SpeakCapture.log
  end

  test "outside its loop, a rented row is read without the mark" do
    scene = BattleSwapScene.new([RED + ROWS[0], RED + ROWS[1]], [0, 1])
    choose(scene)
    SpeakCapture.clear
    scene.list.index = 1
    scene.list.update
    assert_equal [[ROWS[1], true]], SpeakCapture.log
  end

  test "a loop that raises still ends the watch" do
    scene = BattleSwapScene.new([RED + ROWS[0], RED + ROWS[1]], [0, 1])
    list = scene.list
    scene.on_choose = lambda do
      list.update
      raise "the game's loop fails"
    end
    assert_raises(RuntimeError) { scene.pbChoosePokemon(false) }
    SpeakCapture.clear
    list.index = 1
    list.update
    assert_equal [[ROWS[1], true]], SpeakCapture.log
  end

  test "says the title, then the focused row and its prompt, queued, as the rental list first opens" do
    choose(rent_scene)
    assert_equal [["RENTAL POKéMON", false], ["#{ROWS[0]}. Choose the first Pokémon.", false]], SpeakCapture.log
  end

  test "a move under the same prompt says the row alone, the title not again" do
    scene = rent_scene
    choose(scene)
    SpeakCapture.clear
    choose(scene, 1)
    assert_equal [[ROWS[1], true]], SpeakCapture.log
  end

  test "a prompt is said once, however many times the list's loop runs under it" do
    scene = rent_scene
    choose(scene)
    choose(scene, 1)
    SpeakCapture.clear
    choose(scene, 2)
    assert_equal [[ROWS[2], true]], SpeakCapture.log
  end

  test "a new prompt is said after the next row read" do
    scene = rent_scene
    choose(scene)
    SpeakCapture.clear
    popup("RENT")
    scene.sprites["help"].text = "Choose the second Pokémon."
    scene.pbUpdateChoices([0], [RED + ROWS[0], ROWS[1], ROWS[2]])
    choose(scene)
    assert_equal [["SUMMARY", false], ["RENT", true], ["#{ROWS[0]}, #{chosen}. Choose the second Pokémon.", false]],
                 SpeakCapture.log
  end

  test "a screen without a title or a help window says the row alone" do
    scene = rent_scene
    scene.sprites.delete("title")
    scene.sprites.delete("help")
    choose(scene)
    assert_equal [[ROWS[0], false]], SpeakCapture.log
  end

  test "a help window that cannot be read adds no prompt" do
    scene = BattleSwapScene.new(ROWS.dup, [])
    help = Object.new
    def help.text; raise "the window is gone"; end
    scene.sprites["help"] = help
    choose(scene)
    assert_equal [[ROWS[0], false]], SpeakCapture.log
  end

  private

  # The word a rented row carries.
  def chosen
    PokeAccess::I18n.t(:swap_chosen)
  end

  # Runs the scene's list loop once, the cursor first moved to index when given.
  def choose(scene, index = nil)
    list = scene.list
    scene.on_choose = lambda do
      list.index = index if index
      list.update
    end
    scene.pbChoosePokemon(false)
  end

  # The popup the button on a row opens (sevii/0162_PBattle_BattleSwap.rb:170-178): SUMMARY, the choice, OTHERS, read
  # as the cursor goes down to the choice, outside the list's loop.
  def popup(choice)
    win = Window_DrawableCommand.new(["SUMMARY", choice, "OTHERS"])
    win.index = 0
    win.active = true
    win.update
    win.index = 1
    win.update
  end

  # The rental screen as its opener leaves it: the title and the first prompt written, nothing rented.
  def rent_scene
    scene = BattleSwapScene.new(ROWS.dup, [])
    scene.pbStartRentScene(nil)
    scene
  end
end
