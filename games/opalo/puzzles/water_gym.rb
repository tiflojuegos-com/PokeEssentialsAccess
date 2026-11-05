# Opalo's gym of water (map 54): eleven jellyfish that carry the player across the water, to one side or the other by the way
# they face when they touch one, and four wind plates (switches 179, 180, 201 and 202) that each open a gate of three rocks.
# The leader's medal (switch 167) ends it: no rule on arriving, nothing on the info key.
module PokeAccess
  # Where each jellyfish of map 54 takes whoever touches it, by the way they face: the player's shift from the tile they
  # touch it from, read off the move route its page gives the player.
  module OpaloJellyfish
    RIDES = {
      1 => { :right => [11, 0], :left => [-11, 0] },
      2 => { :right => [19, 0], :left => [-19, 0] },
      3 => { :up => [1, -14], :left => [-1, 14] },
      4 => { :right => [7, 0], :left => [-7, 0] },
      5 => { :right => [12, 1], :up => [-12, -1] },
      6 => { :right => [7, 0], :left => [-7, 0] },
      7 => { :up => [1, -9], :left => [-1, 9] },
      8 => { :right => [15, 0], :left => [-15, 0] },
      9 => { :up => [-1, -7], :right => [1, 7] },
      10 => { :up => [1, -13], :left => [-1, 13] },
      11 => { :right => [16, 0], :left => [-16, 0] }
    }
    FACING = { 2 => :down, 4 => :left, 6 => :right, 8 => :up }

    # What a jellyfish does to the player who touches it now, by the way they face: where it carries them.
    def self.ride_line(id)
      shift = (RIDES[id] || {})[FACING[$game_player.direction]]
      return :op_jelly unless shift
      [:op_jelly_ride_said, { :to => PokeAccess::Puzzles.offset_phrase(shift[0], shift[1]) }]
    end
  end
end

PokeAccess::Game.define("opalo") do
  mechanic(:state, 54, :part => :plates) do
    auto
    obstacle({ :tile => 1724 }, :label => :op_g4_gates)
    count :op_g4_plates, :switches => [179, 180, 201, 202]
    solved { $game_switches[167] }
    hint :op_g4_hint
  end

  mechanic(:state, 54, :part => :jellyfish) do
    auto
    name 1..11, :op_jelly
    on_use PokeAccess::OpaloJellyfish::RIDES.keys, lambda { |ev| PokeAccess::OpaloJellyfish.ride_line(ev.id) }
    arrival_hint :op_g4_rule
    solved { $game_switches[167] }
  end
end
