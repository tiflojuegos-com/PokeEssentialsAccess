# Cavern of Creation (map 87): five sockets with no graphic, each asking for a colour among seven and a Minior of that colour
# in the party. Only the right colour adds to var 74 and five open the way down; a wrong one is placed all the same and the
# game says nothing, so the count and the right colour wait for the assist.
PokeAccess::Game.define("keishou") do
  sockets = 16..20
  mechanic(:state, 87) do
    auto
    name sockets, :ks_o_minior_socket
    right_choice sockets, :takes => { :var => 74 }
    count :ks_o_minior_set, :var => 74, :of => 5, :assist => true
    arrival_hint :ks_o_minior_rule, :once => true
  end
end
