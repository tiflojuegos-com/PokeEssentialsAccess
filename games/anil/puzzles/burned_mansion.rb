# The Burned Mansion (maps 119 to 122, floors 1 to 4): a Persian statue on each floor, two on the fourth, is a switch
# (S202 to S206) that takes away or raises walls drawn as tiles, some of them on another floor. Surya waits on the fourth
# floor and only its two statues are needed to reach her: the south one (S205) first, which opens the way to the north
# one (S206). The others open side rooms with items, the first floor's one, the second's one and the third's two; the
# second floor's also raises a wall that leaves the fourth floor out of reach until it is pressed again. All of it follows
# the events and the tiles' passability, not the items the randomizer mode may put there. Surya beaten (switch 210) ends the rule
# on every floor and the fourth floor's info key; the others keep theirs, as their rooms with items are still there.
module PokeAccess
  module AnilMansion
    WALL_TILES = [2983, 2991, 3007, 3015]
    FLOORS = { 119 => 1, 120 => 2, 121 => 3 }
    SWITCHES = { 119 => 202, 120 => 203, 121 => 204 }
    OPENS = { 119 => :anil_mansion_opens_one, 120 => :anil_mansion_opens_cut, 121 => :anil_mansion_opens_two }
    SURYA_FLOOR = 122
    SOUTH_STATUE = 205
    NORTH_STATUE = 206
    BEATEN = 210

    # What the assist says on a side floor: what its statue opens, then that Surya does not need it.
    def self.side_hint(map)
      PokeAccess.sentences([PokeAccess::I18n.t(OPENS[map]), PokeAccess::I18n.t(:anil_mansion_side_hint)])
    end

    # What the assist says on the fourth floor: the statue to press next.
    def self.hint
      return :anil_mansion_hint_south unless $game_switches[SOUTH_STATUE]
      $game_switches[NORTH_STATUE] ? :anil_mansion_hint_open : :anil_mansion_hint_north
    end
  end
end

PokeAccess::Game.define("anil") do
  mansion = PokeAccess::AnilMansion
  mansion::SWITCHES.each do |map, switch|
    mechanic(:state, map) do
      auto
      watch :switch => switch, :label => [:anil_statue_floor, { :n => mansion::FLOORS[map] }],
            :on => :anil_statue_on, :off => :anil_statue_off
      controls
      mansion::WALL_TILES.each { |tile| obstacle({ :tile => tile }, :label => :anil_tile_wall) }
      arrival_hint :anil_mansion_rule
      solved { $game_switches[mansion::BEATEN] }
      active { true }
      hint lambda { mansion.side_hint(map) }
    end
  end
  mechanic(:state, mansion::SURYA_FLOOR) do
    auto
    watch :switch => mansion::SOUTH_STATUE, :label => :anil_statue_south, :on => :anil_statue_on, :off => :anil_statue_off
    watch :switch => mansion::NORTH_STATUE, :label => :anil_statue_north, :on => :anil_statue_on, :off => :anil_statue_off
    controls
    mansion::WALL_TILES.each { |tile| obstacle({ :tile => tile }, :label => :anil_tile_wall) }
    arrival_hint :anil_mansion_rule
    solved { $game_switches[mansion::BEATEN] }
    hint lambda { mansion.hint }
  end
end
