# Stand-ins both engines' stubs share: the RGSS classes and the Essentials drawing and message functions the
# mod calls the same way in every era. engine_gen6.rb and engine_gamedata.rb load it first.

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

# A message table's entry, "msg<id>"; the gen-6 FormNames table names no form unless a spec stubs it.
def pbGetMessage(type, id); defined?(MessageTypes::FormNames) && type == MessageTypes::FormNames ? "" : "msg#{id}"; end

def pbGetMessageFromHash(type, id); "place#{id}"; end

# MapInfos for Locator.map_name (id => object with .name), only for the ids the specs visit.
class TestMapInfo; attr_reader :name; def initialize(id, name = nil); @name = name || "Mapa #{id}"; end; end

MAPINFO_IDS = [1, 35, 40, 999]

# The Poke Radar's search: the patches it shook are whatever a spec left in the radar's state.
def pbPokeRadarHighlightGrass(_showmessage = true); nil; end

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

# The tile ids World::Terrain reads one-way ledges by: one synthetic id per hop direction, tagged as a ledge.
module TestLedge
  TILE_BASE = 1000

  # The synthetic tile id of a ledge hopped in dir.
  def self.tile_id(dir); TILE_BASE + dir; end
end

class Game_System; def map_interpreter; @i ||= Object.new.tap { |o| def o.running?; false; end }; end; end

class Scene_Map;   def update(*a); end; end

# The selectable-window chain the generic net and the command hook bind to, shaped as in every engine: only the base
# and the leaf own an #update. Specs move a cursor by setting @index and calling update, as the game does.
class SpriteWindow_Base
  attr_accessor :active, :visible, :index
  def initialize; @active = true; @visible = true; @index = 0; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
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

class EnumOption
  attr_reader :name, :values
  def initialize(name, values); @name = name; @values = values; end
end

# The Pokedex list window. Its rows are arrays here (the gen-6 and v19 shape), the last field being the
# regional offset flag the screen subtracts before painting the number.
class Window_Pokedex < Window_DrawableCommand; end

# The engine's text painters (drawTextEx here, pbDrawTextPositions below), which the mod wraps to feed PaintCapture.
def drawTextEx(_bitmap, _x, _y, _width, _lines, text, _base = nil, _shadow = nil); text; end

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

# The icon painter: the trainer card's badges are icons, which PaintCapture.icons counts.
def pbDrawImagePositions(_bitmap, images)
  images
end

# The formatted text window: its constructor sets the text through text=, as the real one does.
class Window_AdvancedTextPokemon
  attr_reader :text
  def initialize(text = ""); self.text = text; end
  def text=(value); @text = value; end
end

# The plain text window, the one a function builds its own money window from: as the real one, the constructor keeps
# the text and sizes the window to it (resizeToFit), newWithSize goes through the constructor, and text= repaints.
class Window_UnformattedTextPokemon
  attr_reader :text
  def initialize(text = ""); @text = text; resizeToFit(text); end
  def self.newWithSize(text, _x, _y, _width, _height, _viewport = nil); new(text); end
  def text=(value); @text = value; end
  def resizeToFit(_text, _maxwidth = -1); nil; end
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
