# Citae Astrae's towers. Emerald (map 822): four statues ask whether they are Light or Dark, each setting its switch
# (1287 to 1290) on for Dark; all four on light 1291 and the teleporters to map 308, so every statue is Dark. Sapphire
# (map 823): eight statues whose two options both say Light; talking to each sets 1295 to 1302, and all eight open 1294.
module PokeAccess
  module RebornTowers
    # Each statue by the species its riddle names, as the game writes it.
    EMERALD = { 11 => "Bellossom", 12 => "Oddish", 13 => "Gloom", 14 => "Vileplume" }
    SAPPHIRE = { 13 => "Vaporeon", 14 => "Jolteon", 15 => "Flareon", 16 => "Espeon", 17 => "Umbreon", 18 => "Leafeon",
                 23 => "Glaceon", 24 => "Sylveon" }
    SAPPHIRE_SWITCHES = (1295..1302).to_a
  end
end

PokeAccess::Game.define("reborn") do
  towers = PokeAccess::RebornTowers
  mechanic(:state, 822) do
    auto
    towers::EMERALD.each do |id, species|
      name id, [:rbf_statue, { :name => species }]
      on_reach id, { :text => /Light or Dark/ }, :rbf_em_dark, :assist => true
    end
    hint :rbf_em_hint
    solved(nil, :quiet => true) { $game_switches[1291] }
  end
  mechanic(:state, 823) do
    auto
    towers::SAPPHIRE.each { |id, species| name id, [:rbf_statue, { :name => species }] }
    count :rbf_sa_count, :switches => towers::SAPPHIRE_SWITCHES, :assist => true
    hint :rbf_sa_hint
    solved(nil, :quiet => true) { $game_switches[1294] }
  end
end
