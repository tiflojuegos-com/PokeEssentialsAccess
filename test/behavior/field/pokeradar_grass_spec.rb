# The Poke Radar's shaking grass (pbPokeRadarHighlightGrass), up to v19 kept in $PokemonTemp.pokeradar: after a
# search, each patch it shook by how it shakes and where it lies from the player, nearest ring first.
Suite.define("pokeradar: the patches a search shook are said by kind and place, nearest ring first") do
  t = PokeAccess::I18n
  old = $PokemonTemp
  begin
    $game_player.x = 10
    $game_player.y = 10
    $PokemonTemp = Struct.new(:pokeradar).new([:PIDGEY, 5, 0, [[11, 9, 0, 0], [8, 10, 1, 1], [10, 13, 2, 2]]])
    SpeakCapture.clear
    pbPokeRadarHighlightGrass
    patch = lambda { |kind, dx, dy| t.t(:radar_patch, :kind => t.t(kind), :where => PokeAccess::Locator.dir_phrase(dx, dy)) }
    eq "each patch by its shaking and its place, as the rings go out", SpeakCapture.lines,
       [[patch.call(:radar_kind_normal, 1, -1), patch.call(:radar_kind_vigorous, -2, 0),
         patch.call(:radar_kind_shiny, 0, 3)].join("; ")]

    $PokemonTemp.pokeradar = nil
    SpeakCapture.clear
    pbPokeRadarHighlightGrass
    silent "a search that shook nothing, the radar cancelled, adds nothing"

    $PokemonTemp.pokeradar = [:PIDGEY, 5, 0, [[3, 4]]]
    pbPokeRadarHighlightGrass
    silent "and patches without the stock ring and rarity are left to their own game"
  ensure
    $PokemonTemp = old
  end
end
