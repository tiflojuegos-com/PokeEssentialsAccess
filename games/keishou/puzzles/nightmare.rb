# The Nightmare (map 274, Darkrai's dream): three statues with no graphic (events 10, 11 and 12) answer only when looked at
# from below; each one first seen adds 1 to var 153 and reshapes the dream. With 3 the tile at (44, 25) takes the player to
# Darkrai at (46, 29). The dark eyes (graphic DARKRAI_EYE) send the player home on touch, and four doors are locked.
PokeAccess::Game.define("keishou") do
  statues = [10, 11, 12]
  mechanic(:state, 274) do
    auto
    name statues, :ks_o_statue, :when => lambda { |ev| !$game_self_switches[[274, ev.id, "A"]] }
    name /DARKRAI_EYE/, lambda { PokeAccess::Puzzles.assist? ? :ks_o_darkrai_eye_home : :ks_o_darkrai_eye }
    count :ks_o_statues_seen, :var => 153, :of => 3, :assist => true
    hint :ks_o_nightmare_hint
    arrival_hint :ks_o_nightmare_rule, :once => true
  end
end
