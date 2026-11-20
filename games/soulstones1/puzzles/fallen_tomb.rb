# Tomb of the Fallen One (map 275): nine sprite-less inscriptions on the walls, each read once (its self switch A) and
# only once variable 147 has reached its own count, so they go in one order; each reading raises the variable, rolls away
# a row of rocks and, at 9, lifts the barrier of the exit (event 4). The first one turns into a healing spot once read.
module PokeAccess
  module SoulstonesTomb
    ORDER = [3, 5, 10, 6, 21, 25, 32, 11, 33]

    # True when the inscription has been read.
    def self.read?(id)
      $game_self_switches[[275, id, "A"]] ? true : false
    end

    # The inscriptions that can be read now: the one of the count reached, both last ones at 7.
    def self.next_ids
      n = $game_variables[147].to_i
      return [] if n >= ORDER.length
      (n >= 7 ? ORDER[7, 2] : [ORDER[n]]).reject { |id| read?(id) }
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  tomb = PokeAccess::SoulstonesTomb

  mechanic(:state, 275) do
    auto
    name tomb::ORDER, lambda { |ev|
      next nil if ev.id == 3 && tomb.read?(3)
      PokeAccess::Puzzles.assist? && tomb.next_ids.include?(ev.id) ? :ss1_tomb_next : :ss1_tomb_inscription
    }
    count :ss1_tomb_read, :var => 147, :from => 0, :of => 9, :assist => true, :hide_zero => true
    hint :ss1_tomb_hint
    solved { $game_variables[147].to_i >= 9 }
  end
end
