# Vitro's Ilex Forest (Encinar, map 59): the charcoal man's two Farfetch'd (events 36 and 39, while variable 32 is 10 or more,
# until switch 117 or 118 marks each caught). Each waits on a corner of its square of paths, its facing fixed. Talked to from
# behind (facing_away_from_player?, 0353_Pathfinder) it is caught; seen, it runs to the corner the tile it was talked from
# sends it to and turns to the player, its back to a wall. Floor sensors with no sprite, 2x2 each (Size Events), turn it
# toward whoever comes that way: events 37 and 38 for the first, 40 to 44 for the second. While a bird stands still on a
# corner on screen, where it is and the way it looks are said as they change; with the assist, what to do from there. The
# first is caught on a bottom corner, from above, once the floor at 19,70 turns it to look down; the second on the top
# right corner, from its left, once the floor at 48,43 turns it to look right.
module PokeAccess
  module VitroIlex
    # Each bird's event => [its corners' columns, its corners' rows, the switch that marks it caught].
    BIRDS = { 36 => [[10, 20], [56, 66], 117], 39 => [[35, 45], [43, 53], 118] }
    # How far from the player a bird is on screen, in tiles across and down.
    SCREEN = [8, 6]
    # Each bird => the corners it is caught at, each with the way it has to look there.
    CATCH = { 36 => { [10, 66] => 2, [20, 66] => 2 }, 39 => { [45, 43] => 6 } }
    # Each bird => the hint for its catch, looking that way.
    CATCH_HINT = { 36 => :vitro_ilex_hint_above, 39 => :vitro_ilex_hint_left_north }
    # Each bird => the floor that turns it, on its catch corner, the way it has to look there: [x, y, that way].
    FLOOR = { 36 => [19, 70, 2], 39 => [48, 43, 6] }
    # Each other corner => the tile to talk to the bird from so that it runs on toward its catch corner, and the corner it
    # runs to: [x, y, corner x, corner y].
    DRIVE = { [10, 56] => [11, 56, 10, 66], [20, 56] => [19, 56, 20, 66], [35, 43] => [35, 44, 45, 43],
              [45, 53] => [44, 53, 45, 43], [35, 53] => [35, 52, 45, 53] }

    # True while bird id stands still on one of its corners, its page live, on screen.
    def self.seen?(id)
      cols, rows, caught = BIRDS[id]
      return false if $game_variables[32] < 10 || $game_switches[caught]
      ev = $game_map.events[id]
      return false unless ev && cols.include?(ev.x) && rows.include?(ev.y)
      return false if (ev.moving? rescue false) || (ev.move_route_forcing rescue false)
      (ev.x - $game_player.x).abs <= SCREEN[0] && (ev.y - $game_player.y).abs <= SCREEN[1]
    end

    # With the assist, what to do with bird id where it stands: on its catch corner, how to talk to it from behind, or the
    # floor that turns it the way that lets it; on any other, where to talk to it from to send it on.
    def self.hint(id)
      ev = $game_map.events[id]
      at = [ev.x, ev.y]
      way = CATCH[id][at]
      return CATCH_HINT[id] if way == ev.direction
      if way
        x, y, d = FLOOR[id]
        return [:vitro_ilex_hint_floor, { :x => x, :y => y, :dir => PokeAccess::Routes::Text.toward(d) }]
      end
      x, y, cx, cy = DRIVE[at]
      [:vitro_ilex_hint_drive, { :x => x, :y => y, :cx => cx, :cy => cy }]
    end

    # The way bird id faces.
    def self.facing(id); $game_map.events[id].direction; end

    # Where bird id is from the player and the way it looks.
    def self.line(id)
      ev = $game_map.events[id]
      dx = ev.x - $game_player.x
      dy = ev.y - $game_player.y
      moves = [dy < 0 ? 8 : 2] * dy.abs + [dx < 0 ? 4 : 6] * dx.abs
      name = PokeAccess::Locator.sprite_species(ev.character_name) || PokeAccess::Locator.target_name(ev)
      [:vitro_ilex_bird, { :name => name, :at => PokeAccess::Routes::Text.steps(moves),
                           :dir => PokeAccess::Routes::Text.toward(ev.direction) }]
    end
  end
end

PokeAccess::Game.define("vitro") do
  PokeAccess::VitroIlex::BIRDS.each do |id, (_cols, _rows, caught)|
    mechanic(:state, 59, :part => "farfetchd_#{id}".to_sym) do
      auto
      [2, 4, 6, 8].each do |d|
        phase lambda { PokeAccess::VitroIlex.seen?(id) && PokeAccess::VitroIlex.facing(id) == d },
              :title => lambda { PokeAccess::VitroIlex.line(id) }, :entry_title => true,
              :hint => lambda { PokeAccess::VitroIlex.hint(id) }
      end
      solved { $game_switches[caught] }
    end
  end
end
