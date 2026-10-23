# FL's Character Selection before its classes moved into a module (plugins/fl_character_selection_v1.rb), over a
# stand-in of its CharacterSelectionScene as Pokemon Decades ships it: the title window as it opens, each new character
# under the cursor in the loop that waits for the keys, and the confirmation's question.
class CharacterSelectionScene
  def initialize(moves = [])
    @moves = moves
  end

  def pbStartScene(overworld, battle)
    @overworld = overworld
    @battle = battle
    @sprites = { "messagebox" => Window_AdvancedTextPokemon.new("Choose your character.") }
    @index = 0
    :started
  end

  def pbMidScene
    PokeAccess::Frame.run_pollers
    @moves.each do |i|
      @index = i
      PokeAccess::Frame.run_pollers
    end
    @index
  end

  def pbDisplayConfirm(_text)
    true
  end
end
character_v1_path = File.join(Harness::ROOT, "plugins", "fl_character_selection_v1.rb")
eval(Harness.source(character_v1_path), TOPLEVEL_BINDING, character_v1_path)

class FlCharacterSelectionV1Test < PokeAccessTest
  OVERWORLD = ["trainer_Brendan", "trainer_May"]
  BATTLE = ["Brendan", "May"]

  test "says the title window as it opens, then the first character, queued" do
    play
    assert_equal [["Choose your character.", false], ["Brendan, 1 de 2", false]], SpeakCapture.log
  end

  test "says each character the cursor moves to, cutting in" do
    play([1, 0])
    assert_equal [["May, 2 de 2", true], ["Brendan, 1 de 2", true]], SpeakCapture.log[2..-1]
  end

  test "says the confirmation's question as the game writes it, and hands back the game's answer" do
    scene = CharacterSelectionScene.new
    scene.pbStartScene(OVERWORLD, BATTLE)
    SpeakCapture.clear
    assert_equal true, scene.pbDisplayConfirm("Are you sure?")
    assert_equal [["Are you sure?", false]], SpeakCapture.log
  end

  private

  def play(moves = [])
    scene = CharacterSelectionScene.new(moves)
    scene.pbStartScene(OVERWORLD, BATTLE)
    scene.pbMidScene
  end
end
