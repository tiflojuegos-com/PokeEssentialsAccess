# The Palace of Dreams (map 212): rooms that repeat, each with doors in the north and the south wall. Antarki shows itself
# in the door to take, the demonstration of the imitation round flashes the south, south, north and south doors in turn, and
# three doors light up in the last two rounds. Variable 35 is the stage and variable 91 the door Antarki stands at (stages
# 0 and 1) or the door that lights first (stages 6 and 7); at stage 8 the north centre or the south door leads to the room of
# the boulder. On map 216, below, the boulder is pushed by the core's routes, and an Escher staircase loops: each climb of
# the flight at (30, 45) facing left adds to variable 32, the third in a row takes the player on to (36, 39), and the
# bottom flight (20, 53) sets it back to 0.
module PokeAccess
  module UraniumPalace
    def self.stage; ($game_variables[35] || 0).to_i; end
    def self.door; ($game_variables[91] || 0).to_i; end
    def self.boulder_room?; ($game_variables[30] || 0).to_i >= 22; end
    def self.triple?; stage >= 6 && stage < 8; end
    def self.flights; [$game_variables[32].to_i, 0].max; end
    def self.climbed?; flights >= 3; end

    # Whether the player is in the lower hall of map 216, where the staircase is in sight: the way in from the palace
    # (28, 56), not the halls the Dream Mountain and Venesi lead to.
    def self.by_stairs?
      $game_player.x.between?(18, 38) && $game_player.y.between?(38, 57)
    end

    # The stairs' phase: from the first time by them this visit until the climb.
    def self.stairs_live?; PokeAccess::UraniumVisit.since(:stairs) { by_stairs? } && !climbed?; end

    # The line of a door of the north wall, said as it appears: Antarki before the last rounds, the lights after.
    def self.north_line; triple? ? "" : PokeAccess::I18n.t(:ura_pp_palace_north); end

    # What the three lit doors say as the stage reaches the last rounds.
    def self.triple_line; triple? ? PokeAccess::I18n.t(:ura_pp_palace_triple) : ""; end

    # The next door to take for the stage the puzzle is at, from the pages of the doors.
    def self.hint
      return PokeAccess::I18n.t(:ura_pp_palace_boulder) if boulder_room?
      case stage
      when 0, 1 then follow_antarki
      when 2 then PokeAccess.sentences([PokeAccess::I18n.t(:ura_pp_palace_simon), PokeAccess::I18n.t(:ura_pp_palace_go_south)])
      when 3, 5 then PokeAccess::I18n.t(:ura_pp_palace_go_south)
      when 4 then PokeAccess::I18n.t(:ura_pp_palace_go_north)
      when 6, 7 then lit_door
      when 8 then PokeAccess::I18n.t(:ura_pp_palace_block)
      else ""
      end
    end

    # The door Antarki stands at; any door draws it again when the last answer left none.
    def self.follow_antarki
      case door
      when 1 then PokeAccess::I18n.t(:ura_pp_palace_go_north)
      when 2 then PokeAccess::I18n.t(:ura_pp_palace_go_south)
      else PokeAccess::I18n.t(:ura_pp_palace_redraw)
      end
    end

    # The door that lit first among the three of the north wall.
    def self.lit_door
      key = { 1 => :ura_pp_palace_go_left, 2 => :ura_pp_palace_go_center, 3 => :ura_pp_palace_go_right }[door]
      key ? PokeAccess::I18n.t(key) : ""
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 212) do
    auto
    watch :event => 4, :label => :ura_pp_palace_north, :say => lambda { PokeAccess::UraniumPalace.north_line }
    watch :event => 3, :label => :ura_pp_palace_south, :say => :ura_pp_palace_south
    watch :var => 35, :from => 6, :say => lambda { PokeAccess::UraniumPalace.triple_line }
    arrival_hint :ura_pp_palace_rule, :once => true
    hint lambda { PokeAccess::UraniumPalace.hint }
  end

  mechanic(:state, 216) do
    auto
    phase lambda { PokeAccess::UraniumPalace.stairs_live? },
          :title => :ura_rp_escher_rule, :entry_title => true,
          :hint => lambda { [:ura_rp_escher_hint, { :n => 3 - PokeAccess::UraniumPalace.flights }] }
    solved(nil, :quiet => true) { PokeAccess::UraniumPalace.climbed? }
  end
end
