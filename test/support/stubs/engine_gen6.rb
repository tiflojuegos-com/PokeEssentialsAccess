# Stand-ins for the RGSS / mkxp-z / Essentials gen-6 globals the mod hooks into (PB*, PScreen_*), so the toolkit
# loads under a desktop Ruby; the GameData era has its own stub file.
#
# Known divergences from the real engine (a spec relying on these tests the stub, not the game):
#   - Input.trigger?/press? always return false: specs call the handler they exercise directly.
#   - pbLoadRxData's MapInfos holds only the fixed ids below; an unknown id yields nil.

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

# pbSEPlay records what it was asked to play in $se_played, so a filter in front of it can be pinned.
def pbSEPlay(param, volume = nil, pitch = nil)
  ($se_played ||= []).push(param)
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
  CTRL = 21; ALT = 23
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

module MessageTypes; Kinds = 0; Entries = 1; Items = 2; PlaceNames = 3; end

class PokemonRegionMapScene
  SQUAREWIDTH = 16
  SQUAREHEIGHT = 16
  # A spec's @build stands in for what a game's build does (its ivars, sprites and bottom-bar writes).
  def pbStartScene(*a); @build.call(self, a) if @build; end
  def pbGetMapLocation(_x, _y); ""; end
  def pbEndScene; end
end

# The region map's bottom bar: the region's name at its top and the place under the cursor, which the screen
# writes into it on every move.
class MapBottomSprite
  def mapname=(value); @mapname = value; end
  def maplocation=(value); @maplocation = value; end
end

# The egg hatch scene under its gen-6 name: the hatchling in @pokemon, and pbMain running the animation.
class PokemonEggHatchScene
  def initialize(pokemon = nil); @pokemon = pokemon; end
  def pbMain; :hatched; end
end
# The same scene as v17 names it (Soulstones, Awakening), on the same gen-6 engine.
class PokemonEggHatch_Scene
  def initialize(pokemon = nil); @pokemon = pokemon; end
  def pbMain; :hatched_v17; end
end
# The gen-6 nest page: pbStartScene lays a point sprite per lit square, two pixels up and left of it, over the map,
# and paints the bottom bar. A spec sets the squares (lit) and the town map.
class PokemonNestMapScene
  attr_accessor :lit, :mapdata
  def pbStartScene(species, regionmap = -1)
    @sprites = { "map" => Struct.new(:x, :y).new(16, 32) }
    @mapdata = mapdata
    (lit || []).each_with_index do |(cx, cy), i|
      @sprites["point#{i}"] = Struct.new(:x, :y).new(cx * 16 - 2 + 16, cy * 16 - 2 + 32)
    end
    @numpoints = (lit || []).length
    pbDrawTextPositions(nil, [["Kanto", 0, 0], ["Nido de #{species}", 0, 0]])
    true
  end
end
def pbGetMessage(type, id); "msg#{id}"; end
def pbGetMessageFromHash(type, id); "place#{id}"; end
def pbGetMapNameFromId(id); "Mapa #{id}"; end
# MapInfos for Locator.map_name (id => object with .name), only for the ids the specs visit.
class TestMapInfo; attr_reader :name; def initialize(id, name = nil); @name = name || "Mapa #{id}"; end; end
MAPINFO_IDS = [1, 35, 40, 999]
def pbLoadRxData(path)
  return nil unless path =~ /MapInfos/
  table = MAPINFO_IDS.inject({}) { |h, id| h[id] = TestMapInfo.new(id); h }
  table[36] = TestMapInfo.new(36, "Casa de \\PN")
  table
end
def pbHiddenPower(iv); [0, 60]; end
def getID(mod, sym); (mod.const_get(sym) rescue 0); end
# The Poke Radar's search: the patches it shook are whatever a spec left in the radar's state.
def pbPokeRadarHighlightGrass(_showmessage = true); nil; end

module PBItems
  REPEL = 25; RARECANDY = 50; POTION = 1
  def self.getName(id); { 25 => "Repel", 50 => "Caramelo Raro", 1 => "Pocion" }[id] || "Item#{id}"; end
end
module PBSpecies; def self.getName(id); "Especie#{id}"; end; end
module PBMoves;   def self.getName(id); "Mov#{id}"; end; end
module PBTypes;   def self.getName(id); "Tipo#{id}"; end; end
# Trainer classes: the message table names only the classes the game has, and nothing for any other number.
module PBTrainers
  HIKER = 5
  def self.getName(id); { 5 => "Montanero", 65 => "Posadera" }[id]; end
end

# The gen-6 dex data, read the way the engine reads it: an open file positioned per species (76 bytes each)
# and read a byte at a time. Species 25 is of type 13 alone; any other one of types 1 and 2.
class FakeDexData
  TYPES = { 25 => [13, 13] }
  attr_accessor :pos
  def initialize; @pos = 0; end
  def fgetb
    sp = @pos / 76 + 1; off = @pos % 76
    @pos += 1
    t = TYPES[sp] || [1, 2]
    { 8 => t[0], 9 => t[1] }[off] || 0
  end
  def close; end
end
def pbOpenDexData; FakeDexData.new; end
def pbDexDataOffset(dexdata, species, offset); dexdata.pos = 76 * (species - 1) + offset; end
module PBNatures; def self.getName(id); "Naturaleza#{id}"; end; end
module PBAbilities; def self.getName(id); "Habilidad#{id}"; end; end
module PBRibbons
  def self.getName(id); "Cinta#{id}"; end
  def self.getDescription(id); "Descripcion#{id}"; end
end

# The gen-6 opening's controls help: one screen whose paragraphs the constructor adds through addLabel(x, y, width,
# text), and the key pictures beside them through addImage(x, y, file); no addLabelForScreen and no set_up_screen. A
# paragraph is its text (drawn at 26) or [text, y]; a picture is [y, file].
class ButtonEventScene
  def initialize(labels = [], pictures = [])
    addImage(0, 0, "Graphics/Pictures/helpbg")
    @labels = labels.map { |t| t.is_a?(Array) ? addLabel(104, t[1], 400, t[0]) : addLabel(104, 26, 400, t) }
    @keys = pictures.map { |p| addImage(52, p[0], p[1]) }
  end
  def addLabel(_x, _y, _width, text); text; end
  def addImage(_x, _y, file); file; end
end
module PBStats; def self.getName(s); "Estadistica#{s}"; end; end
class PBMoveData
  def initialize(id); @id = id; end
  def basedamage; 40 + @id.to_i; end
  def accuracy; 100; end
  def type; (@id.to_i + 1) % 3; end
  def category; @id.to_i % 3; end
  def totalpp; 15; end
end

module PBTerrain
  None = 0; Grass = 2; Sand = 3; DeepWater = 5; StillWater = 6; Water = 7; Waterfall = 8; WaterfallCrest = 9
  TallGrass = 10; Ice = 12
  # As v16 answers it: deep water, water and both waterfall tags, and never still water, which is only fished.
  def self.isSurfable?(tag); [Water, DeepWater, WaterfallCrest, Waterfall].include?(tag); end
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

# A map event for grid scenarios (what the locator reads); blocking makes its tile impassable.
class TestEvent
  attr_accessor :id, :name, :x, :y, :character_name, :direction, :blocking, :through
  def initialize(id, name, x, y); @id = id; @name = name; @x = x; @y = y; @character_name = "npc"; @direction = 2; @blocking = false; end
end

# The tileset surface Terrain and Pathfinder read for one-way ledges: a jump direction's passage byte leaves only the
# side opposite the jump open, as Pathfinder::LEDGE_OPP_BIT expects.
module TestLedge
  # RMXP passage bits (0x01 down, 0x02 left, 0x04 right, 0x08 up): each hop direction maps to its opposite side's.
  OPP_BIT = { 2 => 0x08, 8 => 0x01, 4 => 0x04, 6 => 0x02 }
  TILE_BASE = 1000

  # The synthetic tile id of a ledge hopped in dir, one per direction so each has its own passage byte.
  def self.tile_id(dir); TILE_BASE + dir; end

  # The passage byte of a ledge with hop direction dir: every side blocked except the one opposite the jump.
  def self.passage(dir); 0x0F & ~(OPP_BIT[dir] || 0); end
end

# RMXP's map data Table (data[x,y,layer]): the ledge tile id on layer 0 of a ledge tile, 0 elsewhere.
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

  # The terrain tag at (x,y): on a bridge, water (7) while the player is off it and count_bridge unset, else bridge
  # (15); else a set_terrain tag, else 1 on a placed ledge, else 0.
  def terrain_tag(x, y, count_bridge = false)
    if @bridges[[x, y]]
      return 15 if count_bridge || ($PokemonGlobal.bridge rescue 0).to_i > 0
      return 7
    end
    t = @terrain[[x, y]]
    return t if t
    @ledges[[x, y]] ? 1 : 0
  end

  # Registers a bridge tile at (x,y) (gen-6 terrain 15 over water 7). Returns self.
  def place_bridge(x, y); @bridges[[x, y]] = true; (PokeAccess::Terrain.forget_map_memo rescue nil); self; end

  # Places a gen-6 PBTerrain id at (x,y), as Terrain::KIND maps them (7 water, 10 tall grass, 12 ice...).
  def set_terrain(x, y, tag); @terrain[[x, y]] = tag; (PokeAccess::Terrain.forget_map_memo rescue nil); self; end

  # True while (x,y) is inside the map bounds; ledge_jump needs it to accept a landing tile.
  def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end

  # Loads an ASCII grid: '#' wall, '.' floor, 'C' counter, '~' water (terrain 7), '@' player start, any other letter
  # or digit an npc event. Returns self.
  def load_grid(rows)
    (PokeAccess::Terrain.forget_map_memo rescue nil)
    @grid = rows; @height = rows.length; @width = rows.map { |r| r.length }.max; @events = {}; eid = 0
    rows.each_index do |y|
      (0...rows[y].length).each do |x|
        ch = rows[y][x, 1]
        if ch == "@"
          $game_player.x = x; $game_player.y = y
        elsif ch == "~"
          @terrain[[x, y]] = 7
        elsif ch != "#" && ch != "." && ch != "C" && ch =~ /[A-Za-z0-9]/
          eid += 1; @events[eid] = TestEvent.new(eid, "EV#{eid}", x, y)
        end
      end
    end
    self
  end

  # Places a one-way ledge at (x,y) hopped in dir (2/4/6/8): passable only when entered moving in dir, terrain tag 1,
  # and the passage byte that lets ledge_dir_ok? permit exactly dir. Returns self.
  def place_ledge(x, y, dir)
    @ledges[[x, y]] = dir
    tid = TestLedge.tile_id(dir)
    @terrain_tags[tid] = 1
    @passages[tid] = TestLedge.passage(dir)
    (PokeAccess::Terrain.forget_map_memo rescue nil)
    self
  end

  # Clears all placed ledges (the reset calls it between suites).
  def clear_ledges; init_ledges; end

  # Drops the ASCII grid, terrain and bridges and restores the default open 20x20 map.
  def clear_grid; @grid = nil; @width = 20; @height = 20; @terrain = {}; @bridges = {}; (PokeAccess::Terrain.forget_map_memo rescue nil); end

  def cell(x, y); (@grid && y >= 0 && x >= 0 && @grid[y] && x < @grid[y].length) ? @grid[y][x, 1] : "#"; end
  def counter?(x, y); cell(x, y) == "C"; end
  def blocked?(x, y); c = cell(x, y); c == "#" || c == "C" || (c == "~" && !($PokemonGlobal.surfing rescue false)); end

  # True if a blocking event, not through, occupies (x,y).
  def blocking_event_at?(x, y)
    @events.each_value { |e| return true if e.respond_to?(:blocking) && e.blocking && !(e.respond_to?(:through) && e.through) && e.x == x && e.y == y }
    false
  end

  # Passability of a step from (x,y) in dir: a ledge only in its hop direction, a blocking event never, else the grid
  # (open space without one).
  def passable?(x, y, dir)
    dx = (dir == 6 ? 1 : (dir == 4 ? -1 : 0)); dy = (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
    nx = x + dx; ny = y + dy
    ld = @ledges[[nx, ny]]
    return dir == ld if ld
    return false if blocking_event_at?(nx, ny)
    return true unless @grid
    !blocked?(nx, ny)
  end

  # Resets the ledges, terrain, bridges and the passage and terrain-tag tables the real Game_Map carries.
  def init_ledges
    @ledges = {}; @passages = {}; @terrain_tags = {}; @terrain = {}; @bridges = {}
    @data = TestMapData.new(@ledges)
    (PokeAccess::Terrain.forget_map_memo rescue nil)
  end
  def data; @data; end
end

class Game_Temp;   attr_accessor :in_menu, :message_window_showing, :in_battle; end
class Game_System; def map_interpreter; @i ||= Object.new.tap { |o| def o.running?; false; end }; end; end
class Scene_Map;   def update(*a); end; end

# The selectable-window chain the generic net and the command hook bind to, shaped as in every engine: only the base
# and the leaf own an #update. Specs move a cursor by setting @index and calling update, as the game does.
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

# The frontier rental screen: the list in @sprites["list"], the rented indices in @choices, and pbChoosePokemon, the
# list's own loop, whose body a spec hands in as on_choose.
class Window_AdvancedCommandPokemon < Window_DrawableCommand; end
class Window_AdvancedCommandPokemonEx < Window_AdvancedCommandPokemon; end
class BattleSwapScene
  attr_accessor :on_choose
  attr_reader :sprites
  def initialize(rows, choices = nil)
    @sprites = { "list" => Window_AdvancedCommandPokemonEx.new(rows), "title" => FakeTextWin.new,
                 "help" => FakeTextWin.new }
    @choices = choices
  end
  # The two openers, which write the title and the first help line; the close the stock scene has.
  def pbStartRentScene(_rentals)
    @sprites["title"].text = "RENTAL POKéMON"
    @sprites["help"].text = "Choose the first Pokémon."
  end
  def pbStartSwapScene(_current, _new)
    @sprites["title"].text = "POKéMON SWAP"
    @sprites["help"].text = "Select Pokémon to swap."
  end
  def pbEndScene; end
  def list; @sprites["list"]; end
  def pbUpdateChoices(choices, rows); @choices = choices; list.commands = rows; end
  def pbChoosePokemon(_can_cancel); @on_choose.call if @on_choose; list.index; end
end

# The continue screen: pbStartScene builds the panels, each painting its lines in refresh (the continue one the
# trainer's, at the gen-6 positions); pbDrawCurrentSaveFile writes the save on offer, as multi-save titles do.
class PokemonLoadPanel
  def initialize(title, is_continue, trainer, mapname)
    @title = title
    @isContinue = is_continue
    @trainer = trainer
    @mapname = mapname
    refresh
  end
  def refresh
    rows = [[@title, 32, 10]]
    rows += [["Medallas:", 32, 112], [@trainer.numbadges.to_s, 206, 112], [@trainer.name, 112, 64], [@mapname, 386, 10]] if @isContinue
    pbDrawTextPositions(nil, rows)
  end
end
class PokemonLoadScene
  def pbStartScene(commands, show_continue, trainer, _framecount, _mapid)
    @sprites = {}
    commands.each_with_index do |c, i|
      @sprites["panel#{i}"] = PokemonLoadPanel.new(c, show_continue && i == 0, trainer, "Ruta 5")
    end
  end
  def pbDrawCurrentSaveFile(savename = "", auto = nil)
    pbDrawTextPositions(nil, [[auto.nil? ? savename : savename + " Auto Save", 0, 0]])
  end
end

# The classic pause menu scene, reduced to its opening, the info box the Safari and the Bug-Catching
# Contest fill (pbShowInfo, called before the commands are shown) and its command loop, which runs again on
# the same window after every option.
class PokemonMenu_Scene
  attr_reader :info
  def initialize; @sprites = { "cmdwindow" => Window_DrawableCommand.new(["Pokédex", "Bolsa"]) }; end
  def pbStartScene; end
  def pbShowInfo(text); @info = text; end
  def pbShowCommands(_commands); @sprites["cmdwindow"].update; @sprites["cmdwindow"].index; end
end

# Two sibling numeric option kinds, told apart only by class: NumberOption paints "Type value/total", SliderOption
# only its value, over a bar.
class NumberOption
  attr_reader :name, :optstart, :optend
  def initialize(name, optstart, optend); @name = name; @optstart = optstart; @optend = optend; end
end

class SliderOption
  attr_reader :name, :optstart, :optend
  def initialize(name, optstart, optend); @name = name; @optstart = optstart; @optend = optend; end
end

class EnumOption
  attr_reader :name, :values
  def initialize(name, values); @name = name; @values = values; end
end

# The Pokedex list window. Its rows are arrays here (the gen-6 and v19 shape), the last field being the
# regional offset flag the screen subtracts before painting the number.
class Window_Pokedex < Window_DrawableCommand; end

# The engine's text painters (drawTextEx here, pbDrawTextPositions below), which the mod wraps to feed PaintCapture.
def drawTextEx(_bitmap, _x, _y, _width, _lines, text, _base = nil, _shadow = nil); text; end

# The modal panel the engine blocks on until the confirm key (level-up stat gains); gen-6 takes the text alone.
def pbTopRightWindow(text); text; end

# The game's translation call: the text untranslated, each {n} replaced by its argument, as the engine does.
def _INTL(text, *args)
  t = text.to_s.dup
  args.each_with_index { |a, i| t.gsub!("{#{i + 1}}", a.to_s) }
  t
end

def pbDrawTextPositions(_bitmap, textpos)
  textpos
end

def drawFormattedTextEx(_bitmap, _x, _y, _width, text, _base = nil, _shadow = nil, _lineheight = 32)
  text
end

# The row painter of the command lists; PaintCapture samples it for one row's word.
def pbDrawShadowText(_bitmap, _x, _y, _width, _height, string, _base = nil, _shadow = nil, _align = 0)
  string
end

# The outline text painter of the sprite screens (Marin's quest log among them).
def pbDrawOutlineText(_bitmap, _x, _y, _width, _height, string, _base = nil, _shadow = nil, _align = 0)
  string
end

# The icon painter: the trainer card's badges are icons, which PaintCapture.icons counts.
def pbDrawImagePositions(_bitmap, images)
  images
end

# The gen-6 trainer card, reduced to its front: the rows of the stock card and one badge icon per badge the
# player has, as pbDrawTrainerCardFront draws them.
class PokemonTrainerCardScene
  attr_accessor :badges
  def initialize(badges = 2); @badges = badges; end
  def pbStartScene; pbDrawTrainerCardFront; end
  def pbDrawTrainerCardFront
    pbDrawTextPositions(nil, [["Dinero", 34, 112], ["$3000", 302, 112], ["01234", 468, 64], ["N° ID", 332, 64],
                              ["Rojo", 302, 64], ["Nombre", 34, 64]])
    pbDrawImagePositions(nil, (0...@badges).map { |i| ["Graphics/Pictures/badges", 72 + i * 48, 310, i * 32, 0, 32, 32] })
  end
end

# The gen-6 databox, reduced to the images its refresh draws: the gender icon and, for a caught foe (owned, a test
# seam), battleBoxOwned; extra lists the Graphics/Pictures names a game's own box draws after them.
class PokemonDataBox
  attr_accessor :owned, :shiny, :extra
  def initialize(battler); @battler = battler; @owned = false; @shiny = false; @extra = []; end

  def refresh
    imagepos = [["Graphics/Pictures/battleBoxGender.png", 0, 0, 0, 0, -1, -1]]
    imagepos.push(["Graphics/Pictures/battleBoxOwned.png", 8, 36, 0, 0, -1, -1]) if @owned
    imagepos.push(["Graphics/Pictures/shiny", 206, 36, 0, 0, -1, -1]) if @shiny
    @extra.each { |name| imagepos.push(["Graphics/Pictures/#{name}.png", 219, 50, 0, 0, -1, -1]) }
    pbDrawImagePositions(nil, imagepos)
    :refreshed
  end
end

# The item storage screen under its v16 name (v17 and later add the underscore).
class ItemStorageScene
  def initialize(title = "Guardar\nobjeto"); @title = title; end

  # The real order: the item list paints first, through pbDrawTextPositions, and then pbRefresh draws the title with
  # drawTextEx.
  def pbStartScene(*a)
    pbDrawTextPositions(nil, [["Pocion", 98, 14], ["Repelente", 98, 46]])
    drawTextEx(nil, 0, 4, 200, 2, @title)
    drawTextEx(nil, 0, 40, 200, 2, "Una pocion corriente.")
    self
  end
end
class WithdrawItemScene < ItemStorageScene; end

# The item storage screen as v17 names it (Soulstones, Awakening): its prompts go through pbDisplay and pbConfirm, and
# the Toss subclass overrides only initialize.
class ItemStorage_Scene
  def initialize(title = "Tirar\nobjeto"); @title = title; end
  def pbDisplay(msg, brief = false); msg; end
  def pbConfirm(msg); true; end
end
class TossItemScene < ItemStorage_Scene
  def initialize; super("Tirar\nobjeto"); end
end

# FL's Set the Controls (the v16/v17 script): the rebinding list, and the scene, whose pbMain runs one scripted step
# per frame (a line for its text box, or a call).
class Window_PokemonControls < Window_DrawableCommand
  attr_accessor :index, :defaults
  def initialize(controls); @controls = controls; @index = 0; end
  def setNewInput(key); @controls[@index].keyName = key; end
  # A frame of the window; with defaults handed in it is the press on Default, which swaps in a fresh list.
  def update(*a)
    if @defaults
      @controls = @defaults
      @defaults = nil
    end
    super
  end
end
class PokemonControlsScene
  def initialize(window, box, steps = []); @sprites = { "controlwindow" => window, "textbox" => box }; @steps = steps; end
  def pbMain
    @steps.each do |step|
      step.respond_to?(:call) ? step.call : (@sprites["textbox"].text = step)
      PokeAccess::Keys.run_frame_pollers
    end
    nil
  end
  def pbEndScene; nil; end
end

# FL's Roulette: the cursor's indices over its four-by-three table, the cells come up so far and the three painters
# the plugin reader hooks; bet moves the cursor and paints the multiplier a spec gives, 0 painting none as the script.
class RouletteScene
  COLUMNS = 4
  ROWS = 3
  Cursor = Struct.new(:indexX, :indexY)
  attr_accessor :result
  def initialize; @cursor = Cursor.new(1, 1); @playedBalls = [false] * (COLUMNS * ROWS); end
  def played!(i); @playedBalls[i] = true; end
  def bet(x, y, multiplier)
    @cursor.indexX = x
    @cursor.indexY = y
    @multiplier = multiplier
    pbDrawMultiplier
  end
  def pbDrawMultiplier
    return if @multiplier.to_i == 0
    pbDrawTextPositions(nil, [[@multiplier.to_s, 250, 180, true, nil, nil]])
  end
  def coins(n); @coins = n; pbDrawCredits; end
  def pbDrawCredits; pbDrawTextPositions(nil, [[@coins.to_s, 480, 34, true, nil, nil]]); end
  def pbEndSpin; nil; end
end

# A Triple Triad card: the four side numbers, derived here from the species number so a spec can assert them.
class TriadCard
  attr_reader :species, :north, :east, :south, :west, :type
  def initialize(species, form = 0)
    @species = species
    @form = form
    n = species.to_i
    @type = n % 3
    @north = (n % 10) + 1
    @east  = ((n + 3) % 10) + 1
    @south = ((n + 5) % 10) + 1
    @west  = ((n + 7) % 10) + 1
  end

  def createBitmap(size = 0); [self, size]; end
end

# The card shop, both halves: the preview is redrawn with createBitmap for the first card and each change of focused
# species, walked from $triad_shop_script in place of the arrow keys.
def pbBuyTriads(sorting = false)
  script = ($triad_shop_script || [])
  olditem = nil
  script.each_with_index do |sp, i|
    next if i > 0 && sp == olditem
    TriadCard.new(sp).createBitmap(1)
    olditem = sp
  end
  nil
end

def pbSellTriads(sorting = false)
  pbBuyTriads(sorting)
end

# The PC box screen: pbShowCommands writes its question into a standing window of its own, puts up the answers and
# returns once the player has answered.
class PokemonStorageScene
  def pbShowCommands(message, commands, index = 0); [message, commands, index]; end
  def pbDisplay(message); message; end

  # The box grid and party column loops the PC re-enters after every command menu, reduced to their entry.
  def pbSelectBoxInternal(_party); nil; end
  def pbSelectPartyInternal(_party, _depositing); nil; end
  def pbUpdateOverlay(selection, party = nil); [selection, party]; end

  # The gen-6 marking screen: the title in a message window, then a command list of the marks, each tagged with its
  # colour, then OK and Cancel; the loop is the spec's marking_loop.
  attr_accessor :marking_loop
  def pbMark(selected, heldpoke); instance_exec(selected, heldpoke, &@marking_loop); end
end

# A window that just holds text, as the standing information windows of the phone and the dex list do.
class FakeTextWin
  attr_accessor :text
  def initialize(t = ""); @text = t; end
end

# The gen-6 phone: one `start` that creates the windows, runs the screen and returns when it is over, with no
# pbStartScene or pbEndScene (as most games build it); nav is the contact names its loop walks.
class PokemonPhoneScene
  attr_reader :sprites
  attr_accessor :nav
  def initialize; @sprites = {}; @nav = []; end
  def start
    @sprites = { "bottom" => FakeTextWin.new, "info" => FakeTextWin.new }
    @sprites["info"].text = "Registrados <r>12"
    @nav.each do |place|
      @sprites["bottom"].text = "<ac>#{place}"
      PokeAccess::Keys.run_frame_pollers
    end
    :phone_done
  end
end

# The gen-6 dex list, its header in real windows (seen, owned, dexname).
class PokemonPokedexScene
  attr_reader :sprites
  attr_accessor :dummypokemon
  def initialize
    @sprites = { "seen" => FakeTextWin.new, "owned" => FakeTextWin.new, "dexname" => FakeTextWin.new }
  end
  def pbStartScene(*a); self; end
  def pbEndScene(*a); nil; end
  def pbRefresh; :dex_drawn; end

  # The gen-6 dex entry page's text: the entry paragraph (drawTextEx), then the header, labels, category, height and
  # weight, question marks if not owned; with no dummy pokemon (pre-v16) the values come from the message tables.
  def pbChangeToDexEntry(species)
    pk = @dummypokemon
    owned = ($Trainer.owned[species] rescue false)
    textpos = [[format("%03d  %s", (@shown_number || species), PBSpecies.getName(species)), 244, 40],
               ["Alt.", 318, 158], ["Peso", 318, 190]]
    if owned
      kind, entry, height, weight = if pk
                                      [pk.kind, pk.dexEntry, pk.height, pk.weight]
                                    else
                                      [pbGetMessage(MessageTypes::Kinds, species), pbGetMessage(MessageTypes::Entries, species), 7, 69]
                                    end
      drawTextEx(nil, 42, 240, 428, 4, entry)
      textpos.push(["Pokémon #{kind}", 244, 74], [format("%.1f m", height / 10.0), 466, 158],
                   [format("%.1f kg", weight / 10.0), 478, 190])
    else
      textpos.push(["Pokémon ?????", 244, 74], ["????.? m", 466, 158], ["????.? kg", 478, 190])
    end
    pbDrawTextPositions(nil, textpos)
  end
end

# The formatted text window: its constructor sets the text through text=, as the real one does.
class Window_AdvancedTextPokemon
  attr_reader :text
  def initialize(text = ""); self.text = text; end
  def text=(value); @text = value; end
end

class HallOfFameScene
  def writePokemonData(pk, hall = -1)
    drawTextEx(nil, 0, 0, 200, 1, "No. 025")
    drawTextEx(nil, 0, 20, 200, 1, "#{pk ? pk.name : '?'} Nv. #{pk ? pk.level : 0}")
    drawTextEx(nil, 0, 40, 200, 1, "IDNo.12345")
    hall
  end
  def writeWelcome; drawTextEx(nil, 0, 60, 200, 1, "Bienvenido al Salon de la Fama"); end
  def pbStartSceneEntry(*a); end
  # The gen-6 closing box and the congratulation it waits on, built as Africanvs's 0206 does.
  def writeTrainerData
    @sprites = { "messagebox" => Window_AdvancedTextPokemon.new("Name<r>Tester<br>IDNo.<r>12345<br>" \
                                                                "Time<r>01:23<br>Pokédex<r>10/20<br>") }
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new
    @sprites["msgwindow"].text = "¡Enhorabuena por tu victoria!"
    PokeAccess.say_dialogue("¡Enhorabuena por tu victoria!")
  end
end

# Marin's quest log as Africanvs's 0132 paints it: the constructor draws the cover and runs pbUpdate, whose loop
# polls a frame and then takes one scripted step ([:pbList, id], [:pbMain], [:pbLoad, page], [:pbSwitch, dir]).
class Questlog
  class << self
    attr_accessor :quests, :steps
  end

  def initialize
    @page = 0; @sel_one = 0; @sel_two = 0; @scene = 0; @mode = 0
    @ongoing = (Questlog.quests || []).reject { |q| q.completed }
    @completed = (Questlog.quests || []).select { |q| q.completed }
    pbDrawOutlineText(nil, 0, -176, 512, 384, "Misiones", nil, nil, 1)
    pbDrawOutlineText(nil, 0, -36, 512, 384, "Activas: " + @ongoing.size.to_s, nil, nil, 1)
    pbDrawOutlineText(nil, 0, 20, 512, 384, "Completas: " + @completed.size.to_s, nil, nil, 1)
    pbUpdate
  end

  def pbUpdate
    steps = (Questlog.steps || []).dup
    loop do
      PokeAccess::Keys.run_frame_pollers
      step = steps.shift
      break unless step
      send(*step)
    end
  end

  def pbSwitch(dir); @sel_one = (dir == :DOWN ? 1 : 0); end

  def pbList(id)
    PokeAccess::Keys.run_frame_pollers
    @sel_two = 0; @page = 0; @scene = 1; @mode = id
    list = (id == 0 ? @ongoing : @completed)
    list.each_with_index { |q, i| pbDrawOutlineText(nil, 11, -124 + (52 * i), 512, 384, q.name, nil, nil, 1) }
    empty = (id == 0 ? "Sin misiones activas" : "No has completado ninguna misión")
    pbDrawOutlineText(nil, 0, 0, 512, 384, empty, nil, nil, 1) if list.empty?
    pbDrawOutlineText(nil, 0, -176, 512, 384, id == 0 ? "Misiones activas" : "Misiones completadas", nil, nil, 1)
  end

  def pbMain
    PokeAccess::Keys.run_frame_pollers
    @sel_two = 0; @scene = 0
    pbDrawOutlineText(nil, 0, -176, 512, 384, "Misiones", nil, nil, 1)
    pbDrawOutlineText(nil, 0, -36, 512, 384, "Activas: " + @ongoing.size.to_s, nil, nil, 1)
    pbDrawOutlineText(nil, 0, 20, 512, 384, "Completadas: " + @completed.size.to_s, nil, nil, 1)
  end

  def pbLoad(_page)
    list = (@mode == 0 ? @ongoing : @completed)
    return if list.empty?
    quest = list[@sel_two]
    PokeAccess::Keys.run_frame_pollers
    @scene = 2
    pbDrawOutlineText(nil, 188, 162, 512, 384, "De " + quest.npc)
    pbDrawOutlineText(nil, 10, -178, 512, 384, quest.name)
    pbDrawOutlineText(nil, 8, 136, 512, 384, quest.completed ? "Completada" : "Sin completar")
  end
end

# The gen-6 options scene: pbUpdate and no selection-change method (the descriptions are written inline from
# pbOptions), as the real one has.
class PokemonOptionScene
  attr_accessor :sprites
  def initialize; @sprites = {}; end
  # pbUpdate drives the option window from inside itself, as the real scene does.
  def pbUpdate(*a); refresh_option; end
  def refresh_option; end
end

# The gen-6 party scene: pbChangeSelection returns where the cursor lands; pbChoosePokemon starts on @activecmd or
# on the slot the caller passes (a forced switch's fainted Pokemon).
class PokemonScreen_Scene
  attr_accessor :party, :activecmd, :sprites
  def initialize(party = []); @party = party; @activecmd = 0; @sprites = {}; end
  def pbChangeSelection(_key, currentsel); currentsel; end
  def pbChoosePokemon(_switching = false, initialsel = -1)
    @activecmd = initialsel if initialsel >= 0
    @activecmd
  end
  # A member's command menu; Reminiscencia's copy takes a fourth argument, whether the limits box shows.
  def pbShowCommands(_helptext, _commands, index = 0, _showheart = true); index; end
end

# The gen-6 summary scene: pbStartScene draws the first page during the open (drawPage -> drawPageOne), a chain the
# before-hook (reset_reorder) must not silence.
class PokemonSummaryScene
  attr_accessor :pokemon
  def initialize(pk = nil); @pokemon = pk; end
  def pbUpdate(*a); end

  # Awakening's shape, the only gen-6 one with these: the action menu takes the command list first and no message,
  # and the ribbons page redraws its cursor through drawSelectedRibbon.
  def pbShowCommands(commands, index = 0); [commands, index]; end
  def drawSelectedRibbon(ribbonid); ribbonid; end
  def pbStartScene(party = nil, partyindex = 0, *a)
    @pokemon = party ? party[partyindex] : @pokemon
    @page = 1
    drawPage(@page)
  end
  def drawPage(page)
    case page
    when 1 then drawPageOne(@pokemon)
    when 2 then drawPageTwo(@pokemon)
    when 3 then drawPageThree(@pokemon)
    when 4 then drawPageFour(@pokemon)
    when 5 then drawPageFive(@pokemon)
    end
  end
  # The egg branch lives here, as in the gen-6 games, reached only through drawPageOne; the page's positions batch is
  # the spec's @page_one_paint (nil paints nothing).
  def drawPageOne(pk = nil)
    (@pokemon = pk) if pk
    return drawPageOneEgg(@pokemon) if @pokemon && (@pokemon.egg? rescue false)
    pbDrawTextPositions(nil, @page_one_paint) if @page_one_paint
    nil
  end

  # The other four pages. The memo page is one formatted paragraph, the spec's @memo_paint (nil paints nothing).
  def drawPageTwo(pk = nil)
    (@pokemon = pk) if pk
    drawFormattedTextEx(nil, 232, 78, 276, @memo_paint) if @memo_paint
  end
  def drawPageThree(pk = nil); (@pokemon = pk) if pk; end
  def drawPageFour(pk = nil); (@pokemon = pk) if pk; end
  def drawPageFive(pk = nil); (@pokemon = pk) if pk; end

  # The two loops the summary runs inside itself, the move cursor and the ribbon grid; each ends on a
  # redraw of the page it covered, which a spec makes itself.
  def pbMoveSelection; :moves_done; end
  def pbRibbonSelection; :ribbons_done; end

  # The egg page: labels and the item through the positions batch, and the memo as one formatted paragraph.
  def drawPageOneEgg(_pk = nil)
    pbDrawTextPositions(nil, [["TRAINER MEMO", 26, 22], ["Item", 66, 324], ["Ninguno", 16, 358]])
    drawFormattedTextEx(nil, 232, 86, 268,
                        "Un Huevo misterioso recibido en Ciudad Verde. Parece que tardara mucho en eclosionar.")
    :egg_page
  end
end

# The field-move menu the v21 reader hooks: the pbShowCommands loop calls refresh_buttons on each cursor move, over
# the indices a spec seeds in nav.
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
# A trainer exists by default: with none, Appearance.selecting? takes the player to be on the character picker and
# Spatial.busy? silences the guide and the soundscape. A spec that wants the picker sets $Trainer = nil.
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
# Surfing, diving and the bike, writable so a spec can put the player afloat, under the sea or on wheels.
def $PokemonGlobal.surfing; @surfing ? true : false; end
def $PokemonGlobal.surfing=(v); @surfing = v; end
def $PokemonGlobal.diving; @diving ? true : false; end
def $PokemonGlobal.diving=(v); @diving = v; end
def $PokemonGlobal.bicycle; @bicycle ? true : false; end
def $PokemonGlobal.bicycle=(v); @bicycle = v; end
# The bridge state (0 off a bridge), writable: the pathfinder moves it around its searches and terrain depends on it.
def $PokemonGlobal.bridge; @bridge.to_i; end
def $PokemonGlobal.bridge=(v); @bridge = v; end
# The ice-slide flag as gen-6 to v20 name it (ice_sliding from v21), raised while a slide carries the player.
def $PokemonGlobal.sliding; @sliding ? true : false; end
def $PokemonGlobal.sliding=(v); @sliding = v; end
# The appearance in use (-1 until one is chosen at a new game; the first, 0, in the game under way the
# harness plays), and the gen-6 function that changes it: an id out of range is refused and nothing changes.
def $PokemonGlobal.playerID; @playerID.nil? ? 0 : @playerID; end
def $PokemonGlobal.playerID=(v); @playerID = v; end

def pbChangePlayer(id)
  return false if id < 0 || id >= 8
  $PokemonGlobal.playerID = id
  true
end

# Game_Picture, whose show the mod hooks to narrate picture-only screens (a new-game character slider).
class Game_Picture
  attr_reader :number, :name, :x, :y
  def initialize(number = 1); @number = number; @name = ""; @x = 0; @y = 0; end
  def show(name, origin = 0, x = 0, y = 0, zoom_x = 100, zoom_y = 100, opacity = 255, blend_type = 0)
    @name = name; @x = x; @y = y
    self
  end
  def erase; @name = ""; self; end
end
