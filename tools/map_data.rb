# A game's maps read outside the engine: Map###.rxdata, Tilesets.rxdata and MapInfos.rxdata through stand-ins for the
# classes Marshal asks for, and each tile answered as RMXP's Game_Map#passable? and Essentials' terrain tags read it.
# Require it before anything that defines its own Table (the test stubs do): Marshal fills this one.

# RMXP's Table: x, y and z sizes over 16-bit signed cells.
class Table
  attr_reader :xsize, :ysize, :zsize

  def self._load(s)
    t = allocate
    _dim, x, y, z, _n = s.unpack("V5")
    raw = s[20, x * y * z * 2].unpack("v*").map { |v| v >= 32768 ? v - 65536 : v }
    t.instance_variable_set(:@xsize, x)
    t.instance_variable_set(:@ysize, y)
    t.instance_variable_set(:@zsize, z)
    t.instance_variable_set(:@cells, raw)
    t
  end

  def [](x, y = 0, z = 0)
    return nil if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @cells[x + y * @xsize + z * @xsize * @ysize]
  end
end

class Color; def self._load(_s); allocate; end; end
class Tone; def self._load(_s); allocate; end; end

module RPG
  class Map; attr_accessor :width, :height, :events, :tileset_id, :data; end
  class MapInfo; attr_accessor :name, :parent_id, :order; end
  class Event
    attr_accessor :id, :name, :x, :y, :pages
    class Page
      attr_accessor :condition, :graphic, :through, :trigger, :list, :always_on_top, :priority_type
      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid, :variable_value
      end
      class Graphic; attr_accessor :tile_id, :character_name, :direction; end
    end
  end
  class EventCommand; attr_accessor :code, :indent, :parameters; end
  class MoveRoute; attr_accessor :list; end
  class MoveCommand; attr_accessor :code, :parameters; end
  class AudioFile; attr_accessor :name; end
  class BGM < AudioFile; end
  class BGS < AudioFile; end
  class ME < AudioFile; end
  class SE < AudioFile; end
  class Tileset; attr_accessor :id, :name, :passages, :priorities, :terrain_tags; end
end

module MapData
  DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }.freeze

  # A game's data folder: the folder given, or its Data subfolder.
  def self.data_dir(path)
    sub = File.join(path, "Data")
    File.directory?(sub) ? sub : path
  end

  def self.read(path)
    File.open(path, "rb") { |f| Marshal.load(f) }
  end

  # A name as the data holds it (bytes) read as UTF-8, invalid bytes replaced.
  def self.text(s)
    s.to_s.dup.force_encoding("UTF-8").scrub("?")
  end

  # The maps of one game's data folder.
  class Game
    def initialize(path)
      @dir = MapData.data_dir(path)
      abort "no MapInfos.rxdata in #{@dir}" unless File.file?(File.join(@dir, "MapInfos.rxdata"))
    end

    # id => [name, parent id], by id.
    def infos
      @infos ||= MapData.read(File.join(@dir, "MapInfos.rxdata")).map { |id, i| [id, [MapData.text(i.name), i.parent_id.to_i]] }.sort.to_h
    end

    def tilesets
      @tilesets ||= MapData.read(File.join(@dir, "Tilesets.rxdata"))
    end

    # Map id as a Grid.
    def map(id)
      path = File.join(@dir, format("Map%03d.rxdata", id))
      abort "no #{File.basename(path)} in #{@dir}" unless File.file?(path)
      m = MapData.read(path)
      Grid.new(id, (infos[id] || ["?"])[0], m, tilesets[m.tileset_id])
    end
  end

  # One map's tiles and events as the engine reads them.
  class Grid
    attr_reader :id, :name, :width, :height

    def initialize(id, name, map, tileset)
      @id = id
      @name = name
      @map = map
      @tileset = tileset
      @width = map.width
      @height = map.height
    end

    def valid?(x, y)
      x >= 0 && y >= 0 && x < @width && y < @height
    end

    # Whether (x,y) lets the player out of its side toward d, layer 2 down to 0 as RMXP's Game_Map#passable? asks:
    # a shut bit or a fully shut tile stops it, a tile of priority 0 settles it open.
    def side_open?(x, y, d)
      bit = (1 << (d / 2 - 1)) & 0x0f
      [2, 1, 0].each do |z|
        id = @map.data[x, y, z]
        return false if id.nil?
        pass = @tileset.passages[id].to_i
        return false if pass & bit != 0 || pass & 0x0f == 0x0f
        return true if @tileset.priorities[id].to_i == 0
      end
      true
    end

    # Whether a step from (x,y) toward d leaves its tile and enters the next one.
    def step?(x, y, d)
      dx, dy = DIRS[d]
      valid?(x + dx, y + dy) && side_open?(x, y, d) && side_open?(x + dx, y + dy, 10 - d)
    end

    # The terrain tag on top at (x,y): the first layer from 2 down to 0 whose tile carries one, else 0.
    def tag(x, y)
      [2, 1, 0].each do |z|
        id = @map.data[x, y, z]
        t = id ? @tileset.terrain_tags[id].to_i : 0
        return t if t > 0
      end
      0
    end

    def counter?(x, y)
      [0, 1, 2].any? { |z| (id = @map.data[x, y, z]) && @tileset.passages[id].to_i & 0x80 != 0 }
    end

    # The ways a ledge at (x,y) is hopped: the directions it is entered from, as Essentials jumps a ledge the player
    # steps onto.
    def ledge_dirs(x, y)
      DIRS.keys.select { |d| dx, dy = DIRS[d]; step?(x - dx, y - dy, d) }
    end

    # The events with the page they show at the start (no switch, self switch or variable set), as
    # [id, name, x, y, graphic, through, trigger]; an event with no such page is left out.
    def events
      (@map.events || {}).values.sort_by { |e| e.id }.map do |e|
        page = (e.pages || []).reverse.find { |p| shows_alone?(p.condition) }
        next nil unless page
        g = page.graphic
        graphic = g && g.tile_id.to_i > 0 ? "tile #{g.tile_id}" : (g ? g.character_name.to_s : "")
        [e.id, MapData.text(e.name), e.x, e.y, MapData.text(graphic), page.through ? true : false, page.trigger.to_i]
      end.compact
    end

    private

    def shows_alone?(c)
      return true if c.nil?
      !(c.switch1_valid || c.switch2_valid || c.self_switch_valid) && (!c.variable_valid || c.variable_value.to_i <= 0)
    end
  end
end
