# Restaurante Le Chonk (map 116): a waiter (event 31) sets 261 and asks to find the Ditto among the diners, saying its
# disguise is not perfect. It is event 32, in "burguesDitto", a copy of the diners' "burguesow" with a flaw, which the
# locator would say by its file name. Until it is asked for, it goes by the name of the diners it copies; while the task is
# open (var 125 at 0), as the diner who looks odd and, with the assist, as the impostor.
PokeAccess::Game.define("pokemon_z") do
  open = lambda { |_ev| $game_switches[261] && $game_variables[125].to_i == 0 }
  diner = lambda do |ev|
    if open.call(ev)
      PokeAccess::Puzzles.assist? ? :z_chonk_ditto : :z_chonk_odd
    else
      twin = $game_map.events.values.find { |e| e.character_name.to_s == "burguesow" }
      twin ? PokeAccess::Locator.event_name(twin) : nil
    end
  end
  mechanic(:state, 116) do
    auto
    name 32, diner, :when => open
  end
end
