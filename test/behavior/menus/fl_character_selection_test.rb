# FL's Character Selection (plugins/fl_character_selection.rb) over a stand-in of its scene: the title window as it opens,
# then, in the loop that waits for the keys, each new character under the cursor with its place and the name its graphic file
# carries, and the confirmation's question.
module CharacterSelection
  class Scene
    def initialize(moves = [])
      @moves = moves
    end

    def start(overworld, battle)
      @overworld = overworld
      @battle = battle
      @sprites = { "messagebox" => Window_AdvancedTextPokemon.new("Choose your character.") }
      @index = 0
      :started
    end

    def main_loop
      PokeAccess::Frame.run_pollers
      @moves.each do |i|
        @index = i
        PokeAccess::Frame.run_pollers
      end
      @index
    end

    def display_confirm(_text)
      true
    end
  end
end
character_path = File.join(Harness::ROOT, "plugins", "fl_character_selection.rb")
eval(Harness.source(character_path), TOPLEVEL_BINDING, character_path)

class FlCharacterSelectionTest < PokeAccessTest
  STRINGS = { "charsel_slot" => "Personaje %{n} de %{tot}" }
  OVERWORLD = ["trainer_POKEMONTRAINER_Red", "trainer_POKEMONTRAINER_Leaf"]
  BATTLE = ["POKEMONTRAINER_Red", "POKEMONTRAINER_Leaf"]

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @saved = STRINGS.keys.map { |k| [k, table[k]] }
    STRINGS.each { |k, v| table[k] = v }
  end

  def teardown
    table = PokeAccess::I18n.table(:es)
    (@saved || []).each { |k, v| v.nil? ? table.delete(k) : table[k] = v }
    super
  end

  test "says the title window as it opens, queued" do
    CharacterSelection::Scene.new.start(OVERWORLD, BATTLE)
    assert_equal [["Choose your character.", false]], SpeakCapture.log
  end

  test "says the first character as the loop starts, queued behind the title" do
    play(OVERWORLD, BATTLE)
    assert_equal [["Choose your character.", false], ["POKEMONTRAINER Red, 1 de 2", false]], SpeakCapture.log
  end

  test "says each character the cursor moves to, cutting in, and none twice in a row" do
    play(OVERWORLD, BATTLE, [1, 1, 0])
    assert_equal [["POKEMONTRAINER Leaf, 2 de 2", true], ["POKEMONTRAINER Red, 1 de 2", true]], SpeakCapture.log[2..-1]
  end

  test "says only the place when the graphic files name nobody readable" do
    play(["trchar000", "trchar001"], ["trainer000", "trainer001"], [1])
    assert_equal ["Personaje 1 de 2", "Personaje 2 de 2"], SpeakCapture.lines[1..-1]
  end

  test "takes the name from the overworld file when the battle file has none" do
    play(["trainer_Brendan", "trainer_May"], ["b", "m"], [1])
    assert_equal ["Brendan, 1 de 2", "May, 2 de 2"], SpeakCapture.lines[1..-1]
  end

  test "says nothing of characters for a scene with no lists" do
    play([], [])
    assert_equal ["Choose your character."], SpeakCapture.lines
  end

  test "cleans a graphic file name down to the name it carries" do
    { "trainer_POKEMONTRAINER_Red" => "POKEMONTRAINER Red", "POKEMONTRAINER_Leaf" => "POKEMONTRAINER Leaf",
      "Graphics/Characters/trainer_Brendan.png" => "Brendan", "Red" => "Red", "player_blue" => "blue",
      "boy-walk" => "boy walk", "Charizard" => "Charizard", "trainer_2nd_Hero" => "2nd Hero",
      "trainer_Jo" => "Jo", "trchar000" => nil, "trainer000" => nil, "player_m" => nil, "trainer_" => nil,
      "007" => nil, nil => nil
    }.each do |file, name|
      got = PokeAccess::FLCharacterSelection.file_name(file)
      name.nil? ? assert_nil(got, file.inspect) : assert_equal(name, got, file.inspect)
    end
  end

  test "says the confirmation's question as the game writes it, queued, and hands back the game's answer" do
    scene = CharacterSelection::Scene.new
    scene.start(OVERWORLD, BATTLE)
    SpeakCapture.clear
    assert_equal true, scene.display_confirm("Are you sure?")
    assert_equal [["Are you sure?", false]], SpeakCapture.log
  end

  test "hands back the scene's own values" do
    scene = CharacterSelection::Scene.new([1])
    assert_equal [:started, 1], [scene.start(OVERWORLD, BATTLE), scene.main_loop]
  end

  test "stops reading the cursor once the loop has returned" do
    scene = CharacterSelection::Scene.new([1])
    scene.start(OVERWORLD, BATTLE)
    scene.main_loop
    SpeakCapture.clear
    scene.instance_variable_set(:@index, 0)
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  test "says the first character again when the screen opens a second time" do
    2.times { play(OVERWORLD, BATTLE) }
    assert_equal 2, SpeakCapture.lines.count { |l| l == "POKEMONTRAINER Red, 1 de 2" }
  end

  private

  # Opens the screen over the lists and runs its loop through the cursor moves.
  def play(overworld, battle, moves = [])
    scene = CharacterSelection::Scene.new(moves)
    scene.start(overworld, battle)
    scene.main_loop
  end
end
