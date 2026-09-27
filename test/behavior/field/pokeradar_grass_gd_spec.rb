# The Poke Radar's shaking grass from v20, kept in $game_temp.poke_radar_data: the same patches, read from there.
Suite.define("pokeradar: from v20 the patches come from $game_temp, said the same way") do
  t = PokeAccess::I18n
  data = [:PIDGEY, 5, 2, [[5, 4, 0, 2]]]
  $game_temp.define_singleton_method(:poke_radar_data) { data }
  begin
    $game_player.x = 5
    $game_player.y = 5
    SpeakCapture.clear
    pbPokeRadarHighlightGrass
    eq "the shiny patch one step up", SpeakCapture.lines,
       [t.t(:radar_patch, :kind => t.t(:radar_kind_shiny), :where => PokeAccess::Locator.dir_phrase(0, -1))]
  ensure
    (class << $game_temp; self; end).send(:remove_method, :poke_radar_data)
  end
end
