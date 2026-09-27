load File.expand_path("../../../games/pokemon_z/pokedex.rb", File.dirname(__FILE__)) unless defined?(PokeAccess::ZPokedex)

# Pokemon Z's own dex entry: the page count in the mod's words, each move list under the title the game paints (the
# running build's text; here the Spanish source).
Suite.define("pokemon z dex: a page says where it is, and its moves under the game's own title") do
  scene = Object.new
  { :@page => 2, :@totalPages => 3, :@infoPages => 1, :@levelMovesPages => 1, :@eggMovesPages => 1,
    :@levelMovesArray => ["Nv. 1 Placaje", "Nv. 5 Gruñido"] }.each { |k, v| scene.instance_variable_set(k, v) }
  eq "the page, the painted title and the moves", PokeAccess::ZPokedex.page_text(scene),
     "#{PokeAccess::I18n.t(:adv_dex_page, :n => 2, :m => 3)}. MOVIMIENTOS POR NIVEL: Nv. 1 Placaje Nv. 5 Gruñido"
  PokeAccess::Config.verbosity = :brief
  match "brief: the page's words without where it is, a page being a position", PokeAccess::ZPokedex.page_text(scene).to_s,
        /\AMOVIMIENTOS POR NIVEL: Nv\. 1 Placaje/
  PokeAccess::Config.verbosity = :full
  scene.instance_variable_set(:@page, 3)
  scene.instance_variable_set(:@eggMovesArray, ["Mordisco"])
  match "and the egg moves under theirs", PokeAccess::ZPokedex.page_text(scene).to_s, /MOVIMIENTOS HUEVO: Mordisco\z/
end
