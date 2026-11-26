# Tanzan Meteor Base (maps 246, 254, 255). Rotary discs turn the player who steps on an arm out of another arm, flipping
# their switch: off, north leads east, east south, south west, west north; on, the reverse; map 255's turn the other
# way. Map 246: spriteless computers open the north gates. Map 254: the rescue's steps, read from variable 149.
module PokeAccess
  module RebornTanzan
    DISCS = { 246 => [[9, 11, 269, false]], 254 => [[13, 18, 270, false]],
              255 => [[10, 10, 272, true], [36, 7, 273, true]] }
    SIDES = { 2 => [0, -1], 8 => [0, 1], 6 => [-1, 0], 4 => [1, 0] }
    COMPUTERS = { 246 => [[13, :rba_tz_gate_a], [14, :rba_tz_gate_b]],
                  254 => [[52, :rba_tz_lock_a], [53, :rba_tz_lock_b], [69, :rba_tz_side_gate]] }

    # The disc whose exit tile (x,y) is, with the side it lies on, as [cx, cy, switch, reversed, sx, sy]; nil elsewhere.
    def self.disc_at(x, y)
      (DISCS[$game_map.map_id] || []).each do |cx, cy, s, rev|
        SIDES.each_value do |sx, sy|
          return [cx, cy, s, rev, sx, sy] if x == cx + 2 * sx && y == cy + 2 * sy
        end
      end
      nil
    end

    # Where a press toward d from (x,y) leaves the player: from a disc's exit into its arm, out of the arm it turns to,
    # one press walked; nil for any other press.
    def self.spin(x, y, d)
      disc = disc_at(x, y)
      return nil unless disc
      cx, cy, s, rev, sx, sy = disc
      return nil unless SIDES[d] == [sx, sy]
      on = ($game_switches[s] ? true : false) != rev
      ox, oy = on ? [sy, -sx] : [-sy, sx]
      [cx + 2 * ox, cy + 2 * oy, 1]
    end

    # The rescue's step, variable 149.
    def self.step; $game_variables[149].to_i; end

    # With the assist, the next thing to do on map id.
    def self.hint(map)
      if map == 246
        return :rba_tz_hint_gate_a unless $game_switches[267]
        return :rba_tz_hint_gate_b unless $game_switches[268]
        return step < 7 ? :rba_tz_hint_north : nil
      end
      return :rba_tz_hint_cells if step < 7
      return :rba_tz_hint_atrium if step == 7
      step < 10 ? :rba_tz_hint_locks : nil
    end

    # True while map id's part of the base waits for something: on map 246, its gates or, past them, Laura still in
    # her cell.
    def self.open?(map)
      return !($game_switches[267] && $game_switches[268]) || step < 7 if map == 246
      step < 10
    end
  end
end

PokeAccess::Game.define("reborn") do
  base = PokeAccess::RebornTanzan
  terrain_exit(:maps => base::DISCS.keys, :tiles => lambda { |x, y| !base.disc_at(x, y).nil? }) { |x, y, dir| base.spin(x, y, dir[2]) }
  base::DISCS.keys.each do |map|
    mechanic(:state, map) do
      auto
      (base::COMPUTERS[map] || []).each { |id, label| name id, label }
      arrival_hint :rba_tz_disc_rule, :once => true
      hint lambda { base.hint(map) }
      active { base.open?(map) }
      solved { !base.open?(map) }
    end
  end
end
