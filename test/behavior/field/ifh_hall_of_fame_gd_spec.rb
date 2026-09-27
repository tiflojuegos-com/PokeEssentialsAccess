# Hoenn's end-of-part Hall of Fame (HallOfFameSimple_Scene): a subclass of the modern screen that paints its own
# welcome, a line with the date and game mode, and its completion box, none of them through its parent's methods.
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

load File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "hall_of_fame.rb")

Suite.define("ifh hall of fame: the end of part one says its welcome, its date and mode, then its completion box") do
  scene = HallOfFameSimple_Scene.new
  SpeakCapture.clear
  scene.writeWelcome
  scene.writeInfo
  eq "the welcome and the date and mode line, both queued as painted", SpeakCapture.log,
     [["Pokémon Infinite Fusion 2: Hoenn, Part 1", false],
      ["Pokémon Infinite Fusion 2: Hoenn (Part 1), 27/09/2026, Classic (Normal)", false]]
  SpeakCapture.clear
  scene.writeTrainerData
  eq "the completion box row by row, queued", SpeakCapture.log, [["Pokédex: 40 / 501, Side Quests: 3 / 34", false]]
end
