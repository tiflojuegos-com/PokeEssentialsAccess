# Stand-ins for the GameData-era engine (Essentials v17+, Ruby-modern): GameData::* and UI::* present,
# $player instead of $Trainer, so the modern-path readers (v21/v22 triggers, gamedata_trainer_info) load
# and run. Shares the generic engine stubs (Win32/Graphics/Input/Game_*) with the gen-6 file but flips the
# data API on. Selected by PA_ENGINE=gamedata.
#
# Known divergences from the real engine (a spec relying on these tests the stub, not the game):
#   - GameData::Move.try_get NEVER returns nil (it always constructs); the real try_get returns nil for an
#     unknown id, so no spec here can exercise a reader's missing-move fallback. MapMetadata.try_get is the
#     opposite extreme: always nil.
#   - Input.trigger?/press? always return false: nothing input-driven ever fires on its own; specs must
#     call the handler they want to exercise directly.
#   - No surf/waterfall terrain model at all (the gen-6 stub at least has PBTerrain without the waterfall
#     tags 8-9); water-dependent behaviour is out of scope in this engine's specs.
#   - The v22 UI:: screens (see the UI section below) carry no sprite layer, no graphics and no input loop:
#     each class keeps ONLY the state its reader reads plus the CALL ORDER the dedup/reentrancy contracts
#     depend on. Divergences are listed there, class by class.

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

# The engine's sound-effect function, as every era defines it. Records what was asked to play, so a filter
# in front of it (the game-bump mute) can be pinned by what does and does not arrive here.
def pbSEPlay(param, volume = nil, pitch = nil)
  ($se_played ||= []).push(param)
end

module Graphics
  def self.update; end
  def self.frame_rate; 60; end
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
  end
end

def pbGetMessage(type, id); "msg#{id}"; end
def pbGetMessageFromHash(type, id); "place#{id}"; end

# The modern message entry, a bare top-level function as Essentials v19+ defines it (private on Object):
# the dialogue reader must wrap THIS one here, and the gen-6 stub's Kernel singleton there.
def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil); message; end
module MessageTypes; REGION_LOCATION_NAMES = 13; end

# MapInfos for Locator.map_name, same shape and same synthetic ids as the gen-6 stub so both engines can be
# held to the same expectations. pbLoadRxData is deliberately ABSENT: v19+ replaced it with pbLoadMapInfos,
# six of the thirteen games have only the latter, and a stub that offered both would keep hiding a reader
# that asks for the gen-6 loader -- which is exactly how every modern game ended up with no map name at all.
class TestMapInfo; attr_reader :name; def initialize(id, name = nil); @name = name || "Mapa #{id}"; end; end
MAPINFO_IDS = [1, 35, 40, 999]
def pbLoadMapInfos
  table = MAPINFO_IDS.inject({}) { |h, id| h[id] = TestMapInfo.new(id); h }
  table[36] = TestMapInfo.new(36, "Casa de \\PN")
  table
end

class Table; def self._load(s); allocate; end; def _dump(d); ""; end; end
class Color; def self._load(s); allocate; end; def _dump(d); ""; end; end
class Tone;  def self._load(s); allocate; end; def _dump(d); ""; end; end

module GameData
  class Move
    def self.get(id); new(id); end
    def self.try_get(id); new(id); end
    def initialize(id); @id = id; end
    def name; "Move#{@id}"; end
    def power; 40; end
    def accuracy; 100; end
    def type; :TYPE1; end
    def description; "desc#{@id}"; end
  end
  class Type;    def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Type#{@i}"; end; end

  # The slice of GameData::Item the bag and mart readers touch. There is no PBS here, so the two traits
  # that change what is SPOKEN are decided by the id, by convention (documented so a spec never has to
  # guess): an id starting with KEY is an important item (show_quantity? false -> the bag reads no "xN"),
  # and an id starting with TM is a machine (display_name appends the taught move, as the real one does
  # for TMs -- the case that makes display_name differ from name). Prices are fixed: 500 money, 12 BP.
  class Item
    def self.get(i); new(i); end
    def self.try_get(i); new(i); end
    def initialize(i); @i = i; end
    def id; @i; end
    def name; "Item#{@i}"; end
    def portion_name; "Item#{@i}"; end
    def portion_name_plural; "Item#{@i}s"; end
    def description; "idesc#{@i}"; end
    def is_machine?; (@i.to_s =~ /\ATM/) ? true : false; end
    def is_important?; (@i.to_s =~ /\AKEY/) ? true : false; end
    def show_quantity?; !is_important?; end
    def move; :THUNDERBOLT; end
    def display_name; is_machine? ? "#{name} #{GameData::Move.get(move).name}" : name; end
    def price; 500; end
    def bp_price; 12; end
    def sell_price; 250; end
  end

  # A bag pocket's spoken name is its own id ("Medicine"), not a decorated "PocketMedicine": the reader
  # already wraps it in the bag_pocket string, and a readable assertion is worth more than symmetry with
  # the other stand-ins here.
  class BagPocket; def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; @i.to_s; end; def auto_sort; false; end; end
  class Species
    def self.get(i); new(i); end
    def initialize(i); @i = i; end
    def name; "Species#{@i}"; end
    def category; "cat#{@i}"; end
    def pokedex_entry; "dex#{@i}"; end
  end
  class Ability; def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Ability#{@i}"; end; end
  class Nature;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Nature#{@i}"; end; end
  class Status;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Status#{@i}"; end; end
  class Stat;    def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Stat#{@i}"; end; end
  class Ribbon;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Ribbon#{@i}"; end; def description; "rdesc#{@i}"; end; end
  class MapMetadata; def self.try_get(i); nil; end; end
end

# Minimal stand-in for the v22 summary visuals (Essentials v22: UI::PokemonSummaryVisuals) so the real
# summary_v22 hooks register and can be driven. It reproduces the one behaviour the reader ordering depends
# on: set_party_index mutates the shown Pokemon and then calls refresh INTERNALLY (reentrant hook order).
module UI
  class PokemonSummaryVisuals
    attr_accessor :party, :party_index, :pokemon, :page

    def initialize(party, party_index = 0)
      @party = party
      @party_index = party_index
      @pokemon = party[party_index]
      @page = :info
    end

    def refresh; end

    def set_party_index(new_index)
      return if @party_index == new_index
      @party_index = new_index
      @pokemon = @party[@party_index]
      refresh
    end

    def go_to_next_page(page = :skills)
      @page = page
      refresh
    end

    def refresh_move_cursor; end
    def refresh_ribbon_cursor; end
  end
end

# MAX_PARTY_SIZE is the one engine constant the v22 party reader reads directly (to tell the trailing
# Cancel/Confirm buttons from a party slot); the real Settings module carries it, so provide it rather than
# leaving the reader on its `rescue 6` fallback. Nothing else in the toolkit reads a bare Settings.
module Settings; MAX_PARTY_SIZE = 6; end

# ===================================================================================================
# The v22 UI:: rework (Essentials v22, Data/Scripts/016_UI/*). Every screen owns a *Visuals object whose
# list windows are PASSIVE (created active = false), so the generic active-window reader never sees them:
# the mod instead hooks each Visuals' own cursor callback (see core/menus/v22/screen_v22.rb). These
# stand-ins reproduce, per class, only the state the readers read plus the call order the dedup and
# reentrancy contracts depend on.
#
# Divergences from the real engine assumed here (a spec relying on these tests the stub, not the game):
#   - No @sprites layer. The real BagVisuals/MartVisuals delegate index/item to @sprites[:item_list];
#     here the pocket/stock array IS the list and @index indexes it. An index past the last entry is the
#     trailing "CLOSE BAG" / "Quit shopping" row (item => nil), which is what the real list reports too.
#   - No navigate loop. UI::BaseVisuals#navigate (009_Scenes/003_UI_base.rb) runs
#     `refresh_on_index_changed(old) if index != old` after update_input; a spec that needs that follow-up
#     call makes it itself, which is exactly what the engine does on the same frame.
#   - No animation loops. go_to_next_box / go_to_previous_box / show_party_panel / hide_party_panel drop
#     the Graphics + System.uptime slide and keep only the bookkeeping the reader observes.
#   - The held Pokemon lives on @sprites[:cursor] in the real screen (set by pick_up_pokemon); here
#     PokemonStorageVisuals#hold_pokemon sets it directly. That method is the only invented name below.
#   - Bag/Mart initialize does NOT announce, matching the real ones (neither calls set_pocket/set_index).
module UI
  # The common base: every *Visuals exposes #index, its @sprites hash and an (empty by default) cursor
  # callback, and update_visuals updates every sprite it owns -- the real one via pbUpdateSpriteHash, which
  # is how a screen's per-frame tick reaches its command window's own update (and thus the generic reader).
  class BaseVisuals
    attr_reader :index, :sprites

    def initialize; @sprites = {}; end
    def refresh; end
    def refresh_on_index_changed(old_index); end
    def update_visuals
      (@sprites || {}).each_value { |s| s.update if s.respond_to?(:update) }
    end
  end

  # 016_UI/007_UI_Bag.rb. item navigation goes through refresh_on_index_changed; a pocket change goes
  # through set_pocket, which does NOT fire it (it calls refresh) -- the split the bag reader is built on.
  class BagVisuals < BaseVisuals
    attr_reader :pocket

    def initialize(bag, mode = :normal)
      super()
      @bag = bag
      @mode = mode
      @pocket = bag.last_viewed_pocket
      @index = bag.last_viewed_index(@pocket)
    end

    # The focused item id, or nil on the trailing "CLOSE BAG" row.
    def item
      e = @bag.pockets[@pocket][@index]
      e && e[0]
    end

    def set_index(value)
      @index = value
      refresh_on_index_changed(nil)
    end

    def set_pocket(new_pocket)
      @pocket = new_pocket
      @bag.last_viewed_pocket = @pocket
      @index = @bag.last_viewed_index(@pocket)
      @index = 0 if @index > @bag.pockets[@pocket].length
      refresh
    end

    def refresh_on_index_changed(old_index)
      @bag.set_last_viewed_index(@pocket, @index)
    end
  end

  # 016_UI/020_UI_PokeMart.rb. BagSellVisuals really is a BagVisuals subclass whose own
  # refresh_on_index_changed calls super -- which is why BOTH the bag hook and the sell hook fire on one
  # cursor move, and only the reader's dedup keeps the line from being spoken twice.
  class BagSellVisuals < BagVisuals
    def refresh_on_index_changed(old_index); super; end
  end

  # 016_UI/020_UI_PokeMart.rb price wrappers: the unit belongs to the wrapper, not to the reader.
  class MartStockWrapper
    def initialize(stock); @stock = stock; end
    def length; @stock.length; end
    def [](index); @stock[index]; end
    def buy_price(item); item.nil? ? 0 : GameData::Item.get(item).price; end
    def buy_price_string(item); "$#{buy_price(item)}"; end
    def sell_price(item); item.nil? ? 0 : GameData::Item.get(item).sell_price; end
  end

  # 016_UI/021_UI_BattlePointShop.rb: same list, Battle Points instead of money.
  class BPShopStockWrapper < MartStockWrapper
    def buy_price(item); item.nil? ? 0 : GameData::Item.get(item).bp_price; end
    def buy_price_string(item); "#{buy_price(item)} BP"; end
  end

  class MartVisuals < BaseVisuals
    def initialize(stock, index = 0); super(); @stock = stock; @index = index; end

    # The focused item id, or nil on the trailing "Quit shopping" row.
    def item; @stock[@index]; end

    def set_index(value)
      @index = value
      refresh_on_index_changed(nil)
    end

    def refresh_on_index_changed(old_index); end
  end

  # BPShopVisuals deliberately does NOT redefine the cursor callback: the real one inherits it, so the
  # single hook on MartVisuals must cover the BP shop too.
  class BPShopVisuals < MartVisuals; end

  # 016_UI/003_UI_Pokedex_Main.rb. The species list is passive: the screen exposes the focused species id
  # (real: @sprites[:dex_list].species_id) and set_index chains to the cursor callback the reader hooks.
  class PokedexVisuals < BaseVisuals
    def initialize(dex_list, index = 0); super(); @dex_list = dex_list; @index = index; end

    def species; @dex_list[@index]; end

    def set_index(value)
      @index = value
      refresh_on_index_changed(nil)
    end

    def refresh_on_index_changed(old_index); end
  end

  # 016_UI/005_UI_Party.rb. set_index is the reliable hook (both navigate loops call it) and it does NOT
  # chain to refresh_on_index_changed. index MAX_PARTY_SIZE is Cancel, or Confirm in multi-select mode
  # (choose_entry_order), where Cancel moves to MAX_PARTY_SIZE + 1.
  class PartyVisuals < BaseVisuals
    def initialize(party, mode = :normal)
      super()
      @party = party
      @mode = mode
      @multi_select = (mode == :choose_entry_order)
      @index = (party.length == 0) ? Settings::MAX_PARTY_SIZE : 0
    end

    def set_index(new_index); @index = new_index; end
  end

  # 016_UI/001_UI_PauseMenu.rb. @commands is [[ids], [names]] and the visible list is a real command window
  # in @sprites[:commands], so the screen's per-frame update_visuals reaches that window's OWN update --
  # the one the generic command reader hooks. Divergence: the real set_commands seeds the cursor from
  # $game_temp.menu_last_choice, which the stubbed Game_Temp leaves nil, so it falls back to 0.
  class PauseMenuVisuals < BaseVisuals
    def initialize
      super
      @sprites[:commands] = Window_CommandPokemon.new([])
      @sprites[:commands].visible = false
    end

    def set_commands(commands)
      @commands = commands
      win = @sprites[:commands]
      win.commands = @commands[1]
      win.index = (($game_temp.menu_last_choice rescue nil) || 0)
      win.visible = true
    end
  end

  # 016_UI/013_UI_Load.rb (title screen). @commands is a HASH {:continue => "Continue", ...} and @index is
  # one of its KEYS (a symbol, not a number); @save_data is an array of [filename, save hash]. On :continue
  # LEFT/RIGHT cycle the save slot through set_slot_index, which never touches @index -- the split the load
  # reader is built on. The index wrap and the unchanged-slot early return are kept because they are what
  # decides whether the original runs at all.
  class LoadVisuals < BaseVisuals
    attr_reader :slot_index, :save_data

    def initialize(commands, save_data, default_slot_index = 0)
      super()
      @commands = commands
      @save_data = save_data
      @index = commands.keys.first
      @slot_index = default_slot_index
    end

    def set_index(new_index)
      @index = new_index
      refresh_on_index_changed(@index)
    end

    def set_slot_index(new_index, forced = false)
      return if @save_data.nil? || @save_data.empty?
      new_index += @save_data.length while new_index < 0
      new_index -= @save_data.length while new_index >= @save_data.length
      return if !forced && @slot_index == new_index
      @slot_index = new_index
    end
  end

  # 016_UI/014_UI_Save.rb (in-game save). @index is a numeric slot; the wrap allows one extra entry past the
  # last save (the empty "new slot"), which is why an index of save_data.length is legal and reads as empty.
  class SaveVisuals < BaseVisuals
    def initialize(save_data, current_save_data = nil, default_index = 0)
      super()
      @save_data = save_data
      @current_save_data = current_save_data
      @index = default_index
    end

    def set_index(new_index, forced = false)
      slots = @save_data.length + 1
      new_index += slots while new_index < 0
      new_index -= slots while new_index >= slots
      return if !forced && @index == new_index
      @index = new_index
    end
  end

  # 016_UI/017_UI_PokemonStorage.rb. index -1 box name, -2 party button, -3 close, 0+ a slot; box is -1
  # while the party panel is up, else the box number. initialize really does end in set_index(@index), so
  # constructing the screen announces the focused slot -- which is what re-arms the read on a reopen.
  class PokemonStorageVisuals < BaseVisuals
    attr_reader :box

    def initialize(storage, mode = :normal, index = 0)
      super()
      @storage = storage
      @mode = mode
      @index = index
      @box = (mode == :deposit) ? -1 : storage.currentBox
      @held = nil
      set_index(@index)
    end

    # The Pokemon in the storage space under the cursor (nil on a control or an empty slot).
    def slot_pokemon
      return nil if @index < 0
      return @storage.party[@index] if @box < 0
      @storage[@box][@index]
    end

    def pokemon; holding_pokemon? ? @held : slot_pokemon; end
    def holding_pokemon?; !@held.nil?; end

    # Test seam for the picked-up Pokemon (the real screen parks it on @sprites[:cursor]).
    def hold_pokemon(pkmn); @held = pkmn; end

    def set_index(new_index, no_mosaic = false)
      @index = new_index
      refresh_on_index_changed(@index)
    end

    def go_to_next_box(new_box_number = -1)
      new_box_number = (@storage.currentBox + 1) % @storage.maxBoxes if new_box_number < 0
      @storage.currentBox = new_box_number
      @box = new_box_number
    end

    def go_to_previous_box(new_box_number = -1)
      new_box_number = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes if new_box_number < 0
      @storage.currentBox = new_box_number
      @box = new_box_number
    end

    def show_party_panel; @box = -1; set_index(0); end
    def hide_party_panel; @box = @storage.currentBox; set_index(-2); end
  end
end

# The player-owned containers the v22 screens are constructed with. Kept out of UI:: because that is the
# engine's namespace and these are the game objects (Bag / PokemonStorage / PokemonBox) it hands them.

# Stand-in for Bag: pockets is {pocket_symbol => [[item_id, quantity], ...]}, the shape the real pockets
# have, and quantity sums the item across every pocket as the real Bag#quantity does.
class TestBag
  attr_accessor :last_viewed_pocket
  attr_reader :pockets

  def initialize(pockets, last_viewed_pocket = nil)
    @pockets = pockets
    @last_viewed_pocket = last_viewed_pocket || pockets.keys.first
    @last_viewed = {}
  end

  def last_viewed_index(pocket); @last_viewed[pocket] || 0; end
  def set_last_viewed_index(pocket, index); @last_viewed[pocket] = index; end

  def quantity(item)
    n = 0
    @pockets.each_value { |list| list.each { |e| n += e[1].to_i if e[0] == item } }
    n
  end
end

# Stand-in for PokemonBox: a named array of slots (nil = empty).
class TestBox
  attr_accessor :name

  def initialize(name, slots = []); @name = name; @slots = slots; end
  def [](i); @slots[i]; end
  def []=(i, v); @slots[i] = v; end
  def length; @slots.length; end
end

# Stand-in for PokemonStorage: storage[box] is the box, storage[box, i] the slot in it, storage.party the
# party column of the PC (mirroring the real PokemonStorage#[] arity switch).
class TestStorage
  attr_accessor :currentBox
  attr_reader :party

  def initialize(boxes, party = [])
    @boxes = boxes
    @party = party
    @currentBox = 0
  end

  def maxBoxes; @boxes.length; end

  def [](box, index = nil)
    return @boxes[box] if index.nil?
    @boxes[box][index]
  end
end

# Minimal stand-in for the v21.1 battle menus (Essentials Battle::Scene::MenuBase + FightMenu) so the real
# battle_v21 hooks register and can be driven. It reproduces the one behaviour the mega-toggle cue depends
# on: setIndexAndMode assigns @mode DIRECTLY (never through the mode= setter), which is exactly why the open
# must prime @access_mega for the first real toggle to be voiced. battler returns nil so read_menu no-ops
# (no move to read), keeping the spec's spoken log to just the mega cue.
module Battle
  class Scene
    class MenuBase
      attr_reader :index, :mode

      def initialize; @index = 0; @mode = 0; end

      def index=(value); old = @index; @index = value; refresh if @index != old; end

      def mode=(value); old = @mode; @mode = value; refresh if @mode != old; end

      def setIndexAndMode(index, mode)
        oldIndex = @index
        oldMode = @mode
        @index = index
        @mode = mode
        refresh if @index != oldIndex || @mode != oldMode
      end

      def refresh; end
    end

    class FightMenu < MenuBase
      def battler; nil; end
    end
  end
end

# UI::BaseScreen, the root every v22 screen inherits from. It was ABSENT, which made Engine.has?(:ui_rework)
# false in both engines -- so the four in-screen message hooks of menus/v22/screen_v22 never registered in
# any test run, and neither did anything gated on the Sky fork. The four methods are here because a hook
# binds per method: with only one of them present the other three would still be invisible.
module UI
  class BaseScreen
    def show_message(text); text; end
    def show_confirm_message(text); text; end
    def show_confirm_serious_message(text); text; end
    def show_choice_message(text, _choices = nil); text; end
  end
end

module Essentials; VERSION = "21.1"; end

module Game_Player_GD; end
class Game_Player
  attr_accessor :x, :y, :direction, :jumping
  def initialize; @x = 5; @y = 5; @direction = 2; @jumping = false; end
  def update(*a); end
  def passable?(x, y, dir); ($game_map.passable?(x, y, dir) rescue true); end
  def moving?; false; end
  def jumping?; @jumping; end
end

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

  # The terrain tag at (x,y): 1 on a placed ledge (so Terrain.ledge_at? sees it), else 0.
  def terrain_tag(x, y); @ledges[[x, y]] ? 1 : 0; end

  # True while (x,y) is inside the map bounds; ledge_jump needs it to accept a landing tile.
  def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end

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

  # True if a blocking event occupies (x,y) (a solid event makes its tile impassable, as in the real engine).
  def blocking_event_at?(x, y)
    @events.each_value { |e| return true if e.respond_to?(:blocking) && e.blocking && e.x == x && e.y == y }
    false
  end

  # Passability of a one-step move from (x,y) in dir. A ledge tile is passable only when approached moving in
  # its hop direction (high side); a blocking event blocks the destination; otherwise open (modern stub has
  # no grid harness).
  def passable?(x, y, dir)
    dx = (dir == 6 ? 1 : (dir == 4 ? -1 : 0)); dy = (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
    nx = x + dx; ny = y + dy
    ld = @ledges[[nx, ny]]
    return dir == ld if ld
    return false if blocking_event_at?(nx, ny)
    true
  end

  # Exposes the passage/terrain-tag tables the real Game_Map carries, so ledge_passage can read them.
  def init_ledges; @ledges = {}; @passages = {}; @terrain_tags = {}; @data = TestMapData.new(@ledges); end
  def data; @data; end
end

class Game_Temp;   attr_accessor :in_menu, :message_window_showing, :in_battle, :menu_last_choice; end
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
# The concrete command window every modern screen instantiates (the v22 pause menu keeps one in
# @sprites[:commands]); it adds nothing the readers need beyond its Window_DrawableCommand base.
class Window_CommandPokemon < Window_DrawableCommand; end

# The two numeric option kinds as modern Essentials declares them: SIBLING classes with lowest_value /
# highest_value. A NumberOption paints "Type value/total"; a SliderOption paints ONLY its value, over a bar.
class NumberOption
  attr_reader :name, :lowest_value, :highest_value
  def initialize(name, lo, hi); @name = name; @lowest_value = lo; @highest_value = hi; end
end

class SliderOption
  attr_reader :name, :lowest_value, :highest_value
  def initialize(name, lo, hi); @name = name; @lowest_value = lo; @highest_value = hi; end
end

class EnumOption
  attr_reader :name, :values
  def initialize(name, values); @name = name; @values = values; end
end

# The Pokedex list window. Its rows are HASHES here (the modern shape), carrying :shift for the regional
# offset the screen subtracts before painting the number.
class Window_Pokedex < Window_DrawableCommand; end

# The engine's two text-painting functions. Every game has them and the mod wraps both to feed PaintCapture;
# with neither in the harness the whole capture path -- arm, note, take -- ran in no test at all, which is
# how a capture hook bound to a class name no modern game uses went eight games unnoticed.
def drawTextEx(_bitmap, _x, _y, _width, _lines, text, _base = nil, _shadow = nil); text; end

# The modal panel the engine blocks on until the confirm key, used for the level-up stat gains. The
# modern signature takes an optional scene the gen-6 one does not have.
def pbTopRightWindow(text, scene = nil); [text, scene]; end

def pbDrawTextPositions(_bitmap, textpos)
  textpos
end

def drawFormattedTextEx(_bitmap, _x, _y, _width, text, _base = nil, _shadow = nil, _lineheight = 32)
  text
end

# The item storage screen under the name every v18-and-later game gives it. Same shape as the gen-6 stub's,
# so both spellings of the capture hook are pinned, each in the engine pass that has that spelling.
class ItemStorage_Scene
  def initialize(title = "Withdraw
Item"); @title = title; end

  # The real order, checked in all eleven games that have this screen: the item LIST refreshes first,
  # through pbDrawTextPositions, and only then does pbRefresh draw the title with drawTextEx. A stub that
  # painted the title first made "take the first row" look correct when it was reading the first item.
  def pbStartScene(*a)
    pbDrawTextPositions(nil, [["Potion", 98, 14], ["Repel", 98, 46]])
    drawTextEx(nil, 0, 4, 200, 2, @title)
    drawTextEx(nil, 0, 40, 200, 2, "An ordinary potion.")
    self
  end
end
class WithdrawItemScene < ItemStorage_Scene; end

# A window that just holds text, as the phone's standing information windows do.
class FakeTextWin
  attr_accessor :text, :visible
  def initialize(t = ""); @text = t; @visible = true; end
end


# The two shop screens with standing information windows beside their list. The mart is every game's; the
# Battle Point shop is five of them. Both are HERE and not in the spec because core declares its watches at
# load: a class that appears afterwards is a reader bound to nothing.
#
# Their LIFECYCLES differ and that is the point of reproducing them: the Battle Point shop has the engine's
# pbStartScene/pbEndScene, and the mart has neither -- it names both ends after the mode, pbStartBuyScene /
# pbEndBuyScene and the sell pair, in all fifteen games. pbRefresh is what rewrites the windows, on every
# change of the focused item and after every purchase.
class BattlePointShop_Scene
  attr_reader :sprites

  def initialize
    @sprites = { "itemtextwindow" => FakeTextWin.new, "qtywindow" => FakeTextWin.new,
                 "battlepointwindow" => FakeTextWin.new }
    @item = nil
  end

  def pbStartScene(*a); self; end
  def pbEndScene(*a); nil; end

  # description, bag count and points, exactly as the shop rebuilds them when the focus moves.
  def focus(item, in_bag, points)
    @item = item
    @sprites["itemtextwindow"].text = item ? "Raises the Attack of one Pokemon." : "Quit shopping."
    @sprites["qtywindow"].visible = !item.nil?
    @sprites["qtywindow"].text = "In Bag:<r>#{in_bag}"
    @sprites["battlepointwindow"].text = "Battle Points:<r>#{points}"
  end
end

# The ordinary mart is the same screen with money in place of points, and gets the same two windows. Its
# LIFECYCLE is the thing to reproduce faithfully: in all fifteen games it is pbStartBuyScene/pbEndBuyScene
# (and the sell pair), and there is no pbStartScene and no pbEndScene anywhere on the class. A stand-in
# given the engine's usual pair would let a watch bind that binds nothing in a real game -- which is exactly
# how this reader shipped dead the first time.
class PokemonMart_Scene
  attr_reader :sprites

  def initialize
    @sprites = { "itemtextwindow" => FakeTextWin.new, "qtywindow" => FakeTextWin.new,
                 "moneywindow" => FakeTextWin.new }
  end

  def pbStartBuyScene(*a); pbRefresh; self; end
  def pbStartSellScene(*a); pbRefresh; self; end
  def pbEndBuyScene(*a); nil; end
  def pbEndSellScene(*a); nil; end

  # What the mart rewrites whenever the focused item changes and after every purchase.
  def pbRefresh
    @sprites["itemtextwindow"].text = @item ? "Restores 20 HP." : "Quit shopping."
    @sprites["qtywindow"].visible = !@item.nil?
    @sprites["qtywindow"].text = "In Bag:<r>#{@in_bag}"
    @sprites["moneywindow"].text = "Money:<r>$#{@money}"
  end

  def focus(item, in_bag, money)
    @item = item
    @in_bag = in_bag
    @money = money
    pbRefresh
  end
end

# The phone under the modern spelling: it does keep its two windows here too.
class PokemonPhone_Scene
  attr_reader :sprites
  def initialize; @sprites = { "bottom" => FakeTextWin.new, "info" => FakeTextWin.new }; end
  def pbStartScene(*a); self; end
  def pbEndScene(*a); nil; end
end

# The modern dex list, which has NO header windows at all: it paints seen, owned and the search notice
# straight onto its overlay from pbRefresh. Shaped after the real one, so the capture reader is what gets
# exercised here and the window watcher is what gets exercised in the gen-6 pass.
# The dex ENTRY screen. drawPage paints the focused page and the mod arms a capture around it, so what is
# exercised here is that the capture is taken on EVERY page and not left armed for whoever comes next.
class PokemonPokedexInfo_Scene
  attr_accessor :cursor
  def initialize; @species = 25; @page = 2; @cursor = :general; end
  def drawPage(page)
    drawTextEx(nil, 0, 0, 200, 1, "Area unknown")
    drawTextEx(nil, 0, 20, 200, 1, "Kanto")
    page
  end

  # The MUI data page. Its own rule is "cursor = @cursor if !cursor", so an argument WINS over the ivar --
  # which is what the reader has to follow, or it names whichever section the cursor happens to sit on.
  def pbDrawDataNotes(cursor = nil)
    cursor = @cursor if !cursor
    drawFormattedTextEx(nil, 0, 0, 400, "Texto de #{cursor}.")
    cursor
  end
end

# The modern pokedex list, as the nine games of that era really build it: no seen/owned/dexname windows at
# all, one pbDrawTextPositions batch carrying the dex name, the FOCUSED SPECIES and the totals, and an open
# that reaches pbRefresh through pbRefreshDexList (emerald/295_UI_Pokedex_Main.rb:264, :295, :414). That
# chain is the point: an ordinary after-hook on the opener runs its original under the reentrancy guard and
# skipped the pbRefresh hook whole, so the header was mute on open in all nine.
class PokemonPokedex_Scene
  attr_reader :sprites
  def initialize
    @seen_total = 42
    @sprites = { "overlay" => nil, "pokedex" => DexIconSprite.new(1) }
  end
  def pbStartScene(*a); pbRefreshDexList; self; end
  def pbEndScene(*a); nil; end
  def pbRefreshDexList; pbRefresh; end
  def pbRefresh
    pbDrawTextPositions(nil, [["Pokedex", 112, 10],
                              [PokeAccess::Data.species_name(@sprites["pokedex"].species).to_s, 112, 58],
                              ["Seen:", 42, 314], [@seen_total.to_s, 182, 314]])
    :dex_drawn
  end
  def seen_total=(n); @seen_total = n; end
  def focus_species=(id); @sprites["pokedex"].species = id; end
end

# The dex's own icon sprite, which is where the screen keeps the species the list is focused on.
class DexIconSprite
  attr_accessor :species
  def initialize(id); @species = id; end
end

class HallOfFame_Scene
  def writePokemonData(pk, hall = -1)
    drawTextEx(nil, 0, 0, 200, 1, "No. 025")
    drawTextEx(nil, 0, 20, 200, 1, "#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}")
    hall
  end
  def writeWelcome; drawTextEx(nil, 0, 60, 200, 1, "Congrats! Records Logged!"); end
  def pbStartSceneEntry(*a); end
end

# A silent clone: same methods, paints nothing. Bound by the spec through HallOfFame.bind, as a profile does.
class Duet_Scene
  def writePokemonData(pk, hall = -1); hall; end
  def writeWelcome; end
  def pbStartSceneEntry(*a); end
end

# The other shape a clone comes in: Fire Ash's team viewer, which has no entry animation at all and takes no
# record number, so every draw of it is the player browsing.
class Challenge_Scene
  def writePokemonData(pk)
    drawTextEx(nil, 0, 0, 200, 1, "#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}")
  end
end

# The v21.1 summary scene, which is what NINE of the fifteen surveyed games ship (anil, awakening, emerald,
# Fire Ash, both Infinite Fusions, Relict, Royal, Soulstones 2). Absent until now, so every hook in
# core/party/v21/summary_v21.rb resolved to the empty class name and bound nothing: the whole reader was
# untested, which is how the egg page could go mute in it without a single assertion turning red.
#
# drawPage dispatches, and takes the egg branch FIRST, exactly as emerald/298_UI_Summary.rb:303-307 does.
class PokemonSummary_Scene
  attr_accessor :pokemon, :party
  def initialize(pk = nil); @pokemon = pk; end
  def pbStartScene(party = nil, partyindex = 0, *a)
    @party = party
    @pokemon = party ? party[partyindex] : @pokemon
    drawPage(1)
  end
  def drawPage(page)
    return drawPageOneEgg if @pokemon && (@pokemon.egg? rescue false)
    drawTextEx(nil, 0, 0, 200, 1, "Page #{page}")
    page
  end

  # What the page really paints: the memo label and the item through the positions batch, the nickname and
  # the hatch paragraph as free text -- the last being the only thing anyone opens the page for.
  def drawPageOneEgg
    pbDrawTextPositions(nil, [["TRAINER MEMO", 26, 22], ["Item", 66, 324], ["None", 16, 358]])
    drawFormattedTextEx(nil, 232, 86, 268,
                        "A mysterious Egg obtained in Viridian City. It looks like it will take a long time to hatch.")
    :egg_page
  end
  def drawSelectedMove(_move_to_learn, _selected); end
  def pbChooseMoveToForget(_move_to_learn); end

  # The action menu takes the command list FIRST and no message (anil/303_UI_Summary.rb:268; every game with
  # this class has it, the eight modern ones and Awakening), and the ribbons page redraws the focused ribbon
  # through drawSelectedRibbon: the id itself in vanilla, (filter, index, page, maxpage) under the Improved
  # Mementos plugin.
  def pbShowCommands(commands, index = 0); [commands, index]; end
  def drawSelectedRibbon(*args); args; end
  # The per-frame call every one of this scene's loops makes, and the seam a reader uses to see a cursor
  # the game keeps in a local (the EV allocator's).
  def pbUpdate; :updated; end
end

# The opening's controls help, vanilla Essentials (016_UI/001_Non-interactive UI/002_UI_Controls.rb) and
# present with these same two signatures in ten of the surveyed games. Its paragraphs never touch a window:
# addLabelForScreen compiles each one straight into a bitmap, which is why the reader collects them here.
class ButtonEventScene
  def addLabelForScreen(number, x, y, width, text); [number, x, y, width, text]; end
  def set_up_screen(number); number; end
end

# The "Hall de la Fama BW" ceremony in the gen-5 style both games that ship the plugin run
# (HallDeLaFama_GEN = 5): the card and the finale are painted straight onto bitmaps from these two seams
# (royal/_PluginScripts/Hall de la Fama BW/007_hall_of_fame_gen5.rb:650 and :826), with no window to read.
HallDeLaFama_REGION = "KANTO"
class HallDeLaFama
  def gen5_pokemon_info(pokemon, party_index); [pokemon, party_index]; end
  def create_gen5_final_windows; :final; end
  def get_play_time_formatted; "3:07"; end
end

# The team photo camera of the "Fotos del equipo" plugin, cut down to its loop (royal/_PluginScripts/Fotos
# del equipo/001_Party Picture Script.rb:71): each arrow pans one pbScrollMap(dir, 1) up to the two MAX
# constants, and at the edge it bumps instead. The arrows come from $pa_photo_keys, one per pass.
class PartyPicture
  MAX_HORIZONTAL_MOVEMENT = 4
  MAX_VERTICAL_MOVEMENT = 2
  def main
    cx = 0
    cy = 0
    ($pa_photo_keys || []).each do |k|
      if k == 8
        if cy == MAX_VERTICAL_MOVEMENT then pbSEPlay("Player bump") else pbScrollMap(8, 1); cy += 1 end
      elsif k == 2
        if cy == -MAX_VERTICAL_MOVEMENT then pbSEPlay("Player bump") else pbScrollMap(2, 1); cy -= 1 end
      elsif k == 6
        if cx == MAX_HORIZONTAL_MOVEMENT then pbSEPlay("Player bump") else pbScrollMap(6, 1); cx += 1 end
      elsif k == 4
        if cx == -MAX_HORIZONTAL_MOVEMENT then pbSEPlay("Player bump") else pbScrollMap(4, 1); cx -= 1 end
      end
    end
  end
end
class Game_Map; attr_accessor :display_x, :display_y; end
# Scrolls the display a tile per step like the real one, and clamps it to $pa_display_bounds
# ([min_x, max_x, min_y, max_y]) the way a map that snaps to its edges does.
def pbScrollMap(direction, distance, speed = 4)
  d = distance * 128
  x = ($game_map.display_x || 0) + (direction == 6 ? d : (direction == 4 ? -d : 0))
  y = ($game_map.display_y || 0) + (direction == 2 ? d : (direction == 8 ? -d : 0))
  b = $pa_display_bounds
  if b
    x = [[x, b[0]].max, b[1]].min
    y = [[y, b[2]].max, b[3]].min
  end
  $game_map.display_x = x
  $game_map.display_y = y
end

# $player carries the modern trainer fields the readers use.
class TestPlayer
  attr_accessor :name, :money, :character_name, :trainertype, :outfit, :gender
  def initialize; @name = "Tester"; @money = 1000; @character_name = "trchar"; @trainertype = 0; @outfit = 0; @gender = 0; end
  def public_ID; 12345; end
  def badge_count; 3; end
  def numbadges; 3; end
  def party; []; end
  def pokedex; @dex ||= TestDex.new; end
end
class TestDex
  def owned_count; 50; end
  def seen_count; 80; end
  def owned?(s); true; end
  def seen?(s); true; end
end

$game_player = Game_Player.new
$game_map    = Game_Map.new
$game_temp   = Game_Temp.new
$game_system = Game_System.new
$game_switches = Hash.new(false)
$game_variables = Hash.new(0)
$player = TestPlayer.new
$scene = Scene_Map.new
$stats = Object.new
def $stats.play_time; 3661; end
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
