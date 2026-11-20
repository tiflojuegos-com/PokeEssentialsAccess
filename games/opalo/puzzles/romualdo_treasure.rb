# Opalo's treasure of the drunk Romualdo: once he has shown his map (switch 401), a Life Orb lies with no graphic at (93, 20)
# of the Pantano Venenoso (map 89) until it is picked (switch 402). With the assist, the spot is listed meanwhile.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 89, :part => :treasure) do
    auto
    spot :at => [93, 20], :label => :op_romualdo_treasure, :assist => true,
         :when => lambda { $game_switches[401] && !$game_switches[402] }
  end
end
