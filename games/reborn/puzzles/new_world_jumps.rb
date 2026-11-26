# The New World maps of the legendary quests (825, 834, 836, 837, 838) and Chrysolia Deepwoods (840): jump tiles as in
# Obsidia Slums, two tiles the way the player faces, but some stand only while a switch or a count holds and the Arceus
# hall's move with its statues, so each tile is read by its live page. The routes hop them.
module PokeAccess
  module RebornNewWorldJumps
    MAPS = [825, 834, 836, 837, 838, 840]

    # The jump tiles standing now, {[x, y] => {facing => [dx, dy]}}, read once a frame from each event's live page.
    def self.table
      key = [$game_map.map_id, PokeAccess::World::Epoch.frame]
      return @table[1] if @table && @table[0] == key
      links = PokeAccess::World::Mechanics::Links
      out = {}
      ($game_map.events || {}).each_value do |ev|
        pg = links.pages(ev).reverse.find { |p| links.holds?(p.condition, ev, {}) }
        next unless pg && pg.trigger == 1
        jumps = PokeAccess::RebornJumpTiles.jumps_of(pg.list || [])
        out[[ev.x, ev.y]] = jumps unless jumps.empty?
      end
      @table = [key, out]
      out
    end

    # Drops what was read.
    def self.forget; @table = nil; end

    # True when a standing jump tile next to (x,y) throws the player who faces it from there.
    def self.from?(x, y)
      PokeAccess::RebornJumpTiles::DELTA.any? { |d, (dx, dy)| (j = table[[x + dx, y + dy]]) && j[d] }
    end

    # Where a press toward d from (x,y) lands: the landing, false where the jump stays in place, nil with no standing
    # jump tile thrown that way in front.
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

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornNewWorldJumps.forget }

PokeAccess::Game.define("reborn") do
  nw = PokeAccess::RebornNewWorldJumps
  terrain_exit(:maps => nw::MAPS, :tiles => lambda { |x, y| nw.from?(x, y) }) { |x, y, dir| nw.hop(x, y, dir[2]) }
end
