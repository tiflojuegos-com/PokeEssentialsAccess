# Rollout Hero (episode 10, map 366, Blackleaf Woods): Herovor has seven hearts (variable 308) and sixteen wild Pokemon
# (events 31, 39 and 48 to 61) chase it within five tiles, each touch a heart less. Reaching the cabin (event 9, x 12 to
# 14, y 24) ends it (switch 300) with none beaten; the chasers sound as they move and the hearts are said as they
# change.
PokeAccess::Game.define("slld_anime") do
  mechanic(:state, 366) do
    auto
    obstacle(/\A(STOTOX|VENNAP|ARACTULA|BEOPUP|LOPHUG|GECKONE)\z/, :moving => true, :label => :slld_chaser)
    spot :at => [13, 24], :label => :slld_cabin, :onto => true
    watch :var => 308, :label => :slld_hearts, :number => true
    active { $game_switches[299] }
    hint :slld_rollout_hint
    solved(nil, :quiet => true) { $game_switches[300] }
  end
end
