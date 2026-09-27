# FL's Advanced Pokedex (Relict, Awakening): the sub-pages of a fourth entry page (displaySubPage) read down each
# column, with their count; on the way in the name and the types lead.
Suite.define("advanced pokedex: a sub-page reads down each column, with its count; the name and types lead on the way in") do
  ap = PokeAccess::AdvancedPokedex
  scene = Object.new
  scene.instance_variable_set(:@type1, :ELECTRIC)
  paint = lambda do |grid, count|
    PokeAccess::PaintCapture.arm(:adv_spec)
    pbDrawTextPositions(nil, [["Pikachu", 292, 298], [count, 460, 330]])
    pbDrawTextPositions(nil, grid)
    PokeAccess::PaintCapture.take_pairs(:adv_spec)
  end
  info = [["PS: 35", 30, 66], ["Velocidad: 90", 254, 66], ["Ataque: 55", 30, 98], ["Defensa: 40", 254, 98]]
  eq "down the first column, then the second, then the count", ap.text(scene, paint.call(info, "2/7"), false),
     ["PS: 35", "Ataque: 55", "Velocidad: 90", "Defensa: 40",
      PokeAccess::I18n.t(:adv_dex_page, :n => "2", :m => "7")].join(", ")
  PokeAccess::Config.verbosity = :brief
  eq "brief: the columns without the count, a page being a position", ap.text(scene, paint.call(info, "2/7"), false),
     ["PS: 35", "Ataque: 55", "Velocidad: 90", "Defensa: 40"].join(", ")
  PokeAccess::Config.verbosity = :full
  moves = [["MOVIMIENTOS POR NIVEL:", 30, 66], ["Nv. 1 Impactrueno", 30, 98], ["Nv. 5 Gruñido", 254, 98]]
  eq "on the way in: the name and the types the icons show lead", ap.text(scene, paint.call(moves, "1/7"), true),
     ["Pikachu", PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Data.type_name(:ELECTRIC)),
      "MOVIMIENTOS POR NIVEL: Nv. 1 Impactrueno", "Nv. 5 Gruñido",
      PokeAccess::I18n.t(:adv_dex_page, :n => "1", :m => "7")].join(", ")
end

# Any page an addon adds past the vanilla three is its own page, read as painted -- not the info page again.
Suite.define("pokedex entry: a page past the vanilla three is read as painted, not as the info page") do
  scene = Object.new
  eq "page 4 of a plain screen is a page of its own", PokeAccess::PokedexInfoV21.page_id(scene, 4), :page_other
  eq "the vanilla three keep their names", PokeAccess::PokedexInfoV21.page_id(scene, 2), :page_area
  PokeAccess::PokedexInfoV21.painted_rows = ["Datos avanzados", "PS: 35"]
  eq "and it reads what it painted", PokeAccess::PokedexInfoV21.other_text, "Datos avanzados, PS: 35"
  PokeAccess::PokedexInfoV21.painted_rows = []
  falsy "an addon that took the paint itself leaves nothing to repeat", PokeAccess::PokedexInfoV21.other_text
end

# drawPage(4) is read by the plugin's reader alone, with its own capture; it and the core page reader each forget
# their last page when the other takes over.
Suite.define("advanced pokedex: opening page 4 is read by its own reader, and only by it") do
  scene = PokemonPokedexInfo_Scene.new
  scene.instance_variable_set(:@type1, :ELECTRIC)
  scene.instance_variable_set(:@paint, lambda do
    pbDrawTextPositions(nil, [["Pikachu", 292, 298], ["1/7", 460, 330]])
    pbDrawTextPositions(nil, [["PS: 35", 30, 66], ["Ataque: 55", 30, 98]])
  end)
  SpeakCapture.clear
  eq "drawPage keeps its return", scene.drawPage(4), 4
  eq "on the way in: the name, the types, the grid and its count, said once", SpeakCapture.lines,
     [["Pikachu", PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Data.type_name(:ELECTRIC)), "PS: 35", "Ataque: 55",
       PokeAccess::I18n.t(:adv_dex_page, :n => "1", :m => "7")].join(", ")]

  PokeAccess::Cursor.changed?(scene, :pdx_page, "Pikachu. Pokemon Raton.")
  scene.drawPage(4)
  eq "arriving on page 4, the core reader forgets the page it said", PokeAccess::Cursor.current(scene, :pdx_page), nil
  scene.instance_variable_set(:@paint, nil)
  scene.drawPage(1)
  eq "and leaving it, this reader forgets page 4, to say it again on the way back",
     PokeAccess::Cursor.current(scene, :adv_dex), nil
end
