# Obsidia Slums 1F (map 90): jump tiles, touch events drawn with a solid tile, throw the player two tiles the way they
# face, onto a tile the player may stand on, else in place. The core reads them as carries and lands one only where a
# step leads on; here they land between other jump tiles, so the rule answers the hops.
module PokeAccess
  module RebornJumpTiles
    MAPS = [90]
    JUMP = 14
    DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

    # The map's jump tiles, {[x, y] => {facing => [dx, dy]}}, read once per map from their touch pages.
    def self.table
      id = $game_map.map_id
      return @table[1] if @table && @table[0] == id
      out = {}
      ($game_map.events || {}).each_value do |ev|
        PokeAccess::World::Mechanics::Links.pages(ev).each do |pg|
          next unless pg.trigger == 1
          jumps = jumps_of(pg.list || [])
          out[[ev.x, ev.y]] = jumps unless jumps.empty?
        end
      end
      @table = [id, out]
      out
    end

    # The jumps a page makes, {facing => [dx, dy]}: each jumping move route of the player's summed, for the facings its
    # branches on the player's facing leave (all four outside them, the others in an else).
    def self.jumps_of(list)
      out = {}
      ways = {}
      list.each do |c|
        pr = c.parameters || []
        depth = c.indent.to_i
        ways.delete_if { |k, _v| k > depth }
        case c.code
        when 111 then ways[depth] = pr[0] == 6 && pr[1] == -1 ? [pr[2]] : nil
        when 411 then ways[depth] &&= DELTA.keys.reject { |f| ways[depth].include?(f) }
        when 412 then ways.delete(depth)
        when 209
          step = pr[0] == -1 && route_jump(pr[1])
          next unless step
          facings = ways.keys.select { |k| k < depth && ways[k] }.inject(DELTA.keys) { |all, k| all & ways[k] }
          facings.each { |f| out[f] = step }
        end
      end
      out
    end

    # The tiles a move route's jumps add up to, [dx, dy], or nil when it does not jump anywhere.
    def self.route_jump(route)
      jumps = ((route.list rescue nil) || []).select { |m| m.code == JUMP }
      sum = jumps.inject([0, 0]) { |s, m| [s[0] + m.parameters[0].to_i, s[1] + m.parameters[1].to_i] }
      sum == [0, 0] ? nil : sum
    end

    # Drops what was read of the last map.
    def self.forget; @table = nil; end

    # True when a jump tile next to (x,y) throws the player who faces it from there.
    def self.from?(x, y)
      DELTA.any? { |d, (dx, dy)| (j = table[[x + dx, y + dy]]) && j[d] }
    end

    # Where a press toward d from (x,y) lands: a jump's landing, false where it stays in place, nil with no jump tile
    # thrown that way in front.
    def self.hop(x, y, d)
      dx, dy = DELTA[d]
      j = (table[[x + dx, y + dy]] || {})[d]
      return nil unless j
      lx = x + j[0]
      ly = y + j[1]
      landable?(lx, ly) ? [lx, ly] : false
    end

    # True when a jump may land on (x,y), as the engine asks it of a jump.
    def self.landable?(x, y)
      ($game_map.valid?(x, y) && $game_player.passable?(x, y, 0)) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornJumpTiles.forget }

PokeAccess::Game.define("reborn") do
  jumps = PokeAccess::RebornJumpTiles
  terrain_exit(:maps => jumps::MAPS, :tiles => lambda { |x, y| jumps.from?(x, y) }) { |x, y, dir| jumps.hop(x, y, dir[2]) }
  mechanic(:state, jumps::MAPS) do
    auto
    arrival_hint :rba_os_jump_rule
  end
end
