# Silph Co. floors 2F-10F: the doors that open with the Card Key, each made of two or three events under one switch,
# listed with the puzzles while closed. The floor pads, stairs and elevator entrances are named in silph_navigation.rb,
# save the pad this file names.
# The way to the president's office (pad "P" on 7F, map 665, event 4) is shut by an employee (event 35) in a corridor that
# only the 3F pad "O" (map 661, event 7) leads to. He steps aside once 3 workers are rescued (variable 229) and the player
# says yes, or at once with all 14. The elevator reaches every floor; on 3F one Card Key door (switch 582) lies between it
# and the pad, and the Card Key is on the floor of 5F with no door in between. Giovanni leaving sets switch 228.
module PokeAccess
  module IFSilph
    unless const_defined?(:OFFICE_MAP)
      OFFICE_MAP = 665
      GUARD = 35
      PAD = 4
      PAD_FLOOR = 661
      NOOK = [0, 5, 0, 8]
      WORKERS_VAR = 229
      WORKERS_NEEDED = 3
      DOOR_3F = 582
      DONE = 228
    end

    # True once Giovanni has left, which ends the whole business.
    def self.done?
      $game_switches[DONE] ? true : false
    end

    # True when the employee has stepped aside from the corridor to the pad.
    def self.guard_moved?
      ($game_self_switches[[OFFICE_MAP, GUARD, "A"]] || done?) ? true : false
    end

    # True when the bag holds the Card Key.
    def self.key?
      PokeAccess::Engine.bag_quantity(:CARDKEY).to_i > 0
    end

    # How many workers the player has rescued.
    def self.rescued
      $game_variables[WORKERS_VAR].to_i
    end

    # True while the player stands in the corridor on 7F that holds the employee and the pad.
    def self.in_corridor?
      $game_map.map_id == OFFICE_MAP && $game_player.x >= NOOK[0] && $game_player.x <= NOOK[1] &&
        $game_player.y >= NOOK[2] && $game_player.y <= NOOK[3]
    end

    # The sentence for the stretch of the way left once the Card Key and the workers are settled, by where the player is.
    def self.way
      t = PokeAccess::I18n
      if in_corridor?
        t.t(guard_moved? ? :ifx_silph_hint_pad : :ifx_silph_hint_talk)
      elsif $game_map.map_id == PAD_FLOOR
        door = $game_switches[DOOR_3F] ? nil : t.t(:ifx_silph_hint_door)
        PokeAccess.sentences([t.t(:ifx_silph_hint_pad_floor), door])
      else
        t.t(:ifx_silph_hint_to_floor)
      end
    end

    # What the assist says: the Card Key, the workers and the way to the pad, as far as each is still missing.
    def self.hint
      t = PokeAccess::I18n
      return way if guard_moved?
      parts = []
      parts.push(t.t(:ifx_silph_hint_key)) unless key?
      parts.push(t.t(:ifx_silph_hint_workers, :n => rescued)) if rescued < WORKERS_NEEDED
      parts.push(way) if key? && rescued >= WORKERS_NEEDED
      PokeAccess.sentences(parts)
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  doors = { 660 => [10, 11, 14, 15], 661 => [12, 13, 17, 18], 662 => [9, 10, 11, 12], 663 => [9, 10, 13, 14, 16, 17],
            758 => [7, 8, 9], 665 => [8, 9, 10, 11, 12, 13], 666 => [9, 10, 11], 667 => [17, 18, 19, 20, 21, 22, 25, 26],
            668 => [8, 9] }
  doors.each do |map, ids|
    mechanic(:state, map, :part => :card_doors) do
      auto
      name ids, :ifk_silph_door, :when => lambda { |ev| PokeAccess::World::Mechanics.acts?(ev) }
    end
  end

  [121, 212, 660, 661, 662, 663, 665, 666, 667, 668, 758].each do |map|
    mechanic(:state, map, :part => :office) do
      auto
      if map == PokeAccess::IFSilph::OFFICE_MAP
        name PokeAccess::IFSilph::GUARD, :ifx_silph_guard, :when => lambda { |ev| !PokeAccess::IFSilph.guard_moved? }
        name PokeAccess::IFSilph::PAD, :ifx_silph_office_pad, :when => lambda { |ev| PokeAccess::IFSilph.guard_moved? }
      end
      hint lambda { PokeAccess::IFSilph.hint }
      active { PokeAccess::Puzzles.assist? && !PokeAccess::IFSilph.done? }
      solved { PokeAccess::IFSilph.done? }
    end
  end
end
