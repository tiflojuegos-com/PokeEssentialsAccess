# Perseida's gym of Libra (map 54): four rooms joined by pairs of doors with no sprite, each room with three exits and a
# trainer whose hint is about the floor of the way. One exit of each room goes on (EV9 to the second room, EV11 to the third,
# EV13 to the fourth, EV15 to the leader's); the other two send the player back to the entrance (13, 17), where the game
# says it itself. The doors go by the floor of the way to them, as the screen shows it; the assist tells the right ones and
# the traps apart. The leader's medal scene (event 6 of the map) turns its self switch C on, which ends the rule on arriving.
module PokeAccess
  module PerseidaLibra
    ROADS = { :rails => :perseida_libra_road_rails, :sand => :perseida_libra_road_sand,
              :crystals => :perseida_libra_road_crystals, :stone => :perseida_libra_road_stone,
              :clear => :perseida_libra_road_clear }
    EXITS = {
      19 => [:rails, false], 20 => [:sand, false], 9 => [:crystals, true],
      21 => [:rails, false], 22 => [:stone, false], 11 => [:sand, true],
      23 => [:rails, false], 25 => [:rails, false], 13 => [:clear, true],
      24 => [:rails, false], 26 => [:stone, false], 15 => [:crystals, true]
    }
    BACK = [10, 12, 14, 16]
    BEATEN = [54, 6, "C"]

    # An exit's name by the floor of its way; with the assist, whether it is the right one or a trap.
    def self.label(ev)
      road, right = EXITS[ev.id]
      key = :perseida_libra_exit
      key = right ? :perseida_libra_exit_right : :perseida_libra_exit_trap if PokeAccess::Puzzles.assist?
      [key, { :road => PokeAccess::I18n.t(ROADS[road]) }]
    end
  end
end

PokeAccess::Game.define("perseida") do
  libra = PokeAccess::PerseidaLibra
  mechanic(:state, 54) do
    auto
    name libra::EXITS.keys, lambda { |ev| lambda { libra.label(ev) } }
    name libra::BACK, :perseida_libra_back
    arrival_hint :perseida_libra_rule
    solved { $game_self_switches[libra::BEATEN] }
  end
end
