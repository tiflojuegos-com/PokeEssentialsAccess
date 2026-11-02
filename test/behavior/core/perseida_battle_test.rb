# Perseida's battle, loaded with its whole profile over doubles with the shape of its scripts: the command and fight menus
# with their keys and power buttons, the battle box's marks, a boss's lives, the ability and sign strips, the turbo, the
# information screen, the raid's two screens and the tutorial panels. In a process of its own, since its overrides would
# reach every other test here.
class PerseidaBattleTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    NO_CAPTURES_SWITCH = 100
    VARAPOYO = 119
    TURNOSAPOYO = 5
    VARENTEI = 214
    VARSUICUNE = 215
    VARRAIKOU = 213

    # Its extra buttons (0185_PSystem_Controls).
    module Input
      F = 30
      B2 = 33
      M = 36
      ITEMKEYSNAMES = ["F5", "F4", "F3"]
    end

    module PBSpecies
      RAIKOU = 243
      ENTEI = 244
      SUICUNE = 245
    end

    def isConst?(val, mod, constant); val == mod.const_get(constant); end
    def hasBalls?; $has_balls; end

    # A menu's hidden command window, which only keeps the labels and the cursor.
    class MenuWindow
      attr_accessor :commands, :index, :visible
    end

    # 0267_NewBattle_UI: setTexts keeps labels 1 to 4 of the array, leaving out the title and the "Ball" past them.
    class CommandMenuDisplay
      def initialize; @window = MenuWindow.new; end
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

    # 0093_PokeBattle_Scene's battler= and setIndex, with the attributes of 0262_Signos_Poderes_UI.
    class FightMenuDisplay
      attr_reader :battler, :index
      attr_accessor :megaButton, :ultraButton, :zodiacButton, :cometryButton

      def initialize
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
    end

    BattlePokemon = Struct.new(:name, :species, :gender, :sign) do
      def pbGetBirthsignName; sign; end
      def isEgg?; false; end
    end
    BattleMove = Struct.new(:id, :name, :type, :category, :basedamage, :pp, :totalpp)

    # The battler as the box, the menus and the information read it (0084_PokeBattle_Battler).
    class PokeBattle_Battler
      attr_accessor :index, :name, :level, :hp, :totalhp, :status, :pokemon, :moves, :lives, :stages, :type1, :type2, :item,
                    :ability, :lastMoveUsed, :shiny, :magnific, :shadow, :rows

      def initialize(index, name, opts = {})
        @index = index
        @name = name
        @level = opts[:level] || 30
        @hp = opts[:hp] || 50
        @totalhp = opts[:totalhp] || 100
        @status = opts[:status] || 0
        @pokemon = BattlePokemon.new(name, opts[:species] || 25, opts[:gender] || 0, opts[:sign] || "El Bardo")
        @moves = opts[:moves] || [BattleMove.new(0, "", 0, 0, 0, 0, 0)] * 4
        @lives = opts[:lives] || 1
        @stages = opts[:stages] || [0, 0, 0, 0, 0, 0, 0, 0]
        @type1 = opts[:type1] || 1
        @type2 = opts[:type2] || @type1
        @item = opts[:item] || 0
        @ability = opts[:ability] || 7
        @lastMoveUsed = opts[:last] || -1
        @shiny = opts[:shiny]
        @magnific = opts[:magnific]
        @shadow = opts[:shadow]
        @rows = opts[:rows] || []
      end

      def displayGender; @pokemon.gender; end
      def isShiny?; @shiny; end
      def isMagnific?; @magnific; end
      def isShadow?; @shadow; end
      def pbThis(_lower = false); @name; end
    end

    class PokeBattle_Battle
      attr_accessor :battlers, :doublebattle, :opponent, :scene, :weather, :weatherduration, :turncount, :zodiac

      def initialize(battlers, opts = {})
        @battlers = battlers
        @doublebattle = opts[:double] ? true : false
        @opponent = opts[:opponent]
        @scene = PokeBattle_Scene.new(self)
        @weather = opts[:weather] || 0
        @weatherduration = opts[:duration] || 0
        @turncount = opts[:turn] || 0
        @zodiac = opts[:zodiac]
      end

      def pbCanUseZodiacPower?(_index); @zodiac; end
    end

    # 0268_NewBattle_WSED_Commands' menus and 0093_PokeBattle_Scene's choosers, up to the frame loops.
    class PokeBattle_Scene
      attr_accessor :lastcmd, :lastmove, :sprites

      def initialize(battle)
        @battle = battle
        @lastcmd = [0, 0, 0, 0]
        @lastmove = [0, 0, 0, 0]
        @sprites = { "commandwindow" => CommandMenuDisplay.new, "fightwindow" => FightMenuDisplay.new }
      end

      def pbCommandMenu(index)
        pbCommandMenuEx(index, ["", "Luchar", "Mochila", "Pokémon", "Huir", "Ball"])
      end

      def pbCommandMenuEx(index, texts, _mode = 0)
        cw = @sprites["commandwindow"]
        cw.setTexts(texts)
        cw.index = @lastcmd[index]
        cw.index = 0 if @lastcmd[index] == 9
      end

      def pbFightMenu(index)
        cw = @sprites["fightwindow"]
        battler = @battle.battlers[index]
        cw.battler = battler
        if battler.moves[@lastmove[index]].id != 0
          cw.setIndex(@lastmove[index])
        else
          cw.setIndex(0)
        end
        cw.cometryButton = 0
        cw.cometryButton = 1 if $game_variables[VARAPOYO] >= TURNOSAPOYO
        cw.zodiacButton = 0
        cw.zodiacButton = 1 if @battle.pbCanUseZodiacPower?(index) && $game_variables[VARAPOYO] < TURNOSAPOYO
        cw.megaButton = 0
        cw.ultraButton = 0
      end

      def pbChooseTarget(index, _targettype, _move = 0)
        cw = @sprites["fightwindow"]
        cw.battler = @battle.battlers[index]
        pbUpdateSelected(1)
        pbUpdateSelected(-1)
        1
      end

      def pbUpdateSelected(_index); end
      def pbDisplayMessage(_msg, _brief = false); end
      def pbDisplayPausedMessage(_msg); end
      def pbShowCommands(_msg, _commands, _default); 0; end
      def pbHPChanged(_pkmn, _oldhp, _anim = false); end
      def pbLevelUp(*_a); end
      def pbSelectBattler(_index, _mode = 1); end
      def pbBreakBar(_pkmn); end
    end

    # 0250_EliteBattle_AbilityMessages: at the top level, and it paints its two strings through pbDrawOutlineText.
    def showAbilityMessage(battler, _hide = true, sign = false)
      return if battler.pokemon.nil?
      if sign
        pbDrawOutlineText(nil, 38, -3, 242, 20, "Signo del Bardo", nil, nil, 0)
      else
        pbDrawOutlineText(nil, 38, -3, 242, 20, PBAbilities.getName(battler.ability).to_s, nil, nil, 0)
      end
      pbDrawOutlineText(nil, 0, 27, 252, 20, "de #{battler.pokemon.name}", nil, nil, 2)
    end

    # 0269_NewBattle_Besier: its loop runs the updates of the panel shown; here, the test's steps.
    def pbShowBattleInfo(battle)
      $info_steps.call(battle)
    end

    class BattleInfo_PokemonUI
      attr_accessor :selected

      def initialize(battle, indexes)
        @battle = battle
        @indexes = indexes
        @selected = 0
      end

      def update; -1; end
    end

    class BattleInfo_BattleUI
      attr_reader :selected

      def initialize(battle, battlers)
        @battle = battle
        @battlers = battlers
        @selected = -1
        self.selected = 0
      end

      def isMyPartner?(selected); selected < (@battle.doublebattle ? 2 : 1); end

      def selected=(value)
        @selected = value
        drawTexts
      end

      def getWeatherText; @battle.weather == 2 ? "Lluvia" : ""; end
      def drawFieldInfo(x, y, text, value, textpos, _maxValue, _bmp); textpos.push([text, x, y]); end

      def drawTexts
        textpos = []
        drawFieldInfo(261, 157, getWeatherText, @battle.weatherduration, textpos, 5, nil) if @battle.weather > 0
        @battlers[@selected].rows.each { |text, value, max| drawFieldInfo(261, 181, text, value, textpos, max, nil) }
      end

      def update; -1; end
    end

    # 0274_NewBattle_Raid_Screen: it paints all its text in initialize; show runs the test's cursor, a frame each.
    class RaidBattles
      def initialize(pokemon, rank = 1)
        @selected = 0
        @pokemon = pokemon
        @rank = rank
        textpos = [["Incursión de la Vena", 24, 24, 0, nil, nil]]
        text = ["Comenzar Incursión", "Reconfigurar Equipo", "Salir"]
        for i in 0...3
          textpos.push([text[i], 42, 102 + i * 64 - 6, false, nil, nil])
        end
        pbDrawTextPositions(:overlay, textpos)
        @rank = 5 if @rank > 5
        @rank = 1 if @rank < 1
      end

      def show
        $raid_cursor.each do |step|
          step == :pc ? pbPokeCenterPC : (@selected = step)
          PokeAccess::Frame.run_pollers
        end
      end
    end

    # 0275_NewBattle_Raid_Rewards: the same, with the prizes after the exit.
    class RaidRewards
      def initialize(pokemon, rank = 1)
        @pokemon = pokemon
        @rank = rank
        textpos = [["Incursión de la Vena", 24, 24, 0, nil, nil], ["Salir", 42, 96, false, nil, nil]]
        [["Caramelo", 2], ["Baya", 1]].each_with_index do |row, i|
          textpos.push([_INTL("{1}  x{2}", row[0], row[1]), 42, 144 + i * 28 - 6, false, nil, nil])
        end
        pbDrawTextPositions(:overlay, textpos)
      end

      def show; end
    end

    def pbPokeCenterPC; end

    # 0240_Tutoriales.
    def pbCartelesTutorial(_width, _interpad, _text, _y = 26, _height = 330); end
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

    def with_var(id, value)
      was = $game_variables[id]
      $game_variables[id] = value
      yield
    ensure
      $game_variables[id] = was
    end

    def with_switch(id, value = true)
      was = $game_switches[id]
      $game_switches[id] = value
      yield
    ensure
      $game_switches[id] = was
    end

    def with_balls(value)
      $has_balls = value
      yield
    ensure
      $has_balls = nil
    end

    def lines(log); log.map { |line| line[0] }; end

    def command_play
      PokeAccess::Battle.set_battle(nil)
      probe(:menu_brief) { at(:brief) { said { single.scene.pbCommandMenu(0) } } }
      probe(:menu_moves) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenu(0)
          said { scene.sprites["commandwindow"].index = 1; scene.sprites["commandwindow"].index = 3 }
        end
      end
      probe(:menu_no_button) do
        scene = single.scene
        scene.lastcmd = [4, 0, 0, 0]
        at(:brief) { said { scene.pbCommandMenu(0) } }
      end
      probe(:menu_after_throw) do
        scene = single.scene
        at(:brief) do
          scene.pbCommandMenu(0)
          said { scene.sprites["commandwindow"].index = 4 }
        end
      end
      probe(:menu_chooser) { at(:brief) { said { double.scene.pbCommandMenu(2) } } }
      probe(:menu_hint) do
        battle = single(:opponent => :a_trainer)
        PokeAccess::Battle.set_battle(battle)
        with_balls(true) { [said { battle.scene.pbCommandMenu(0) }, said { battle.scene.pbCommandMenu(0) }] }
      end
      probe(:menu_hint_ball) do
        battle = single
        PokeAccess::Battle.set_battle(battle)
        with_balls(true) { lines(said { battle.scene.pbCommandMenu(0) }) }
      end
      probe(:menu_hint_no_balls) do
        battle = single
        PokeAccess::Battle.set_battle(battle)
        with_balls(false) { lines(said { battle.scene.pbCommandMenu(0) }) }
      end
      probe(:menu_hint_safari) do
        battle = single
        PokeAccess::Battle.set_battle(battle)
        lines(said { battle.scene.pbCommandMenuEx(0, ["¿Qué hará Ash?", "Ball", "Cebo", "Piedra", "Huir"], 2) })
      end
      probe(:menu_hint_boss) do
        battle = single
        PokeAccess::Battle.set_battle(battle)
        with_balls(true) { with_switch(NO_CAPTURES_SWITCH) { lines(said { battle.scene.pbCommandMenu(0) }) } }
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
      probe(:rebound_key) do
        scene = single.scene
        PokeAccess::Config.rebinds[:x] = 0x51
        begin
          lines(said { scene.pbFightMenu(0) })[1]
        ensure
          PokeAccess::Config.rebinds.delete(:x)
        end
      end
      probe(:fight_hint_brief) { at(:brief) { lines(said { single.scene.pbFightMenu(0) }) } }
      probe(:fight_cometry) do
        scene = single.scene
        at(:brief) do
          with_var(VARAPOYO, TURNOSAPOYO) do
            opening = said { scene.pbFightMenu(0) }
            press = said { scene.sprites["fightwindow"].cometryButton = 2 }
            again = said { scene.pbFightMenu(0) }
            [opening, press, again]
          end
        end
      end
      probe(:fight_zodiac) do
        scene = single(:zodiac => true).scene
        at(:brief) do
          opening = said { scene.pbFightMenu(0) }
          press = said { scene.sprites["fightwindow"].zodiacButton = 2 }
          [opening, press]
        end
      end
      probe(:fight_power_key) do
        scene = single(:zodiac => true).scene
        lines(said { scene.pbFightMenu(0) })
      end
      probe(:fight_no_button) do
        scene = single.scene
        at(:brief) { lines(said { scene.pbFightMenu(0) }) }
      end
    end

    def target_play
      with_said = lambda do |*args|
        battle = double
        said { battle.scene.pbChooseTarget(*args) }
      end
      PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbUpdateSelected, :hook_container => true) do |scene, _r, args|
        $target_chooser = PokeAccess::Battle.target_chooser_index(scene) if args[0] == 1
      end
      probe(:target_two_args) { with_said.call(2, 1); $target_chooser }
      probe(:target_three_args) { with_said.call(0, 1, 3); $target_chooser }
    end

    def box_play
      probe(:box_boss) do
        boss = PokeBattle_Battler.new(1, "Eevee", :gender => 1)
        mine = PokeBattle_Battler.new(0, "Pikachu", :gender => 1, :level => 12)
        with_switch(NO_CAPTURES_SWITCH) do
          [PokeAccess::Battle.shown_level(boss), PokeAccess::Battle.shown_sex(boss),
           PokeAccess::Battle.shown_level(mine), PokeAccess::Battle.shown_sex(mine)]
        end
      end
      probe(:box_no_boss) do
        foe = PokeBattle_Battler.new(1, "Eevee", :gender => 1, :level => 9)
        [PokeAccess::Battle.shown_level(foe), PokeAccess::Battle.shown_sex(foe)]
      end
      probe(:box_beasts) do
        beast = PokeBattle_Battler.new(1, "Entei", :species => PBSpecies::ENTEI, :level => 40)
        hidden = PokeAccess::Battle.shown_level(beast)
        shown = with_var(VARENTEI, 5) { PokeAccess::Battle.shown_level(beast) }
        boss = with_switch(NO_CAPTURES_SWITCH) { PokeAccess::Battle.shown_level(beast) }
        [hidden, shown, boss]
      end
      probe(:box_marks) do
        out = {}
        { :shiny => { :shiny => true }, :magnific => { :magnific => true }, :both => { :shiny => true, :magnific => true },
          :shadow => { :shadow => true }, :plain => {} }.each do |name, opts|
          foe = PokeBattle_Battler.new(1, "Eevee", opts)
          line = said { PokemonDataBox.new(foe).refresh }
          out[name] = [lines(line), PokeAccess::Battle.shown_marks(foe)]
        end
        out
      end
      probe(:box_boss_mark) do
        boss = PokeBattle_Battler.new(1, "Eevee")
        other = PokeBattle_Battler.new(3, "Wurmple")
        mine = PokeBattle_Battler.new(0, "Pikachu")
        with_switch(NO_CAPTURES_SWITCH) do
          line = said { [boss, other, mine].each { |b| PokemonDataBox.new(b).refresh } }
          [lines(line), PokeAccess::Battle.shown_marks(boss), PokeAccess::Battle.shown_marks(mine)]
        end
      end
      probe(:box_sign) do
        foe = PokeBattle_Battler.new(1, "Eevee")
        box = PokemonDataBox.new(foe)
        box.extra = ["Battle/battleSignBox"]
        box.refresh
        PokeAccess::Battle.shown_marks(foe)
      end
      probe(:box_state) do
        at(:full) do
          foe = PokeBattle_Battler.new(1, "Eevee", :shiny => true, :status => 6, :level => 7)
          PokemonDataBox.new(foe).refresh
          PokeAccess::Battle.battler_state(foe, true)
        end
      end
      probe(:weathers) do
        [[9, 10, 11, 12].map { |id| PokeAccess::Battle.weather_name(id) },
         [8, 9, 10, 11].map { |id| PokeAccess::Battle.overworld_weather_name(id) }]
      end
    end

    def lives_play
      probe(:lives_shown) do
        boss = PokeBattle_Battler.new(1, "Eevee", :lives => 3)
        lone = PokeBattle_Battler.new(1, "Eevee", :lives => 1)
        [PokeAccess::Battle.shown_hp(boss, true), PokeAccess::Battle.shown_hp(lone, true)]
      end
      probe(:lives_lost) do
        scene = single.scene
        boss = PokeBattle_Battler.new(1, "Eevee", :lives => 2)
        last = PokeBattle_Battler.new(1, "Eevee", :lives => 1)
        [said { scene.pbBreakBar(boss) }, said { scene.pbBreakBar(last) }]
      end
    end

    def strip_play
      b = PokeBattle_Battler.new(0, "Pikachu", :ability => 7)
      scene = single.scene
      ability = PokeAccess::Data.ability_name(7)
      probe(:strip_ability_name) { ability }
      probe(:strip_ability) do
        said do
          showAbilityMessage(b)
          PokeAccess::BattleScene::STRIP_WAIT.times { PokeAccess::Frame.run_pollers }
        end
      end
      probe(:strip_before_line) do
        lines(said do
          showAbilityMessage(b)
          scene.pbDisplayMessage("¡Sube el ataque!")
        end)
      end
      probe(:strip_named_line) do
        lines(said do
          showAbilityMessage(b)
          scene.pbDisplayMessage("¡#{ability} de Pikachu lo protege!")
        end)
      end
      probe(:strip_sign) do
        lines(said do
          showAbilityMessage(b, true, true)
          scene.pbDisplayMessage("¡Pikachu canta!")
        end)
      end
    end

    def turbo_play
      rate = [40]
      was = Graphics.method(:frame_rate)
      Graphics.define_singleton_method(:frame_rate) { rate[0] }
      step = lambda do |value|
        rate[0] = value
        said { PokeAccess::Frame.run_pollers }
      end
      begin
        out = []
        PokeAccess::Battle.battle_started
        out.push(step.call(40), step.call(80), step.call(120), step.call(120), step.call(80), step.call(40))
        out.push(step.call(120))
        PokeAccess::Battle.battle_ended
        out.push(step.call(80))
        probe(:turbo) { out }
      ensure
        Graphics.define_singleton_method(:frame_rate, was)
        said { PokeAccess::Frame.run_pollers }
      end
    end

    def keys_play
      probe(:m_battle) do
        r = PokeAccess::Remap
        out = [r.remapped_button?(Input::M), PokeAccess::KeyHints.key(:clara_map, "M")]
        PokeAccess::Battle.battle_started
        out.push(r.remapped_button?(Input::M), PokeAccess::KeyHints.key(:clara_map, "M"))
        kept = PokeAccess::Config.rebinds
        PokeAccess::Config.rebinds = { :clara_map => 0x4B }
        out.push(r.remapped_button?(Input::M), PokeAccess::KeyHints.key(:clara_map, "M"))
        PokeAccess::Config.rebinds = kept
        PokeAccess::Battle.battle_ended
        out.push(r.remapped_button?(Input::M))
        out
      end
    end

    def info_battle
      foe = PokeBattle_Battler.new(1, "Zigzagoon", :gender => 1, :level => 9, :hp => 10, :totalhp => 40, :status => 1,
                                   :type1 => 4, :type2 => 5, :stages => [0, 0, -2, 0, 0, 0, 0, 0], :ability => 8, :item => 5,
                                   :rows => [["Maldito", true, 5]])
      own = PokeBattle_Battler.new(0, "Pikachu", :gender => 0, :level => 12, :hp => 20, :totalhp => 35, :moves => MOVES,
                                   :last => 10, :type1 => 3, :ability => 7, :item => 6,
                                   :rows => [["Púas", 2, -1], ["Reflejo", 1, 5], ["Canon", 2, 0], ["Anulación", 0, 5], ["", 1, 5]])
      battle = PokeBattle_Battle.new([own, foe, nil, nil], :weather => 2, :duration => 3, :turn => 2, :opponent => Struct.new(:name).new("Ana"))
      [battle, own, foe]
    end

    def info_play
      battle, own, foe = info_battle
      $Trainer = Struct.new(:name).new("Ash")
      grid = BattleInfo_PokemonUI.new(battle, [1, 0])
      sheet = BattleInfo_BattleUI.new(battle, [own, foe])
      probe(:info_opening) do
        log = nil
        $info_steps = lambda do |_b|
          log = said { grid.update; grid.update }
        end
        at(:brief) { pbShowBattleInfo(battle) }
        log
      end
      probe(:info_grid_move) do
        $info_steps = lambda do |_b|
          grid.update
          SpeakCapture.clear
          grid.selected = 1
          grid.update
          $info_log = [SpeakCapture.log.dup, PokeAccess::Info.info_text]
        end
        at(:brief) { pbShowBattleInfo(battle) }
        $info_log
      end
      probe(:info_grid_full) do
        fresh = BattleInfo_PokemonUI.new(battle, [1, 0])
        $info_steps = lambda { |_b| $info_log = lines(said { fresh.update }) }
        at(:full) { pbShowBattleInfo(battle) }
        $info_log
      end
      probe(:info_no_item) do
        lone = PokeBattle_Battler.new(0, "Pikachu", :moves => MOVES, :item => 0)
        page = BattleInfo_BattleUI.new(battle, [lone, foe])
        $info_steps = lambda { |_b| $info_log = lines(said { page.update })[0] }
        at(:full) { pbShowBattleInfo(battle) }
        $info_log
      end
      probe(:info_sheet_own) do
        at(:full) do
          sheet.selected = 0
          $info_steps = lambda do |_b|
            $info_log = said { sheet.update }
            $info_text = PokeAccess::Info.info_text
          end
          pbShowBattleInfo(battle)
          [$info_log, $info_text]
        end
      end
      probe(:info_sheet_brief) do
        at(:brief) do
          sheet.selected = 0
          $info_steps = lambda { |_b| $info_log = said { sheet.update } }
          pbShowBattleInfo(battle)
          lines($info_log)
        end
      end
      probe(:info_sheet_foe) do
        at(:full) do
          sheet.selected = 1
          $info_steps = lambda { |_b| $info_log = lines(said { sheet.update }) }
          pbShowBattleInfo(battle)
          $info_log
        end
      end
      probe(:info_stays) do
        at(:brief) do
          $info_steps = lambda do |_b|
            sheet.selected = 0
            sheet.update
            $info_log = lines(said { sheet.update; sheet.update })
          end
          pbShowBattleInfo(battle)
          $info_log
        end
      end
      probe(:info_back_command) do
        scene = battle.scene
        at(:brief) do
          scene.pbCommandMenu(0)
          scene.sprites["commandwindow"].index = 2
          scene.sprites["commandwindow"].visible = true
          scene.sprites["fightwindow"].visible = false
          $info_steps = lambda { |_b| }
          said { pbShowBattleInfo(battle) }
        end
      end
      probe(:info_back_fight) do
        scene = battle.scene
        at(:brief) do
          scene.pbFightMenu(0)
          scene.sprites["commandwindow"].visible = false
          scene.sprites["fightwindow"].visible = true
          $info_steps = lambda { |_b| }
          said { pbShowBattleInfo(battle) }
        end
      end
    end

    def raid_play
      pk = BattlePokemon.new("Eevee", 133, 0, "El Mago")
      probe(:raid_entry) do
        $raid_cursor = [0, 0, 1, 2]
        at(:full) { said { RaidBattles.new(pk, 7).show } }
      end
      probe(:raid_positions_off) do
        $raid_cursor = [1]
        at(:brief) { lines(said { RaidBattles.new(pk, 2).show }) }
      end
      probe(:raid_pc) do
        $raid_cursor = [1, :pc, 1]
        at(:brief) { lines(said { RaidBattles.new(pk, 1).show }) }
      end
      probe(:raid_rewards) { at(:full) { said { RaidRewards.new(pk, 3).show } } }
      probe(:raid_rewards_info) { PokeAccess::Info.info_text }
    end

    def tutorial_play
      probe(:tutorial) do
        log = said { pbCartelesTutorial(440, 4, "<ac>Un Pokémon puede entrar en <b>Sobrecarga de maná.</b>\n\nCúralo.</ac>") }
        [log, PokeAccess::Info.info_text]
      end
      probe(:tutorial_bound) do
        remap = PokeAccess::Remap
        hints = PokeAccess::KeyHints
        rebinds = remap.method(:no_rebinds?)
        key = hints.method(:key)
        remap.define_singleton_method(:no_rebinds?) { false }
        hints.define_singleton_method(:key) { |_button, _letter| "K" }
        log = said { pbCartelesTutorial(440, 4, "<ac>Para usarlo pulsa la tecla W.</ac>") }
        remap.define_singleton_method(:no_rebinds?, rebinds)
        hints.define_singleton_method(:key, key)
        [log, PokeAccess::Info.info_text]
      end
      probe(:info_illusion) do
        real = Struct.new(:name).new("Zoroark")
        disguise = Struct.new(:name).new("Pikachu")
        effects = PBEffects.const_defined?(:Illusion) ? PBEffects::Illusion : PBEffects.const_set(:Illusion, 900)
        fighter = Struct.new(:effects, :pokemon)
        [PokeAccess::PerseidaBattleInfo.shown_of(fighter.new({ effects => disguise }, real)).name,
         PokeAccess::PerseidaBattleInfo.shown_of(fighter.new({}, real)).name]
      end
    end

    PokeAccess::Battle.battle_started
    command_play
    fight_play
    PokeAccess::Battle.battle_ended
    target_play
    box_play
    lives_play
    strip_play
    turbo_play
    keys_play
    info_play
    raid_play
    tutorial_play
  RUBY

  profile "perseida", WORLD, PLAY

  BATTLE_HOOKS = /\A(?:PokeBattle_|CommandMenuDisplay|FightMenuDisplay|PokemonDataBox|BattleInfo_|Raid)/

  test "loads whole, and every battle hook binds on the game's own methods" do
    assert_equal [], played(:load_errors)
    assert_equal [], played(:missing_hooks).grep(BATTLE_HOOKS)
    absent = %w[showAbilityMessage pbDrawOutlineText pbShowBattleInfo pbPokeCenterPC pbCartelesTutorial]
    assert_equal [], played(:absent_functions) & absent
  end

  test "the menu opens on the labels it keeps, queued, and in a single battle names nobody" do
    assert_equal [["Luchar", false]], played(:menu_brief)
  end

  test "moving the cursor cuts in with the label" do
    assert_equal [["Mochila", true], ["Huir", true]], played(:menu_moves)
  end

  test "a menu opening past the last button says so, and the throw that leaves it there stays silent" do
    assert_equal [[t(:perseida_cmd_none), false]], played(:menu_no_button)
    assert_equal [], played(:menu_after_throw)
  end

  test "in a double battle the menu first says whose orders it asks for" do
    assert_equal [["Eevee", false], ["Luchar", false]], played(:menu_chooser)
  end

  test "the keys go after the first option of a battle, once" do
    first, second = played(:menu_hint)
    assert_equal [["Luchar", false], [t(:perseida_bt_keys, :list => "A Luchar, S Mochila, D Pokémon, F Huir", :info => "M"), false]],
                 first
    assert_equal [["Luchar", false]], second
  end

  test "the keys name the labels the menu holds, as the Safari Zone's" do
    assert_equal ["Ball", t(:perseida_bt_keys, :list => "A Ball, S Cebo, D Piedra, F Huir", :info => "M")],
                 played(:menu_hint_safari)
  end

  test "the ball list's key is said only in a single wild battle with Balls and captures" do
    base = t(:perseida_bt_keys, :list => "A Luchar, S Mochila, D Pokémon, F Huir", :info => "M")
    assert_equal ["Luchar", "#{base} #{t(:perseida_bt_ball, :key => "B")}"], played(:menu_hint_ball)
    assert_equal ["Luchar", base], played(:menu_hint_no_balls)
    assert_equal ["Luchar", base], played(:menu_hint_boss)
  end

  test "the move line adds the power its button paints, from full, before the PP" do
    pp = t(:mv_pp, :pp => 35, :tot => 35)
    brief, medium, full = played(:fight_levels)
    assert_equal "Placaje. #{pp}", brief
    assert_equal "Placaje. #{t(:mv_type, :t => "Tipo1")}. #{pp}", medium
    assert_match(/#{Regexp.escape(t(:mv_power, :p => 40))}\. #{Regexp.escape(pp)}\z/, full)
  end

  test "a power under 10 is not painted and not said" do
    refute_match(/#{Regexp.escape(t(:mv_power, :p => 0))}/, played(:fight_low_power))
    assert_includes played(:fight_low_power), "Gruñido"
  end

  test "the power's edge is the 10 its button starts painting at" do
    ten, nine = played(:fight_power_edge)
    assert_includes ten, t(:mv_power, :p => 10)
    refute_includes nine, t(:mv_power, :p => 9)
  end

  test "the fight menu's keys are said after the move, once, and only with hints" do
    first, second = played(:fight_hint)
    assert_equal [t(:perseida_fight_keys, :list => "A, S, D, F", :info => "M"), false], first[1]
    assert_equal 1, second.length
    assert_equal 1, played(:fight_hint_brief).length
  end

  test "a key moved with the mod's remap is named as it is now" do
    assert_equal t(:perseida_fight_keys, :list => "Q, S, D, F", :info => "M"), played(:rebound_key)
  end

  test "Cometry's button comes up queued after the move, goes on at once, and comes up again on the next opening" do
    opening, press, again = played(:fight_cometry)
    ready = [t(:bt_special_ready, :name => t(:perseida_cometry)), false]
    assert_equal ready, opening[1]
    assert_equal 2, opening.length
    assert_equal [[t(:bt_special_on, :name => t(:perseida_cometry)), true]], press
    assert_equal [ready], again.reject { |line| line[1] }
  end

  test "the star power's button goes the same way, and with hints names its key" do
    opening, press = played(:fight_zodiac)
    assert_equal [t(:bt_special_ready, :name => t(:perseida_star_power)), false], opening[1]
    assert_equal [[t(:bt_special_on, :name => t(:perseida_star_power)), true]], press
    assert_equal "#{t(:bt_special_ready, :name => t(:perseida_star_power))}. #{t(:perseida_power_key, :key => "Z")}",
                 played(:fight_power_key).last
  end

  test "with no power to use, the menu says only the move" do
    assert_equal 1, played(:fight_no_button).length
  end

  test "the target chooser is its first argument, with the third one or without it" do
    assert_equal [2, 0], [played(:target_two_args), played(:target_three_args)]
  end

  test "a boss's box leaves out its level and sex, the player's keeps them, and off a boss battle all do" do
    assert_equal [nil, "", 12, " ♀"], played(:box_boss)
    assert_equal [9, " ♀"], played(:box_no_boss)
  end

  test "a beast's level is unknown until its variable reaches 5, and a boss's stays unpainted" do
    assert_equal [t(:bt_level_unknown), 40, nil], played(:box_beasts)
  end

  test "the colour of the name and the Shadow strip count as marks, said as a foe enters" do
    marks = played(:box_marks)
    shiny = t(:bt_marks_entry, :name => "Eevee", :marks => t(:pk_shiny))
    assert_equal [[shiny], [t(:pk_shiny)]], marks[:shiny]
    assert_equal [[t(:bt_marks_entry, :name => "Eevee", :marks => t(:perseida_magnific))], [t(:perseida_magnific)]], marks[:magnific]
    assert_equal [[shiny], [t(:pk_shiny)]], marks[:both]
    assert_equal [[t(:bt_marks_entry, :name => "Eevee", :marks => t(:perseida_mark_shadow))], [t(:perseida_mark_shadow)]], marks[:shadow]
    assert_equal [[], []], marks[:plain]
  end

  test "the boss's own box is a mark, on battler 1 alone" do
    line, boss, mine = played(:box_boss_mark)
    assert_equal [t(:bt_marks_entry, :name => "Eevee", :marks => t(:ss2_adv_boss))], line
    assert_equal [[t(:ss2_adv_boss)], []], [boss, mine]
  end

  test "the sign icon reads as the star power at work" do
    assert_equal [t(:perseida_blessed)], played(:box_sign)
  end

  test "a battler's state says the overload and the shiny name" do
    state = played(:box_state)
    assert_includes state, t(:perseida_st_overload)
    assert_includes state, t(:pk_shiny)
  end

  test "its extra weathers have words, in battle and on the map" do
    battle, field = played(:weathers)
    assert_equal [t(:w_storm), t(:perseida_w_toxic), t(:w_fog), t(:w_snow)], battle
    assert_equal [t(:w_shadow_sky), t(:w_storm), t(:perseida_w_toxic), t(:w_fog)], field
  end

  test "a boss's spare lives go with its hit points, and the one it loses is said as its bar breaks" do
    boss, lone = played(:lives_shown)
    assert_equal "#{t(:bt_hp_pct, :n => 50)}, #{t(:blv_lives, :n => 2)}", boss
    assert_equal t(:bt_hp_pct, :n => 50), lone
    left, last = played(:lives_lost)
    assert_equal [[t(:blv_life_lost, :name => "Eevee", :rest => t(:blv_lives_left, :n => 1)), false]], left
    assert_equal [[t(:blv_life_lost, :name => "Eevee", :rest => t(:blv_lives_last)), false]], last
  end

  test "an ability strip with no line after it is said when its wait is over" do
    ability = played(:strip_ability_name)
    assert_equal [[t(:bt_ability, :name => "Pikachu", :ability => ability), false]], played(:strip_ability)
  end

  test "a strip goes ahead of the battle's line, unless that line names the ability and the Pokemon" do
    ability = played(:strip_ability_name)
    assert_equal [t(:bt_ability, :name => "Pikachu", :ability => ability), "¡Sube el ataque!"], played(:strip_before_line)
    assert_equal ["¡#{ability} de Pikachu lo protege!"], played(:strip_named_line)
  end

  test "a sign's strip says the sign it paints, not the ability" do
    assert_equal [t(:bt_ability, :name => "Pikachu", :ability => "Signo del Bardo"), "¡Pikachu canta!"], played(:strip_sign)
  end

  test "Alt's turbo is said both ways; the rates of the battle's start and end, and off a battle, say nothing" do
    assert_equal [[], [], [[t(:turbo_on), true]], [], [[t(:turbo_off), true]], [], [], []], played(:turbo)
  end

  test "M goes on Alt off a battle and stays the game's in one, unless the remap screen gives it a key; the hint says which" do
    assert_equal [true, "#{t(:key_alt)} M", false, "M", true, "K", true], played(:m_battle)
  end

  test "the information opens queued on the grid's battler, and says it once" do
    log = played(:info_opening)
    assert_equal 1, log.length
    assert_includes log[0][0], "Zigzagoon ♀, #{t(:bt_target_foe)}"
    assert_equal false, log[0][1]
  end

  test "the grid's battler has its place in the list" do
    assert_equal ["Zigzagoon ♀, #{t(:bt_target_foe)}, 1 de 2"], played(:info_grid_full)
  end

  test "an empty hand reads as none" do
    assert_includes played(:info_no_item), t(:dbk_item, :i => t(:sum_none))
  end

  test "moving in the grid cuts in with the next battler" do
    log, info = played(:info_grid_move)
    assert_equal 1, log.length
    assert_equal log[0][0], info
    assert_includes log[0][0], "Pikachu ♂, #{t(:bt_target_self)}"
    assert_equal true, log[0][1]
  end

  test "the player's own sheet says all it paints, in order, the row with no text left out" do
    log, info = played(:info_sheet_own)
    line = log[0][0]
    want = [t(:sum_whose, :name => "Pikachu ♂", :level => 12), t(:bt_hp_exact, :hp => 20, :tot => 35),
            t(:ss2_effects, :list => "Púas 2, Reflejo 1/5, Canon 2, Anulación"), t(:bt_type, :t => "Tipo3"), t(:dbk_ability, :a => "Habilidad7"),
            t(:dbk_item, :i => PokeAccess::Data.item_name(6)), t(:dbk_lastmove, :m => "Placaje"),
            t(:bt_weather, :w => "Lluvia 3/5"), "Ash", t(:dbk_turn, :n => 3)].join(". ")
    assert_equal want, line
    assert_equal false, log[0][1]
    assert_equal want, info
  end

  test "at brief the sheet keeps who it is, the HP and the effects" do
    assert_equal [[t(:sum_whose, :name => "Pikachu ♂", :level => 12), t(:bt_hp_exact, :hp => 20, :tot => 35),
                   t(:ss2_effects, :list => "Púas 2, Reflejo 1/5, Canon 2, Anulación")].join(". ")], played(:info_sheet_brief)
  end

  test "a foe's sheet says its bar, status, stages and types, with no ability or item, and whose it is" do
    line = played(:info_sheet_foe)[0]
    assert_includes line, t(:bt_hp_pct, :n => 25)
    assert_includes line, t(:st_sleep)
    assert_includes line, t(:bt_type, :t => "Tipo4 Tipo5")
    assert_includes line, "Maldito"
    assert_includes line, "Ana"
    refute_match(/#{Regexp.escape(t(:dbk_ability, :a => "Habilidad8"))}/, line)
    refute_match(/#{Regexp.escape(t(:dbk_item, :i => PokeAccess::Data.item_name(5)))}/, line)
  end

  test "the sheet says nothing again while its focus stays" do
    assert_equal [], played(:info_stays)
  end

  test "leaving the information says the option of the menu under it again" do
    assert_equal [["Pokémon", false]], played(:info_back_command)
    log = played(:info_back_fight)
    assert_equal 1, log.length
    assert_includes log[0][0], "Placaje"
    assert_equal false, log[0][1]
  end

  test "the raid's entry leads with its title, stars and sign, then its options by their place" do
    log = played(:raid_entry)
    head = ["Incursión de la Vena", t(:perseida_raid_rank, :n => 5), t(:perseida_sign, :name => "El Mago"),
            t(:list_entry, :name => "Comenzar Incursión", :n => 1, :tot => 3)].join(". ")
    assert_equal [[head, false], [t(:list_entry, :name => "Reconfigurar Equipo", :n => 2, :tot => 3), true],
                  [t(:list_entry, :name => "Salir", :n => 3, :tot => 3), true]], log
  end

  test "a rank of one star goes in the singular, and without positions the option is bare" do
    assert_includes played(:raid_pc)[0], t(:perseida_raid_rank, :n => 1)
    assert_includes played(:raid_positions_off)[0], "Reconfigurar Equipo"
  end

  test "back from the PC, the entry's cursor is said again" do
    log = played(:raid_pc)
    assert_equal 2, log.length
    assert_equal "Reconfigurar Equipo", log[1]
  end

  test "the rewards say the title, the Pokemon, the stars and sign, the prizes and the exit, and the info key keeps them" do
    want = ["Incursión de la Vena", "Eevee", t(:perseida_raid_rank, :n => 3), t(:perseida_sign, :name => "El Mago"),
            "Caramelo x2, Baya x1", "Salir"].join(". ")
    assert_equal [[want, false]], played(:raid_rewards)
    assert_equal want, played(:raid_rewards_info)
  end

  test "a tutorial panel says the key it names as it is bound" do
    log, info = played(:tutorial_bound)
    assert_equal [["Para usarlo pulsa la tecla K.", false]], log
    assert_equal "Para usarlo pulsa la tecla K.", info
  end

  test "a battler's sheet goes by the disguise it paints under Illusion" do
    assert_equal ["Pikachu", "Zoroark"], played(:info_illusion)
  end

  test "a tutorial panel is said whole with no tags, queued, and the info key keeps it" do
    log, info = played(:tutorial)
    want = "Un Pokémon puede entrar en Sobrecarga de maná. Cúralo."
    assert_equal [[want, false]], log
    assert_equal want, info
  end
end
