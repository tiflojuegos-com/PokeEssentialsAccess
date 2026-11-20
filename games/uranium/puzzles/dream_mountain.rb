# Dream Mountain (map 84), the sleeping girl's mission: the boulder dropped on the slime (variable 30 from 16 to 17), the
# bridge to the figure (18), the three caves of which variable 35 picks the good one (19), the toothed boulders that fill
# the shadow at (40, 39) to open the way west, and the three balls whose centre one attacks.
module PokeAccess
  # What the mountain's hints read from the game.
  module UraniumDreamMountain
    # Variable 30, the mission's step.
    def self.step
      $game_variables[30].to_i
    end

    # Whether an event's self switch is on.
    def self.on?(event, letter = "A")
      $game_self_switches[[84, event, letter]] ? true : false
    end

    # Whether the event stands on the tile.
    def self.at?(event, x, y)
      ev = $game_map.events[event]
      ev ? (ev.x == x && ev.y == y) : false
    end

    # Whether the shadow at (40, 39), the way west, is already covered.
    def self.covered?
      on?(51)
    end

    # Whether the mission is over for this visit: the postgame warp is on.
    def self.over?
      $game_switches[139] ? true : false
    end

    # The good cave counted from the left, as the cave hint says it.
    def self.cave_hint
      [:ura_po_dm_hint_cave, { :n => $game_variables[35].to_i + 1 }]
    end

    # The push of a toothed boulder that covers the shadow, by what is left of the two that can.
    def self.teeth_hint
      return :ura_po_dm_hint_teeth_near if !on?(49) && at?(49, 42, 36)
      return :ura_po_dm_hint_teeth_far if on?(49) && !on?(50) && at?(50, 49, 30)
      :ura_po_dm_hint_teeth_any
    end
  end
end

PokeAccess::Game.define("uranium") do
  mission = PokeAccess::UraniumDreamMountain

  mechanic(:state, 84) do
    auto
    arrival_hint :ura_po_dm_rule, :once => true
    name [49, 50, 97, 103, 131], :ura_po_dm_teeth
    name 42, :ura_po_dm_cave_1
    name 43, :ura_po_dm_cave_2
    name 44, :ura_po_dm_cave_3
    name 58, :ura_po_dm_mimic, :assist => true
    active { !mission.over? }
    phase lambda { mission.step < 17 }, :quiet => true, :hint => :ura_po_dm_hint_slime
    phase lambda { mission.step == 17 }, :quiet => true, :hint => :ura_po_dm_hint_bridge
    phase lambda { mission.step == 18 }, :quiet => true, :hint => :ura_po_dm_hint_figure
    phase lambda { mission.step == 19 }, :quiet => true, :hint => lambda { mission.cave_hint }
    phase lambda { mission.step >= 20 && !mission.covered? }, :quiet => true, :hint => lambda { mission.teeth_hint }
    phase lambda { mission.step >= 20 && mission.covered? && !mission.on?(58, "C") }, :quiet => true, :hint => :ura_po_dm_hint_mimic
  end
end
