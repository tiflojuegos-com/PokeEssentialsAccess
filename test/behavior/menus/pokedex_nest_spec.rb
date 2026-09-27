# The gen-6 nest page (PokemonNestMapScene): its bottom bar, then the squares its point sprites light, named by the
# town map's points (a point behind a switch still off gives way to the one the square shows).
Suite.define("pokedex (gen-6): the nest page says its bar, then the places its map lights") do
  t = PokeAccess::I18n
  scene = PokemonNestMapScene.new
  scene.mapdata = { 0 => ["Kanto", "kanto.png",
                          [[3, 2, "Ruta 1"], [4, 2, "Ruta 1"], [10, 5, "Bosque"],
                           [12, 7, "Cueva", nil, nil, nil, nil, 50], [12, 7, "Pradera"], [20, 9, "Isla"]]],
                    1 => ["Johto", "johto.png", [[3, 2, "Ruta 29"]]] }
  scene.lit = [[3, 2], [4, 2], [10, 5], [12, 7]]
  $game_switches[50] = false
  begin
    SpeakCapture.clear
    eq "the page keeps its own return", scene.pbStartScene(25, 0), true
    eq "the bar, then each lit place once, the switched-off point giving way to the one it shows",
       SpeakCapture.lines, ["Kanto, Nido de 25. #{t.t(:pdx_places, :list => 'placeRuta 1, placeBosque, placePradera')}"]

    SpeakCapture.clear
    scene.pbStartScene(25, 1)
    eq "the region asked for is the one whose places are named", SpeakCapture.lines,
       ["Kanto, Nido de 25. #{t.t(:pdx_places, :list => 'placeRuta 29')}"]

    SpeakCapture.clear
    scene.pbStartScene(25)
    match "with no region asked for, the player's own (region 0 where the map has none)", SpeakCapture.lines.join(" "),
          /placeBosque/

    SpeakCapture.clear
    scene.lit = []
    scene.pbStartScene(25, 0)
    eq "a species with no nests says only the bar", SpeakCapture.lines, ["Kanto, Nido de 25"]
  ensure
    $game_switches.delete(50)
  end
end

# Insurgence's nest page predates the region map's square constants (its PokemonRegionMapScene has only LEFT, TOP,
# RIGHT and BOTTOM) and lays its points 16 pixels apart: the places are still named.
Suite.define("pokedex (gen-6): a region map scene without square constants still names the lit places") do
  t = PokeAccess::I18n
  k = PokemonRegionMapScene
  saved = [:SQUAREWIDTH, :SQUAREHEIGHT].map { |c| [c, k.const_get(c)] }
  scene = PokemonNestMapScene.new
  scene.mapdata = { 0 => ["Torren", "torren.png", [[3, 2, "Helios City"], [10, 5, "Deyraan Town"]]] }
  scene.lit = [[3, 2], [10, 5]]
  begin
    saved.each { |c, _v| k.send(:remove_const, c) }
    SpeakCapture.clear
    scene.pbStartScene(776, 0)
    eq "the bar, then the places lit on the 16-pixel grid", SpeakCapture.lines,
       ["Kanto, Nido de 776. #{t.t(:pdx_places, :list => 'placeHelios City, placeDeyraan Town')}"]
  ensure
    saved.each { |c, v| k.const_set(c, v) unless k.const_defined?(c) }
  end
end
