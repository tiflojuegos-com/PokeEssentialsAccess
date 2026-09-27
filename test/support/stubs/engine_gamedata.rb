# Stand-ins for the GameData-era engine (v17+): GameData::* and UI::* present, $player instead of $Trainer.
# Selected by PA_ENGINE=gamedata.
#
# Known divergences from the real engine (a spec relying on these tests the stub, not the game):
#   - GameData::Move.try_get never returns nil (the real one does for an unknown id); MapMetadata.try_get always
#     returns nil.
#   - Input.trigger?/press? always return false: specs call the handler they exercise directly.
#   - No surf/waterfall terrain model.
#   - The v22 UI:: screens keep only the state their readers read and the call order the dedup relies on (see below).

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
# The Poke Radar's search: the patches it shook are whatever a spec left in the radar's state.
def pbPokeRadarHighlightGrass(_showmessage = true); nil; end

# The modern message entry: a bare top-level function (private on Object), as v19+ defines it.
def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil); message; end
module MessageTypes; REGION_LOCATION_NAMES = 13; end

# MapInfos with the gen-6 stub's ids; pbLoadRxData is absent on purpose, as in v19+ (pbLoadMapInfos replaced it).
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

# Battler effect ids: Illusion (its value is the Pokemon imitated) and Type3 (a type a move added on top).
module PBEffects
  Illusion = 42
  Type3 = 43
end

module GameData
  class Move
    def self.get(id); new(id); end
    def self.try_get(id); new(id); end
    def initialize(id); @id = id; end
    def name; "Move#{@id}"; end
    def power; 40; end
    def accuracy; 100; end
    def type; :TYPE1; end
    def category; 0; end
    def description; "desc#{@id}"; end
  end
  class Type;    def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Type#{@i}"; end; end

  # The slice of GameData::Item the bag and mart readers touch; traits by id: KEY* is important (no "xN"),
  # KEYQTY* is important but shows its count, TM* is a machine (display_name adds the move). Prices: 500, 12 BP.
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
    def show_quantity?; (@i.to_s =~ /\AKEYQTY/) ? true : !is_important?; end
    def move; :THUNDERBOLT; end
    def display_name; is_machine? ? "#{name} #{GameData::Move.get(move).name}" : name; end
    def price; 500; end
    def bp_price; 12; end
    def sell_price; 250; end
  end

  # A bag pocket's name is its own id ("Medicine"), undecorated, for readable assertions.
  class BagPocket; def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; @i.to_s; end; def auto_sort; false; end; end
  class Species
    def self.get(i); new(i); end
    def initialize(i); @i = i; end
    def name; "Species#{@i}"; end
    def category; "cat#{@i}"; end
    def pokedex_entry; "dex#{@i}"; end
    def types; [:TYPE1]; end
  end
  class Ability; def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Ability#{@i}"; end; end
  class Nature;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Nature#{@i}"; end; end
  class Status;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Status#{@i}"; end; end
  class Stat;    def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Stat#{@i}"; end; end
  class Ribbon;  def self.get(i); new(i); end; def initialize(i); @i = i; end; def name; "Ribbon#{@i}"; end; def description; "rdesc#{@i}"; end; end
  class MapMetadata; def self.try_get(i); nil; end; end
  # Trainer classes, looked up only through try_get: an id the game does not have answers nil.
  class TrainerType
    NAMES = { :AQUAGRUNT_M => "Recluta Aqua", :TECHWIZARD => "Mago tecnico" }
    def self.try_get(i); NAMES[i] ? new(i) : nil; end
    def initialize(i); @i = i; end
    def name; NAMES[@i]; end
  end
end

# The v22 summary visuals: set_party_index changes the shown Pokemon and then calls refresh itself (reentrant hook
# order), the one behaviour the reader's ordering depends on.
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

# Settings::MAX_PARTY_SIZE, which the v22 party reader reads to tell the trailing buttons from a party slot.
module Settings; MAX_PARTY_SIZE = 6; end

# The v19-v21 party screen: a panel per member and a button row of non-panel sprites. The real choose loop sets
# selected= on every sprite itself; move_cursor, an invented name, stands for that loop body.
class PokemonPartyConfirmCancelSprite
  attr_reader :selected
  def initialize(text = "", x = 0, y = 0, narrowbox = false, viewport = nil); @text = text; @selected = false; end
  def selected=(value); @selected = value; end
end
class PokemonPartyCancelSprite < PokemonPartyConfirmCancelSprite; end
class PokemonPartyConfirmSprite < PokemonPartyConfirmCancelSprite; end
class PokemonPartyCancelSprite2 < PokemonPartyConfirmCancelSprite; end

class PokemonPartyPanel
  attr_reader :selected
  def initialize(pokemon, index = 0, viewport = nil); @pokemon = pokemon; @text = nil; @selected = false; end
  def selected=(value); @selected = value; end
  def text=(value); @text = value; end
end

class PokemonParty_Scene
  def initialize(party, multiselect = false)
    @party = party
    @sprites = {}
    party.each_with_index { |pk, i| @sprites["pokemon#{i}"] = PokemonPartyPanel.new(pk, i) }
    if multiselect
      @sprites["pokemon#{Settings::MAX_PARTY_SIZE}"] = PokemonPartyConfirmSprite.new
      @sprites["pokemon#{Settings::MAX_PARTY_SIZE + 1}"] = PokemonPartyCancelSprite2.new
    else
      @sprites["pokemon#{Settings::MAX_PARTY_SIZE}"] = PokemonPartyCancelSprite.new
    end
  end

  # The opening a spec scripts: every game's pbStartScene sets the help line and then marks the first member.
  attr_accessor :on_start
  def pbStartScene(*_a); @on_start.call if @on_start; end

  def pbSetHelpText(helptext); @helptext = helptext; end

  def pbSelect(item)
    @activecmd = item
    @sprites.each { |k, s| s.selected = (k == "pokemon#{item}") }
  end

  def move_cursor(item)
    @activecmd = item
    @sprites.each { |k, s| s.selected = (k == "pokemon#{item}") }
  end

  # The choose loop's entry, re-entered after every command with the cursor where it was, or on initialsel;
  # on_choose stands for what the player does inside the loop before the choice is taken.
  attr_accessor :on_choose
  def pbChoosePokemon(_switching = false, initialsel = -1, _canswitch = 0)
    @activecmd = initialsel if initialsel.is_a?(Integer) && initialsel >= 0
    @on_choose.call if @on_choose
    @activecmd
  end
end

# ===================================================================================================
# The v22 UI:: rework. Each screen's *Visuals list windows are passive, so the mod hooks each Visuals' own cursor
# callback (core/menus/v22/screen_v22.rb); these stand-ins keep only the state the readers read and the call order.
#
# Divergences from the real engine (a spec relying on these tests the stub, not the game):
#   - No @sprites layer: the pocket/stock array is the list and @index indexes it; an index past the end is the
#     trailing close row (item => nil), as in the real list.
#   - No navigate loop: a spec calls refresh_on_index_changed itself where the engine would after update_input.
#   - No animation loops: the box and party-panel slides keep only the bookkeeping the reader observes.
#   - PokemonStorageVisuals#hold_pokemon, the only invented name, sets the held Pokemon (the real one lives on
#     @sprites[:cursor]).
#   - Bag/Mart initialize does not announce, as in the real ones.
module UI
  # The common base: #index, @sprites, an empty cursor callback, and update_visuals updating every sprite it owns, as
  # the real one does through pbUpdateSpriteHash.
  class BaseVisuals
    attr_reader :index, :sprites

    def initialize; @sprites = {}; end
    def refresh; end
    def refresh_on_index_changed(old_index); end
    def update_visuals
      (@sprites || {}).each_value { |s| s.update if s.respond_to?(:update) }
    end
  end

  # Item moves go through refresh_on_index_changed; a pocket change goes through set_pocket, which calls refresh
  # instead (the split the bag reader is built on).
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

  # A BagVisuals subclass whose refresh_on_index_changed calls super, as the real one: both the bag hook and the sell
  # hook fire on one cursor move, and only the reader's dedup keeps the line from being said twice.
  class BagSellVisuals < BagVisuals
    def refresh_on_index_changed(old_index); super; end
  end

  # The mart's price wrapper: the unit belongs to the wrapper, not to the reader.
  class MartStockWrapper
    def initialize(stock); @stock = stock; end
    def length; @stock.length; end
    def [](index); @stock[index]; end
    def buy_price(item); item.nil? ? 0 : GameData::Item.get(item).price; end
    def buy_price_string(item); "$#{buy_price(item)}"; end
    def sell_price(item); item.nil? ? 0 : GameData::Item.get(item).sell_price; end
  end

  # The BP shop's wrapper: the same list in Battle Points instead of money.
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

  # Inherits the cursor callback, as the real one does, so the one hook on MartVisuals covers the BP shop.
  class BPShopVisuals < MartVisuals; end

  # The Pokedex's passive species list: species is the focused id, and set_index chains to the cursor callback the
  # reader hooks.
  class PokedexVisuals < BaseVisuals
    def initialize(dex_list, index = 0); super(); @dex_list = dex_list; @index = index; end

    def species; @dex_list[@index]; end

    def set_index(value)
      @index = value
      refresh_on_index_changed(nil)
    end

    def refresh_on_index_changed(old_index); end
  end

  # The party: set_index (which both navigate loops call) does not chain to refresh_on_index_changed. Index
  # MAX_PARTY_SIZE is Cancel, or Confirm in :choose_entry_order mode, where Cancel is MAX_PARTY_SIZE + 1.
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

  # The pause menu: @commands is [[ids], [names]], shown in a real command window in @sprites[:commands] that
  # update_visuals updates (the one the generic reader hooks). The cursor starts on menu_last_choice, or 0.
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

  # The title screen: @commands is a hash {:continue => "Continue", ...} and @index one of its keys; @save_data is
  # [[filename, save hash], ...]. set_slot_index cycles the save slot without touching @index, and keeps the wrap
  # and the unchanged-slot early return that decide whether the original runs.
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

  # The in-game save: @index is a numeric slot, and the wrap allows one past the last save, the empty new slot.
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

  # The PC: index -1 box name, -2 party button, -3 close, 0+ a slot; box is -1 while the party panel is up, else the
  # box number. initialize ends in set_index(@index), as the real one does, so opening announces the focused slot.
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

# The game objects the v22 screens are built with (Bag, PokemonStorage, PokemonBox), outside the engine's UI::.

# Bag: pockets is {pocket => [[item_id, quantity], ...]}; quantity sums an item over every pocket, as the real one.
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

# PokemonStorage: storage[box] is the box, storage[box, i] a slot in it, storage.party the PC's party column.
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

# The v21.1 battle menus (MenuBase, FightMenu): setIndexAndMode assigns @mode directly, never through mode= (the
# mega-toggle cue depends on it); battler is nil, so read_menu reads no move.
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

    # The databox, reduced to the images its refresh draws: the shiny icon and, for a caught foe (owned, a test
    # seam), draw_owned_icon's icon_own, or a Deluxe Battle Kit style's from its own folder (style_path); extra lists
    # the Graphics/UI/Battle names a plugin's or a game's box draws after them.
    class PokemonDataBox
      attr_accessor :owned, :style_path, :extra
      def initialize(battler); @battler = battler; @owned = false; @style_path = nil; @extra = []; end

      def refresh
        imagepos = [["Graphics/UI/Battle/icon_shiny", 0, 0]]
        imagepos.push(["#{@style_path || 'Graphics/UI/Battle'}/icon_own", 8, 36]) if @owned
        @extra.each { |name| imagepos.push(["Graphics/UI/Battle/#{name}", 219, 4]) }
        pbDrawImagePositions(nil, imagepos)
        :refreshed
      end
    end

    def pbDisplayMessage(msg, _brief = false); msg; end

    # The Enhanced Battle UI's closing of its panels (Confirm, Cancel and Shift of the fight menu).
    def pbHideInfoUI; @enhancedUIToggle = nil; end
  end

  # The battler's two HP entry points, returning the amount moved; on_reduce, a test seam, runs inside pbReduceHP,
  # where a plugin (a boss shield, a disguise) shows its own messages.
  class Battler
    attr_accessor :name, :hp, :totalhp, :index, :battle, :on_reduce

    def initialize(name, hp, totalhp, index = 0)
      @name = name; @hp = hp; @totalhp = totalhp; @index = index
    end

    def opposes?; @index.odd?; end

    def pbReduceHP(amt, _anim = true, _register = true, _any_anim = true)
      amt = @hp if amt > @hp
      @hp -= amt
      @on_reduce.call(self) if @on_reduce
      amt
    end

    def pbRecoverHP(amt, _anim = true, _any_anim = true)
      amt = @totalhp - @hp if amt > @totalhp - @hp
      @hp += amt
      amt
    end
  end
end

# UI::BaseScreen, the root of every v22 screen (Engine.has?(:ui_rework) checks it), with the four message methods
# menus/v22/screen_v22 hooks.
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

  # The terrain tag at (x,y): 1 on a placed ledge (so Terrain.ledge_at? sees it), else 0.
  def terrain_tag(x, y); @ledges[[x, y]] ? 1 : 0; end

  # True while (x,y) is inside the map bounds; ledge_jump needs it to accept a landing tile.
  def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end

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

  # True if a blocking event, not through, occupies (x,y).
  def blocking_event_at?(x, y)
    @events.each_value { |e| return true if e.respond_to?(:blocking) && e.blocking && !(e.respond_to?(:through) && e.through) && e.x == x && e.y == y }
    false
  end

  # Passability of a step from (x,y) in dir: a ledge only in its hop direction, a blocking event never, else open.
  def passable?(x, y, dir)
    dx = (dir == 6 ? 1 : (dir == 4 ? -1 : 0)); dy = (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
    nx = x + dx; ny = y + dy
    ld = @ledges[[nx, ny]]
    return dir == ld if ld
    return false if blocking_event_at?(nx, ny)
    true
  end

  # Resets the ledges and the passage and terrain-tag tables the real Game_Map carries (ledge_passage reads them).
  def init_ledges; @ledges = {}; @passages = {}; @terrain_tags = {}; @data = TestMapData.new(@ledges); (PokeAccess::Terrain.forget_map_memo rescue nil); end
  def data; @data; end
end

class Game_Temp;   attr_accessor :in_menu, :message_window_showing, :in_battle, :menu_last_choice; end
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
# The concrete command window modern screens instantiate (the v22 pause menu keeps one in @sprites[:commands]).
class Window_CommandPokemon < Window_DrawableCommand; end

# Two sibling numeric option kinds (lowest_value, highest_value): NumberOption paints "Type value/total",
# SliderOption only its value, over a bar.
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

# An options row that opens a submenu: a name over a constant value.
class ButtonOption
  attr_reader :name
  def initialize(name); @name = name; end
  def get; 0; end
end

# The options list: options, their values, and drawItem painting each row's name, the last row's being exit_word, and
# after a NumberOption's name its value in number_format ("Type %d/%d" as v21 paints it); a value set repaints.
class Window_PokemonOption < Window_DrawableCommand
  attr_accessor :exit_word, :number_format
  def initialize(options, exit_word = "Close")
    super([])
    @options = options
    @values = Array.new(options.length, 0)
    @exit_word = exit_word
    @number_format = "Type %d/%d"
  end
  def [](i); @values[i]; end
  def []=(i, v); @values[i] = v; refresh; end
  def drawItem(index, _count, _rect)
    o = @options[index]
    pbDrawShadowText(nil, 0, 0, 0, 0, o.nil? ? @exit_word : o.name, nil, nil)
    return unless o.is_a?(NumberOption)
    pbDrawShadowText(nil, 0, 0, 0, 0, format(@number_format, o.lowest_value + self[index], o.highest_value - o.lowest_value + 1), nil, nil)
  end
  def refresh; (@options.length + 1).times { |i| drawItem(i, @options.length + 1, nil) }; end
end

# The options screen, reduced to its closing: a submenu is one of these opened from a row of another.
class PokemonOption_Scene
  def pbEndScene; end
end

# The Pokegear's selection loop, rerun after every app it opens: each pass selects the focused button.
class PokegearButton
  attr_reader :name
  def initialize(name); @name = name; @selected = false; end
  def selected=(v); @selected = v; end
end
class PokemonPokegear_Scene
  attr_accessor :index
  def initialize(names); @buttons = names.map { |n| PokegearButton.new(n) }; @index = 0; end
  def pbUpdate; @buttons.each_with_index { |b, i| b.selected = (i == @index) }; end
  def pbStartScene(_commands = nil); pbUpdate; end
  def pbScene; pbUpdate; -1; end
end

# The Pokedex list window. Its rows are hashes here (the modern shape), carrying :shift for the regional
# offset the screen subtracts before painting the number.
class Window_Pokedex < Window_DrawableCommand; end

# The pause menu scene, reduced to its opening, its command loop and the info box the Safari and the
# Bug-Catching Contest fill (pbShowInfo, called before the commands are shown).
class PokemonPauseMenu_Scene
  attr_reader :info
  def pbStartScene; end
  def pbShowInfo(text); @info = text; end
  def pbShowCommands(_commands); 0; end
end

# The save screen's scene, reduced to the summary panel its pbStartScreen builds and pbEndScreen disposes.
class PokemonSave_Scene
  def pbStartScreen
    panel = "<ac><c3=209808,90F090>Ruta 5</c3></ac>Player<r><c3=0070F8,78B8E8>Ceniza</c3><br>" +
            "Time<r>3h 12m<br>Badges<r>3<br>"
    @sprites = { "locwindow" => Struct.new(:text).new(panel) }
  end
  def pbEndScreen; @sprites = {}; end
end

# The engine's text painters (drawTextEx here, pbDrawTextPositions below), which the mod wraps to feed PaintCapture.
def drawTextEx(_bitmap, _x, _y, _width, _lines, text, _base = nil, _shadow = nil); text; end

# The modal panel the engine blocks on until the confirm key (level-up stat gains); the modern one takes a scene.
def pbTopRightWindow(text, scene = nil); [text, scene]; end

# The EV Allocator plugin's full-description panel (an ability's or a move's whole text), so its watch binds at load.
def pbFullAbilityWindow(text, scene = nil); [text, scene]; end

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

# The HGSS trainer card, reduced to its two faces: the front writes its badge count as text beside the
# icons, and the special key turns it to the back.
class PokemonTrainerCard_Scene
  def pbStartScene; pbDrawTrainerCardFront; end
  def pbDrawTrainerCardFront
    pbDrawTextPositions(nil, [["NOMBRE", 272, 54], ["Rojo", 480, 54], ["MEDALLAS", 32, 214], ["2", 304, 214],
                              ["Pulsa [D] para girar la tarjeta.", 16, 350]])
  end
  def pbDrawTrainerCardBack
    pbDrawTextPositions(nil, [["DEBUT HALL DE LA FAMA", 32, 22], ["Combates Online", 32, 134], ["4", 350, 134]])
    pbDrawImagePositions(nil, [["Graphics/UI/Trainer Card/badges0", 36, 234, 0, 0, 48, 48],
                               ["Graphics/UI/Trainer Card/badges0", 92, 234, 48, 0, 48, 48]])
  end
end

# The item storage screen under its v18+ name, shaped as the gen-6 stub's, so each spelling's capture hook is pinned.
class ItemStorage_Scene
  def initialize(title = "Withdraw\nItem"); @title = title; end

  # The real order: the item list paints first, through pbDrawTextPositions, and then pbRefresh draws the title with
  # drawTextEx.
  def pbStartScene(*a)
    pbDrawTextPositions(nil, [["Potion", 98, 14], ["Repel", 98, 46]])
    drawTextEx(nil, 0, 4, 200, 2, @title)
    drawTextEx(nil, 0, 40, 200, 2, "An ordinary potion.")
    self
  end
end
class WithdrawItemScene < ItemStorage_Scene; end

# The egg hatch scene under its modern name: the hatchling in @pokemon, and pbMain running the animation.
class PokemonEggHatch_Scene
  def initialize(pokemon = nil); @pokemon = pokemon; end
  def pbMain; :hatched; end
end

# A window that just holds text, as the phone's standing information windows do.
class FakeTextWin
  attr_accessor :text, :visible
  def initialize(t = ""); @text = t; @visible = true; end
end


# The two shop screens with standing information windows, here because core declares its watches at load. The Battle
# Point shop has pbStartScene/pbEndScene; the mart has neither, only pbStartBuyScene/pbEndBuyScene and the sell pair.
class BattlePointShop_Scene
  attr_reader :sprites

  def initialize
    @sprites = { "itemtextwindow" => FakeTextWin.new, "qtywindow" => FakeTextWin.new,
                 "battlepointwindow" => FakeTextWin.new }
    @item = nil
  end

  def pbStartScene(*a); self; end
  def pbEndScene(*a); nil; end

  # Sets the description, bag count and points as the shop rebuilds them when the focus moves.
  def focus(item, in_bag, points)
    @item = item
    @sprites["itemtextwindow"].text = item ? "Raises the Attack of one Pokemon." : "Quit shopping."
    @sprites["qtywindow"].visible = !item.nil?
    @sprites["qtywindow"].text = "In Bag:<r>#{in_bag}"
    @sprites["battlepointwindow"].text = "Battle Points:<r>#{points}"
  end
end

# The mart: the same windows with money for points, and no pbStartScene or pbEndScene, as the real one.
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

# The secret bases' decoration shop (Secret Bases Remade and Royal's fork), here because its plugin reader binds at
# load: the prompts it writes in its own help window, and the frame update each of its loops runs.
class SecretBaseMart_Scene
  attr_reader :sprites

  def initialize(money = "$1.500")
    @sprites = { "moneywindow" => FakeTextWin.new("Dinero:\r\n<r>#{money}") }
  end

  def pbDisplay(msg, _brief = false); msg; end
  def pbDisplayPaused(msg); msg; end
  def pbConfirm(_msg); true; end
  def update; :updated; end
end

# The phone under the modern spelling, with its two windows.
class PokemonPhone_Scene
  attr_reader :sprites
  def initialize; @sprites = { "bottom" => FakeTextWin.new, "info" => FakeTextWin.new }; end
  def pbStartScene(*a); self; end
  def pbEndScene(*a); nil; end
end

# The dex entry screen: drawPage paints the focused page inside a capture the mod arms, taken on every page.
class PokemonPokedexInfo_Scene
  attr_accessor :cursor
  def initialize; @species = 25; @page = 2; @cursor = :general; end
  # Paints what a spec hands it in @paint, else the two rows the area specs expect.
  def drawPage(page)
    if @paint
      @paint.call
    else
      drawTextEx(nil, 0, 0, 200, 1, "Area unknown")
      drawTextEx(nil, 0, 20, 200, 1, "Kanto")
    end
    page
  end

  # The MUI data page: a cursor argument wins over @cursor, as in the game's "cursor = @cursor if !cursor". A spec
  # hands the section's paragraphs as [text, x, y] in @notes_paint (the stats box paints seven).
  def pbDrawDataNotes(cursor = nil)
    cursor = @cursor if !cursor
    if @notes_paint
      @notes_paint.each { |t, x, y| drawFormattedTextEx(nil, x, y, 400, t) }
    else
      drawFormattedTextEx(nil, 0, 0, 400, "Texto de #{cursor}.")
    end
    cursor
  end

  # The MUI species sub-list: the focused cell's name and the page ("1/2") as positions, then the box beneath as
  # the paragraphs a spec hands in @list_paint ([text, x, y]), as the game paints them.
  def pbDrawSpeciesDataList(list, index, page, maxpage, _cursor = nil)
    pbDrawTextPositions(nil, [[list[page * 12 + index].to_s, 256, 248], ["#{page + 1}/#{maxpage + 1}", 51, 249]])
    (@list_paint || []).each { |t, x, y| drawFormattedTextEx(nil, x, y, 446, t) }
    :list_drawn
  end

  # The MUI move sub-list: a command window of bare names in @sprites["movecmds"], the list on show picked
  # by @moveListIndex, its title painted first in the batch. A spec fills the lists and the window.
  def pbDrawMoveList
    title = ["LEVEL-UP", "TM/TUTOR", "INHERIT", "Z-MOVES"][@moveListIndex.to_i]
    pbDrawTextPositions(nil, [[title, 130, 51], ["PP", 144, 120]])
  end
  def pbChooseMove; end
  def pbChooseSpeciesDataList(_cursor = nil); end
  def pbCurrentMoveID
    sel = @moveList[@sprites["movecmds"].index]
    @moveListIndex == 0 ? sel[1] : sel
  end
end

# The modern Pokedex list: no header windows, one pbDrawTextPositions batch with the dex name, the focused species
# and the totals, and an open that reaches pbRefresh through pbRefreshDexList, nested in the opener.
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

  # The search screen: the grid repaints on opening and after a filter changes, a cursor move only sets the cursor
  # sprite's index; moves, an invented name, stands for the loop's arrow presses.
  def pbDexSearch(moves = [])
    @orderCommands = ["Numerical", "A to Z"]
    @nameCommands = ["A", "B"]
    params = [0, 1, -1, -1, -1, -1, -1, -1, -1, -1]
    @sprites["searchcursor"] = PokedexSearchSelectionSprite.new
    pbRefreshDexSearch(params, 0)
    moves.each { |i| @sprites["searchcursor"].index = i }
    :searched
  end
  def pbRefreshDexSearch(params, index); [params, index]; end
  def pbRefreshDexSearchParam(mode, _cmds, _sel, index); [mode, index]; end
end

# The search screen's cursor, shared by the grid (mode -1) and the filter sub-screens.
class PokedexSearchSelectionSprite
  attr_reader :index
  def initialize; @index = 0; @mode = -1; end
  def index=(value); @index = value; end
  def mode=(value); @mode = value; end
end

# The dex's icon sprite, where the screen keeps the focused species.
class DexIconSprite
  attr_accessor :species
  def initialize(id); @species = id; end
end

# The formatted text window: its constructor sets the text through text=, as the real one does.
class Window_AdvancedTextPokemon
  attr_reader :text
  def initialize(text = ""); self.text = text; end
  def text=(value); @text = value; end
end

class HallOfFame_Scene
  def writePokemonData(pk, hall = -1)
    drawTextEx(nil, 0, 0, 200, 1, "No. 025")
    drawTextEx(nil, 0, 20, 200, 1, "#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}")
    hall
  end
  def writeWelcome; drawTextEx(nil, 0, 60, 200, 1, "Congrats! Records Logged!"); end
  def pbStartSceneEntry(*a); end
  # The v21 closing box (each row closed with <br> after its _INTL) and the congratulation it waits on.
  def writeTrainerData
    @sprites = { "messagebox" => Window_AdvancedTextPokemon.new("Name<r>Tester<br>ID No.<r>12345<br>" \
                                                                "Time<r>1h 23m<br>Pokédex<r>10/20<br>") }
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new
    @sprites["msgwindow"].text = "League champion!\nCongratulations!"
    PokeAccess.say_dialogue("League champion!\nCongratulations!")
  end
end

# A silent clone: same methods, paints nothing. Bound by the spec through HallOfFame.bind, as a profile does.
class Duet_Scene
  def writePokemonData(pk, hall = -1); hall; end
  def writeWelcome; end
  def pbStartSceneEntry(*a); end
end

# A clone with no entry animation and no record number (Fire Ash's team viewer): every draw is the player browsing.
class Challenge_Scene
  def writePokemonData(pk)
    drawTextEx(nil, 0, 0, 200, 1, "#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}")
  end
end

# The v21.1 summary scene the core/party/v21/summary_v21.rb hooks bind to; drawPage takes the egg branch first, as
# the real one does.
class PokemonSummary_Scene
  attr_accessor :pokemon, :party
  def initialize(pk = nil); @pokemon = pk; end
  def pbStartScene(party = nil, partyindex = 0, *a)
    @party = party
    @pokemon = party ? party[partyindex] : @pokemon
    drawPage(1)
  end
  # on_draw, if a spec sets it, runs inside the draw with the page, for a page that opens a screen of its own.
  attr_accessor :on_draw
  def drawPage(page)
    return drawPageOneEgg if @pokemon && (@pokemon.egg? rescue false)
    drawTextEx(nil, 0, 0, 200, 1, "Page #{page}")
    @on_draw.call(page) if @on_draw
    page
  end

  # The egg page: the memo label and the item through the positions batch, the hatch paragraph as free text.
  def drawPageOneEgg
    pbDrawTextPositions(nil, [["TRAINER MEMO", 26, 22], ["Item", 66, 324], ["None", 16, 358]])
    drawFormattedTextEx(nil, 232, 86, 268,
                        "A mysterious Egg obtained in Viridian City. It looks like it will take a long time to hatch.")
    :egg_page
  end
  def drawSelectedMove(_move_to_learn, _selected); end
  def pbChooseMoveToForget(_move_to_learn); end

  # The action menu takes the command list first and no message; drawSelectedRibbon gets the ribbon id in vanilla,
  # (filter, index, page, maxpage) under the Improved Mementos plugin.
  def pbShowCommands(commands, index = 0); [commands, index]; end
  def drawSelectedRibbon(*args); args; end
  # The per-frame call every one of this scene's loops makes, and the seam a reader uses to see a cursor
  # the game keeps in a local (the EV allocator's).
  def pbUpdate; :updated; end

  # The marking screen, a loop whose locals hold the cursor and the marks; its frames are the spec's marking_loop,
  # run in the scene.
  MARK_HEIGHT = 16
  attr_accessor :marking_loop
  def pbMarking(pokemon); instance_exec(pokemon, &@marking_loop); end
end

# The v19+ PC box scene: pbMark runs the spec's marking_loop, and pbMarkingSetArrow moves the arrow over the grid,
# the one place its cursor is not a local. The box cursor readers hook pbUpdateOverlay and pbSelectBoxInternal.
class PokemonStorageScene
  MARK_HEIGHT = 16
  attr_accessor :marking_loop
  def initialize(storage = nil); @storage = storage; end
  def pbMark(selected, heldpoke); instance_exec(selected, heldpoke, &@marking_loop); end
  def pbMarkingSetArrow(arrow, selection); [arrow, selection]; end
  def pbUpdateOverlay(*a); end
  def pbSelectBoxInternal(*a); end
  # Infinite Fusion's splicers inside the PC: the box cursor armed to fuse, or back to normal.
  def setFusing(on); @fusing = on; end

  # The arrow's move, which the multi-select plugin (Storage System Utilities) follows.
  def pbSetArrow(*_a); :arrow; end

  # Anil's PC search in its order: the jump to the chosen box, then the frames of the fade, which a spec
  # hands in as on_search_frame.
  attr_accessor :on_search_frame
  def pbSearch(box = 0); pbJumpToBox(box); @on_search_frame.call if @on_search_frame; :searched; end
  def pbJumpToBox(_box); :jumped; end
end

# The opening's controls help: addLabelForScreen compiles each paragraph straight into a bitmap, with no window, so
# the reader collects them there.
class ButtonEventScene
  def addLabelForScreen(number, x, y, width, text); [number, x, y, width, text]; end
  def set_up_screen(number); number; end
end

# The "Hall de la Fama BW" ceremony in the gen-5 style (HallDeLaFama_GEN = 5): the card and the finale are painted
# straight onto bitmaps from these two seams, with no window to read.
HallDeLaFama_REGION = "KANTO"
class HallDeLaFama
  def gen5_pokemon_info(pokemon, party_index); [pokemon, party_index]; end
  def create_gen5_final_windows; :final; end
  def get_play_time_formatted; "3:07"; end
  # Every text window is built hidden unless asked otherwise.
  def create_text_window(text, visible = false)
    w = HallOfFameTextWindow.new(text)
    w.visible = visible
    w
  end
end

# The ceremony's text window, with its own text= and visible=.
class HallOfFameTextWindow
  attr_reader :visible
  def initialize(text); @text = text; @visible = false; end
  def text=(t); @text = t; end
  def visible=(v); @visible = v; end
end

# The "Fotos del equipo" plugin's team photo camera, cut down to its loop: each arrow from $pa_photo_keys pans one
# pbScrollMap(dir, 1) up to the MAX constants, and bumps at the edge.
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
# The v21 name of the ice-slide flag (sliding before v21), raised while a slide carries the player.
def $PokemonGlobal.ice_sliding; @ice_sliding ? true : false; end
def $PokemonGlobal.ice_sliding=(v); @ice_sliding = v; end

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
