# The Pokemon Xenoverse profile loaded whole, over doubles with the shape of its scripts, every hook it declares bound:
# the boy/girl choice, the starter choice and the place past its third Pokemon, the pause menu, the bag and its quantity
# box, the battle bag's pages, the message box's speaker, the trainer card's badges, the party's commands, the summary,
# the controls, the tournament's bracket, the title, the game modes, the shop, the map names and the preload script. In
# a process of its own, since its overrides would reach every other test here.
class XenoverseProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # Hooks.wrap answers false and notes nothing when the class is absent: once the core is loaded, every hook the
    # profile declares that did not bind is kept here, so a double missing from this world fails the binding test.
    UNBOUND_HOOKS = []
    module UnboundNote
      def wrap(cname, meth, opts = {}, &mw)
        bound = super
        UNBOUND_HOOKS.push("#{cname}##{meth}") if bound == false && defined?(CORE_MISSING) && !opts[:optional]
        bound
      end
    end
    HOOK_TRAP = TracePoint.new(:end) do |tp|
      mod = tp.self
      if defined?(PokeAccess::Hooks) && mod.equal?(PokeAccess::Hooks) && !mod.singleton_class.ancestors.include?(UnboundNote)
        mod.singleton_class.prepend(UnboundNote)
      end
    end
    HOOK_TRAP.enable

    Pic = Struct.new(:bitmap, :visible, :opacity, :x) do
      def disposed?; false; end
    end
    Mon = Struct.new(:name, :type1, :type2)
    MugName = Struct.new(:visible, :active, :name)
    FANCY_BADGE_NAMES = ["Medaglia Radice", "Medaglia Competizione", "Medaglia Zucchero"]

    def drawTextExH(*_args); end
    def pbDrawOutlineText(bitmap, x, y, width, height, string, base = nil, shadow = nil, align = 0); end
    def pbEnterPokemonName(*_args); ""; end
    def pbGetMapNameFromId(id); "Bosco Ombroso #{id}"; end

    # 0000_Settings: Surf asks the fifth badge, by index.
    HIDDENMOVESCOUNTBADGES = false
    BADGEFORSURF = 4

    class XenoverseStyle
      def disposed?; false; end
    end

    class Scene_Intro
      def initialize(screen); @screen = screen; end
      def update; end
    end

    # 0238_GameModeScreen: both labels outlined on one sprite as it opens, the selected mode's rules on another.
    class GameModeScreen
      def initialize
        @sprites = { 'classicinfo' => Spr.new, 'info' => Spr.new }
        pbDrawOutlineText(@sprites['classicinfo'].bitmap, 300, 100, 200, 30, "Moderna")
        pbDrawOutlineText(@sprites['classicinfo'].bitmap, 50, 100, 200, 30, "Classica")
      end
      def drawInfo(index = 0, _max = 40)
        pbDrawOutlineText(@sprites['info'].bitmap, 10, 200, 400, 30, "Regole #{index}")
      end
      def endscene; end
    end

    module Fullbox
      def self.makeSprite(*_args); end
    end

    class MugWrapper
      def initialize(box); @mugname = box; end
    end

    class Fullbox_Choice
      def initialize(*_args); end
      def loop; end
      def setSelection(*_args); end
      def select; end
      def dispose; end
    end

    # 0168_Gender: the question painted on the card, the choice in @select.
    class PokemonGenderSelectScene
      attr_accessor :select
      def update; end
      def pbStartScene
        @sprites = {}
        @select = 0
        pbDrawTextPositions(nil, [["Is it a boy or a girl?", 256, 16, 2]])
      end
      def pbEndScene; end
    end

    # 0151_SceltaStarter: the Si/No labels painted at construction, the question once a Pokemon is taken.
    class SceltaStarter
      attr_accessor :select, :selected, :confirm
      def initialize(pokemon)
        @select, @selected, @confirm = 0, false, 0
        @sprites = { 'shyleonDet' => Pic.new(nil, true, 255), 'trishoutDet' => Pic.new(nil, true, 255),
                     'shulongDet' => Pic.new(nil, true, 255), 'confirm' => Pic.new(Object.new),
                     'si' => Pic.new(Object.new), 'no' => Pic.new(Object.new) }
        pbDrawTextPositions(@sprites['si'].bitmap, [["Si", 40, 6, 2]])
        pbDrawTextPositions(@sprites['no'].bitmap, [["No", 40, 6, 2]])
        @data = { "pkmn_0" => pokemon[0], "pkmn_1" => pokemon[1], "pkmn_2" => pokemon[2] }
      end
      def ask(name)
        @selected = true
        pbDrawTextPositions(@sprites['confirm'].bitmap, [["Vuoi scegliere #{name}?", 256, 310, 2]])
      end
      def gettinginput; end
      def input_action; end
      def closescene; end
    end

    # 0194_NewMenu_Scene: items with their translated label, the cursor moved by handleInput.
    class NewMenu_Item
      attr_reader :displayedName
      def initialize(name); @displayedName = name; end
      def select; end
    end

    class NewMenu
      def initialize(items); @items, @index, @looping = items, 0, true; end
      def open
        update
        @index = 1
        handleInput
      end
      def update; end
      def handleInput; end
      def close; end
    end

    BagDouble = Struct.new(:registeredItem)

    # 0225_NewBag: the pocket's name and rows, the info box painting the item's name, the quantity box painting "x005".
    class NewBagScreen
      def pbStartScene(bag)
        @pocketNames = ["", "Strumenti", "Medicine"]
        @curPocketIndex, @curPocket, @index, @bag, @switching = 1, [[1, 3], [2, 1]], 0, bag, false
        @s = { "qtbg" => Pic.new(Object.new) }
        drawItemInfo
      end
      def drawItemInfo; pbDrawTextPositions(nil, [[["Pozione", "Antidoto"][@curPocket[@index][0] - 1], 16, 198, 0]]); end
      def update; end
      def updatePocket(p)
        @curPocketIndex, @curPocket, @index = p, [], 0
      end
      def pbChangeSelection; end
      def pbRefresh; end
      def pbDisplay(_text); end
      def pbConfirm(_text); true; end
      def pbChooseNumber(_helptext, _qty)
        pbDrawTextPositions(@s["qtbg"].bitmap, [["x" + sprintf("%03d", 5), 130, 5, 1]])
        PokeAccess::Frame.run_pollers
        5
      end
      def pbShowCommands(_helptext, _commands); 0; end
      def pbEndScene; end
    end

    # 0230_NewMart: the buy chooser over a painted grid, drawItemInfo given the grid's index after each move.
    class MartAdapter
      def getMoney; 3000; end
      def getQuantity(_item); 2; end
      def getName(item); ["", "Pozione", "Antidoto"][item]; end
      def getDisplayName(item); getName(item); end
      def getPrice(_item); 300; end
      def getDisplayPrice(_item); "300"; end
      def getDescription(_item); "Cura."; end
      def getBattlePrice(_item); 5; end
    end

    class PokemonMartScene
      def initialize; @buying, @stock, @adapter, @bpmode = true, [1, 2], MartAdapter.new, false; end
      def pbChooseBuyItem
        drawItemInfo(0)
        drawItemInfo(1)
        nil
      end
      def drawItemInfo(index); end
    end

    class PokeBattle_Scene
      def pbCommandMenuEx(*_args); end
      def pbFightMenu(*_args); end
    end

    %w[NewCommandWindow NextGenCommandWindow].each do |name|
      Object.const_set(name, Class.new { def refreshCommands; end; def update; end })
    end
    %w[NewFightWindow NextGenFightWindow].each do |name|
      Object.const_set(name, Class.new { def update; end; def megaButtonTrigger; end })
    end

    # 0177_EliteBattle_UI: a pocket's paged grid, its name and page count.
    class NewBattleBag
      def initialize
        @selPocket, @item, @pocket, @page, @pages, @pname, @back, @ret = 1, 0, [[1, 2]], 0, 2, "Medicine", false, nil
      end
      def show; end
      def hide; end
      def update; end
      def useItem?; false; end
      def getItemText(_n); "Medicines"; end
    end

    class DexObtained
      def addPokemonInfo; end
      def inloop; end
      def whatToDo; end
      def update; end
      def message(*_args); end
      def endscene; end
    end

    # 0222_NewParty: the command list paints its question and a button per command, the cursor at @index.
    class PokemonScreen_Scene
      def pbShowCommands(helptext, commands, y = nil, index = 0, pkmn = nil, x = 0)
        return -1 if pkmn.nil?
        @cmds = {}
        commands.each_index { |i| @cmds["cmd#{i}"] = Spr.new }
        pbDrawTextPositions(Object.new, [[helptext, 30, 348, 0]])
        [0, 1].each { |i| @index = i; updateCmds }
        @index
      end
      def updateCmds; end
    end

    class PokemonSummary
      def pbStartScreen(*_args); end
    end

    # 0223_NewSummary: Stats on page two and Memo on page four, their paragraphs written with drawTextExH; each page
    # notes whether the profile's capture is the one armed while it paints.
    class PokemonSummaryScene
      def drawPageTwo
        ($page_armed ||= []).push(PokeAccess::PaintCapture.armed?(:xenoverse_summary_stats))
        drawTextExH(nil, 16, 300, 480, 2, "Cresce in fretta.", nil, nil)
      end
      def drawPageFour
        ($page_armed ||= []).push(PokeAccess::PaintCapture.armed?(:xenoverse_summary_memo))
        drawTextExH(nil, 16, 80, 480, 2, "Incontrato a Borgo Ciclamino.", nil, nil)
      end
    end

    # 0228_NewCommandScreen: each page a sprite with its descriptions painted top to bottom, the page in sight at x 0.
    class CommandScreen
      def initialize
        @page = 0
        @sprites = { "page1" => Spr.new, "page2" => Spr.new(512) }
        pbDrawTextPositions(@sprites["page1"].bitmap, [["Muoviti", 200, 40, 0], ["Conferma", 200, 90, 0],
                                                       ["Annulla", 200, 140, 0], ["Corri", 200, 190, 0],
                                                       ["Salva", 200, 240, 0]])
        pbDrawTextPositions(@sprites["page2"].bitmap, [["Registro", 200, 40, 0], ["Menu", 200, 90, 0],
                                                       ["Squadra", 200, 140, 0], ["Borsa", 200, 190, 0]])
        $controls_steps.each { |step| step.call(self) }
      end
      def turn
        @page = 1
        @sprites["page1"].x, @sprites["page2"].x = -512, 0
      end
    end

    # 0250_Tournament: the bracket's picture from the first round's pool and those still in.
    class PWT
      def initialize(player, difficulty, trainerpool = nil, doublebattle = false, testpool = false)
        @firstPool, @pool = trainerpool, trainerpool
      end
      def showChart; end
    end

    # The PokeWES screens (0197, 0129, 0216-0220) and the Mystery Gift (0247), with their methods' arities.
    class PokeWES
      def initialize(scene = false); end
      def commands; end
    end
    class MNScene
      def initialize(scene = false, scenemap = nil); end
    end
    class AchievementsScreen
      def initialize; end
      def openScene; end
    end
    class DexSearch
      def initialize(viewport, dexmain, dextype); end
      def handleInput; end
    end
    class DexSearchChoice
      def initialize(viewport, options, default); end
      def selectChoice; end
    end
    class DexInfo
      def initialize(species, dextype, dexmain); end
      def updatePokemonInfo; end
      def close; end
    end
    class MysteryGiftScene
      def initialize; end
      def commands; end
    end

    # 0117_PScreen_TrainerCard's back: one picture per earned badge (@obtBadge), the cursor at @index.
    class PokemonTrainerCardScene
      def pbTrainerCard; end
      def back(earned, index)
        @sprites = { "medals" => Pic.new(nil, true, 255), "sfade" => Pic.new(nil, true, 0) }
        @retro, @obtBadge, @index = true, earned, index
      end
    end

    # A sprite with a bitmap of its own, which the screens paint their labels onto, and a place.
    class Spr
      attr_accessor :bitmap, :x, :y
      def initialize(x = 0, y = 0); @bitmap, @x, @y = Object.new, x, y; end
      def disposed?; false; end
    end

    # 0239_Misc: the braille box, its text drawn as dots until C or B.
    def pbDisplayBrailleText(text = "", height = -1); end

    # 0224_NewNameEntry: the keyboard naming screen paints its own hint under the field.
    class PokemonEntryScene
      def pbStartScene(helptext, minlength, maxlength, initialText, subject = 0, pokemon = nil)
        pbDrawTextPositions(Object.new, [["Enter text using the keyboard. Press ENTER to confirm.", 256, 2, 2]])
      end
    end

    # 0226_NewStorage: the box's 16 slots and the party's 6 under @selIndex, its painted box name and lower bar, the
    # action buttons' painted labels; the loop runs the steps the play hands it, a frame each.
    Box = Struct.new(:currentbox)
    Party = Struct.new(:party)
    Storage = Struct.new(:currentBox)
    class NewPokemonStorage
      attr_accessor :sel, :held, :party0
      def initialize
        @storage, @selIndex, @heldmon = Storage.new(0), 0, nil
        @party0 = Mon.new("Shyleon")
        def @party0.level; 7; end
        def @party0.markings; 2; end
        @sprites = { "box" => Spr.new, "partybox" => Spr.new, "boxname" => Spr.new, "lbo" => Spr.new }
        @sprites["box"].instance_variable_set(:@currentbox, [nil] * 16)
        def (@sprites["box"]).currentbox; @currentbox; end
        party = [@party0]
        @sprites["partybox"].instance_variable_set(:@party, party)
        def (@sprites["partybox"]).party; @party; end
        pbDrawTextPositions(@sprites["boxname"].bitmap, [["Box 1", 138, 4, 2]])
        pbDrawTextPositions(@sprites["lbo"].bitmap, [["Jump", 102, 3, 1], ["Actions", 280, 3, 1], ["Close", 474, 3, 1]])
        @acsel = (0...5).map { Object.new }
        %w[Move Summary Item Mark Free].each_with_index { |t, i| pbDrawTextPositions(@acsel[i], [[t, 75, 4, 2]]) }
        handling
      end
      def handling
        $storage_steps.each { |step| step.call(self) }
      end
      def step(sel, held); @selIndex, @heldmon = sel, held; end
      def open_actions
        @index = 1
        @s = { "bar" => Spr.new, "sac0" => Spr.new }
        pbDrawTextPositions(@s["bar"].bitmap, [["Shyleon", 10, 10, 0], ["Lv.  7", 150, 10, 0]])
      end
      def showCommands(_helptext, _commands); 0; end
      def chooseNumber(_helptext, _qty, _min = 0, _cancel = 0); 1; end
      def setMarkings(_pkmn)
        @m = { "box" => Spr.new, "cursor" => Spr.new(348, 0) }
        pbDrawTextPositions(@m["box"].bitmap, [["Markings", 10, 10, 0]])
      end
      def mark_at(x); @m["cursor"].x = x; end
    end

    # 0227_NewOptions: a bar per option with its values under selIndex, the row under @index.
    Opt = Struct.new(:name)
    Bar = Struct.new(:options, :selIndex)
    class PokemonOptionScene
      def pbStartScene
        @PokemonOptions = [Opt.new("Velocità testo"), Opt.new("Scena lotta")]
        @sprites = { "banner" => Spr.new, "lowerbar" => Spr.new,
                     "opt0" => Bar.new(%w[Lento Medio Veloce], 1), "opt1" => Bar.new(%w[On Off], 0) }
        pbDrawTextPositions(@sprites["banner"].bitmap, [["Settings", 71, 13, 0]])
        pbDrawTextPositions(@sprites["lowerbar"].bitmap, [["Default", 104, 3, 1], ["Save", 280, 3, 1], ["Back", 474, 3, 1]])
        @index = 0
      end
      def pbOptions
        $option_steps.each { |step| step.call(self, @sprites) }
      end
      def index=(i); @index = i; end
    end

    # 0229_NewMovelearner: the question painted as it opens, each move read as drawMoveInfo paints it, and its own Yes/No.
    class MoveRelearnerScene
      def pbStartScene(pokemon, moves)
        @pastmoves = moves
        pbDrawTextPositions(Object.new, [["Teach which move to #{pokemon}?", 256, 10, 2]])
      end
      def drawMoveInfo(_index); end
      def pbUpdate; end
      def pbConfirm(msg)
        @s = { "yes" => Spr.new(496, 226), "no" => Spr.new(496, 266) }
        pbDrawTextPositions(@s["yes"].bitmap, [["Sì", 44, 5, 2]])
        pbDrawTextPositions(@s["no"].bitmap, [["No", 44, 5, 2]])
        $confirm_steps.each { |step| step.call(@s); pbUpdate }
        true
      end
      def pbEndScene; end
    end

    # 0216_DEX_MAIN: the grid's species under @selIndex up to the last seen, the counts and description painted above.
    class DexMain
      def initialize(list)
        @dexlist, @selIndex, @lastpokemonIndex = list, 0, list.length - 1
        @sprites = { "overlay" => Spr.new }
        pbDrawTextPositions(@sprites["overlay"].bitmap, [["2", 206, 12, true], ["1", 152, 12, true]])
        pbDrawTextPositions(@sprites["overlay"].bitmap, [["Progress", 20, 9, false], ["Pokédex di Eldiw", 266, 9, false],
                                                         ["Close", 460, 346, true], ["Search", 276, 346, true]])
      end
      def inputHandle
        $dex_steps.each { |step| step.call(self) }
      end
      def sel=(i); @selIndex = i; end
    end

    # 0170_TreasureHook: the hook in its lane (@corsia) and the obstacles coming up, read as the scene updates.
    Img = Struct.new(:width, :height)
    class Hook
      attr_accessor :hits, :position, :image
      def initialize; @corsia, @hits, @position, @image = 3, 0, [146, 60], Img.new(48, 48); end
      def lane=(l); @corsia = l; @position[0] = 512 / 6 * l - 24; end
    end
    class Obstacle
      attr_accessor :type, :position, :image
      def initialize(lane, y, type); @type, @position, @image = type, [512 / 6 * lane - 24, y], Img.new(48, 48); end
    end
    class TreasureHookScene
      attr_reader :sprites
      def pbStartScene
        @sprites = { "bg" => Spr.new, "hook" => Hook.new, "obs1" => Obstacle.new(1, 500, 1), "obs2" => Obstacle.new(2, 500, 1) }
      end
      def update; end
      def pbEndScene; end
    end
  RUBY

  PLAY = <<-'RUBY'
    HOOK_TRAP.disable
    probe(:unbound_hooks) { UNBOUND_HOOKS.uniq }

    def texts(log)
      log.map { |entry| entry[0] }
    end

    def gender_play
      scene = PokemonGenderSelectScene.new
      opened = said { scene.pbStartScene }
      moved = said { scene.select = 1; scene.update }
      scene.pbEndScene
      probe(:gender) { [texts(opened), texts(moved)] }
    end

    def starter_play
      scene = SceltaStarter.new([Mon.new("Shyleon"), Mon.new("Trishout"), Mon.new("Shulong")])
      first = said { scene.input_action }
      past = said { scene.select = 3; scene.gettinginput }
      back = said { scene.select = 2; scene.gettinginput }
      asked = said { scene.ask("Shulong"); scene.gettinginput }
      scene.closescene
      probe(:starter) { [texts(first), texts(past), texts(back), texts(asked)] }
    end

    def menu_play
      menu = NewMenu.new([NewMenu_Item.new("Pokedex"), NewMenu_Item.new("Squadra")])
      probe(:menu) { texts(said { menu.open }) }
    end

    def bag_play
      scene = NewBagScreen.new
      opened = said { scene.pbStartScene(BagDouble.new(0)) }
      empty = said { scene.updatePocket(2) }
      scene.updatePocket(1)
      quantity = said { scene.pbChooseNumber("Quante?", 10) }
      scene.pbEndScene
      probe(:bag) { [texts(opened), texts(empty), texts(quantity)] }
    end

    def battle_bag_play
      bag = NewBattleBag.new
      bag.show
      probe(:battle_bag) { texts(said { bag.update }) }
      bag.hide
    end

    def fullbox_play
      $fullbox_mugshots = { "left" => [MugWrapper.new(MugName.new(true, true, "Rem"))] }
      probe(:fullbox) { texts(said { Fullbox.makeSprite("Ciao!", "Come stai?") }) }
      $fullbox_mugshots = nil
    end

    def badges_play
      $Trainer.badges = [true, false, true, false, false, false, false, false]
      card = PokemonTrainerCardScene.new
      PokeAccess::XenoverseBadges.watch(card)
      frames = [0, 2, 1, -1].map do |index|
        card.back([true, true], index)
        texts(said { PokeAccess::Frame.run_pollers })
      end
      PokeAccess::XenoverseBadges.unwatch
      probe(:badges) { frames }
    end

    def frame
      texts(said { PokeAccess::Frame.run_pollers })
    end

    def braille_play
      probe(:braille) { texts(said { pbDisplayBrailleText("Cerca la luce") }) }
    end

    def name_entry_play
      probe(:name_entry) { texts(said { PokemonEntryScene.new.pbStartScene("Il tuo nome?", 1, 12, "") }) }
    end

    def storage_play
      log = []
      $storage_steps = [
        lambda { |s| log.push(frame) },
        lambda { |s| s.step(5, nil); log.push(frame) },
        lambda { |s| s.step(16, nil); log.push(frame) },
        lambda { |s| s.step(16, s.party0); log.push(frame) },
        lambda { |s| s.step(1, s.party0); log.push(frame) },
        lambda { |s| s.open_actions; log.push(frame) },
        lambda { |s| s.setMarkings(s.party0); log.push(frame) },
        lambda { |s| s.mark_at(370); log.push(frame) }
      ]
      NewPokemonStorage.new
      probe(:storage) { log }
    end

    def options_play
      log = []
      $option_steps = [lambda { |s, _sp| log.push(frame) }, lambda { |s, sp| sp["opt0"].selIndex = 2; log.push(frame) },
                       lambda { |s, _sp| s.index = 1; log.push(frame) }]
      scene = PokemonOptionScene.new
      scene.pbStartScene
      scene.pbOptions
      probe(:options) { log }
    end

    def learner_play
      scene = MoveRelearnerScene.new
      scene.pbStartScene("Shyleon", [1, 2])
      first = texts(said { scene.drawMoveInfo(0) })
      second = texts(said { scene.drawMoveInfo(1) })
      log = []
      $confirm_steps = [lambda { |s| }, lambda { |s| s["no"].y = 256 }, lambda { |s| s["no"].y = 266 }]
      confirm = said { scene.pbConfirm("Teach Pound?") }
      scene.pbEndScene
      probe(:learner) { [first, second, texts(confirm)] }
    end

    def dex_play
      def $Trainer.seen; { 1 => true, 4 => true }; end
      def $Trainer.owned; { 1 => true }; end
      log = []
      $dex_steps = [lambda { |d| log.push(frame) }, lambda { |d| d.sel = 1; log.push(frame) },
                    lambda { |d| d.sel = 2; log.push(frame) }]
      DexMain.new([1, 2, 4]).inputHandle
      probe(:dex) { log }
    end

    def hook_play
      scene = TreasureHookScene.new
      scene.pbStartScene
      opened = texts(said { scene.update })
      scene.sprites["obs1"].position[1] = 300
      scene.sprites["obs2"].position[1] = 300
      row = texts(said { scene.update })
      scene.sprites["hook"].lane = 2
      moved = texts(said { scene.update })
      scene.sprites["hook"].hits = 1
      hit = texts(said { scene.update })
      scene.pbEndScene
      probe(:hook) { [opened, row, moved, hit] }
    end

    def field_moves_play
      $game_switches[186] = false
      before = PokeAccess::FieldMoves.can?(:CUT)
      $game_switches[186] = true
      after = PokeAccess::FieldMoves.can?(:CUT)
      $game_switches[188] = true
      $Trainer.badges = [true, true, true, true, false, false, false, false]
      no_badge = PokeAccess::FieldMoves.can?(:SURF)
      $Trainer.badges[4] = true
      badge = PokeAccess::FieldMoves.can?(:SURF)
      probe(:field_moves) { [before, after, PokeAccess::FieldMoves.can?(:ROCKSMASH), no_badge, badge] }
    end

    def party_play
      scene = PokemonScreen_Scene.new
      shown = said { scene.pbShowCommands("Do what with Shyleon?", ["Summary", "Switch"], nil, 0, Mon.new("Shyleon")) }
      probe(:party) { texts(shown) }
    end

    def summary_play
      scene = PokemonSummaryScene.new(TestPoke.build(:name => "Shyleon"))
      stats = texts(said { scene.drawPageTwo })
      memo = texts(said { scene.drawPageFour })
      probe(:summary) { [$page_armed, stats, memo] }
    end

    def controls_play
      log = []
      $controls_steps = [lambda { |s| log.push(frame) }, lambda { |s| s.turn; log.push(frame) }]
      CommandScreen.new
      probe(:controls) { log }
    end

    def tournament_play
      pool = [$Trainer, [0, "Ana", 5], [0, "Bea", 6], [0, "Cid", 7]]
      pwt = PWT.new($Trainer, 1, pool)
      pwt.instance_variable_set(:@pool, [$Trainer, pool[1]])
      probe(:tournament) { [texts(said { pwt.showChart }), PokeAccess.clean($Trainer.name.to_s)] }
    end

    def title_play
      shown = texts(said { Scene_Intro.new(XenoverseStyle.new).update })
      other = texts(said { Scene_Intro.new(Object.new).update })
      probe(:title) { [shown, other, PokeAccess::TitleScreen.prompt] }
    end

    def game_modes_play
      scene = GameModeScreen.new
      first = texts(said { scene.drawInfo(0) })
      second = texts(said { scene.drawInfo(1) })
      scene.endscene
      probe(:game_modes) { [first, second] }
    end

    def mart_play
      probe(:mart) { texts(said { PokemonMartScene.new.pbChooseBuyItem }) }
    end

    def naming_play
      probe(:naming) { PokeAccess::Locator.game_map_name(12) }
    end

    def compat_play
      load File.join(Harness::ROOT, "games", "xenoverse", "compat.rb")
      FontInstaller.module_eval("def self.install; :installed; end")
      probe(:compat) { FontInstaller.install }
    end

    braille_play
    name_entry_play
    storage_play
    options_play
    learner_play
    dex_play
    hook_play
    field_moves_play
    party_play
    summary_play
    controls_play
    tournament_play
    title_play
    game_modes_play
    mart_play
    naming_play
    compat_play
    gender_play
    starter_play
    menu_play
    bag_play
    battle_bag_play
    fullbox_play
    badges_play
  RUBY

  profile "xenoverse", WORLD, PLAY

  # The game functions the profile wraps, which must be there for its readers to run.
  FUNCTIONS = %w[drawTextExH pbDrawTextPositions pbDrawOutlineText pbDisplayBrailleText pbEnterPokemonName]

  test "loads whole and binds what it declares" do
    assert_equal [[], [], [], []],
                 [played(:load_errors), played(:missing_hooks), played(:absent_functions) & FUNCTIONS, played(:unbound_hooks)]
  end

  test "the summary's pages arm the profile's capture after the core's own, so what they paint reaches its readers" do
    armed, stats, memo = played(:summary)
    assert_equal [true, true], armed
    assert_equal 1, stats.length
    refute_empty stats[0]
    assert_equal 1, memo.length
    assert memo[0].end_with?("Incontrato a Borgo Ciclamino."), memo[0]
  end

  test "the party's commands follow the question the core says once, each by the button under the cursor" do
    assert_equal ["Do what with Shyleon?", "Summary", "Switch"], played(:party)
  end

  test "the controls say each page's keys with the description painted beside them" do
    first, second = played(:controls)
    arrows = PokeAccess::Routes::Text.and_list([:up, :down, :left, :right].map { |b| t("btn_#{b}".to_sym) })
    assert_equal 1, first.length
    assert first[0].start_with?(t(:xenoverse_named, :name => arrows, :text => "Muoviti")), first[0]
    assert_equal 1, second.length
    assert_includes second[0], "Registro"
    refute_includes second[0], "Muoviti"
  end

  test "the tournament's bracket says the pairs still in and the trainers out as a list" do
    line, player = played(:tournament)
    out = t(:xenoverse_bracket_out, :list => t(:list_and, :rest => "Bea", :last => "Cid"))
    assert_equal [PokeAccess.sentences([t(:xenoverse_bracket), t(:xenoverse_versus, :a => player, :b => "Ana"), out])], line
  end

  test "the title says its prompt over the game's own style only" do
    shown, other, prompt = played(:title)
    assert_equal [[prompt], []], [shown, other]
  end

  test "the game modes say the selected mode's label and the rules painted for it" do
    assert_equal [[PokeAccess.sentences(["Classica", "Regole 0"])], [PokeAccess.sentences(["Moderna", "Regole 1"])]],
                 played(:game_modes)
  end

  test "the shop's buy grid says each item with its price and place, the money only the first time" do
    first, second = played(:mart)
    assert first.start_with?(t(:mart_item, :name => "Pozione", :price => "300")), first
    assert first.end_with?(t(:tc_money, :n => 3000)), first
    assert second.start_with?(t(:mart_item, :name => "Antidoto", :price => "300")), second
    refute_includes second, t(:tc_money, :n => 3000)
  end

  test "a map takes the name the game translates for it" do
    assert_equal "Bosco Ombroso 12", played(:naming)
  end

  test "the preload script turns the font installer the game defines later into a no-op" do
    assert_nil played(:compat)
  end

  test "the boy/girl choice says the painted question first, then each picture's word" do
    opened, moved = played(:gender)
    assert_equal [PokeAccess.sentences(["Is it a boy or a girl?", t(:gsel_boy)])], opened
    assert_equal [t(:gsel_girl)], moved
  end

  test "the starter choice names each Pokemon, says the place past the third, and the painted question with its answer" do
    first, past, back, asked = played(:starter)
    assert_equal 1, first.length
    assert_match(/\AShyleon/, first[0])
    assert_equal [t(:xenoverse_starter_edge)], past
    assert_equal 1, back.length
    assert_match(/\AShulong/, back[0])
    assert_equal [PokeAccess.sentences(["Vuoi scegliere Shulong?", "Si"])], asked
  end

  test "the pause menu says each item's label" do
    assert_equal ["Pokedex", "Squadra"], played(:menu)
  end

  test "the bag says the pocket and the painted item name, an empty pocket, and the painted quantity" do
    opened, empty, quantity = played(:bag)
    assert_equal 1, opened.length
    assert opened[0].start_with?(t(:bag_pocket, :name => "Strumenti")), opened[0]
    assert_includes opened[0], t(:bag_item, :name => "Pozione", :qty => 3)
    assert_equal [PokeAccess.sentences([t(:bag_pocket, :name => "Medicine"), t(:xenoverse_bag_empty)])], empty
    assert_includes quantity, t(:xenoverse_quantity, :n => 5)
  end

  test "the battle bag says the pocket's name and page before its first row" do
    line = played(:battle_bag)
    assert_equal 1, line.length
    assert line[0].start_with?(t(:xenoverse_bag_page, :name => "Medicine", :n => 1, :tot => 2)), line[0]
  end

  test "the message box says the visible portrait's name before its rows" do
    line = played(:fullbox)
    assert_equal 1, line.length
    assert_includes line[0], t(:xenoverse_named, :name => "Rem", :text => "Ciao! Come stai?")
  end

  test "the braille box says its text as a line of dialogue" do
    assert_includes played(:braille), t(:xenoverse_braille, :text => "Cerca la luce")
  end

  test "the game's own naming screen is read by the core's keyboard reader: the question first" do
    said = played(:name_entry)
    refute_empty said
    assert_includes said.join(" "), "Il tuo nome?"
  end

  test "the PC says the box and its slot, a party slot, the held Pokemon, a place to drop it, the actions and the marks" do
    opened, empty, party, holding, drop, actions, marks, next_mark = played(:storage)
    assert_equal 1, opened.length
    assert opened[0].start_with?("Box 1"), opened[0]
    assert opened[0].end_with?(t(:pc_empty) + t(:pc_pos, :row => 1, :col => 1)), opened[0]
    assert_equal [t(:pc_empty) + t(:pc_pos, :row => 2, :col => 2)], empty
    team = t(:list_entry, :name => t(:pc_team), :n => 1, :tot => 6)
    assert_equal [t(:xenoverse_pc_party, :slot => t(:pc_slot, :name => "Shyleon", :level => 7), :entry => team)], party
    assert_equal [t(:xenoverse_pc_party, :slot => t(:xenoverse_holding, :name => "Shyleon"), :entry => team)], holding
    assert_equal [t(:pc_place, :held => "Shyleon") + t(:pc_pos, :row => 1, :col => 2)], drop
    bar = t(:xenoverse_pc_bar, :name => "Shyleon", :level => "Lv. 7")
    assert_equal [PokeAccess.sentences([bar, t(:list_entry, :name => "Summary", :n => 2, :tot => 5)])], actions
    circle = t(:xenoverse_mark, :name => t(:mk_circle), :state => t(:mk_off))
    assert_equal [PokeAccess.sentences(["Markings", circle])], marks
    assert_equal [t(:xenoverse_mark, :name => t(:mk_triangle), :state => t(:mk_on))], next_mark
  end

  test "the options say the painted title first, then each row's name and value as either changes" do
    opened, changed, row = played(:options)
    entry = lambda { |name, value, n| t(:list_entry, :name => t(:xenoverse_named, :name => name, :text => value), :n => n, :tot => 2) }
    assert_equal 1, opened.length
    assert opened[0].start_with?(PokeAccess.sentences(["Settings", entry.call("Velocità testo", "Medio", 1)])), opened[0]
    assert_equal [entry.call("Velocità testo", "Veloce", 1)], changed
    assert_equal [entry.call("Scena lotta", "On", 2)], row
  end

  test "the move relearner says its question before the first move, and its Yes/No by the bouncing button after the core's question" do
    first, second, confirm = played(:learner)
    assert_equal 1, first.length
    assert first[0].start_with?("Teach which move to Shyleon?. ") || first[0].start_with?("Teach which move to Shyleon? "), first[0]
    assert_equal 1, second.length
    refute_includes second[0], "Teach which move"
    assert_equal ["Teach Pound?", "Sì", "No"], confirm
  end

  test "the Pokedex grid names a seen Pokemon with caught or seen, and an unseen one as unknown" do
    opened, unseen, seen = played(:dex)
    assert_equal 1, opened.length
    assert opened[0].start_with?(t(:dex_region_counts, :name => "Pokédex di Eldiw", :seen => "2", :owned => "1")), opened[0]
    assert_includes opened[0], t(:dex_caught)
    assert_equal [t(:list_entry, :name => t(:dex_unknown), :n => 2, :tot => 3)], unseen
    assert_equal 1, seen.length
    assert seen[0].end_with?(", 3 de 3, " + t(:dex_seen)) || seen[0].end_with?(t(:dex_seen)), seen[0]
  end

  test "the treasure hook says its lane, each row that comes into sight, what lies ahead in a new lane, and the hits" do
    opened, row, moved, hit = played(:hook)
    assert_equal 1, opened.length
    assert opened[0].start_with?(t(:xenoverse_hook_start, :n => 3)), opened[0]
    assert_equal [t(:xenoverse_named, :name => t(:xenoverse_hook_rock), :text => "1, 2")], row
    assert_equal [t(:xenoverse_named, :name => t(:xenoverse_hook_lane, :n => 2), :text => t(:xenoverse_hook_rock))], moved
    assert_equal [t(:xenoverse_hook_hits, :n => 1)], hit
  end

  test "Cut goes by the Kaiserium N gem's switch, Surf by its gem and the fifth badge, Rock Smash by its own gem" do
    before, after, smash, no_badge, badge = played(:field_moves)
    assert_equal [false, true], [before, after]
    assert_equal false, smash
    assert_equal [false, true], [no_badge, badge]
  end

  test "the badges count the pictures shown and never read the cursor past either end" do
    at_first, past_end, at_second, before_first = played(:badges)
    entry = t(:list_entry, :name => "Medaglia Radice", :n => 1, :tot => 2)
    assert_equal [PokeAccess.sentences([t(:tr_badges, :n => 2), entry])], at_first
    assert_equal [], past_end
    assert_equal [t(:tr_badges, :n => 2)], at_second
    assert_equal [], before_first
  end
end
