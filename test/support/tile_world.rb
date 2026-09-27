# A map split the way RMXP splits it: Game_Map#passable? answers for one side of a tile and the player's move asks
# it of both tiles, which the grid stub cannot (a shore). Rows: '#' wall, '.' floor, '~' water (terrain 7), 'D' deep
# water (terrain 5), ']' floor closed on its right side, 'g' tall grass (terrain 10, no riding onto it), 'V' a
# waterfall's crest (terrain 9, surfable), 'W' the fall (terrain 8, only climbed or dropped), '@' the start.
class TileWorld
  attr_accessor :map_id, :events, :width, :height

  TAGS = { "~" => 7, "D" => 5, "g" => 10, "V" => 9, "W" => 8 }

  def initialize(rows, map_id = 900)
    @rows = rows
    @map_id = map_id
    @events = {}
    @height = rows.length
    @width = rows.map { |r| r.length }.max
    rows.each_index do |y|
      x = rows[y].index("@")
      @start = [x, y] if x
    end
  end

  # Where the '@' stood.
  def start; @start; end

  def cell(x, y); (y >= 0 && x >= 0 && @rows[y] && x < @rows[y].length) ? @rows[y][x, 1] : "#"; end
  def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end
  def water?(x, y); c = cell(x, y); c == "~" || c == "D" || c == "V"; end
  def terrain_tag(x, y, *_); TAGS[cell(x, y)] || 0; end
  def counter?(_x, _y); false; end
  def passable?(x, y, d = 0)
    c = cell(x, y)
    valid?(x, y) && c != "#" && c != "W" && !(c == "]" && d == 6)
  end
end

# The player on a TileWorld: a move needs both tiles open, water only afloat, and no bike onto tall grass.
class TileWorldPlayer
  attr_accessor :x, :y, :through, :direction

  def initialize(x, y); @x = x; @y = y; @direction = 2; end
  def moving?; false; end
  def jumping?; false; end

  def passable?(x, y, d)
    nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
    m = $game_map
    return false unless m.valid?(nx, ny) && m.passable?(x, y, d) && m.passable?(nx, ny, 10 - d)
    return false if m.events.values.any? { |e| e.x == nx && e.y == ny && (e.respond_to?(:blocking) && e.blocking) }
    return false if ($PokemonGlobal.bicycle rescue false) && m.cell(nx, ny) == "g"
    return true if ($PokemonGlobal.surfing rescue false)
    !m.water?(nx, ny)
  end
end

# Runs a block on a TileWorld made from rows, with its player at the '@', putting the real map and player back.
def with_tile_world(rows)
  old_map = $game_map; old_pl = $game_player
  world = TileWorld.new(rows)
  $game_map = world
  $game_player = TileWorldPlayer.new(world.start[0], world.start[1])
  PokeAccess::Pathfinder.invalidate_cache(true)
  PokeAccess::Terrain.forget_map_memo
  yield world
ensure
  $game_map = old_map; $game_player = old_pl
  PokeAccess::Pathfinder.invalidate_cache(true)
  PokeAccess::Terrain.forget_map_memo
end
