# Kiri Forest (map 183) and the Ancient Grave (190), MQ10: fifteen graves take a Rose Incense, and only the one at (14, 42)
# (event 16, drawn like the rest, so the assist alone tells it apart) opens the way down to the Ancient Grave when it is given
# one. Below, two sockets (events 7 and 8) take the Intrepid and Dauntless plates, var 66 counts them and at 2 the wall of the
# dais goes; the socket of event 6 holds the shield. The altar of event 32 (map 183) takes the rusted sword and shield, and
# the barrow of event 22 (map 177) the Forgotten Letter.
module PokeAccess
  module KeishouKiri
    # The name of a grave: the way down once the golden grave has opened, the golden one with the assist, else a grave.
    def self.grave_name(ev)
      return :ks_grave unless ev.id == 16
      return :ks_grave_descent if $game_self_switches[[183, 16, "A"]]
      PokeAccess::Puzzles.assist? ? :ks_grave_golden : :ks_grave
    end
  end
end

PokeAccess::Game.define("keishou") do
  graves = [16] + (18..31).to_a
  mechanic(:state, 183) do
    auto
    name graves, lambda { |ev| PokeAccess::KeishouKiri.grave_name(ev) }
    name 32, :ks_o_altar
  end

  mechanic(:state, 177) do
    auto
    name 22, :ks_o_barrow
  end

  mechanic(:state, 190) do
    auto
    name [7, 8], :ks_plate_socket
    name 6, :ks_shield_socket, :when => lambda { |_ev| !$game_self_switches[[190, 6, "A"]] }
    count :ks_plates_set, :var => 66, :of => 2
  end
end
