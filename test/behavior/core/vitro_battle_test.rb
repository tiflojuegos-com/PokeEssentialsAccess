# Vitro's battle, loaded with its whole profile over doubles with the shape of its scripts: the labels its command buttons paint,
# the keys of its menus, the power its fight buttons paint, what the screens over the menus leave behind, the information sheet
# under an Illusion, the boss's box and the marks it paints without a file, the figures that float over a foe, the floating
# immunity, the list of Balls, the battle bag and the experience panel. In a process of its own, since its overrides would reach
# every other test here.
class VitroBattleTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    NO_CAPTURE_SWITCH = 36
    NO_CAPTURES_SWITCH = NO_CAPTURE_SWITCH
    COMMANDBOX = 2
    FIGHTBOX = 3

    module MessageTypes; ItemDescriptions = 5; end
    module PBEffects; Illusion = 99; end

    def hasBalls?; $has_balls; end
    def pbInSafari?; $in_safari; end
    def pbInBugContest?; $in_contest; end

    # A menu's hidden command window, which only keeps the labels and the cursor.
    class MenuWindow
      attr_accessor :commands, :index, :visible
    end

    # 0102_PokeBattle_SceneCommands: the buttons keep a list of labels of their own, some not the window's.
    class CommandMenuButtons
      def initialize
        @commandtext = ["Luchar", "Pokémon", "Bolsa", "Huir", "Llamar", "Ball", "Roca", "Cebo", "Ball"]
      end
    end

    # 0102: setTexts keeps labels 1 to 4 on the window, and the mode comes after the cursor.
    class CommandMenuDisplay
      attr_accessor :mode

      def initialize(_viewport = nil, doublebattle = false, trainer = false)
        @window = MenuWindow.new
        @buttons = CommandMenuButtons.new
        unless doublebattle || $game_switches[NO_CAPTURE_SWITCH] || trainer || !hasBalls? || pbInSafari? || pbInBugContest?
          @atajoBall = :an_icon
        end
      end

      def index; @window.index; end
      def index=(value); @window.index = value; end
      def visible; @window.visible; end
      def visible=(value); @window.visible = value; end

      def setTexts(value)
        commands = []
        for i in 1..4
          commands.push(value[i]) if value[i] && value[i] != nil
        end
        @window.commands = commands
      end
    end

    # 0102's battler= and setIndex, with 0104's show_move_info.
    class FightMenuDisplay
      attr_reader :battler, :index
      attr_accessor :megaButton, :ultraButton, :zButton, :dynaButton, :teraButton

      def initialize(_battler = nil, _viewport = nil)
        @window = MenuWindow.new
        @index = 0
      end

      def visible; @window.visible; end
      def visible=(value); @window.visible = value; end
      def battler=(value); @battler = value; end

      def setIndex(value)
        if @battler && @battler.moves[value].id != 0
          @index = value
          @window.index = value
          return true
        end
        false
      end

      def show_move_info(move_id, battle)
        scene = MoveInfoScene.new(move_id, @battler, battle, @index)
        scene.main
      end
    end

    # 0104: a frame of its loop, with what it paints.
    class MoveInfoScene
      def initialize(_move_id, battler, _battle, index)
        @battler = battler
        @current_index = index
        @movedata = battler.moves[index]
      end

      def main
        PokeAccess::Frame.run_pollers
        :closed
      end

      def draw_info
        pbDrawTextPositions(:bitmap, [[@movedata.name, 0, 0, 0, nil, nil]])
      end
    end

    BattlePokemon = Struct.new(:name, :gender, :ability, :item, :type1, :type2) do
      def isEgg?; false; end
    end
    BattleMove = Struct.new(:id, :name, :type, :category, :basedamage, :pp, :totalpp)

    # The battler as the box, the menus and the information read it.
    class PokeBattle_Battler
      attr_accessor :index, :name, :level, :hp, :totalhp, :status, :pokemon, :moves, :stages, :type1, :type2, :item, :ability,
                    :lastMoveUsed, :shiny, :shadow, :effects, :mega, :owned

      def initialize(index, name, opts = {})
        @index = index
        @name = name
        @level = opts[:level] || 30
        @hp = opts[:hp] || 50
        @totalhp = opts[:totalhp] || 100
        @status = opts[:status] || 0
        @ability = opts[:ability] || 3
        @item = opts[:item] || 0
        @type1 = opts[:type1] || 1
        @type2 = opts[:type2] || @type1
        @pokemon = BattlePokemon.new(name, opts[:gender] || 0, opts[:own_ability] || @ability, opts[:own_item] || @item,
                                     @type1, @type2)
        @moves = opts[:moves] || [BattleMove.new(0, "", 0, 0, 0, 0, 0)] * 4
        @stages = opts[:stages] || [0, 0, 0, 0, 0, 0, 0, 0]
        @lastMoveUsed = opts[:last] || -1
        @shiny = opts[:shiny]
        @shadow = opts[:shadow]
        @mega = opts[:mega]
        @owned = opts[:owned]
        @effects = { PBEffects::Illusion => opts[:illusion] }
      end

      def displayGender; @pokemon.gender; end
      def isShiny?; @shiny; end
      def isShadow?; @shadow; end
      def pbThis(_lower = false); @name; end
    end

    class PokeBattle_Battle
      attr_accessor :battlers, :doublebattle, :opponent, :scene, :turncount

      def pbDisplayConfirm(_msg); end

      def initialize(battlers, opts = {})
        @battlers = battlers
        @doublebattle = opts[:double] ? true : false
        @opponent = opts[:opponent]
        @turncount = 0
        @scene = PokeBattle_Scene.new(self)
      end

      def pbParty(_index); []; end
    end

    # 0099_PokeBattle_Scene's window switch, 0102's menus up to their loops, and 0103's entry to its information.
    class PokeBattle_Scene
      attr_accessor :lastcmd, :lastmove, :sprites

      def initialize(battle)
        @battle = battle
        @lastcmd = [0, 0, 0, 0]
        @lastmove = [0, 0, 0, 0]
        @sprites = { "commandwindow" => CommandMenuDisplay.new(nil, battle.doublebattle, battle.opponent),
                     "fightwindow" => FightMenuDisplay.new(nil, nil) }
      end

      def pbShowWindow(windowtype)
        @sprites["commandwindow"].visible = (windowtype == COMMANDBOX)
        @sprites["fightwindow"].visible = (windowtype == FIGHTBOX)
      end

      def pbCommandMenu(index)
        pbCommandMenuEx(index, ["", "Luchar", "Mochila", "Pokémon", "Huir"], 0)
      end

      def pbCommandMenuEx(index, texts, mode = 0)
        pbShowWindow(COMMANDBOX)
        cw = @sprites["commandwindow"]
        cw.setTexts(texts)
        cw.index = @lastcmd[index]
        cw.index = 0 if @lastcmd[index] == 9
        cw.mode = mode
      end

      # The menu's W: the list of Balls, and the button past the last after a throw.
      def press_ball(index)
        cw = @sprites["commandwindow"]
        if pbUseBallInBattle(@battle, 1)
          cw.index = 5
          @lastcmd[index] = 0
        end
      end

      def pbFightMenu(index)
        pbShowWindow(FIGHTBOX)
        cw = @sprites["fightwindow"]
        battler = @battle.battlers[index]
        cw.battler = battler
        if battler.moves[@lastmove[index]].id != 0
          cw.setIndex(@lastmove[index])
        else
          cw.setIndex(0)
        end
        cw.megaButton = 0
        cw.ultraButton = 0
        cw.teraButton = 0
        cw.zButton = 0
        cw.dynaButton = 0
      end

      def pbShowBattleInfo(scene)
        sceneInfo = BattleInfoScene.new(scene)
        sceneInfo.main
      end

      def tkShowFloatingText(_pkmn, _text = "", _doublebattle = false, _color = nil, _outline = nil, _duration = 1); end

      def pbHPChanged(pkmn, oldhp, _anim = false); [pkmn, oldhp]; end
      def pbUpdateSelected(_index); end
      def pbChooseTarget(index, _targettype, _move = 0); index; end
      def pbDisplayMessage(_msg, _brief = false); end
      def pbDisplayPausedMessage(_msg); end
      def pbShowCommands(_msg, _commands, _default); 0; end
      def pbLevelUp(*_a); end
      def pbSelectBattler(_index, _mode = 1); end
    end

    # 0103: the grid or a sheet, shown for a frame each by the test's steps; the ability and item rows go by the Pokemon it
    # displays.
    class BattleInfoScene
      def initialize(battle)
        @battle = battle
        @player_battlers = [battle.battlers[0]]
        @all_battlers = battle.battlers.compact
        @position = $info_position || 0
        @show_details = $info_details ? true : false
      end

      def main
        PokeAccess::Frame.run_pollers
        :closed
      end

      def get_critical_stage(_battler); 0; end
      def get_all_battle_effects; []; end

      def get_display_pokemon(battler)
        if battler.effects[PBEffects::Illusion]
          illusion_battler = battler.effects[PBEffects::Illusion]
          return illusion_battler.pokemon if illusion_battler.respond_to?(:pokemon) && illusion_battler.pokemon
          return illusion_battler if illusion_battler.is_a?(BattlePokemon)
        end
        return battler.pokemon if battler.respond_to?(:pokemon)
        battler
      end
    end

    # 0101_PokeBattle_SceneDatabox: the icons it draws through pbDrawImagePositions, none under the boss's switch.
    class PokemonDataBox
      def refresh
        imagepos = []
        unless $game_switches[NO_CAPTURES_SWITCH]
          imagepos.push(["Graphics/Pictures/Battle/battleMegaEvoBox", 4, 6, 0, 0, -1, -1]) if @battler.mega
          if @battler.owned && (@battler.index & 1) == 1
            imagepos.push(["Graphics/Pictures/Battle/battleBoxOwned", 204, 14, 0, 0, -1, -1])
          end
        end
        pbDrawImagePositions(nil, imagepos)
      end
    end

    # 0246_Ball Selector: what its input does to the list, and its two functions, the list's steps the test's.
    class BallSelectorInterface
      attr_reader :index

      def initialize
        @index = 0
        @ball_list = $ball_list.map { |row| row[0] }
        @ball_counts = $ball_list.map { |row| row[1] }
        update_display
      end

      def update_display
        pbDrawTextPositions(:bitmap, [[@ball_counts[@index].to_s, 0, 0, 2, nil, nil]])
      end

      def press(step)
        @index += step
        @index = @ball_list.length - 1 if @index < 0
        @index = 0 if @index >= @ball_list.length
        update_display
      end
    end

    def pbBallSelector
      list = BallSelectorInterface.new
      $ball_steps.call(list)
    end

    def pbUseBallInBattle(_battle, _battler_index)
      selected_ball = pbBallSelector
      return true if selected_ball && selected_ball != nil
      false
    end

    # 0245_EliteBattle_NewBattleBag: drawPocket as it is, up to its sprites; the input's changes are the test's.
    class NewBattleBag
      PocketText = ["Medicinas", "Pokéballs", "Bayas", "Objeto Batalla"]

      attr_reader :index, :ret, :finished
      attr_accessor :sprites

      Rect = Struct.new(:x)
      Sel = Struct.new(:src_rect)

      def initialize(_scene = nil, _viewport = nil)
        @lastUsed = $bag_last || 0
        @index = 0
        @item = 0
        @selPocket = 0
        @ret = nil
        @sprites = { "sel" => Sel.new(Rect.new(864)) }
      end

      def show; @ret = nil; end

      def drawPocket(pocket, index)
        @pocket = []
        ($bag_items[index] || []).each { |row| @pocket.push(row) }
        return if @pocket.length < 1
        @pages = @pocket.length / 6
        @pages += 1 if @pocket.length % 6 > 0
        @page = 0
        @item = 0
        @back = false
        @selPocket = pocket
        @pname = pbPocketNames[pocket]
      end

      def update; end

      def useItem?
        $confirm_steps.each do |box|
          @sprites["sel"].src_rect.x = box * 466
          PokeAccess::Frame.run_pollers
        end
        @ret = nil
        false
      end

      def at(values)
        values.each { |name, value| instance_variable_set(name, value) }
        update
      end
    end

    def pbPocketNames; ["", "Objetos", "Botiquín", "Poké Balls", "MTs", "Bayas", "Mejoras", "Tesoros"]; end

    # 0107_ExpMenu: the panels as it paints them, in its initialize.
    class PartyExpScreen
      def initialize(party, exp_data)
        @filtered_party = party
        @filtered_exp_data = exp_data
        for i in 0...party.length
          next if !party[i] || party[i].isEgg?
          draw_pokemon_info(:bitmap, party[i], i)
        end
      end

      def draw_pokemon_info(bitmap, pkmn, index)
        textpos = []
        textpos.push([pkmn.name, 72, 12, 0, nil, nil])
        pbDrawTextPositions(bitmap, textpos)
        textpos = []
        textpos.push([sprintf("Nv.%d", pkmn.level), 72, 40, 0, nil, nil])
        if @filtered_exp_data[index] && @filtered_exp_data[index] > 0
          textpos.push([sprintf("+%d", @filtered_exp_data[index]), 140, 40, 0, nil, nil])
        end
        pbDrawTextPositions(bitmap, textpos)
      end
    end

    ExpMember = Struct.new(:name, :level, :egg) do
      def isEgg?; egg; end
    end
  RUBY

  PLAY = <<-'RUBY'
    MOVES = [BattleMove.new(10, "Placaje", 1, 0, 40, 35, 35), BattleMove.new(11, "Gruñido", 1, 2, 0, 40, 40),
             BattleMove.new(0, "", 0, 0, 0, 0, 0), BattleMove.new(0, "", 0, 0, 0, 0, 0)]

    def single(opts = {})
      own = PokeBattle_Battler.new(0, "Pikachu", :moves => MOVES)
      foe = PokeBattle_Battler.new(1, "Zigzagoon")
      PokeBattle_Battle.new([own, foe, nil, nil], opts)
    end

    def double(opts = {})
      a = PokeBattle_Battler.new(0, "Pikachu", :moves => MOVES)
      b = PokeBattle_Battler.new(1, "Zigzagoon")
      c = PokeBattle_Battler.new(2, "Eevee", :moves => MOVES)
      d = PokeBattle_Battler.new(3, "Wurmple")
      PokeBattle_Battle.new([a, b, c, d], { :double => true }.merge(opts))
    end

    def at(level)
      was = PokeAccess::Config.verbosity
      PokeAccess::Config.verbosity = level
      yield
    ensure
      PokeAccess::Config.verbosity = was
    end

    def with_switch(id, value = true)
      was = $game_switches[id]
      $game_switches[id] = value
      yield
    ensure
      $game_switches[id] = was
    end

    def with_balls(value = true)
      $has_balls = value
      yield
    ensure
      $has_balls = nil
    end

    def lines(log); log.map { |line| line[0] }; end

    def command_play
      probe(:menu_open) { at(:brief) { said { single.scene.pbCommandMenu(0) } } }
      probe(:menu_moves) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenu(0)
          said { scene.sprites["commandwindow"].index = 1; scene.sprites["commandwindow"].index = 3 }
        end
      end
      probe(:menu_battle) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenu(0)
          lines(said { [0, 1, 2, 3].each { |i| scene.sprites["commandwindow"].index = i } })
        end
      end
      probe(:menu_safari) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenuEx(0, ["", "Ball", "Cebo", "Piedra", "Huir"], 2)
          lines(said { [0, 1, 2, 3].each { |i| scene.sprites["commandwindow"].index = i } })
        end
      end
      probe(:menu_contest) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenuEx(0, ["", "Luchar", "Ball", "Pokémon", "Huir"], 3)
          lines(said { [0, 1, 2, 3].each { |i| scene.sprites["commandwindow"].index = i } })
        end
      end
      probe(:menu_shadow) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenuEx(0, ["", "Luchar", "Mochila", "Pokémon", "Llamar"], 1)
          lines(said { [0, 1, 2, 3].each { |i| scene.sprites["commandwindow"].index = i } })
        end
      end
      probe(:menu_mode_changes) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenuEx(0, ["", "Ball", "Cebo", "Piedra", "Huir"], 2)
          scene.lastcmd = [2, 0, 0, 0]
          [lines(said { scene.pbCommandMenu(0) }), lines(said { scene.pbCommandMenuEx(0, ["", "Ball", "Cebo", "Piedra", "Huir"], 2) })]
        end
      end
      probe(:menu_chooser) { at(:brief) { said { double.scene.pbCommandMenu(2) } } }
      probe(:menu_single_names_nobody) { at(:full) { lines(said { single.scene.pbCommandMenu(0) }).include?("Pikachu") } }
      probe(:menu_hint_wild) do
        with_balls do
          scene = single.scene
          [said { scene.pbCommandMenu(0) }, said { scene.pbCommandMenu(0) }]
        end
      end
      probe(:menu_hint_trainer) { with_balls { said { single(:opponent => :a_trainer).scene.pbCommandMenu(0) } } }
      probe(:menu_hint_no_balls) { with_balls(false) { lines(said { single.scene.pbCommandMenu(0) }) } }
      probe(:menu_hint_boss) do
        with_balls { with_switch(NO_CAPTURES_SWITCH) { lines(said { single.scene.pbCommandMenu(0) }) } }
      end
      probe(:menu_hint_double) { with_balls { lines(said { double.scene.pbCommandMenu(0) }) } }
      probe(:menu_hint_safari) do
        $in_safari = true
        begin
          with_balls { lines(said { single.scene.pbCommandMenuEx(0, ["", "Ball", "Cebo", "Piedra", "Huir"], 2) }) }
        ensure
          $in_safari = nil
        end
      end
      probe(:menu_hint_brief) { with_balls { at(:brief) { lines(said { single.scene.pbCommandMenu(0) }) } } }
      probe(:menu_hint_moved_cursor) do
        scene = single.scene
        at(:brief) { scene.pbCommandMenu(0) }
        lines(said { scene.sprites["commandwindow"].index = 1 })
      end
      probe(:menu_hint_rebound) do
        PokeAccess::Config.rebinds[:l] = 0x4B
        PokeAccess::Config.rebinds[:r] = 0x4A
        begin
          with_balls { lines(said { single.scene.pbCommandMenu(0) }) }
        ensure
          PokeAccess::Config.rebinds.delete(:l)
          PokeAccess::Config.rebinds.delete(:r)
        end
      end
    end

    def fight_play
      probe(:fight_levels) do
        [:brief, :medium, :full].map do |level|
          scene = single.scene
          at(level) { lines(said { scene.pbFightMenu(0) })[0] }
        end
      end
      probe(:fight_low_power) do
        scene = single.scene
        scene.lastmove = [1, 0, 0, 0]
        at(:full) { lines(said { scene.pbFightMenu(0) })[0] }
      end
      probe(:fight_power_edge) do
        mine = [BattleMove.new(10, "Golpe", 1, 0, 10, 5, 5), BattleMove.new(11, "Roce", 1, 0, 9, 5, 5)] + MOVES[2, 2]
        battle = PokeBattle_Battle.new([PokeBattle_Battler.new(0, "Pikachu", :moves => mine), nil, nil, nil])
        scene = battle.scene
        at(:full) do
          ten = lines(said { scene.pbFightMenu(0) })[0]
          scene.lastmove = [1, 0, 0, 0]
          [ten, lines(said { scene.pbFightMenu(0) })[0]]
        end
      end
      probe(:fight_hint) do
        scene = single.scene
        [said { scene.pbFightMenu(0) }, said { scene.pbFightMenu(0) }]
      end
      probe(:fight_hint_brief) { at(:brief) { lines(said { single.scene.pbFightMenu(0) }) } }
      probe(:fight_hint_rebound) do
        PokeAccess::Config.rebinds[:l] = 0x4B
        begin
          lines(said { single.scene.pbFightMenu(0) })[1]
        ensure
          PokeAccess::Config.rebinds.delete(:l)
        end
      end
    end

    def closing_play
      probe(:move_info_closes) do
        battle = single
        scene = battle.scene
        at(:brief) do
          scene.pbFightMenu(0)
          fight = scene.sprites["fightwindow"]
          log = said { fight.show_move_info(10, battle) }
          [log, PokeAccess::Info.info_text]
        end
      end
      probe(:info_over_commands) do
        battle = single
        scene = battle.scene
        $info_details = true
        at(:brief) do
          PokeAccess::Battle.set_battle(battle)
          scene.lastcmd = [1, 0, 0, 0]
          scene.pbCommandMenu(0)
          log = said { scene.pbShowBattleInfo(battle) }
          info = PokeAccess::Info.info_text
          PokeAccess::Battle.set_battle(nil)
          $info_details = nil
          [log, info]
        end
      end
      probe(:info_over_moves) do
        battle = single
        scene = battle.scene
        at(:brief) do
          scene.pbFightMenu(0)
          said { scene.pbShowBattleInfo(battle) }
        end
      end
    end

    def sheet_of(foe)
      own = PokeBattle_Battler.new(0, "Pikachu", :moves => MOVES)
      battle = PokeBattle_Battle.new([own, foe, nil, nil])
      $info_position = 1
      $info_details = true
      at(:full) { lines(said { BattleInfoScene.new(battle).main })[0] }
    ensure
      $info_position = nil
      $info_details = nil
    end

    def sheet_play
      probe(:sheet_illusion) do
        disguise = PokeBattle_Battler.new(1, "Zoroark", :ability => 8, :item => 9, :own_ability => 8, :own_item => 9)
        sheet_of(PokeBattle_Battler.new(1, "Eevee", :ability => 5, :item => 6, :illusion => disguise))
      end
      probe(:sheet_illusion_pokemon) do
        disguise = BattlePokemon.new("Zoroark", 0, 8, 9, 1, 1)
        sheet_of(PokeBattle_Battler.new(1, "Eevee", :ability => 5, :item => 6, :illusion => disguise))
      end
      probe(:sheet_swapped_ability) do
        sheet_of(PokeBattle_Battler.new(1, "Eevee", :ability => 5, :own_ability => 7, :item => 6, :own_item => 4))
      end
      probe(:sheet_empty_hand) { sheet_of(PokeBattle_Battler.new(1, "Eevee", :item => 0, :own_item => 4)) }
    end

    def box_play
      probe(:box_boss) do
        boss = PokeBattle_Battler.new(1, "Eevee", :gender => 1, :level => 40)
        mine = PokeBattle_Battler.new(0, "Pikachu", :gender => 1, :level => 12)
        second = PokeBattle_Battler.new(3, "Wurmple", :gender => 1, :level => 9)
        with_switch(NO_CAPTURES_SWITCH) do
          [PokeAccess::Battle.shown_level(boss), PokeAccess::Battle.shown_sex(boss),
           PokeAccess::Battle.shown_level(mine), PokeAccess::Battle.shown_sex(mine),
           PokeAccess::Battle.shown_level(second), PokeAccess::Battle.shown_sex(second)]
        end
      end
      probe(:box_no_boss) do
        foe = PokeBattle_Battler.new(1, "Eevee", :gender => 1, :level => 9)
        [PokeAccess::Battle.shown_level(foe), PokeAccess::Battle.shown_sex(foe)]
      end
      probe(:box_boss_lines) do
        boss = PokeBattle_Battler.new(1, "Eevee", :gender => 1, :level => 40)
        battle = PokeBattle_Battle.new([PokeBattle_Battler.new(0, "Pikachu"), boss, nil, nil])
        PokeAccess::Battle.set_battle(battle)
        with_switch(NO_CAPTURES_SWITCH) do
          begin
            at(:full) do
              PokemonDataBox.new(boss).refresh
              [PokeAccess::Battle.foe_info, PokeAccess::Battle.battler_state(boss, true)]
            end
          ensure
            PokeAccess::Battle.set_battle(nil)
          end
        end
      end
      probe(:box_marks) do
        out = {}
        { :shiny => { :shiny => true }, :shadow => { :shadow => true }, :plain => {},
          :owned => { :owned => true }, :mega => { :mega => true } }.each do |name, opts|
          foe = PokeBattle_Battler.new(1, "Eevee", opts)
          line = at(:full) { said { PokemonDataBox.new(foe).refresh } }
          out[name] = [lines(line), PokeAccess::Battle.shown_marks(foe)]
        end
        out
      end
      probe(:box_unreadable) { PokeAccess::VitroBattleBox.with_painted(PokemonDataBox.new(Object.new), [:an_icon]) }
      probe(:box_boss_marks) do
        boss = PokeBattle_Battler.new(1, "Eevee", :owned => true, :mega => true)
        other = PokeBattle_Battler.new(3, "Wurmple", :owned => true)
        mine = PokeBattle_Battler.new(0, "Pikachu", :shiny => true)
        with_switch(NO_CAPTURES_SWITCH) do
          line = at(:full) { said { [boss, other, mine].each { |b| PokemonDataBox.new(b).refresh } } }
          [lines(line), PokeAccess::Battle.shown_marks(boss), PokeAccess::Battle.shown_marks(other),
           PokeAccess::Battle.shown_marks(mine)]
        end
      end
    end

    def float_play
      probe(:hp_foe) do
        foe = PokeBattle_Battler.new(1, "Zigzagoon", :hp => 40)
        said { single.scene.pbHPChanged(foe, 50) }
      end
      probe(:hp_foe_heals) do
        foe = PokeBattle_Battler.new(1, "Zigzagoon", :hp => 63)
        said { single.scene.pbHPChanged(foe, 50) }
      end
      probe(:hp_own) do
        own = PokeBattle_Battler.new(0, "Pikachu", :hp => 40)
        said { single.scene.pbHPChanged(own, 50) }
      end
      probe(:float_single) do
        foe = PokeBattle_Battler.new(1, "Zigzagoon")
        said { single.scene.tkShowFloatingText(foe, "Inmune...", false, :a_colour) }
      end
      probe(:float_double) do
        foe = PokeBattle_Battler.new(3, "Wurmple")
        said { double.scene.tkShowFloatingText(foe, "Inmune...", true, :a_colour) }
      end
      probe(:float_blank) do
        foe = PokeBattle_Battler.new(3, "Wurmple")
        scene = double.scene
        [said { scene.tkShowFloatingText(foe, "", true) }, said { scene.tkShowFloatingText(foe, nil, true) }]
      end
      probe(:float_repeat_key) do
        foe = PokeBattle_Battler.new(1, "Zigzagoon")
        single.scene.tkShowFloatingText(foe, "Inmune otra vez...", false)
        PokeAccess.last_dialogue
      end
    end

    def ball_play
      $ball_list = [[1, 5], [25, 2], [50, 1]]
      probe(:balls_open) do
        $ball_steps = lambda { |_list| nil }
        at(:brief) { said { pbBallSelector } }
      end
      probe(:balls_move) do
        $ball_steps = lambda do |list|
          $ball_log = at(:brief) { [said { list.press(1) }, said { list.press(1) }, said { list.press(1) }, said { list.press(-1) }] }
          nil
        end
        at(:brief) { pbBallSelector }
        $ball_log
      end
      probe(:balls_positions) do
        $ball_steps = lambda do |list|
          $ball_log = at(:medium) { lines(said { list.press(1) }) }
          nil
        end
        at(:medium) { pbBallSelector }
        $ball_log
      end
      probe(:balls_full) do
        $ball_steps = lambda do |list|
          $ball_log = at(:full) { lines(said { list.press(1) }) }
          nil
        end
        at(:full) { pbBallSelector }
        $ball_log
      end
      probe(:balls_info) do
        $ball_steps = lambda do |list|
          at(:brief) { list.press(1) }
          $ball_log = PokeAccess::Info.info_text
          nil
        end
        at(:brief) { pbBallSelector }
        $ball_log
      end
      probe(:balls_cancel) do
        scene = single.scene
        scene.lastcmd = [1, 0, 0, 0]
        $ball_steps = lambda { |_list| nil }
        at(:brief) do
          scene.pbCommandMenu(0)
          said { scene.press_ball(0) }
        end
      end
      probe(:balls_throw) do
        scene = single.scene
        $ball_steps = lambda { |_list| 25 }
        at(:brief) do
          scene.pbCommandMenu(0)
          lines(said { scene.press_ball(0) })
        end
      end
    end

    def bag_play
      $bag_items = { 0 => [[1, 3]], 1 => (1..7).map { |n| [n + 100, n] } }
      $PokemonBag = Struct.new(:left) { def pbQuantity(_item); left; end }.new(3)
      $confirm_steps = [2, 3, 2]
      probe(:bag_main) do
        bag = NewBattleBag.new
        bag.show
        moves = [said { bag.update }, said { bag.update }]
        moves.push(said { bag.at(:@index => 3) })
        moves.push(said { bag.at(:@index => 5) })
        moves
      end
      probe(:bag_main_info) do
        bag = NewBattleBag.new
        bag.at(:@index => 2)
        PokeAccess::Info.info_text
      end
      probe(:bag_last) do
        $bag_last = 25
        begin
          bag = NewBattleBag.new
          [said { bag.at(:@index => 4) }, PokeAccess::Info.info_text]
        ensure
          $bag_last = nil
        end
      end
      probe(:bag_last_gone) do
        [[25, 0], [0, 3]].map do |last, left|
          $bag_last = last
          $PokemonBag.left = left
          begin
            bag = NewBattleBag.new
            [said { bag.at(:@index => 4) }, PokeAccess::Info.info_text]
          ensure
            $bag_last = nil
            $PokemonBag.left = 3
          end
        end
      end
      probe(:bag_reopens) do
        bag = NewBattleBag.new
        bag.update
        bag.show
        said { bag.update }
      end
      probe(:bag_pocket) do
        bag = NewBattleBag.new
        bag.drawPocket(3, 1)
        first = said { bag.update }
        info = PokeAccess::Info.info_text
        second = said { bag.at(:@item => 2) }
        page = said { bag.at(:@item => 6) }
        back = said { bag.at(:@back => true) }
        back_info = PokeAccess::Info.info_text
        again = said { bag.at(:@back => false) }
        [first, info, second, page, back, again, back_info]
      end
      probe(:bag_pocket_out) do
        bag = NewBattleBag.new
        bag.update
        bag.drawPocket(3, 1)
        bag.update
        [said { bag.at(:@selPocket => 0) }, begin
          bag.drawPocket(3, 1)
          said { bag.update }
        end]
      end
      probe(:bag_empty) do
        bag = NewBattleBag.new
        bag.update
        log = said { bag.drawPocket(5, 2) }
        [log, said { bag.update }]
      end
      probe(:bag_full_pocket_says_nothing_of_it) do
        bag = NewBattleBag.new
        said { bag.drawPocket(2, 0) }
      end
      probe(:bag_chosen_silent) do
        bag = NewBattleBag.new
        bag.drawPocket(3, 1)
        bag.update
        said { bag.at(:@ret => 101, :@selPocket => 0) }
      end
      probe(:bag_confirm) do
        bag = NewBattleBag.new
        bag.drawPocket(3, 1)
        bag.update
        bag.at(:@ret => 101, :@selPocket => 0)
        answer = nil
        log = said { answer = bag.useItem? }
        after = said { PokeAccess::Frame.run_pollers; bag.update }
        [log, answer, after]
      end
      probe(:bag_no_confirm_no_poll) do
        bag = NewBattleBag.new
        bag.drawPocket(3, 1)
        bag.at(:@ret => 101)
        bag.sprites["sel"].src_rect.x = 2 * 466
        said { PokeAccess::Frame.run_pollers }
      end
    end

    def exp_play
      probe(:exp_gains) do
        party = [ExpMember.new("Pikachu", 13, false), ExpMember.new("Eevee", 9, false), ExpMember.new("Huevo", 1, true),
                 ExpMember.new("Pidgey", 7, false)]
        said { PartyExpScreen.new(party, { 0 => 120, 1 => 0, "before_0" => 90, 3 => 1 }) }
      end
      probe(:exp_none) do
        said { PartyExpScreen.new([ExpMember.new("Eevee", 9, false)], { "before_0" => 90 }) }
      end
    end

    command_play
    fight_play
    closing_play
    sheet_play
    box_play
    float_play
    ball_play
    bag_play
    exp_play
  RUBY

  profile "vitro", WORLD, PLAY

  BATTLE_HOOKS = /\A(?:PokeBattle_|CommandMenuDisplay|FightMenuDisplay|PokemonDataBox|BallSelector|NewBattleBag|PartyExp|BesBattle)/

  test "loads whole, and every battle hook binds on the game's own methods" do
    assert_equal [], played(:load_errors)
    assert_equal [], played(:missing_hooks).grep(BATTLE_HOOKS)
    assert_equal [], played(:absent_functions) & %w[pbUseBallInBattle]
  end

  test "the menu opens on the label its button paints, queued, not on its hidden window's" do
    assert_equal [["Luchar", false]], played(:menu_open)
  end

  test "moving the cursor cuts in with the label the button paints" do
    assert_equal [["Bolsa", true], ["Huir", true]], played(:menu_moves)
  end

  test "the Safari Zone's and the bug contest's buttons paint their own labels" do
    assert_equal %w[Luchar Bolsa Pokémon Huir], played(:menu_battle)
    assert_equal %w[Luchar Bolsa Pokémon Llamar], played(:menu_shadow)
    assert_equal %w[Ball Cebo Roca Huir], played(:menu_safari)
    assert_equal %w[Luchar Ball Pokémon Huir], played(:menu_contest)
  end

  test "the labels go by the mode the menu is opening in, which it only sets after the cursor" do
    assert_equal [%w[Pokémon], %w[Roca]], played(:menu_mode_changes)
  end

  test "in a double battle the menu first says whose orders it asks for, and in a single one nobody" do
    assert_equal [["Eevee", false], ["Luchar", false]], played(:menu_chooser)
    assert_equal false, played(:menu_single_names_nobody)
  end

  test "the information's key and the Balls' go after the first option of a battle, once" do
    first, second = played(:menu_hint_wild)
    keys = "#{t(:vitro_bt_keys, :info => "Q")} #{t(:vitro_bt_ball, :key => "W")}"
    assert_equal [["Luchar", false], [keys, false]], first
    assert_equal [["Luchar", false]], second
  end

  test "the Balls' key is said only where the menu paints it" do
    alone = t(:vitro_bt_keys, :info => "Q")
    assert_equal [["Luchar", false], [alone, false]], played(:menu_hint_trainer)
    assert_equal ["Luchar", alone], played(:menu_hint_no_balls)
    assert_equal ["Luchar", alone], played(:menu_hint_boss)
    assert_equal ["Pikachu", "Luchar", alone], played(:menu_hint_double)
  end

  test "the Safari Zone paints no information key, and a short scheme leaves the keys out" do
    assert_equal ["Ball"], played(:menu_hint_safari)
    assert_equal ["Luchar"], played(:menu_hint_brief)
  end

  test "moving the cursor adds no keys" do
    assert_equal ["Bolsa"], played(:menu_hint_moved_cursor)
  end

  test "the keys are said as the player has them bound" do
    assert_equal ["Luchar", "#{t(:vitro_bt_keys, :info => "K")} #{t(:vitro_bt_ball, :key => "J")}"], played(:menu_hint_rebound)
  end

  test "the move line adds the power its button paints, from full, before the PP" do
    pp = t(:mv_pp, :pp => 35, :tot => 35)
    power = t(:mv_power, :p => 40)
    brief, medium, full = played(:fight_levels)
    assert_equal "Placaje. #{pp}", brief
    refute_includes medium, power
    assert_match(/\APlacaje\..*#{Regexp.escape(power)}\. #{Regexp.escape(pp)}\z/, full)
  end

  test "a power under 10 is not painted and not said, and 10 is" do
    refute_includes played(:fight_low_power), t(:mv_power, :p => 0)
    ten, nine = played(:fight_power_edge)
    assert_includes ten, t(:mv_power, :p => 10)
    refute_includes nine, t(:mv_power, :p => 9)
  end

  test "the move information's key goes after the first move of a battle, once" do
    first, second = played(:fight_hint)
    assert_equal [t(:vitro_fight_keys, :info => "Q"), false], first[1]
    assert_equal 2, first.length
    assert_equal 1, second.length
    assert_equal ["Placaje. #{t(:mv_pp, :pp => 35, :tot => 35)}"], played(:fight_hint_brief)
    assert_equal t(:vitro_fight_keys, :info => "K"), played(:fight_hint_rebound)
  end

  test "closing the move's information runs it unguarded and says the focused move again" do
    log, info = played(:move_info_closes)
    assert_equal 2, log.length
    assert_equal "Placaje", log[0][0][/\A[^.]+/]
    assert_equal ["Placaje. #{t(:mv_pp, :pp => 35, :tot => 35)}", false], log[1]
    assert_includes info, "Placaje"
  end

  test "closing the battle's information over the commands says the focused button again, and the T goes back to the foe" do
    log, info = played(:info_over_commands)
    assert_equal "Pikachu", log[0][0][/\APikachu/]
    assert_equal ["Bolsa", false], log[-1]
    assert_includes info, "Zigzagoon"
    refute_includes info, "Pikachu"
  end

  test "closing the battle's information over the moves says the focused move again" do
    log = played(:info_over_moves)
    assert_equal "Pikachu", log[0][0][/\APikachu/]
    assert_equal ["Placaje. #{t(:mv_pp, :pp => 35, :tot => 35)}", false], log[-1]
  end

  test "under an Illusion the sheet names the disguise's ability and item, as it paints them" do
    [:sheet_illusion, :sheet_illusion_pokemon].each do |probe|
      sheet = played(probe)
      assert_includes sheet, t(:dbk_ability, :a => "Habilidad8")
      assert_includes sheet, t(:dbk_item, :i => "Item9")
      refute_includes sheet, t(:dbk_ability, :a => "Habilidad5")
      refute_includes sheet, t(:dbk_item, :i => "Item6")
    end
  end

  test "with no Illusion it names the Pokemon's own ability and item, not what a move left on the battler" do
    sheet = played(:sheet_swapped_ability)
    assert_includes sheet, t(:dbk_ability, :a => "Habilidad7")
    assert_includes sheet, t(:dbk_item, :i => "Item4")
    refute_includes sheet, t(:dbk_ability, :a => "Habilidad5")
  end

  test "an empty hand is the battler's, whatever the Pokemon holds" do
    sheet = played(:sheet_empty_hand)
    assert_includes sheet, t(:dbk_item, :i => t(:sum_none))
    refute_includes sheet, t(:dbk_item, :i => "Item4")
  end

  test "the boss's box draws no level and no sex; the rest keep theirs" do
    sign = PokeAccess::Party.sign(1)
    assert_equal [nil, "", 12, " #{sign}", 9, " #{sign}"], played(:box_boss)
    assert_equal [9, " #{sign}"], played(:box_no_boss)
  end

  test "the lines about a boss leave its level out" do
    foe, state = played(:box_boss_lines)
    assert_match(/\A#{Regexp.escape(t(:bt_foe_nolevel, :name => "Eevee"))}/, foe)
    refute_match(/40/, foe)
    assert_includes state, t(:bt_state_nolevel, :name => "Eevee", :hp => t(:bt_hp_pct, :n => 50))
    refute_match(/40/, state)
  end

  test "a foe's marks with no file are said as it enters: the shiny's name, the Shadow row" do
    marks = played(:box_marks)
    shiny = [t(:pk_shiny)]
    shadow = [t(:perseida_mark_shadow)]
    assert_equal [[t(:bt_marks_entry, :name => "Eevee", :marks => shiny[0])], shiny], marks[:shiny]
    assert_equal [[t(:bt_marks_entry, :name => "Eevee", :marks => shadow[0])], shadow], marks[:shadow]
    assert_equal [[], []], marks[:plain]
    assert_equal [t(:dex_caught)], marks[:owned][1]
    assert_equal [t(:bt_mark_mega)], marks[:mega][1]
  end

  test "a battler the box cannot ask keeps the icons it drew, and the refresh goes on" do
    assert_equal [:an_icon], played(:box_unreadable)
  end

  test "under the boss's switch only battler 1 gets the boss's mark, and no box draws its icons" do
    said, boss, other, mine = played(:box_boss_marks)
    assert_equal [t(:ss2_adv_boss)], boss
    assert_equal [], other
    assert_equal [t(:pk_shiny)], mine
    assert_equal [t(:bt_marks_entry, :name => "Eevee", :marks => t(:ss2_adv_boss))], said
  end

  test "a foe's change is said in hit points, as the figure that floats over it, losing and gaining" do
    assert_equal [[t(:bt_hp_change, :name => "Zigzagoon", :verb => t(:bt_lose), :n => 10, :rest => t(:bt_hp_pct, :n => 40)), false]],
                 played(:hp_foe)
    assert_equal [[t(:bt_hp_change, :name => "Zigzagoon", :verb => t(:bt_gain), :n => 13, :rest => t(:bt_hp_pct, :n => 63)), false]],
                 played(:hp_foe_heals)
  end

  test "the player's own change stays in exact hit points" do
    assert_equal [[t(:bt_hp_change, :name => "Pikachu", :verb => t(:bt_lose), :n => 10, :rest => t(:bt_hp_exact, :hp => 40, :tot => 100)), false]],
                 played(:hp_own)
  end

  test "a floating text is said as painted, queued, with whom it floats over only in a double battle" do
    assert_equal [["Inmune...", false]], played(:float_single)
    assert_equal [[t(:bt_marks_entry, :name => "Wurmple", :marks => "Inmune..."), false]], played(:float_double)
    assert_equal [[], []], played(:float_blank)
    assert_equal "Inmune otra vez...", played(:float_repeat_key)
  end

  test "the list of Balls opens on the one in the centre, queued, with its count" do
    assert_equal [["Pocion, 5", false]], played(:balls_open)
  end

  test "the arrows cut in with each Ball, and the list goes round" do
    moves = played(:balls_move)
    assert_equal [[["Repel, 2", true]], [["Caramelo Raro, 1", true]], [["Pocion, 5", true]], [["Caramelo Raro, 1", true]]], moves
  end

  test "its place is said at the level positions are, and its description only in full" do
    assert_equal [t(:list_entry, :name => "Repel, 2", :n => 2, :tot => 3)], played(:balls_positions)
    full = played(:balls_full)
    assert_equal 1, full.length
    assert_includes full[0], "msg25"
    assert_includes full[0], "Repel, 2"
  end

  test "the info key holds the Ball in the centre" do
    assert_includes played(:balls_info), "Repel"
  end

  test "closing the list with no throw says the menu's focused button again; a throw leaves it" do
    log = played(:balls_cancel)
    assert_equal ["Pocion, 5", false], log[0]
    assert_equal ["Bolsa", false], log[1]
    assert_equal 2, log.length
    assert_equal ["Pocion, 5"], played(:balls_throw)
  end

  test "the bag's main screen says the labels it paints and back, each once" do
    first, again, medicine, back = played(:bag_main)
    assert_equal [["Medicinas", true]], first
    assert_equal [], again
    assert_equal [["Objeto Batalla", true]], medicine
    assert_equal [[t(:bb_back), true]], back
    assert_equal "Bayas", played(:bag_main_info)
  end

  test "the last-used button says its word and its item, and the info key holds it" do
    log, info = played(:bag_last)
    assert_equal [["#{t(:bb_last)}, Repel", true]], log
    assert_includes info, "Repel"
  end

  test "the last-used button says only its heading with no item left, as painted" do
    played(:bag_last_gone).each do |log, info|
      assert_equal [["Último objeto usado", true]], log
      assert_equal "Último objeto usado", info
    end
  end

  test "showing the bag again says its focused button again" do
    assert_equal [["Medicinas", true]], played(:bag_reopens)
  end

  test "inside a pocket: its name and page as the page changes, the item with its x, back, and the info key's item" do
    first, info, second, page, back, again, back_info = played(:bag_pocket)
    assert_equal t(:bb_back), back_info
    assert_equal [["Poké Balls, 1/2. Item101, x1", true]], first
    assert_includes info, "Item101"
    assert_equal [["Item103, x3", true]], second
    assert_equal [["Poké Balls, 2/2. Item107, x7", true]], page
    assert_equal [[t(:bb_back), true]], back
    assert_equal [["Item107, x7", true]], again
  end

  test "leaving a pocket says the button again, and coming back says the pocket's name again" do
    out, back_in = played(:bag_pocket_out)
    assert_equal [["Medicinas", true]], out
    assert_equal [["Poké Balls, 1/2. Item101, x1", true]], back_in
  end

  test "a button with nothing to list says so and stays where it is" do
    log, after = played(:bag_empty)
    assert_equal [[t(:vitro_bag_empty), true]], log
    assert_equal [], after
    assert_equal [], played(:bag_full_pocket_says_nothing_of_it)
  end

  test "a chosen item waits in silence for its confirmation" do
    assert_equal [], played(:bag_chosen_silent)
  end

  test "the confirmation says the description, then the choices it writes, the first queued; after it, the button" do
    log, answer, after = played(:bag_confirm)
    assert_equal [["msg101", true], ["USAR", false], ["NO USAR", true], ["USAR", true]], log
    assert_equal false, answer
    assert_equal [["Medicinas", true]], after
  end

  test "outside a confirmation the frame poll says nothing" do
    assert_equal [], played(:bag_no_confirm_no_poll)
  end

  test "the experience panel says each member that gains, as painted; not the others, nor an egg" do
    assert_equal [["Pikachu, Nv.13, +120", false], ["Pidgey, Nv.7, +1", false]], played(:exp_gains)
    assert_equal [], played(:exp_none)
  end
end
