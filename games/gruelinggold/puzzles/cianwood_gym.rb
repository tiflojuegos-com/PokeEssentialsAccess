# Cianwood Gym (map 257): three holes (events 5, 24 and 28) shut the row between the entrance and Chuck. Parallel events
# read where boulders 18 and 16 lie: on the west button (12,16) and the east one (18,16) they turn on self switches A and B
# of event 5, and with both on switch 129 opens the holes for good, each then a way out of the gym when stepped on. Boulders
# 1, 2 and 3 each fill the hole above their start, adding to var 36; at 3 the holes are floor and the Rock Smash rocks go.
# A boulder of the entrance (8, 9 or 10) left on (15,20) throws the player out to start over. Leaving resets the boulders,
# not switch 129 nor the holes filled. The hints follow a plan checked against the events, the player staying put on each
# push as v20 pushes: the entrance cleared, the west boulder, then the east one, then the holes.
module PokeAccess
  module GgCianwood
    MAP = 257

    # Whether a hole boulder has fallen into its hole: its self switch A, kept across visits.
    def self.fallen?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # Whether the event id stands on (x, y).
    def self.at?(id, x, y)
      ev = $game_map.events[id]
      ev ? ev.x == x && ev.y == y : false
    end

    # Whether the Rock Smash rock id is gone: smashed this visit, or every hole filled.
    def self.smashed?(id)
      return true if $game_variables[36].to_i >= 3
      ev = $game_map.events[id]
      ev.nil? || PokeAccess.ivar(ev, :@erased) ? true : false
    end

    # Whether the way in still has to be cleared: the rock above the entrance whole, or the centre boulder unmoved.
    def self.closed?
      return false if $game_variables[36].to_i >= 3
      !smashed?(13) || (!fallen?(2) && at?(2, 15, 16))
    end

    # The hint for clearing the way in, without its last push once the centre boulder is in its hole.
    def self.open_hint
      fallen?(2) ? :gg_cianwood_open_short_hint : :gg_cianwood_open_hint
    end

    # A step's hint followed by the way to start over.
    def self.with_reset(key)
      "#{PokeAccess::I18n.t(key)} #{PokeAccess::I18n.t(:gg_cianwood_reset_hint)}"
    end
  end
end

PokeAccess::Game.define("gruelinggold") do
  gym = PokeAccess::GgCianwood
  mechanic(:state, gym::MAP) do
    auto
    watch :self => [5, "A"], :say => lambda { $game_switches[129] ? nil : :gg_cianwood_west_down }
    watch :self => [5, "B"], :say => lambda { $game_switches[129] ? nil : :gg_cianwood_east_down }
    watch :switch => 129, :say => :gg_cianwood_holes_open
    count :gg_cianwood_holes_filled, :var => 36, :of => 3, :hide_zero => true
    name [5, 24, 28], lambda { |_ev| $game_switches[129] ? :gg_cianwood_hole_open : :gg_cianwood_hole },
         :when => lambda { |_ev| $game_variables[36].to_i < 3 }
    name 1..3, :gg_cianwood_hole_boulder, :assist => true, :when => lambda { |ev| !gym.fallen?(ev.id) }
    name 18, :gg_cianwood_west_boulder, :assist => true
    name 16, :gg_cianwood_east_boulder, :assist => true
    spot :at => [12, 16], :label => :gg_button_west, :onto => true, :when => lambda { !$game_switches[129] }
    spot :at => [18, 16], :label => :gg_button_east, :onto => true, :when => lambda { !$game_switches[129] }
    phase lambda { PokeAccess::Puzzles.assist? && gym.closed? }, :quiet => true,
          :hint => lambda { gym.with_reset(gym.open_hint) }
    phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[129] && !gym.at?(18, 12, 16) }, :quiet => true,
          :hint => lambda { gym.with_reset(:gg_cianwood_west_hint) }
    phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[129] && !gym.at?(16, 18, 16) }, :quiet => true,
          :hint => lambda { gym.with_reset(:gg_cianwood_east_hint) }
    phase lambda { PokeAccess::Puzzles.assist? && $game_switches[129] && $game_variables[36].to_i < 3 }, :quiet => true,
          :hint => lambda { gym.with_reset(:gg_cianwood_holes_hint) }
    solved(:gg_cianwood_solved) { $game_variables[36].to_i >= 3 }
    arrival_hint :gg_cianwood_rule, :once => true
  end
end
