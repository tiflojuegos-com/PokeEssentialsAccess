# Route 4 (maps 412, 713, 715, 719, 720 and 724): jump stones, touch events drawn with a solid tile, throw the player
# two tiles the way they face for the facings their page names, as Obsidia Slums' do (RebornJumpTiles). On the lower
# level (switch 410) their page goes blank, so only the page of the floor a search looks at counts (World::Floors).
module PokeAccess
  module RebornRoute4Jumps
    MAPS = [412, 713, 715, 719, 720, 724]

    # The map's jump stones on the pages of the floor looked at, {[x, y] => {facing => [dx, dy]}}, read once per map and
    # floor.
    def self.table
      key = [$game_map.map_id, PokeAccess::World::Floors.on?(410)]
      return @tables[key] if @tables && @tables.key?(key)
      out = {}
      PokeAccess::World::Events.records.each do |r|
        pg = PokeAccess.ivar(r.ev, :@page)
        next unless pg && pg.trigger == 1
        jumps = PokeAccess::RebornJumpTiles.jumps_of(pg.list || [])
        out[[r.x, r.y]] = jumps unless jumps.empty?
      end
      (@tables ||= {})[key] = out
    end

    # Drops what was read of the last map.
    def self.forget; @tables = nil; end

    # True when a stone next to (x,y) throws the player who faces it from there.
    def self.from?(x, y)
      PokeAccess::RebornJumpTiles::DELTA.any? { |d, (dx, dy)| (j = table[[x + dx, y + dy]]) && j[d] }
    end

    # Where a press toward d from (x,y) lands: the jump's landing, false where it stays in place, nil with no stone
    # thrown that way in front.
    def self.hop(x, y, d)
      dx, dy = PokeAccess::RebornJumpTiles::DELTA[d]
      j = (table[[x + dx, y + dy]] || {})[d]
      return nil unless j
      lx = x + j[0]
      ly = y + j[1]
      PokeAccess::RebornJumpTiles.landable?(lx, ly) ? [lx, ly] : false
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornRoute4Jumps.forget }

PokeAccess::Game.define("reborn") do
  jumps = PokeAccess::RebornRoute4Jumps
  terrain_exit(:maps => jumps::MAPS, :tiles => lambda { |x, y| jumps.from?(x, y) }) { |x, y, dir| jumps.hop(x, y, dir[2]) }
  mechanic(:state, jumps::MAPS, :part => :jumps) do
    auto
    arrival_hint :rbk_r4_jump_rule, :once => true
  end
end
