# The Tanoby Key of Sevault Canyon (map 240, 0246_Tanoby Key): seven boulders (EV1 to EV7) to push into seven floor
# sockets (EV8 to EV14, also named Boulder); pbCheckTanobyKey fixes a boulder that reaches a free socket, adds 1 to
# variable 51 and shakes the screen, and at 7 EV15 lights switch 121.
module PokeAccess
  module SeviiTanobyKey
    MAP = 240
    BOULDERS = (1..7).to_a
    SOCKETS = (8..14).to_a

    # True while a socket holds no boulder: its own switch A is off.
    def self.free?(ev)
      !$game_self_switches[[MAP, ev, "A"]]
    end
  end
end

PokeAccess::Game.define("sevii") do
  key = PokeAccess::SeviiTanobyKey

  mechanic(:state, key::MAP) do
    auto
    name key::BOULDERS, :sevii_tanoby_boulder
    name key::SOCKETS, lambda { |ev| key.free?(ev.id) ? :sevii_tanoby_socket : :sevii_tanoby_socket_full }
    count :sevii_tanoby_count, :var => 51, :of => 7
    arrival_hint :sevii_tanoby_rule
    key::SOCKETS.each do |socket|
      spot :event => socket, :label => :sevii_tanoby_free_socket, :assist => true, :when => lambda { key.free?(socket) }
    end
    hint :sevii_tanoby_hint
    solved(:sevii_tanoby_done) { $game_switches[121] }
  end
end
