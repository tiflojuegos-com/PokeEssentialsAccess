# Infinite Fusion's Pokedex entry pages a long entry (150 characters a page) and flips without drawPage: a flip reads
# the page's text, then which page it is.
class PokemonPokedexInfo_Scene
  def changeEntryPage
    drawTextEx(nil, 425, 340, 400, 4, "2/2")
    drawTextEx(nil, 40, 244, 400, 4, "y se esconde entre las rocas.")
    :flipped
  end
  # Hoenn's Q/W: the info page repainted for another sprite, its artist line and, for a fusion, its entry.
  def update_displayed_sprite(_delta)
    pbDrawTextPositions(nil, [["Sprite: Artista#9", 224, 156]])
    drawTextEx(nil, 40, 244, 400, 4, @entry_shown || "Una entrada.")
    :switched
  end
end
load File.expand_path("../../../games/infinitefusion_common/entry_pages.rb", File.dirname(__FILE__))

Suite.define("infinite fusion: flipping a long entry says the page it shows and which it is") do
  SpeakCapture.clear
  eq "the flip keeps its return", PokemonPokedexInfo_Scene.new.changeEntryPage, :flipped
  eq "the page's text, then where it stands", SpeakCapture.lines,
     ["y se esconde entre las rocas. #{PokeAccess::I18n.t(:if_entry_page, :n => 2, :m => 2)}"]
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  PokemonPokedexInfo_Scene.new.changeEntryPage
  eq "brief: the page's text alone, the page it is being a position", SpeakCapture.lines, ["y se esconde entre las rocas."]
  PokeAccess::Config.verbosity = :full
end

Suite.define("infinite fusion hoenn: switching the info page's sprite says its artist, and the entry when it changes") do
  scene = PokemonPokedexInfo_Scene.new
  PokeAccess::Cursor.store(scene, :pdx_page, "Pikachu. Una entrada. Sprite: Artista#1")
  SpeakCapture.clear
  eq "the switch keeps its return", scene.update_displayed_sprite(1), :switched
  eq "the new sprite's artist, the entry heard with the page left out", SpeakCapture.lines, ["Sprite: Artista#9"]
  scene.instance_variable_set(:@entry_shown, "Otra entrada de fusión.")
  SpeakCapture.clear
  scene.update_displayed_sprite(1)
  eq "a fusion's custom entry that changed with the sprite follows it", SpeakCapture.lines,
     ["Sprite: Artista#9. Otra entrada de fusión."]
end
