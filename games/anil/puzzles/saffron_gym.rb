# Saffron's gym (maps 128 and 127): a maze of nine rooms joined by pads with no sprite, each moving the player to a tile of
# another room of map 127; Sabrina waits in the middle one. TOWARDS_LEADER holds the pads that are the first step of a
# shortest way from their room to hers, found on the map's passability with the pads as the only way between rooms.
# Her medal (switch 196) ends it: the rule is said no more on arriving.
module PokeAccess
  module AnilPads
    MAP = 127
    HALL = 128
    PADS = 8..37
    EXITS = [7, 42]
    ENTRANCE = 3
    TOWARDS_LEADER = [10, 11, 13, 14, 17, 20, 26, 29, 33, 34, 36, 37]
    BEATEN = 196

    # The pad's name; with the assist, the ones that lead towards the leader are told apart.
    def self.label(ev)
      PokeAccess::Puzzles.assist? && TOWARDS_LEADER.include?(ev.id) ? :anil_pad_towards : :anil_pad
    end
  end
end

PokeAccess::Game.define("anil") do
  pads = PokeAccess::AnilPads
  mechanic(:state, pads::HALL) do
    auto
    name pads::ENTRANCE, :anil_pad_in
  end
  mechanic(:state, pads::MAP) do
    auto
    name pads::PADS, lambda { |ev| pads.label(ev) }
    name pads::EXITS, :anil_pad_exit
    sent_back :anil_pad_sent, :events => pads::PADS
    arrival_hint :anil_pads_rule
    solved { $game_switches[pads::BEATEN] }
  end
end
