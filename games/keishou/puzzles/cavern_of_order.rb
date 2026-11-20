# Cavern of Order (map 219, Miraijima Cavern): three tiles at (23..25, 48) open with Xerneas and Yveltal in the party, which
# only the assist names, as the tiles speak of life and destruction alone; three
# at (23..25, 35) open the row of letters with Unown of forms G, A, R, D and E in the party, in any order. The Zygarde Cube
# is picked up from the socket at (24, 53) facing up and set on the one at (24, 24); with 100 Zygarde Cells in the bag it
# makes Zygarde appear at (24, 20).
PokeAccess::Game.define("keishou") do
  mechanic(:state, 219) do
    auto
    name 1..3, lambda { PokeAccess::Puzzles.assist? ? :ks_o_order_pair_tile_asks : :ks_o_order_pair_tile },
         :when => lambda { |ev| !$game_self_switches[[219, ev.id, "A"]] }
    name 5..7, :ks_o_order_letter_tile, :when => lambda { |_ev| !$game_self_switches[[219, 5, "A"]] }
    name 19, :ks_o_cube_pickup, :when => lambda { |_ev| !$game_self_switches[[219, 19, "A"]] }
    name 21, lambda { PokeAccess::Puzzles.assist? ? :ks_o_cube_socket_cells : :ks_o_cube_socket },
         :when => lambda { |_ev| !$game_switches[134] }
    hint :ks_o_order_hint
    active { PokeAccess::Puzzles.assist? && !$game_switches[134] }
  end
end
