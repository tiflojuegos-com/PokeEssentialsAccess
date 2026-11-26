# Rhodochrine Jungle (map 150): three four-tile pits hide in the grass; stepping on one drops the player to The
# Underroot and opens it for good (switches 1784, 1788 and 1789), then it shows a hole that asks before jumping down.
# Without the assist a hidden pit stays out of the lists; with it, it is named and the walks keep off it.
module PokeAccess
  module RebornJunglePits
    MAP = 150
    PITS = { 49 => 1784, 59 => 1784, 61 => 1784, 62 => 1784, 101 => 1788, 102 => 1788, 104 => 1788, 106 => 1788,
             58 => 1789, 107 => 1789, 108 => 1789, 109 => 1789 }

    # True once the pit has opened.
    def self.open?(ev)
      $game_switches[PITS[ev.id]] ? true : false
    end

    # The name of a pit: an open hole, or with the assist a hidden one; nil leaves it its own name.
    def self.label(ev)
      return :rbd_rj_hole if open?(ev)
      PokeAccess::Puzzles.assist? ? :rbd_rj_hidden_pit : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  pits = PokeAccess::RebornJunglePits
  mechanic(:state, pits::MAP, :part => :pits) do
    auto
    name pits::PITS.keys, lambda { |ev| pits.label(ev) }, :grouped => true
    hide pits::PITS.keys, :when => lambda { |ev| !pits.open?(ev) && !PokeAccess::Puzzles.assist? }
    avoid pits::PITS.keys, :assist => true
    not_control pits::PITS.keys
    active { false }
  end
end
