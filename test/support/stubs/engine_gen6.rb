# Minimal stand-ins for the RGSS / mkxp-z / Essentials gen-6 globals the mod hooks into, so the whole
# toolkit loads and runs under a desktop Ruby without the game. Only what the mod touches is stubbed;
# everything returns harmless defaults. This is the gen-6 engine (PB*/PScreen_*); the GameData era has its
# own stub file.
#
# Known divergences from the real engine (a spec relying on these tests the stub, not the game):
#   - PBTerrain.isSurfable? only accepts Water (7); the real gen-6 engine also surfs the waterfall tags
#     (8-9), so waterfall-adjacent surf behaviour is NOT exercised here.
#   - Input.trigger?/press? always return false: nothing input-driven ever fires on its own; specs must
#     call the handler they want to exercise directly.
#   - pbLoadRxData's MapInfos table holds only the FIXED ids below; an unknown id yields nil, which is what
#     lets Locator.map_name's no-entry fallback be tested (a default_proc would fabricate every id).

class Win32API
  def initialize(*a); end
  def call(*a); 0; end
end

module Audio
  def self.se_play(*a); end
  def self.se_stop(*a); end
  def self.bgs_play(*a); end
  def self.bgm_play(*a); end
end

module Graphics
  def self.update; end
  def self.frame_rate; 40; end
  def self.width; 512; end
  def self.height; 384; end
  def self.transition(*a); end
  def self.freeze; end
end

module Input
  DOWN = 2; LEFT = 4; RIGHT = 6; UP = 8
  A = 11; B = 12; C = 13; X = 14; Y = 15; Z = 16; L = 17; R = 18
  CTRL = 21
  class << self
    def update; end
    def dir4; 0; end
    def dir8; 0; end
    def trigger?(*a); false; end
    def press?(*a); false; end
    def repeat?(*a); false; end
    def triggerex?(*a); false; end
    def pressex?(*a); false; end
  end
end

module Kernel
  def self.pbMessageDisplay(*a); end
  def self.pbMessage(*a); end
  def self.pbConfirmMessage(*a); false; end
end

module MessageTypes; Kinds = 0; Entries = 1; Items = 2; end
def pbGetMessage(type, id); "msg#{id}"; end
def pbGetMessageFromHash(type, id); "place#{id}"; end
def pbGetMapNameFromId(id); "Mapa #{id}"; end
# MapInfos table for Locator.map_name: a hash of id => object responding to .name, populated ONLY for the
# ids the specs visit -- an unknown id has no entry (like a real MapInfos), so map_name's fallback stays
# testable instead of a default_proc fabricating a name for anything.
class TestMapInfo; attr_reader :name; def initialize(id); @name = "Mapa #{id}"; end; end
MAPINFO_IDS = [1, 35, 40, 999]
def pbLoadRxData(path)
  return nil unless path =~ /MapInfos/
  MAPINFO_IDS.inject({}) { |h, id| h[id] = TestMapInfo.new(id); h }
end
def pbHiddenPower(iv); [0, 60]; end
def getID(mod, sym); (mod.const_get(sym) rescue 0); end

module PBItems
  REPEL = 25; RARECANDY = 50; POTION = 1
  def self.getName(id); { 25 => "Repel", 50 => "Caramelo Raro", 1 => "Pocion" }[id] || "Item#{id}"; end
end
module PBSpecies; def self.getName(id); "Especie#{id}"; end; end
module PBMoves;   def self.getName(id); "Mov#{id}"; end; end
module PBTypes;   def self.getName(id); "Tipo#{id}"; end; end
module PBNatures; def self.getName(id); "Naturaleza#{id}"; end; end
module PBAbilities; def self.getName(id); "Habilidad#{id}"; end; end
module PBRibbons; def self.getName(id); "Cinta#{id}"; end; end
module PBStats; def self.getName(s); "Estadistica#{s}"; end; end
class PBMoveData
  def initialize(id); @id = id; end
  def basedamage; 40 + @id.to_i; end
  def accuracy; 100; end
  def type; @id.to_i % 3; end
end

module PBTerrain
  None = 0; Grass = 2; Sand = 3; Water = 7; Waterfall = 8; TallGrass = 10; Ice = 12
  def self.isSurfable?(tag); tag == Water; end
end

module PBEffects
  Reflect = 1; LightScreen = 2; AuroraVeil = 3; Spikes = 4; StealthRock = 5; ToxicSpikes = 6
  Tailwind = 7; StickyWeb = 8; TrickRoom = 9; Gravity = 10
  GrassyTerrain = 11; MistyTerrain = 12; ElectricTerrain = 13; PsychicTerrain = 14
end

class Table; def self._load(s); allocate; end; def _dump(d); ""; end; end
class Color; def self._load(s); allocate; end; def _dump(d); ""; end; end
class Tone;  def self._load(s); allocate; end; def _dump(d); ""; end; end

class Game_Player
  attr_accessor :x, :y, :direction, :jumping
  def initialize; @x = 5; @y = 5; @direction = 2; @jumping = false; end
  def update(*a); end
  def passable?(x, y, dir); ($game_map.passable?(x, y, dir) rescue true); end
  def moving?; false; end
  def jumping?; @jumping; end
end

# A minimal map event for grid scenarios (x/y/name/sprite/facing -- what the locator reads). A test may set
# @blocking to make the tile it stands on impassable, mirroring a solid event in the real engine.
class TestEvent
  attr_accessor :id, :name, :x, :y, :character_name, :direction, :blocking
  def initialize(id, name, x, y); @id = id; @name = name; @x = x; @y = y; @character_name = "npc"; @direction = 2; @blocking = false; end
end

# Reproduces the surface Terrain/Pathfinder read for one-way ledges: it maps a jump direction to the tileset
# passage byte the real engine would carry (the side OPPOSITE the jump is the only one left open, matching
# Pathfinder::LEDGE_OPP_BIT), and it exposes @passages/@terrain_tags/data[x,y,i] so ledge_passage resolves.
module TestLedge
  # RMXP passage bit blocked per direction (0x01 down, 0x02 left, 0x04 right, 0x08 up); the byte of a ledge
  # leaves only the side opposite the jump open, so ledge_dir_ok? permits exactly that jump direction.
  OPP_BIT = { 2 => 0x08, 8 => 0x01, 4 => 0x04, 6 => 0x02 }
  TILE_BASE = 1000

  # The synthetic tileset tile id for a ledge whose hop direction is dir (a distinct id per direction so each
  # carries its own passage byte).
  def self.tile_id(dir); TILE_BASE + dir; end

  # The passage byte of a ledge with hop direction dir: every side blocked except the one opposite the jump.
  def self.passage(dir); 0x0F & ~(OPP_BIT[dir] || 0); end
end

# A stand-in for RMXP's map data Table (data[x,y,layer]): returns the ledge tile id on layer 0 of a ledge
# tile, 0 elsewhere, which is exactly what ledge_passage walks.
class TestMapData
  def initialize(ledges); @ledges = ledges; end
  def [](x, y, layer)
    d = @ledges[[x, y]]
    (d && layer == 0) ? TestLedge.tile_id(d) : 0
  end
end

class Game_Map
  attr_accessor :map_id, :width, :height

  def initialize; @map_id = 1; @width = 20; @height = 20; @events = {}; @grid = nil; init_ledges; end

  def events; @events; end

  # The terrain tag at (x,y): a tag placed with set_terrain, else 1 on a placed ledge (so
  # Terrain.ledge_at? sees it), else 0.
  def terrain_tag(x, y)
    t = @terrain[[x, y]]
    return t if t
    @ledges[[x, y]] ? 1 : 0
  end

  # Places a gen-6 PBTerrain id, the numbers Terrain::KIND maps (7 water, 10 tall grass, 12 ice...), so a
  # spec can lay out real surfaces instead of stubbing out whatever reads them.
  def set_terrain(x, y, tag); @terrain[[x, y]] = tag; self; end

  # True while (x,y) is inside the map bounds; ledge_jump needs it to accept a landing tile.
  def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end

  # Loads an ASCII grid so passable?/counter?/events mirror real walls. '#'=wall, '.'=floor, 'C'=counter,
  # '@'=player start, any other letter/digit = an npc event on that tile. Returns self.
  def load_grid(rows)
    @grid = rows; @height = rows.length; @width = rows.map { |r| r.length }.max; @events = {}; eid = 0
    rows.each_index do |y|
      (0...rows[y].length).each do |x|
        ch = rows[y][x, 1]
        if ch == "@"
          $game_player.x = x; $game_player.y = y
        elsif ch != "#" && ch != "." && ch != "C" && ch =~ /[A-Za-z0-9]/
          eid += 1; @events[eid] = TestEvent.new(eid, "EV#{eid}", x, y)
        end
      end
    end
    self
  end

  # Registers a one-way ledge at (x,y) whose hop direction is dir (2/4/6/8): opt-in and mirroring the real
  # engine, the tile is passable ONLY when entered moving in dir (from the high side), reads terrain tag 1,
  # and carries the passage byte that makes ledge_dir_ok? permit exactly dir. Returns self.
  def place_ledge(x, y, dir)
    @ledges[[x, y]] = dir
    tid = TestLedge.tile_id(dir)
    @terrain_tags[tid] = 1
    @passages[tid] = TestLedge.passage(dir)
    self
  end

  # Clears all placed ledges (the reset calls this so a ledge never leaks between suites).
  def clear_ledges; init_ledges; end

  # Drops any loaded ASCII grid and restores the default open 20x20 map, so a grid built by one suite does
  # not leak its walls (or its resized dimensions) into the next, which otherwise assumes open space.
  def clear_grid; @grid = nil; @width = 20; @height = 20; @terrain = {}; end

  def cell(x, y); (@grid && y >= 0 && x >= 0 && @grid[y] && x < @grid[y].length) ? @grid[y][x, 1] : "#"; end
  def counter?(x, y); cell(x, y) == "C"; end
  def blocked?(x, y); c = cell(x, y); c == "#" || c == "C"; end

  # True if a blocking event occupies (x,y) (a solid event makes its tile impassable, as in the real engine).
  def blocking_event_at?(x, y)
    @events.each_value { |e| return true if e.respond_to?(:blocking) && e.blocking && e.x == x && e.y == y }
    false
  end

  # Passability of a one-step move from (x,y) in dir. A ledge tile is passable only when approached moving in
  # its hop direction (high side); a blocking event or a wall blocks the destination; otherwise the grid (or
  # open space) decides.
  def passable?(x, y, dir)
    dx = (dir == 6 ? 1 : (dir == 4 ? -1 : 0)); dy = (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
    nx = x + dx; ny = y + dy
    ld = @ledges[[nx, ny]]
    return dir == ld if ld
    return false if blocking_event_at?(nx, ny)
    return true unless @grid
    !blocked?(nx, ny)
  end

  # Exposes the passage/terrain-tag tables the real Game_Map carries, so ledge_passage can read them.
  def init_ledges
    @ledges = {}; @passages = {}; @terrain_tags = {}; @terrain = {}
    @data = TestMapData.new(@ledges)
  end
  def data; @data; end
end

class Game_Temp;   attr_accessor :in_menu, :message_window_showing, :in_battle; end
class Game_System; def map_interpreter; @i ||= Object.new.tap { |o| def o.running?; false; end }; end; end
class Scene_Map;   def update(*a); end; end

# The selectable-window chain the mod's generic auto-detect net and the command hook bind to, reproduced
# minimally but with the SAME shape as every engine (gen-6/v21/v22): Window_DrawableCommand descends from
# SpriteWindow_Selectable, only the base and the leaf own an #update, and the middle class inherits it. This
# lets menus.rb wrap the real navigation update at load (so the net is not a no-op) and lets specs drive a
# cursor move by setting @index then calling update, exactly as the game does. #index/#active are the
# accessors the net reads. A spec that needs a filtered pocket adds #pocket on a subclass.
class SpriteWindow_Base
  attr_accessor :active, :visible, :index
  def initialize; @active = true; @visible = true; @index = 0; end
  def disposed?; false; end
end
class SpriteWindow_Selectable < SpriteWindow_Base
  def update(*a); @index; end
end
class SpriteWindow_SelectableEx < SpriteWindow_Selectable; end
class Window_DrawableCommand < SpriteWindow_SelectableEx
  attr_accessor :commands
  def initialize(commands = []); super(); @commands = commands; end
  def update(*a); old = self.index; super; refresh if self.index != old; @index; end
  def refresh; end
end

# The gen-6 summary scene the readers hook (PokemonSummaryScene#pbUpdate/drawPage*). Defined here so the
# hooks wrap real methods at load; specs set @pokemon and call the method to drive the wiring. pbStartScene
# mirrors the engine: it draws the first page synchronously during the open (drawPage -> drawPageOne), the
# chain that the before-hook (reset_reorder) must not silence, so the sheet is read on open.
# The Options scene EXACTLY as the seven gen-6 games have it: pbUpdate and no selection-change method
# (they write each description inline into @sprites["textbox"] from inside pbOptions). Stubbing it with a
# pbChangeSelection it does not have would let the reader pass here and stay mute in every real game.
class PokemonOptionScene
  attr_accessor :sprites
  def initialize; @sprites = {}; end
  # pbUpdate drives the option window from inside itself, exactly like the real scene: that is what makes
  # it a container, and a spec whose pbUpdate did nothing would never catch a hook that guards it.
  def pbUpdate(*a); refresh_option; end
  def refresh_option; end
end

class PokemonSummaryScene
  attr_accessor :pokemon
  def initialize(pk = nil); @pokemon = pk; end
  def pbUpdate(*a); end
  def pbStartScene(party = nil, partyindex = 0, *a)
    @pokemon = party ? party[partyindex] : @pokemon
    @page = 1
    drawPage(@page)
  end
  def drawPage(page); drawPageOne(@pokemon) if page == 1; end
  def drawPageOne(pk = nil); (@pokemon = pk) if pk; end
end

# The field-move / registered-item menu the v21 reader hooks (SelectMoveMenu_Scene). pbShowCommands is the
# modal loop; it draws the focused option on open and calls refresh_buttons on each cursor move WITHIN the
# loop. A spec seeds @nav (the indices the cursor visits) so the loop is deterministic without real input;
# this is the chain a before-hook (reset+read) must not silence for the after-hook (refresh_buttons) that
# reads each option as you navigate.
class SelectMoveMenu_Scene
  attr_accessor :commands, :index
  def initialize(commands = [], nav = []); @commands = commands; @index = 0; @nav = nav; end
  def pbShowCommands(*a)
    @nav.each { |i| @index = i; refresh_buttons }
    @index
  end
  def refresh_buttons(*a); @index; end
end

$game_player = Game_Player.new
$game_map    = Game_Map.new
$game_temp   = Game_Temp.new
$game_system = Game_System.new
$game_switches = Hash.new(false)
$game_variables = Hash.new(0)
# A trainer EXISTS by default, and that is not decoration: Appearance.selecting? reads "no trainer yet"
# as "the player is on the new-game character picker", which makes Spatial.busy? permanently true --
# and busy? gates the guide and the whole soundscape (footsteps, wall cues, radar, surfaces). With
# $Trainer nil, every gen-6 spec of those subsystems passed VACUOUSLY: nothing spoke, nothing raised,
# green. A spec that wants the picker instead sets $Trainer = nil for its duration.
class TestTrainer
  attr_accessor :name, :money, :badges, :publicID
  def initialize
    @name = "Ayoub"; @money = 3000; @badges = [false] * 8; @publicID = 12345
  end
  def public_ID; @publicID; end
  def pokedexOwned; 12; end
  def pokedexSeen; 30; end
  def numbadges; @badges.select { |b| b }.length; end
end
$Trainer = TestTrainer.new
$scene = Scene_Map.new
$stats = nil
$PokemonGlobal = Object.new
def $PokemonGlobal.surfing; false; end
def $PokemonGlobal.diving; false; end
def $PokemonGlobal.bridge; 0; end

# Pictures. Every RMXP game has this pair and the mod hooks Game_Picture#show to narrate picture-only
# screens (a new-game character slider is nothing but this), so a stub without it left that whole family
# bound to nothing and untestable.
class Game_Picture
  attr_reader :number, :name, :x, :y
  def initialize(number = 1); @number = number; @name = ""; @x = 0; @y = 0; end
  def show(name, origin = 0, x = 0, y = 0, zoom_x = 100, zoom_y = 100, opacity = 255, blend_type = 0)
    @name = name; @x = x; @y = y
    self
  end
  def erase; @name = ""; self; end
end
