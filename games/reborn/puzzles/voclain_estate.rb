# Voclain Estate (map 506), Serra's gym: three rooms, each closed to the north by a wall of mirrors to break with Rock
# Smash. The right half mirrors the left; the right mirror is where the mirroring stops. A wrong one hurts the party and
# adds to variable 316; the right one (events 10, 13 and 23) opens the way. Serra's room mirrors (31 to 47) only hurt.
module PokeAccess
  module RebornVoclain
    MAP = 506
    MIRRORS = (3..10).to_a + (13..20).to_a + (23..30).to_a
    SERRA_ROOM = (31..47).to_a

    # True once Serra is beaten.
    def self.done?
      $game_variables[123].to_i >= 20
    end

    # A phase test: the player in that box of tiles, Serra not yet beaten.
    def self.room(box)
      lambda { !done? && box.call }
    end
  end
end

PokeAccess::Game.define("reborn") do
  manor = PokeAccess::RebornVoclain
  mechanic(:state, manor::MAP) do
    name manor::MIRRORS, :rbf_voclain_mirror
    name manor::SERRA_ROOM, :rbf_voclain_mirror
    hide manor::SERRA_ROOM, :assist => true
    arrival_hint :rbf_voclain_rule, :once => true
    phase manor.room(at(4, 13, 60, 66)), :quiet => true, :hint => :rbf_voclain_hint1, :hidden => right_way(10)
    phase manor.room(at(5, 12, 44, 50)), :title => :rbf_voclain_room2, :hint => :rbf_voclain_hint2,
          :hidden => right_way(13)
    phase manor.room(at(5, 12, 28, 34)), :quiet => true, :hint => :rbf_voclain_hint3, :hidden => right_way(23)
    phase manor.room(at(3, 15, 2, 19)), :quiet => true, :hint => :rbf_voclain_hint_serra
    solved(nil, :quiet => true) { manor.done? }
  end
  mechanic(:state, manor::MAP, :part => :reflection) do
    phase manor.room(at(11, 11, 28, 33)), :title => :rbf_voclain_no_reflection
    solved(nil, :quiet => true) { manor.done? }
  end
end
