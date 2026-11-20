# Haiiro Chamber (map 206, Sakyu Temple): the socket (event 1, on (14, 11)) has no graphic. It gives the DNA Splicers once;
# with switch 205 on and the Z-Power Ring in the bag it takes the ring, and Kyurem, if there is one unfused in the party, comes
# for it and the fight starts. What the socket asks for is said with the assist alone.
PokeAccess::Game.define("keishou") do
  mechanic(:state, 206) do
    auto
    name 1, lambda { PokeAccess::Puzzles.assist? ? :ks_o_kyurem_socket_asks : :ks_o_kyurem_socket },
         :when => lambda { |_ev| !$game_self_switches[[206, 1, "C"]] }
  end
end
