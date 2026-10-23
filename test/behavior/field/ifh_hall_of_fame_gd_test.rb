# Hoenn's end-of-part Hall of Fame (games/infinitefusion_hoenn/hall_of_fame.rb): a subclass of the modern screen that
# paints its own welcome, a line with the date and game mode, and its completion box, each said queued as painted; the
# member panel it inherits is read once, though the hall's reader is bound to it and to its parent.

# The scene as Hoenn defines it, none of its own paints going through its parent's methods.
class HallOfFameSimple_Scene < HallOfFame_Scene
  def writeWelcome
    pbDrawTextPositions(nil, [["Pokémon Infinite Fusion 2: Hoenn", 256, 304, 2], ["Part 1", 256, 334, 2]])
  end

  def writeInfo
    pbDrawTextPositions(nil, [["Pokémon Infinite Fusion 2: Hoenn (Part 1)", 256, 304, 2]])
    pbDrawTextPositions(nil, [["27/09/2026", 120, 334, 2]])
    pbDrawTextPositions(nil, [["Classic (Normal)", 356, 334, 2]])
  end

  def writeTrainerData
    @sprites = { "messagebox" => Window_AdvancedTextPokemon.new("Pokédex:<r>40 / 501<br>Side Quests:<r>3 / 34<br>") }
  end
end

ifh_hof_path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "hall_of_fame.rb")
eval(Harness.source(ifh_hof_path), TOPLEVEL_BINDING, ifh_hof_path)

class IfhHallOfFameGdTest < PokeAccessTest
  test "its own welcome is said as painted, queued" do
    HallOfFameSimple_Scene.new.writeWelcome
    assert_equal [["Pokémon Infinite Fusion 2: Hoenn, Part 1", false]], SpeakCapture.log
  end

  test "its date and game mode are said as painted, queued" do
    HallOfFameSimple_Scene.new.writeInfo
    assert_equal [["Pokémon Infinite Fusion 2: Hoenn (Part 1), 27/09/2026, Classic (Normal)", false]], SpeakCapture.log
  end

  test "its completion box is read row by row, queued" do
    HallOfFameSimple_Scene.new.writeTrainerData
    assert_equal [["Pokédex: 40 / 501, Side Quests: 3 / 34", false]], SpeakCapture.log
  end

  test "the member panel it inherits is read once" do
    HallOfFameSimple_Scene.new.writePokemonData(Poke.build(:name => "Chispa", :level => 50), -1)
    assert_equal [["No. 025, Chispa Lv. 50", false]], SpeakCapture.log
  end
end
