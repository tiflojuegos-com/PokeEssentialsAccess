# Stand-ins shaped as Elite Battle: DX's battle windows as the v21 port Dark Horizon ships paints them (Golden Crown's
# v19.1 copy has the same classes and methods), the fight window carrying the mechanic buttons the ZUD patch adds; then
# plugins/ebdx.rb evaluated once over them, since the harness loaded it before they existed. Required by the ebdx_*
# tests, so it loads once.

# The outline text EBDX paints its buttons with, which the gamedata stubs lack.
def pbDrawOutlineText(_bitmap, _x, _y, _width, _height, string, _base = nil, _shadow = nil, _align = 0)
  string
end

# A window sprite: the source rect a button lights by (x past 0 is its lit half), the picture it holds, and the
# parameter a move button keeps its category in.
class EbdxSprite
  Rect = Struct.new(:x, :y, :width)
  attr_accessor :bitmap, :param
  attr_reader :src_rect

  def initialize(bitmap = nil, param = nil)
    @bitmap = bitmap
    @param = param
    @src_rect = Rect.new(0, 0, 10)
  end
end

# Luka's SelectorSprite: target anchors it on a sprite, as the bag moves its selector.
class EbdxSelector
  attr_accessor :anchor

  def target(sprite)
    @anchor = sprite if sprite
  end
end

# A battle move as the fight window reads it; painted is the name the button writes when it is not the move's own.
EbdxMove = Struct.new(:id, :name, :painted, :category, :pp, :total_pp, :power, :accuracy)

# A battler: its slot, name, Pokemon and moves, and whether it is in Primal form.
class EbdxBattler
  attr_accessor :index, :name, :pokemon, :moves, :primal

  def initialize(index, name, moves = [], pokemon = Object.new)
    @index = index
    @name = name
    @moves = moves
    @pokemon = pokemon
  end

  def primal?; @primal ? true : false; end
end

# A party member as the lineup draws it.
class EbdxMember
  attr_accessor :hp, :status, :egg

  def initialize(hp, status = :NONE, egg = false)
    @hp = hp
    @status = status
    @egg = egg
  end

  def egg?; @egg; end
end

# The battle: its battlers, the positions on the player's side, each side's party and the opposing trainers.
class EbdxBattle
  attr_reader :battlers, :opponent

  def initialize(battlers, positions = 1, parties = [[], []], opponent = nil)
    @battlers = battlers
    @positions = positions
    @parties = parties
    @opponent = opponent
  end

  def pbSideSize(_side); @positions; end
  def pbParty(side); @parties[side]; end
end

# The command window: refreshCommands paints the buttons compileCommands answers; the battle loop moves @index.
class CommandWindowEBDX
  attr_accessor :index
  attr_reader :indexes

  def initialize(battle, labels)
    @battle = battle
    @labels = labels
    @index = 0
    @indexes = []
    update
  end

  def refreshCommands(index)
    compileCommands(index)
    nil
  end

  def compileCommands(_index)
    @indexes = (0...@labels.length).to_a
    @labels.dup
  end

  def update; nil; end
end

# The fight window: generateButtons writes each move's name and PP in outline text, then the name again, keeping the
# category on the button; a mechanic button lights on its trigger and goes dark on showPlay.
class FightWindowEBDX
  attr_accessor :index, :battler

  def initialize
    @index = 0
    @button = {}
    @showMega = false
    @megaButton = EbdxSprite.new
  end

  def generateButtons
    @button = {}
    @battler.moves.each_with_index do |m, i|
      name = m.painted || m.name
      @button["#{i}"] = EbdxSprite.new(nil, m.category)
      pbDrawOutlineText(nil, 198, 10, 196, 42, name, nil, nil, 1)
      pbDrawOutlineText(nil, 0, 48, 191, 26, "#{m.pp}/#{m.total_pp}", nil, nil, 2)
      pbDrawTextPositions(nil, [[name, 99, 18, 2, nil, nil]])
    end
    nil
  end

  def showPlay
    [@megaButton, @zMoveButton, @ultraButton, @dynaButton].compact.each { |b| b.src_rect.x = 0 }
  end

  def megaButton; @showMega = true; end
  def megaButtonTrigger; light(@megaButton); end

  def zMoveButton
    @zMoveButton ||= EbdxSprite.new
    @showZMove = true
  end

  def zMoveButtonTrigger; light(@zMoveButton); end

  def ultraButton
    @ultraButton ||= EbdxSprite.new
    @showUltra = true
  end

  def ultraButtonTrigger; light(@ultraButton); end

  def update; nil; end

  private

  def light(button)
    button.src_rect.x += button.src_rect.width
    button.src_rect.x = 0 if button.src_rect.x > button.src_rect.width
  end
end

# The target window: refresh takes the target texts, index= moves the cursor.
class TargetWindowEBDX
  attr_reader :index

  def initialize
    @index = 0
  end

  def refresh(texts)
    @texts = texts
  end

  def index=(val)
    @index = val
  end
end

# The battle questions' choice boxes.
class ChoiceWindowEBDX
  attr_accessor :index

  def initialize(commands)
    @commands = commands
    @index = 0
  end

  def update; nil; end
end

# The battle bag: six main buttons (four pockets, the last-used item, back), the open pocket's items and the
# confirmation's two buttons, all reached by the selector; useItem? anchors it on confirm, then on each button of
# @presses, and answers @answer.
class BagWindowEBDX
  attr_accessor :sprites
  attr_reader :ret

  def initialize
    @sprites = { "sel" => EbdxSelector.new, "confirm" => EbdxSprite.new, "cancel" => EbdxSprite.new }
    (0..5).each { |k| @sprites["pocket#{k}"] = EbdxSprite.new }
    @items = {}
    @index = 0
    @selPocket = 0
    @lastUsed = 0
  end

  def show
    @ret = nil
    @sprites["sel"].target(@sprites["pocket#{@index}"])
  end

  def update; nil; end

  def useItem?
    @sprites["sel"].target(@sprites["confirm"])
    Input.update
    (@presses || []).each do |b|
      @sprites["sel"].target(@sprites[b])
      Input.update
    end
    @answer
  end
end

# A battle databox: refresh draws only once the box is set up (@loaded).
class DataBoxEBDX
  def initialize(battler, pokemon, sprites)
    @battler = battler
    @pokemon = pokemon
    @sprites = sprites
    @loaded = true
  end

  def refresh; nil; end
end

# A party lineup: refresh paints one side's balls.
class PartyLineupEBDX
  def initialize(battle, side)
    @battle = battle
    @side = side
    @num = 6
  end

  def refresh; nil; end
end

# The Pokedex page a capture shows, drawn as its constructor does: the number and name, the labels, the category, the
# measures, then the entry.
class EliteBattle_Pokedex
  ROWS = [["025   Pikachu", 262, 41, 0], ["Height", 274, 169, 0], ["Weight", 274, 201, 0],
          ["Mouse Pokémon", 262, 77, 0], ["0.4 m", 482, 169, 1], ["6.0 kg", 482, 201, 1]]
  ENTRY = "It keeps its tail raised to monitor its surroundings."

  def initialize(species)
    @species = species
    @pokemon = Struct.new(:form).new(0)
    drawPage
  end

  def drawPage
    pbDrawTextPositions(nil, ROWS)
    drawTextEx(nil, 32, 250, 452, 4, ENTRY)
    :drawn
  end
end

# EBDX's target choice: the window refreshed with @target_texts, its cursor on each index of @target_path in turn
# (the first is pbFirstTarget's), answering @target_ret; and its pbShowOpponent, which slides a trainer in.
module Battle
  class Scene
    def pbChooseTarget(_idxBattler, _target_data, _visibleSprites = nil)
      @targetWindow.refresh(@target_texts)
      @target_path.each { |i| @targetWindow.index = i }
      @target_ret
    end

    def pbShowOpponent(_index = 0, _speech = false, _file = nil); nil; end
  end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "plugins", "ebdx.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end
