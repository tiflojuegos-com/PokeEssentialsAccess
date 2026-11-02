# Vitro's contests, its Berry Blender, its Pokegear with the radio and the skins, the Walker, the trades by code, the EV
# redistributor, the new game's selectors, the shop of Pokemon and the list of Pokedexes, loaded with the whole profile over doubles
# with the shape of its scripts. In a process of its own, since its overrides would reach every other test here.
class VitroScreensTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    $Trainer = Struct.new(:money).new(500)
    $game_variables = Hash.new(0)
    def pbGetTimeNow; Time.local(2026, 11, 2, 9, 30); end

    module PBMoves
      NAMES = { 30 => "Placaje", 33 => "Arañazo", 34 => "Finta" }
      def self.getName(id); NAMES[id] || ""; end
    end
    module PBItems
      CHERIBERRY = 201
      ORANBERRY = 202
      NAMES = { 201 => "Zreza", 202 => "Baya Aranja", 7 => "Restos" }
      def self.getName(id); NAMES[id] || "Item#{id}"; end
    end

    # One frame of a game's loop per action, the frame's speech kept apart: what the double's loop method runs.
    $steps = []
    def each_frame(actions)
      actions.each do |action|
        action.call if action
        PokeAccess::Frame.run_pollers
        $steps.push(SpeakCapture.log.dup)
        SpeakCapture.clear
      end
    end

    Height = Struct.new(:height)
    Bar = Struct.new(:y, :bitmap)
    Move = Struct.new(:id)
    Mon = Struct.new(:name, :ot, :moves)

    PBContestMoveData = Struct.new(:id) do
      def contestType; { 30 => "Tough", 33 => "Cool", 34 => "Smart" }[id]; end
      def hearts; { 30 => 3, 34 => 1 }[id]; end
      def jam; { 30 => 1 }[id]; end
    end
    def pbGetContestMoveDescription(id); "Efecto #{id}"; end

    # PokeContestScene as 0232_Contest_Core and 0233_Contest_Scene leave it: its messages block in a window of their own, and
    # pbMoveButtons runs its own loop with the cursor in a local, the bar moved by it.
    class PokeContestScene
      attr_accessor :frames, :results_scores
      attr_reader :pkmn1, :pkmn2, :pkmn3, :pkmn4, :sprites
      def initialize
        @sprites = {}
        @pkmn1 = Mon.new("Bulby", "Ash", [Move.new(30), Move.new(33), Move.new(0), Move.new(0)])
        @pkmn2 = Mon.new("Rival", "Eva", [])
        @pkmn3 = Mon.new("Otro", "", [])
        @pkmn4 = Mon.new("Cuarto", "Leo", [])
        (1..4).each do |i|
          instance_variable_set("@pkmn#{i}hearts", 0)
          instance_variable_set("@pkmn#{i}total", 0)
          instance_variable_set("@pkmn#{i}stars", 0)
        end
        @applause = 0
        @round = 2
        @pokeorder = [@pkmn2, @pkmn1, @pkmn3, @pkmn4]
        @Oblivious = [false] * 4
        @AvoidOnce = [0] * 4
        @currentpos = 1
        @frames = []
      end

      def pbShowMessageWindow(msg, brief = false); @shown = _INTL(msg); end
      def pbShowMessage(text, brief = false, *args); pbShowMessageWindow(_INTL(text), brief); end
      def pbShowJudgeMessage(text); pbShowMessage(_INTL("{2}{1}", text, "<c3=98a1ff,3050c8>"), false); end

      def pbDrawText
        rows = []
        @pokeorder.each_with_index { |p, i| rows.push([_INTL("{1}", p.name), 344, 2 + 96 * i, 0, nil, nil, true]) }
        pbDrawTextPositions(nil, rows)
      end

      def pbMoveButtons
        @sprites["selectbar"] = Bar.new(196, Height.new(46))
        each_frame(@frames)
        @sprites["selectbar"] = nil
      end

      def move_bar(row); @sprites["selectbar"].y = 200 + (row * 46 - 4); end

      def pbAdjustHearts(amount, target = @currentpoke, position = @currentpos)
        i = [@pkmn1, @pkmn2, @pkmn3, @pkmn4].index(target) + 1
        current = instance_variable_get("@pkmn#{i}hearts")
        amount.abs.times do
          current += amount > 0 ? 1 : -1
          instance_variable_set("@pkmn#{i}hearts", current)
        end
        current
      end

      def pbAddHearts(amount, target = @currentpoke, position = @currentpos); pbAdjustHearts(amount.abs, target, position); end

      def pbDecreaseStarGraphics(position, change, decrease = true)
        pokemon = @pokeorder[position]
        i = [@pkmn1, @pkmn2, @pkmn3, @pkmn4].index(pokemon) + 1
        now = instance_variable_get("@pkmn#{i}stars")
        instance_variable_set("@pkmn#{i}stars", decrease ? [now - change, 0].max : now + change)
      end

      def pbCrowd(move = nil)
        if @excited
          @applause += 1 if @applause < 5
          pbAddHearts(1, @pkmn1, 2)
        end
      end

      def excite(on); @excited = on; end
      def pbObliviousGraphic
        %w[obliviousone oblivioustwo obliviousthree obliviousfour].each_with_index do |name, i|
          @sprites[name] = :mark if (@Oblivious[i] == true || @AvoidOnce[i] > 0) && !@sprites[name]
        end
      end
      def shield(place); @AvoidOnce[place] = 1; pbObliviousGraphic; end
      def pbShowHeartMeterForAll; :meters; end
      def pbShowPhaseTitle(title); :title; end
      def score(values)
        @results_data = [@pkmn1, @pkmn2, @pkmn3, @pkmn4].zip(values).map { |p, v| { :pokemon => p, :display_score => v } }
      end
      def pbShowPreliminaryResults; pbShowPhaseTitle("Evaluación Preliminar"); end
      def pbShowRoundResults(round_num, totals, title); pbShowPhaseTitle(title); end
      def pbDrawCelebrationHeader(bitmap, pokemon)
        pbDrawTextPositions(bitmap, [[_INTL("¡GANADOR!"), 256, 5, 2], [pokemon.name, 256, 30, 2], [pokemon.ot, 256, 55, 2]])
      end
      def pbDrawCelebrationMessage(bitmap, pokemon)
        pbDrawTextPositions(bitmap, [[_INTL("¡{1} ha ganado el concurso!", pokemon.name), 256, 20, 2]])
      end
      def pbEndScene; :ended; end
      def add_total(i, n); instance_variable_set("@pkmn#{i}total", n); end
      def add_stars(i, n); instance_variable_set("@pkmn#{i}stars", n); end
    end

    # The summary with 0238_Patch's move list: drawSelectedMove takes the contest face as a third argument.
    class PokemonSummaryScene
      def initialize(pokemon); @pokemon = pokemon; end
      def drawSelectedMove(moveToLearn, moveid, contestMode = false); :painted; end
      def pbChooseMoveToForget(moveToLearn); :forgotten; end
    end

    module BlenderConfig
      BTN_LABELS = ["+ Añadir", "- Quitar", "¡Licuar!"]
    end

    # BerryBlenderScene as 0237 leaves it: pbGridSelect's loop runs over pbShowSelector's paint and its cursor is a local.
    class BerryBlenderScene
      attr_accessor :frames, :pick
      attr_reader :lastBerryIdx
      def pbStartScene(berries)
        @sprites = {}
        @selected_btn = 0
        @current_berry_count = 0
        pbRefreshSlots(berries)
        pbRefreshButtons(0)
        @lastBerryIdx = 0
      end
      def pbRefreshSlots(berries)
        @current_berry_count = berries.length
        pbRefreshButtons(berries.length)
      end
      def pbRefreshButtons(count); :painted; end
      def press(dir)
        @selected_btn = (@selected_btn + dir) % 3
        pbRefreshButtons(@current_berry_count)
      end
      def last_berry(i); @lastBerryIdx = i; end
      def pbShowSelector(available)
        @sel_available = available
        @sel_cells = available.map { |_e| [0, 0] }
        pbDrawTextPositions(nil, [["¿Qué baya añadir?", 4, 10, 0]])
        pbDrawTextPositions(nil, [[_INTL("C: Seleccionar"), 127, 11, 2]])
        pbDrawTextPositions(nil, [[_INTL("X: Cancelar"), 127, 11, 2]])
        available.each { |e| pbDrawTextPositions(nil, [[e[2].to_s, 8, -2, 0]]) }
        pbUpdateCursor(0)
      end
      def pbUpdateCursor(pos)
        return unless @sel_cells && @sel_cells[pos]
        pos
      end
      def pbGridSelect(available)
        pbShowSelector(available)
        pbUpdateCursor(@lastBerryIdx)
        each_frame(@frames)
        @pick
      end
      def pbEndScene; :ended; end
    end

    # The pause menu's class, which PokegearBase inherits and overrides, as 0282_Pokegear does.
    class Menu2
      def initialize; @selected_item = 0; @items = []; end
      def redrawSelector; :redrawn; end
      def drawIcons; :drawn; end
      def pbUpdate; :run; end
    end

    class PokegearBase < Menu2
      DayOfWeek = %w[Domingo Lunes Martes Miércoles Jueves Viernes Sábado]
      attr_accessor :frames, :selected
      def initialize
        @selected_item = 0
        @items = [["pokegeartrcard", "Ficha", "x"], ["pokegearRadio", "Radio", "y"], ["pokegearSkin", "Skins", "z"]]
        @frames = []
      end
      def pbStartScene; redrawSelector; pbRefresh; end
      def pbRefresh; :refreshed; end
      def redrawSelector; :own; end
      def move(n); @selected_item = n; end
      def pbUpdate; each_frame(@frames); end
      def pbEndScene; @exit = true; end
    end

    class PokegearSkinSelector < PokegearBase
      def initialize
        @selected_item = 0
        @items = [["skin1", "Azul", 1], ["skin2", "Rosa", 2]]
        @frames = []
      end
      def pbStartScene; redrawSelector; end
      def redrawSelector; :own_skin; end
      def pbUpdate; each_frame(@frames); end
    end

    # RadioSystem and RadioInterface as 0295_Radio_Core leave them.
    class RadioDouble
      attr_accessor :current_frequency, :station, :current, :after
      def initialize; @current_frequency = 0.0; @station = ""; @current = "..."; end
      def get_station_info; @station; end
      def get_display_text; { :current => @current, :next => @after }; end
    end
    class RadioInterface
      attr_reader :radio_system
      def initialize
        @radio_system = RadioDouble.new
        update_display
      end
      def update_display; :painted; end
      def get_available_stations; [{ :frequency => 2 }, { :frequency => 7.5 }]; end
      def cleanup_on_exit; :left; end
    end

    # WalkerScene as 0382_Walker UI leaves it: each piece of paint calls the next one down.
    class WalkerScene
      def text(str, x, y, align = 0, base = nil, shadow = nil); pbDrawTextPositions(nil, [[str, x, y, align]]); end
      def fit_text(str, x, y, width, base = nil, shadow = nil); str; end
      def title_bar(str); text(str, 26, 18, 0); end
      def hint_bar(str); text(str, 26, 344, 0); end
      def option_list(x, y, w, items, index); items.each_index { |i| fit_text(items[i][0], x + 14, y, w - 28) }; end
      def wrap(str, x, y, w, color); str.split(" ").each { |word| text(word, x, y, 0) }; end
      def busy(msg); text(msg, 136, 180, 0); end
      def choose(items, &draw); draw.call if draw; :chosen; end
      def dispose; :gone; end
      def paint_menu(index)
        items = [["Enviar Pokémon", false], ["Salir", false]]
        title_bar("WALKER")
        text("Sin Pokémon", 26, 64, 0)
        wrap("Envía un Pokémon a la app.", 26, 112, 142, nil)
        fit_text("Saldo: 5 W", 26, 272, 224)
        option_list(192, 56, 306, items, index)
        hint_bar("A  ELEGIR      B  SALIR")
      end
      def paint_qr
        title_bar("CONECTAR LA APP")
        text("CÓDIGO", 204, 84, 0)
        fit_text("ABC123", 260, 80, 200)
        wrap("Escanea este código.", 204, 200, 282, nil)
        hint_bar("B  ATRÁS")
      end
    end

    TradeMon = Struct.new(:name, :item)
    # TradeUI_Base as 0388_CodeTrade_BaseUI leaves it: refreshOverlay paints all it shows; MenuHandlers fill the menu.
    class TradeUI_Base
      attr_accessor :frames, :options, :info, :code, :mon, :selected
      def initialize
        @selected = 0
        @options = [[:a, {}, "Ofrecer Pokémon"], [:b, {}, "Salir"]]
        @info = "Ningún Pokémon"
        @code = []
        @frames = []
      end
      def pbMenuOptions; @options; end
      def pbScreenTitle; "Intercambio - Ofrecer Pokémon"; end
      def pbPokemonInfoText; @info; end
      def pbCodeLines; @code; end
      def pbDisplayedPokemon; @mon; end
      def refreshOverlay; :painted; end
      def mainLoop; refreshOverlay; each_frame(@frames); disposeUI; end
      def disposeUI; :gone; end
    end
    class TradeUI_Offer < TradeUI_Base; end

    class TradeCodeBoxWindow
      attr_reader :boxes, :cursorIndex
      attr_writer :cursorIndex
      def initialize(boxes); @boxes = boxes; @cursorIndex = 0; end
      def getFullCode; @boxes.join(""); end
    end

    # TradeCodeManualEntry: the boxes paint what they hold before the overlay paints its line and its two commands.
    class TradeCodeManualEntry
      COMMANDS = ["Confirmar", "Cancelar"]
      attr_accessor :frames, :focus, :cmd
      attr_reader :box
      def initialize; @frames = []; end
      def createUI
        @boxWindow = TradeCodeBoxWindow.new(["ABC", ""])
        @box = @boxWindow
        @focus = :grid
        @cmdIndex = 0
        drawTextEx(nil, 0, 0, 160, 1, "ABC")
        pbDrawTextPositions(nil, [["Introduce el código manualmente.\nUsa las flechas para moverte y C para editar.", 32, 32, 0],
                                  ["Confirmar", 32, 300, false], ["Cancelar", 128, 300, false]])
      end
      def go_commands(i); @focus = :commands; @cmdIndex = i; end
      def pbStart(initial_code = "")
        createUI
        each_frame(@frames)
        @code
      end
    end

    class Window_TradeLog < Window_DrawableCommand
      def initialize; super([]); @entries = []; end
      def entries=(value); @entries = value; end
      def itemCount; @entries.length; end
    end

    # TradeLog_Scene as 0392_CodeTrade_LogUI leaves it: its page paints first, then runs its own loop.
    class TradeLog_Scene
      attr_accessor :frames
      attr_reader :sprites
      def initialize(lists); @lists = lists; @frames = []; end
      def pbStartScene
        @trade_data = @lists
        @trade_text = ["Mis ofertas", "Ofertas recibidas"]
        @current_tab = 0
        @sprites = { "itemlist" => Window_TradeLog.new }
        @sprites["itemlist"].entries = @trade_data[0]
      end
      def swapTab
        @current_tab = 1 - @current_tab
        @sprites["itemlist"].index = 0
        @sprites["itemlist"].entries = @trade_data[@current_tab]
      end
      def pbShowTradeDetails(entry)
        pbDrawTextPositions(nil, [["Pokémon ofrecido: Pikachu", 6, -2, 0]])
        drawFormattedTextEx(nil, 38, 48, 452, "Nombre: #{entry['name']}")
        drawFormattedTextEx(nil, 38, 80, 452, "Código:")
        drawFormattedTextEx(nil, 38, 112, 452, "  QWERTYUIOPASDFG")
        drawFormattedTextEx(nil, 38, 144, 452, " ...")
        drawFormattedTextEx(nil, 38, 176, 452, "ID de sesión: 77")
        drawFormattedTextEx(nil, 38, 208, 452, "Fecha: 01/11/2026 10:00")
        drawFormattedTextEx(nil, 38, 344, 452, "<c2=0000ffff>B:</c2> Volver")
        each_frame(@frames)
      end
      def pbEndScene; :ended; end
    end

    def pbFakeSummary(pokemon); :summary; end

    EvMon = Struct.new(:name, :level, :totalhp, :attack, :defense, :speed, :spatk, :spdef, :nature, :shadow, :stage, :held) do
      def status; name == "Dormida" ? 1 : 0; end
      def isShadow?; shadow; end
      def heartStage; stage; end
      def hasItem?; held > 0; end
      def item; held; end
      def isShiny?; false; end
      attr_writer :hp, :pokerus
      def hp; @hp || 1; end
      def pokerusStage; @pokerus || 0; end
    end

    # EVReorganizeScene as 0326_EV Redistributor leaves it; pbScene's loop redraws every frame.
    class EVReorganizeScene
      STAT_ORDER = [0, 1, 2, 4, 5, 3]
      attr_accessor :frames, :selected_stat
      attr_reader :current_evs
      def initialize(pokemon, evs)
        @pokemon = pokemon
        @original_evs = evs.dup
        @current_evs = evs
        @ivs = [31] * 6
        @max_evs = evs.inject(0) { |s, e| s + e }
        @selected_stat = 0
        @frames = []
      end
      def pbStartScene; drawScreen; end
      def drawScreen; :drawn; end
      def getTopTwoStats; [1, 4]; end
      def calculateCost
        cost = 0
        6.times { |i| d = @current_evs[i] - @original_evs[i]; cost += d * 100 if d > 0 }
        cost
      end
      def pbScene; each_frame(@frames); end
      def pbEndScene; :ended; end
    end

    Check = Struct.new(:src_rect)
    Rect2 = Struct.new(:x)

    # AdvSelector, as 0328 builds it: the options paint at y_pos, their notes below, the title above the rows.
    class AdvSelector
      attr_accessor :frames, :selected
      def initialize(text, text2 = nil, text3 = nil)
        @selected = 0
        @sprites = {}
        @frames = []
        rows = []
        rows.push([_INTL(text3), 256, 8, 2]) if text3
        text.each_with_index do |label, i|
          y = 48 + i * 96
          rows.push([_INTL(label), 40, y, 0])
          drawFormattedTextEx(nil, 32, y + 32, 472, _INTL(text2[i]))
        end
        pbDrawTextPositions(nil, rows)
      end
      def show; each_frame(@frames); end
    end

    # SandboxSelector builds itself without calling up, and its notes sit two pixels higher.
    class SandboxSelector < AdvSelector
      def initialize(text, text2 = nil, text3 = nil)
        @selected = 0
        @sprites = {}
        @frames = []
        rows = [[_INTL(text3), 256, 8, 2]]
        text.each_with_index do |label, i|
          y = 48 + i * 96
          rows.push([_INTL(label), 40, y, 0])
          drawFormattedTextEx(nil, 32, y + 30, 472, _INTL(text2[i]))
        end
        pbDrawTextPositions(nil, rows)
      end
      def show; each_frame(@frames); end
    end

    # LockeSelector as 0329 builds it: the notes paint before the rows, the last one empty, and the first option starts ticked.
    class LockeSelector
      attr_accessor :frames, :selected
      attr_reader :sprites
      def initialize
        @selected = 0
        @frames = []
        @sprites = { "ch0" => Check.new(Rect2.new(20)), "ch1" => Check.new(Rect2.new(0)), "ch2" => Check.new(Rect2.new(0)) }
        rows = [[_INTL("Selecciona un modo de juego."), 40, 8, 0]]
        labels = ["Modo Normal", "Modo Permadeath", "Modo Random", "Terminar"]
        notes = ["Sin reglas especiales.", "Si se debilita, no revive.", "Todo aleatorio.", ""]
        labels.each_with_index do |label, i|
          rows.push([label, 60, 48 + i * 80, 0])
          drawFormattedTextEx(nil, 32, 48 + i * 80 + 32, 472, notes[i])
        end
        pbDrawTextPositions(nil, rows)
      end
      def toggle(i); @sprites["ch#{i}"].src_rect.x = @sprites["ch#{i}"].src_rect.x == 20 ? 0 : 20; end
      def show; each_frame(@frames); end
    end

    # RandomConfig as 0330 builds it, a class of its own with LockeSelector's layout.
    class RandomConfig
      attr_accessor :frames
      def initialize
        @selected = 0
        @frames = []
        @sprites = { "ch0" => Check.new(Rect2.new(20)), "ch1" => Check.new(Rect2.new(0)) }
        drawFormattedTextEx(nil, 32, 80, 472, "Movimientos al azar.")
        pbDrawTextPositions(nil, [[_INTL("Configuración extra del Modo Random"), 40, 8, 0], ["Movimientos aleatorios", 60, 48, 0],
                                  ["Habilidades aleatorias", 60, 128, 0], ["Terminar", 60, 208, 0]])
      end
      def show; each_frame(@frames); end
    end

    # PokemonCreaturesMartAdapter and the window of 0176_PScreen_Mart, its stock in species.
    class PokemonCreaturesMartAdapter
      def getDisplayName(item); { 172 => "Pichu (Lv.5)" }[item].to_s; end
      def getDisplayPrice(item, selling = false); _INTL("{1} F", { 172 => 100 }[item]); end
      def getDescription(item); { 172 => "Almacena electricidad." }[item].to_s; end
    end
    class PlainAdapter
      def getDisplayName(item); "Poción"; end
      def getDisplayPrice(item, selling = false); "$ 300"; end
    end
    class BuyAdapter
      def initialize(adapter); @adapter = adapter; end
      def getDisplayName(item); @adapter.getDisplayName(item); end
      def getDisplayPrice(item); @adapter.getDisplayPrice(item, false); end
    end
    class Window_PokemonMart < Window_DrawableCommand
      def initialize(stock, adapter); super(stock); @stock = stock; @adapter = adapter; end
    end

    class Window_DexesList < Window_DrawableCommand
      def initialize(commands, seen, owned); super(commands); @seen = seen; @owned = owned; end
    end
    class PokemonPokedexMenu_Scene
      attr_reader :sprites
      def initialize; @sprites = { "commands" => Window_DexesList.new(["Johto", "Salir"], ["10"], ["5"]) }; end
      def pbRefresh; :refreshed; end
    end
    $dex_list_body = nil
    def pbPokedexMenu(menu_index = 0); $dex_list_body.call if $dex_list_body; :closed; end
    def pbFadeOutIn(z = 0); yield; end
  RUBY

  PLAY = <<-'RUBY'
    def at_level(level)
      was = PokeAccess::Config.verbosity
      PokeAccess::Config.verbosity = level
      yield
    ensure
      PokeAccess::Config.verbosity = was
    end

    # What each frame of the block's loops said, and what was said outside them, last.
    def stepped
      $steps = []
      SpeakCapture.clear
      yield
      $steps.dup.push(SpeakCapture.log.dup)
    end

    def contest_scene
      PokeContestScene.new
    end

    def info; PokeAccess::Info.info_text; end
    def row; PokeAccess::Info.row_text; end

    probe(:contest_messages) do
      scene = contest_scene
      [said { scene.pbShowJudgeMessage("Muy bien Bulby, ¡veamos!") },
       said { scene.pbShowMessage("¡Exhibición n.º 2<br>¿Qué movimiento vas a usar?") },
       said { scene.pbShowMessage("Bulby se exhibe.", true) }]
    end

    probe(:contest_order) do
      scene = contest_scene
      first = said { scene.pbDrawText }
      again = said { scene.pbDrawText }
      scene.instance_variable_set(:@pokeorder, [scene.pkmn1, scene.pkmn2, scene.pkmn3, scene.pkmn4])
      [first, again, said { scene.pbDrawText }]
    end

    probe(:contest_menu) do
      at_level(:full) do
        scene = contest_scene
        scene.instance_variable_set(:@pkmn1lastmoveid, 33)
        scene.add_stars(1, 1)
        scene.sprites["oblivioustwo"] = :mark
        scene.sprites["nervousone"] = :mark
        scene.sprites["nomovethree"] = :mark
        scene.add_total(1, 7)
        scene.frames = [nil, nil, lambda { scene.move_bar(1) }, lambda { scene.move_bar(2) }, lambda { scene.move_bar(0) }]
        steps = nil
        kept = nil
        steps = stepped { scene.frames.push(lambda { kept = info }); scene.pbMoveButtons }
        [steps, kept, said { PokeAccess::Frame.run_pollers }]
      end
    end

    probe(:contest_menu_brief) do
      at_level(:brief) do
        scene = contest_scene
        scene.frames = [nil]
        stepped { scene.pbMoveButtons }
      end
    end

    probe(:contest_menu_again) do
      scene = contest_scene
      scene.frames = [nil]
      first = stepped { scene.pbMoveButtons }
      second = stepped { scene.pbMoveButtons }
      [first[0].length, second[0].length]
    end

    probe(:contest_rounds) do
      scene = contest_scene
      [0, 1, 5, 6].map do |n|
        scene.instance_variable_set(:@round, n)
        PokeAccess::VitroContests.round_text(scene)
      end
    end

    probe(:contest_hearts) do
      scene = contest_scene
      gain = said { scene.pbAdjustHearts(3, scene.pkmn2, 1) }
      none = said { scene.pbAdjustHearts(0, scene.pkmn2, 1) }
      jam = said { scene.pbAdjustHearts(-4, scene.pkmn1, 2) }
      [gain, none, jam, info]
    end

    probe(:contest_stars) do
      scene = contest_scene
      gain = said { scene.pbDecreaseStarGraphics(1, 1, false) }
      down = said { scene.pbDecreaseStarGraphics(1, 1) }
      none = said { scene.pbDecreaseStarGraphics(1, 1) }
      [gain, down, none]
    end

    probe(:contest_crowd) do
      scene = contest_scene
      still = said { scene.pbCrowd }
      again = said { scene.pbCrowd }
      scene.excite(true)
      rose = said { scene.pbCrowd }
      [still, again, rose]
    end

    probe(:contest_shield) do
      scene = contest_scene
      first = said { scene.shield(1) }
      again = said { scene.pbObliviousGraphic }
      [first, again]
    end

    probe(:contest_meters_empty) do
      said { contest_scene.pbShowHeartMeterForAll }
    end

    probe(:contest_panel_follows) do
      scene = contest_scene
      scene.pbDrawText
      order = info
      scene.pbDecreaseStarGraphics(1, 1, false)
      stars = info
      scene.shield(1)
      shield = info
      scene.sprites["startletwo"] = :mark
      [order, stars, shield, PokeAccess::VitroContests.panel(scene)]
    end

    probe(:contest_panel_hearts) do
      scene = contest_scene
      scene.instance_variable_set(:@pkmn1hearts, 3)
      scene.instance_variable_set(:@pkmn2hearts, -1)
      PokeAccess::VitroContests.panel(scene)
    end

    probe(:contest_meters) do
      scene = contest_scene
      scene.add_total(1, 12)
      scene.add_total(2, 4)
      [said { scene.pbShowHeartMeterForAll }, info]
    end

    probe(:contest_results) do
      scene = contest_scene
      scene.score([30, 40, 30, 0])
      title = said { scene.pbShowPreliminaryResults }
      phase_info = info
      scene.score([70, 60, 10, 0])
      round = said { scene.pbShowRoundResults(1, [1, 1, 1, 1], "Primera Ronda") }
      last = said { scene.pbShowRoundResults(5, [1, 1, 1, 1], "Quinta Ronda") }
      [title, phase_info, round, last]
    end

    probe(:contest_stage) do
      scene = contest_scene
      head = said { scene.pbDrawCelebrationHeader(nil, scene.pkmn1) }
      foot = said { scene.pbDrawCelebrationMessage(nil, scene.pkmn1) }
      kept = info
      scene.pbEndScene
      [head, foot, kept, info]
    end

    probe(:forget_faces) do
      scene = PokemonSummaryScene.new(Mon.new("Bulby", "Ash", [Move.new(30)]))
      opened = said { scene.pbChooseMoveToForget(0) }
      first = said { scene.drawSelectedMove(0, 30) }
      moved = said { scene.drawSelectedMove(0, 33, false) }
      turned = said { scene.drawSelectedMove(0, 33, true) }
      kept = info
      next_move = said { scene.drawSelectedMove(0, 30, true) }
      back = said { scene.drawSelectedMove(0, 30, false) }
      [opened, first, moved, turned, kept, next_move, back]
    end

    probe(:blender_open) do
      scene = BerryBlenderScene.new
      opening = said { scene.pbStartScene([]) }
      moved = said { scene.press(1) }
      same = said { scene.pbRefreshButtons(0) }
      [opening, moved, same]
    end

    probe(:blender_grid) do
      scene = BerryBlenderScene.new
      scene.pbStartScene([])
      scene.last_berry(1)
      cells = [[:CHERIBERRY, 201, 3], [:ORANBERRY, 202, 5]]
      item_row = nil
      scene.frames = [nil, lambda { scene.pbUpdateCursor(0) }, lambda { item_row = row }]
      scene.pick = nil
      cancel = stepped { scene.pbGridSelect(cells) }
      scene.pick = :ORANBERRY
      scene.frames = []
      SpeakCapture.clear
      PokeAccess::Cursor.reset(scene, :vitro_bb_cell)
      chose = stepped do
        scene.pbGridSelect(cells)
        scene.pbRefreshSlots([:ORANBERRY])
      end
      [cancel, item_row, chose, info, said { scene.press(2) }]
    end

    probe(:blender_past_list) do
      cells = [[:CHERIBERRY, 201, 3], [:ORANBERRY, 202, 5]]
      [2, 1].map do |last|
        scene = BerryBlenderScene.new
        scene.pbStartScene([])
        scene.last_berry(last)
        scene.pick = nil
        scene.frames = []
        log = said { scene.pbGridSelect(cells) }
        [log.map { |line, _queued| line }, scene.lastBerryIdx]
      end
    end

    probe(:blender_quiet_cursor) do
      scene = BerryBlenderScene.new
      scene.pbStartScene([])
      unopened = said { scene.pbUpdateCursor(0) }
      scene.pick = nil
      scene.frames = []
      scene.pbGridSelect([[:CHERIBERRY, 201, 3], [:ORANBERRY, 202, 5]])
      [unopened, said { scene.pbUpdateCursor(1) }]
    end

    probe(:blender_greys) do
      (0..4).map do |count|
        scene = BerryBlenderScene.new
        scene.pbStartScene([:ORANBERRY] * count)
        (0..2).map do |button|
          scene.instance_variable_set(:@selected_btn, button)
          PokeAccess::Cursor.reset(scene, :vitro_bb_button)
          said { scene.pbRefreshButtons(count) }[0][0].include?(PokeAccess::I18n.t(:opt_unavailable))
        end
      end
    end

    probe(:gear) do
      scene = PokegearBase.new
      opening = said { scene.pbStartScene }
      kept = nil
      scene.frames = [nil, lambda { scene.move(1) }, nil, lambda { kept = info; scene.pbRefresh }, nil]
      steps = stepped { scene.pbUpdate }
      scene.pbEndScene
      [opening, steps, kept, info]
    end

    probe(:gear_skins) do
      $game_variables[23] = 1
      scene = PokegearSkinSelector.new
      kept = nil
      scene.frames = [nil, lambda { scene.move(1) }, lambda { $game_variables[23] = 0 }, lambda { scene.move(0) }, lambda { kept = row }]
      steps = stepped { scene.pbStartScene; scene.pbUpdate }
      [steps, kept]
    end

    probe(:radio) do
      was_hint = said { RadioInterface.new }
      scene = RadioInterface.new
      radio = scene.radio_system
      SpeakCapture.clear
      noise = said { radio.current = "...zzt... ...zzt..."; scene.update_display }
      tune = said { radio.current_frequency = 0.5; scene.update_display }
      station = said do
        radio.current_frequency = 7.5
        radio.station = "Canal Música Pokémon"
        radio.current = "Nardo: Bienvenidos."
        radio.after = "¡Hoy es lunes!"
        scene.update_display
      end
      kept_next = info
      same = said { scene.update_display }
      nextline = said { radio.current = "¡Hoy es lunes!"; radio.after = nil; scene.update_display }
      blank = said { radio.current = ""; scene.update_display }
      kept_row = row
      kept = info
      other = said do
        radio.current_frequency = 2.0
        radio.station = "Canal Variedades"
        radio.current = "¡Hoy es lunes!"
        scene.update_display
      end
      scene.cleanup_on_exit
      [was_hint, noise, tune, station, same, nextline, blank, kept_row, kept, other, info, kept_next]
    end

    probe(:walker) do
      scene = WalkerScene.new
      menu = said { scene.paint_menu(0) }
      same = said { scene.paint_menu(0) }
      moved = said { scene.paint_menu(1) }
      kept = info
      back = said { scene.choose([]) { scene.paint_menu(1) } }
      busy = said { scene.busy("Conectando…") }
      qr = said { scene.paint_qr }
      kept_qr = info
      row_qr = row
      scene.dispose
      [menu, same, moved, kept, back, busy, qr, kept_qr, info, row_qr]
    end

    probe(:trade) do
      scene = TradeUI_Offer.new
      scene.frames = [nil,
                      lambda { scene.selected = 1 },
                      lambda { $kept_trade = info },
                      lambda { scene.info = "Pikachu ♂  Nv. 5"; scene.code = ["ABC-DEF"]; scene.mon = TradeMon.new("Pikachu", 7); scene.refreshOverlay },
                      lambda { $kept_code = info },
                      lambda { pbFadeOutIn { :party } }]
      steps = stepped { scene.mainLoop }
      [steps, $kept_trade, $kept_code, info]
    end

    probe(:trade_summary_seam) do
      fired = []
      PokeAccess::MenuReturn.on_return { fired.push(:back) }
      pbFakeSummary(nil)
      fired
    end

    probe(:trade_entry) do
      scene = TradeCodeManualEntry.new
      scene.frames = [nil,
                      lambda { scene.box.cursorIndex = 1 },
                      lambda { $kept_box = info },
                      lambda { scene.box.boxes[1] = "XYZ" },
                      lambda { scene.go_commands(0) },
                      lambda { $kept_cmd = row },
                      lambda { scene.go_commands(1) }]
      steps = stepped { scene.pbStart("ABC") }
      [steps, $kept_box, $kept_cmd]
    end

    probe(:trade_log) do
      offers = [{ "name" => "Pika", "species" => 25, "level" => 5, "ot" => "Ash", "type" => "offer" },
                { "name" => "Eve", "species" => 133, "level" => 7, "ot" => "Eva", "type" => "offer" }]
      scene = TradeLog_Scene.new([offers, []])
      opening = said { scene.pbStartScene }
      list = scene.sprites["itemlist"]
      first = said { list.update }
      moved = said { list.index = 1; list.update }
      kept = info
      swap = said { scene.swapTab }
      empty = said { list.update }
      empty_info = info
      back_tab = said { scene.swapTab; list.update }
      page_info = nil
      scene.frames = [nil, lambda { page_info = info }]
      page = stepped { scene.pbShowTradeDetails(offers[0]) }
      after_page = said { list.update }
      scene.pbEndScene
      [opening, first, moved, kept, swap, empty, back_tab, page, page_info, after_page, empty_info]
    end

    # A Pokemon whose nature, 5 * 0 + 2, raises the row of Attack and lowers the row of Speed.
    def ev_mon(nature = 2, shadow = false, stage = 0)
      EvMon.new("Bulby", 12, 200, 150, 90, 80, 70, 60, nature, shadow, stage, 0)
    end

    def ev_scene(mon = ev_mon)
      EVReorganizeScene.new(mon, [4, 12, 0, 0, 0, 0])
    end

    probe(:ev_icons) do
      fainted = ev_mon
      fainted.hp = 0
      fainted.pokerus = 1
      ill = ev_mon
      ill.pokerus = 1
      cured = ev_mon
      cured.pokerus = 2
      [ev_mon, fainted, ill, cured, ev_mon(2, true)].map { |mon| PokeAccess::VitroEv.head(mon) }
    end

    probe(:ev) do
      scene = ev_scene
      scene.frames = []
      opening = said { scene.pbStartScene }
      attack = said { scene.selected_stat = 1; scene.drawScreen }
      kept = info
      sp_atk = said { scene.selected_stat = 3; scene.drawScreen }
      moved = said { scene.current_evs[1] = 11; scene.current_evs[4] = 1; scene.drawScreen }
      speed = said { scene.selected_stat = 5; scene.drawScreen }
      button = said { scene.selected_stat = 6; scene.drawScreen }
      [opening, attack, kept, sp_atk, moved, speed, button]
    end

    probe(:ev_status) do
      mon = ev_mon
      mon.name = "Dormida"
      said { ev_scene(mon).pbStartScene }[0]
    end

    probe(:ev_tints) do
      [[2, false, 0], [6, false, 0], [2, true, 3], [2, true, 4]].map do |nature, shadow, stage|
        scene = ev_scene(ev_mon(nature, shadow, stage))
        scene.selected_stat = 1
        said { scene.drawScreen }
      end
    end

    # What the row of a stat says under a nature: 5 * raised + lowered, each counted from Attack.
    def ev_row_of(nature, row)
      scene = ev_scene(ev_mon(nature))
      scene.selected_stat = row
      said { scene.drawScreen }[0][0]
    end

    probe(:ev_natures) do
      [ev_row_of(7, 2), ev_row_of(7, 5), ev_row_of(7, 1), ev_row_of(6, 2), ev_row_of(24, 4), ev_row_of(11, 5)]
    end

    probe(:ev_short) do
      scene = ev_scene
      scene.selected_stat = 6
      scene.current_evs[1] = 7
      scene.current_evs[4] = 9
      short = said { scene.drawScreen }
      exact = ev_scene
      exact.selected_stat = 6
      exact.current_evs[1] = 7
      exact.current_evs[4] = 5
      [short, said { exact.drawScreen }]
    end

    probe(:ev_return) do
      scene = ev_scene
      scene.selected_stat = 1
      scene.drawScreen
      out = nil
      scene.frames = [lambda { out = said { pbFadeOutIn { :question }; scene.drawScreen } }]
      pbFadeOutIn { scene.pbScene }
      after = said { pbFadeOutIn { :later }; scene.drawScreen }
      [out, after]
    end

    probe(:selector_locke) do
      at_level(:full) do
        scene = nil
        title = said { scene = LockeSelector.new }
        kept = nil
        scene.frames = [nil,
                        lambda { scene.selected = 1 },
                        lambda { scene.toggle(1) },
                        lambda { kept = info },
                        lambda { scene.selected = 3 },
                        lambda { pbFadeOutIn { :question } }]
        steps = stepped { pbFadeOutIn { scene.show } }
        [title, steps, kept, info]
      end
    end

    probe(:selector_medium) do
      at_level(:medium) do
        scene = RandomConfig.new
        kept = nil
        scene.frames = [nil, lambda { kept = row }]
        SpeakCapture.clear
        [stepped { scene.show }, kept]
      end
    end

    probe(:selector_sandbox) do
      at_level(:full) do
        scene = nil
        title = said do
          scene = SandboxSelector.new(["Original", "Libre"], ["Vive los eventos.", "Omite los eventos."], "¿Cómo quieres jugar?")
        end
        scene.frames = [nil, lambda { scene.selected = 1 }]
        [title, stepped { scene.show }]
      end
    end

    probe(:selector_adv) do
      at_level(:full) do
        scene = nil
        title = said { scene = AdvSelector.new(["Uno"], ["Primero."]) }
        scene.frames = [nil]
        [title, stepped { scene.show }]
      end
    end

    probe(:mart) do
      pichu = Window_PokemonMart.new([172], BuyAdapter.new(PokemonCreaturesMartAdapter.new))
      line = PokeAccess::Menus.focused_text(pichu)
      kept = info
      kept_row = row
      plain = Window_PokemonMart.new([1], BuyAdapter.new(PlainAdapter.new))
      other = PokeAccess::Menus.focused_text(plain)
      other_row = row
      closing = Window_PokemonMart.new([172], BuyAdapter.new(PokemonCreaturesMartAdapter.new))
      closing.index = 1
      [line, kept, kept_row, other, other_row, PokeAccess::Menus.focused_text(closing)]
    end

    probe(:dex_list) do
      scene = PokemonPokedexMenu_Scene.new
      win = scene.sprites["commands"]
      first = said { win.update }
      same = said { win.update }
      back = said { scene.pbRefresh; win.update }
      [first, same, back]
    end

    probe(:dex_seam) do
      fired = []
      PokeAccess::MenuReturn.on_return { fired.push(:back) }
      inside = nil
      $dex_list_body = lambda { pbFadeOutIn { :dex }; inside = fired.length }
      pbPokedexMenu
      [inside, fired.length]
    end
  RUBY

  profile "vitro", WORLD, PLAY

  test "loads whole" do
    assert_equal [], played(:load_errors)
  end

  test "a contest message is said once as its window takes it, the judge's without its colour" do
    judge, round, brief = played(:contest_messages)
    assert_equal [["Muy bien Bulby, ¡veamos!", false]], judge
    assert_equal [["¡Exhibición n.º 2 ¿Qué movimiento vas a usar?", false]], round
    assert_equal [["Bulby se exhibe.", false]], brief
  end

  test "the running order is said with the player's place, when it changes" do
    first, again, moved = played(:contest_order)
    assert_equal [["#{t(:if2_ct_order, :list => 'Rival, Bulby, Otro, Cuarto')}. #{t(:sv_ct_place, :n => 2)}", false]], first
    assert_equal [], again
    assert_includes moved[0][0], t(:sv_ct_place, :n => 1)
  end

  test "the move menu follows its bar: the first row queued with its data, the grey, a missing move, and nothing outside it" do
    steps, kept, outside = played(:contest_menu)
    tackle = "#{t(:list_entry, :name => 'Placaje', :n => 1, :tot => 4)}. #{t(:if2_ct_category, :t => t(:cnd_tough))}. " \
             "EXHIBICIÓN 3. INHIBICIÓN 1. Efecto 30"
    assert_equal [[tackle, false]], steps[0]
    assert_equal [], steps[1]
    scratch = "#{t(:list_entry, :name => 'Arañazo', :n => 2, :tot => 4)}. #{t(:if2_ct_repeat)}. " \
              "#{t(:if2_ct_category, :t => t(:cnd_cool))}. EXHIBICIÓN 4. INHIBICIÓN 0. Efecto 33"
    assert_equal [[scratch, true]], steps[2]
    assert_equal [[t(:list_entry, :name => t(:row_empty), :n => 3, :tot => 4), true]], steps[3]
    assert_equal [[tackle, true]], steps[4]
    assert_includes kept, tackle
    assert_includes kept, t(:sv_ct_round, :n => 2, :tot => 5)
    assert_includes kept, "Rival / Eva, #{t(:vitro_ct_nervous)}"
    assert_includes kept, "Bulby / Ash, #{t(:vitro_ct_stars, :n => 1)}, #{t(:vitro_ct_shielded)}"
    assert_includes kept, "Otro, #{t(:vitro_ct_out)}"
    assert_includes kept, t(:sv_ct_place, :n => 2)
    assert_includes kept, t(:if2_ct_totals, :list => "Rival 0, Bulby 7, Otro 0, Cuarto 0")
    assert_equal [], outside
  end

  test "the round is told only among the five a contest runs" do
    assert_equal [nil, t(:sv_ct_round, :n => 1, :tot => 5), t(:sv_ct_round, :n => 5, :tot => 5), nil], played(:contest_rounds)
  end

  test "the move menu says only the name at the brief level" do
    assert_equal [["Placaje", false]], played(:contest_menu_brief)[0]
  end

  test "each round's menu says its row again" do
    assert_equal [1, 1], played(:contest_menu_again)
  end

  test "a change of hearts says what the row holds, and none is said without a change" do
    gain, none, jam, kept = played(:contest_hearts)
    assert_equal [[t(:if2_ct_hearts, :name => "Rival", :n => 3), false]], gain
    assert_equal [], none
    assert_equal [[t(:if2_ct_hearts, :name => "Bulby", :n => -4), false]], jam
    assert_includes kept, t(:sv_ct_round, :n => 2, :tot => 5)
  end

  test "stars are said by the place's contestant when their count moves" do
    gain, down, none = played(:contest_stars)
    assert_equal [["Bulby, #{t(:vitro_ct_stars, :n => 1)}", false]], gain
    assert_equal [["Bulby, #{t(:vitro_ct_stars, :n => 0)}", false]], down
    assert_equal [], none
  end

  test "the applause meter is said when it shows a new level, with the hearts it gives" do
    still, again, rose = played(:contest_crowd)
    assert_equal [[t(:if2_ct_applause, :n => 0, :max => 5), false]], still
    assert_equal [], again
    assert_equal [[t(:if2_ct_hearts, :name => "Bulby", :n => 1), false], [t(:if2_ct_applause, :n => 1, :max => 5), false]], rose
  end

  test "the shield mark is said when it goes up, by who stands at that place" do
    first, again = played(:contest_shield)
    assert_equal [[t(:sv_ct_oblivious, :name => "Bulby"), false]], first
    assert_equal [], again
  end

  test "the meters of the first round, with nothing in them yet, say nothing" do
    assert_equal [], played(:contest_meters_empty)
  end

  test "the info key's panel follows the order, the stars, the shield and the startled mark as they change" do
    order, stars, shield, startled = played(:contest_panel_follows)
    assert_includes order, t(:if2_ct_order, :list => "").sub(/\s*\z/, "")
    assert_includes stars, t(:vitro_ct_stars, :n => 1)
    assert_includes shield, t(:vitro_ct_shielded)
    assert_includes startled, t(:vitro_ct_startled)
  end

  test "the info key's panel says the hearts each row shows this round" do
    panel = played(:contest_panel_hearts)
    assert_includes panel, "Bulby / Ash, #{t(:vitro_ct_hearts, :n => 3)}"
    assert_includes panel, "Rival / Eva, #{t(:vitro_ct_hearts, :n => -1)}"
  end

  test "the meters of a round's end are said as totals, in the panel's order" do
    said_totals, kept = played(:contest_meters)
    list = t(:if2_ct_totals, :list => "Rival 4, Bulby 12, Otro 0, Cuarto 0")
    assert_equal [[list, false]], said_totals
    assert_includes kept, list
  end

  test "a phase of the results says the title and the player's place, and the last one the table" do
    title, phase_info, round, last = played(:contest_results)
    assert_equal ["Evaluación Preliminar", false], title[0]
    assert_equal "#{t(:sv_ct_place, :n => 2)}. #{t(:if2_ct_score, :name => 'Bulby', :n => 30)}", title[1][0]
    assert_equal t(:if2_ct_place, :pos => 1, :name => "Rival", :n => 40), phase_info.split(", puesto")[0]
    assert_includes phase_info, t(:if2_ct_place, :pos => 3, :name => "Otro", :n => 30)
    assert_equal ["Primera Ronda", false], round[0]
    assert_includes round[1][0], t(:sv_ct_place, :n => 1)
    assert_equal ["Quinta Ronda", false], last[0]
    assert_equal [t(:if2_ct_place, :pos => 1, :name => "Bulby", :n => 70), t(:if2_ct_place, :pos => 2, :name => "Rival", :n => 60),
                  t(:if2_ct_place, :pos => 3, :name => "Otro", :n => 10), t(:if2_ct_place, :pos => 4, :name => "Cuarto", :n => 0)].join(", "),
                 last[1][0]
    assert_equal false, last[1][1]
  end

  test "the winner's stage is said as it paints, kept for the info key until the scene ends" do
    head, foot, kept, gone = played(:contest_stage)
    assert_equal [["¡GANADOR! Bulby. Ash", false]], head
    assert_equal [["¡Bulby ha ganado el concurso!", false]], foot
    assert_equal "¡GANADOR! Bulby. Ash. ¡Bulby ha ganado el concurso!", kept
    assert_nil gone
  end

  test "the move-to-forget list reads the move of its own arguments, and left and right turn it to its contest face and back" do
    opened, first, moved, turned, kept, next_move, back = played(:forget_faces)
    assert_includes opened.map { |l| l[0] }, t(:vitro_forget_keys)
    assert_includes first[0][0], "Placaje"
    refute_includes first[0][0], "MOVIMIENTOS"
    refute_includes first[0][0], "EXHIBICIÓN"
    assert_includes moved[0][0], "Arañazo"
    refute_includes moved[0][0], "EXHIBICIÓN"
    contest = "MOV. CONCURSO. Arañazo. #{t(:if2_ct_category, :t => t(:cnd_cool))}. EXHIBICIÓN 0. INHIBICIÓN 0. Efecto 33"
    assert_equal [[contest, true]], turned
    assert_equal contest, kept
    assert_equal [["Placaje. #{t(:if2_ct_category, :t => t(:cnd_tough))}. EXHIBICIÓN 3. INHIBICIÓN 1. Efecto 30", true]], next_move
    assert_includes back[0][0], "MOVIMIENTOS"
    assert_includes back[0][0], "Placaje"
    refute_includes back[0][0], "EXHIBICIÓN"
  end

  test "the blender says its title, its empty slots and the button; a move says the next, with its grey" do
    opening, moved, same = played(:blender_open)
    assert_equal [["Licuabayas", false], [t(:vitro_bb_empty), false],
                  [t(:list_entry, :name => "+ Añadir", :n => 1, :tot => 3), false]], opening
    assert_equal [["#{t(:list_entry, :name => '- Quitar', :n => 2, :tot => 3)}, #{t(:opt_unavailable)}", true]], moved
    assert_equal [], same
  end

  test "the grid says its title and only the cell the cursor lands on; closing says the button, and a choice the slots first" do
    cancel, item_row, chose, kept, moved = played(:blender_grid)
    assert_equal [["¿Qué baya añadir? C: Seleccionar. X: Cancelar", false],
                  [t(:list_entry, :name => "Baya Aranja: 5", :n => 2, :tot => 2), false]], cancel[0]
    assert_equal [[t(:list_entry, :name => "Zreza: 3", :n => 1, :tot => 2), true]], cancel[1]
    assert_equal [t(:list_entry, :name => "+ Añadir", :n => 1, :tot => 3), false], cancel[3][-1]
    assert_equal t(:list_entry, :name => "Zreza: 3", :n => 1, :tot => 2), item_row
    assert_equal [t(:vitro_bb_berries, :list => "Baya Aranja"), false], chose.last[-2]
    assert_equal [t(:list_entry, :name => "+ Añadir", :n => 1, :tot => 3), false], chose.last[-1]
    assert_includes kept, t(:vitro_bb_berries, :list => "Baya Aranja")
    assert_equal [["#{t(:list_entry, :name => '¡Licuar!', :n => 3, :tot => 3)}, #{t(:opt_unavailable)}", true]], moved
  end

  test "a cell is said only while the grid is up" do
    assert_equal [[], []], played(:blender_quiet_cursor)
  end

  test "the buttons are told grey as their count leaves them: adding up to four, taking from one, blending from two" do
    assert_equal [[false, true, true], [false, false, true], [false, false, false], [false, false, false], [true, false, false]],
                 played(:blender_greys)
  end

  test "the Pokegear says its clock, the word of each icon, and the icon again as an entry returns" do
    opening, steps, kept, gone = played(:gear)
    assert_equal [["09:30. Lunes", false]], opening
    assert_equal [[t(:list_entry, :name => "Ficha", :n => 1, :tot => 3), false]], steps[0]
    radio = t(:list_entry, :name => "Radio", :n => 2, :tot => 3)
    assert_equal [[radio, true]], steps[1]
    assert_equal [], steps[2]
    assert_equal [[radio, true]], steps[3]
    assert_equal "#{radio}. 09:30. Lunes", kept
    assert_nil gone
  end

  test "the skins say their names and the one in use, which the choice moves" do
    steps, kept = played(:gear_skins)
    assert_equal "#{t(:list_entry, :name => 'Azul', :n => 1, :tot => 2)}, #{t(:rv_pc_marked)}", kept
    assert_equal [[t(:list_entry, :name => "Azul", :n => 1, :tot => 2), false]], steps[0]
    assert_equal [["#{t(:list_entry, :name => 'Rosa', :n => 2, :tot => 2)}, #{t(:rv_pc_marked)}", true]], steps[1]
    assert_equal [[t(:list_entry, :name => "Rosa", :n => 2, :tot => 2), true]], steps[2]
    assert_equal [["#{t(:list_entry, :name => 'Azul', :n => 1, :tot => 2)}, #{t(:rv_pc_marked)}", true]], steps[3]
  end

  test "the radio says each tuning, cutting in, and each new line of a program, queued, without its static" do
    first, noise, tune, station, same, nextline, blank, kept_row, kept, other, gone, kept_next = played(:radio)
    assert_includes kept_next, "Nardo: Bienvenidos. ¡Hoy es lunes!"
    assert_equal [["0.0. #{t(:vitro_radio_keys)}", false]], first
    assert_equal [], noise
    assert_equal [["0.5", true]], tune
    assert_equal [["7.5. Canal Música Pokémon", true], ["Nardo: Bienvenidos.", false]], station
    assert_equal [], same
    assert_equal [["¡Hoy es lunes!", false]], nextline
    assert_equal [], blank
    assert_equal "7.5. Canal Música Pokémon", kept_row
    assert_includes kept, t(:vitro_radio_marks, :list => "2.0, 7.5")
    assert_equal [["2.0. Canal Variedades", true], ["¡Hoy es lunes!", false]], other
    assert_nil gone
  end

  test "a Walker screen says what it paints once, then the option, not the bar's letters; the QR's code too" do
    menu, same, moved, kept, back, busy, qr, kept_qr, gone, row_qr = played(:walker)
    refute_includes kept_qr, "Salir"
    assert_equal kept_qr, row_qr
    text = "WALKER. Sin Pokémon. Envía un Pokémon a la app. Saldo: 5 W"
    assert_equal [[text, false], [t(:list_entry, :name => "Enviar Pokémon", :n => 1, :tot => 2), false]], menu
    assert_equal [], same
    assert_equal [[t(:list_entry, :name => "Salir", :n => 2, :tot => 2), true]], moved
    assert_includes kept, text
    assert_includes kept, "Salir"
    assert_equal [[t(:list_entry, :name => "Salir", :n => 2, :tot => 2), false]], back
    assert_equal [["Conectando…", false]], busy
    assert_equal [["CONECTAR LA APP. CÓDIGO. ABC123. Escanea este código.", false]], qr
    assert_includes kept_qr, "ABC123"
    assert_nil gone
  end

  test "a trade screen says its panel and each option, its code left to the info key" do
    steps, kept, kept_code, gone = played(:trade)
    panel = "Intercambio - Ofrecer Pokémon. Ningún Pokémon"
    salir = t(:list_entry, :name => "Salir", :n => 2, :tot => 2)
    assert_equal [panel, false], steps[0][0]
    assert_equal [t(:list_entry, :name => "Ofrecer Pokémon", :n => 1, :tot => 2), false], steps[0][1]
    assert_equal [[salir, true]], steps[1]
    assert_includes kept, panel
    assert_includes kept, salir
    assert_equal [["Intercambio - Ofrecer Pokémon. Pikachu ♂ Nv. 5", false]], steps[3].map { |l, q| [l.gsub(/\s+/, " "), q] }
    assert_includes kept_code, "ABC-DEF"
    assert_includes kept_code, salir
    assert_includes kept_code, t(:sum_item, :i => "Restos")
    assert_equal [[salir, true]], steps[5]
    assert_nil gone
  end

  test "the summary a trade opens counts as a return" do
    assert_includes played(:trade_summary_seam), :back
  end

  test "the manual entry says its line, each box with what it holds, and the commands; the code stays on the info key" do
    steps, kept_box, kept_cmd = played(:trade_entry)
    assert_equal ["Introduce el código manualmente. Usa las flechas para moverte y C para editar.", false], steps[0][0]
    assert_equal [t(:vitro_trade_box, :n => 1, :tot => 2, :text => "ABC"), false], steps[0][1]
    assert_equal [[t(:vitro_trade_box, :n => 2, :tot => 2, :text => t(:row_empty)), true]], steps[1]
    assert_includes kept_box, "Código: ABC"
    assert_equal [[t(:vitro_trade_box, :n => 2, :tot => 2, :text => "XYZ"), true]], steps[3]
    assert_equal [[t(:list_entry, :name => "Confirmar", :n => 1, :tot => 2), true]], steps[4]
    assert_equal t(:list_entry, :name => "Confirmar", :n => 1, :tot => 2), kept_cmd
    assert_equal [[t(:list_entry, :name => "Cancelar", :n => 2, :tot => 2), true]], steps[6]
  end

  test "the EV panel says the status icon, cured Pokerus and a Shadow Pokemon's mark as painted" do
    plain, fainted, ill, cured, shadow = played(:ev_icons)
    [t(:pk_fainted), t(:pk_pokerus), t(:perseida_mark_shadow)].each { |word| refute_includes plain, word }
    assert_includes fainted, t(:pk_fainted)
    refute_includes fainted, t(:pk_pokerus)
    assert_includes ill, t(:pk_pokerus)
    refute_includes ill, t(:pk_pokerus_cured)
    assert_includes cured, t(:pk_pokerus_cured)
    assert_includes shadow, t(:perseida_mark_shadow)
  end

  test "a grid's last cell chosen past the list opens on its first, where the cursor stays painted" do
    past, within = played(:blender_past_list)
    lines, last = past
    assert_equal 0, last
    assert lines.any? { |line| line.include?(": 3") }, lines.inspect
    lines, last = within
    assert_equal 1, last
    assert lines.any? { |line| line.include?(": 5") }, lines.inspect
  end

  test "the trade log says its title, its rows as painted, an empty list, another list, and a trade's page" do
    opening, first, moved, kept, swap, empty, back_tab, page, page_info, after_page, empty_info = played(:trade_log)
    assert_equal t(:row_empty), empty_info
    unknown = t(:pdx_unknown_short)
    assert_equal [["Mis ofertas Intercambio. #{t(:vitro_tradelog_keys)}", false]], opening
    assert_equal [[t(:list_entry, :name => "OFRECIDO: #{unknown} Nv.5 - Ash", :n => 1, :tot => 2), false]], first
    assert_equal [[t(:list_entry, :name => "OFRECIDO: #{unknown} Nv.7 - Eva", :n => 2, :tot => 2), true]], moved
    assert_equal "OFRECIDO: #{unknown} Nv.7 - Eva", kept
    assert_equal [["Ofertas recibidas Intercambio", true]], swap
    assert_equal [t(:row_empty), false], empty[0]
    assert_equal ["Mis ofertas Intercambio", true], back_tab[0]
    assert_equal [["Pokémon ofrecido: Pikachu. Nombre: Pika. Fecha: 01/11/2026 10:00. B: Volver", true]], page[0]
    assert_equal [], page[1]
    assert_includes page_info, "QWERTYUIOPASDFG"
    assert_includes page_info, "ID de sesión: 77"
    assert_includes page_info, "Fecha: 01/11/2026 10:00"
    assert_equal 1, after_page.length
    assert_includes after_page[0][0], "Ash"
  end

  test "the EV screen says its panel, each row as painted with the tint on the right stat, and a change with what it leaves" do
    opening, attack, kept, sp_atk, moved, speed, button = played(:ev)
    assert_equal ["DATOS. Bulby. Nv. 12. Objeto: Ninguno", false], opening[0]
    hp = t(:awk_ev_row, :name => "Estadistica0", :value => 200, :ev => 4, :iv => 31)
    assert_equal [hp, false], opening[1]
    row = t(:awk_ev_row, :name => "Estadistica1", :value => 150, :ev => 12, :iv => 31)
    assert_equal [["#{row}, #{t(:vitro_ev_nat_up)}, #{t(:awk_ev_recommended)}", true]], attack
    assert_includes kept, t(:awk_ev_totals, :n => 16, :max => 16)
    assert_includes kept, t(:awk_ev_left, :n => 0)
    assert_includes kept, "Bulby"
    assert_equal [["#{t(:awk_ev_row, :name => 'Estadistica4', :value => 70, :ev => 0, :iv => 31)}, #{t(:awk_ev_recommended)}", true]], sp_atk
    change = "#{t(:awk_ev_change, :ev => 1, :name => 'Estadistica4', :value => 70)}. #{t(:awk_ev_totals, :n => 16, :max => 16)}. " \
             "#{t(:awk_ev_left, :n => 0)}. #{t(:awk_ev_cost, :n => 100)}"
    assert_equal [[change, true]], moved
    assert_includes speed[0][0], t(:vitro_ev_nat_down)
    refute_includes opening[1][0], t(:vitro_ev_nat_up)
    assert_equal 1, button.length
    assert_includes button[0][0], "Confirmar"
    assert_includes button[0][0], t(:awk_ev_cost, :n => 100)
  end

  test "the EV screen's panel tells the status its icon shows" do
    assert_equal ["DATOS. Dormida. Nv. 12. #{PokeAccess::Party.status_word(1)}. Objeto: Ninguno", false], played(:ev_status)
  end

  test "the tint falls on the stat the nature names, from Attack on, and not on a locked shadow" do
    raised, plain, locked, open = played(:ev_tints)
    assert_includes raised[0][0], t(:vitro_ev_nat_up)
    refute_includes plain[0][0], t(:vitro_ev_nat_up)
    refute_includes plain[0][0], t(:vitro_ev_nat_down)
    refute_includes locked[0][0], t(:vitro_ev_nat_up)
    assert_includes open[0][0], t(:vitro_ev_nat_up)
  end

  test "a nature's tint falls on its stats by the game's numbering, and a neutral one on none" do
    defense, speed, attack, neutral, sp_def, speed_up = played(:ev_natures)
    assert_includes speed_up, t(:vitro_ev_nat_up)
    assert_includes defense, t(:vitro_ev_nat_up)
    assert_includes speed, t(:vitro_ev_nat_down)
    refute_includes attack, t(:vitro_ev_nat_up)
    refute_includes attack, t(:vitro_ev_nat_down)
    refute_includes neutral, t(:vitro_ev_nat_up)
    refute_includes neutral, t(:vitro_ev_nat_down)
    refute_includes sp_def, t(:vitro_ev_nat_up)
  end

  test "a cost over the money says so, and the very money does not" do
    short, exact = played(:ev_short)
    assert_includes short[0][0], t(:awk_ev_short)
    refute_includes exact[0][0], t(:awk_ev_short)
  end

  test "the EV row is said again back from a question, only while the loop runs" do
    out, after = played(:ev_return)
    assert_equal 1, out.length
    assert_equal [], after
  end

  test "the Locke selector says its title, each row with its tick and note, and a toggle only as the state" do
    title, steps, kept, gone = played(:selector_locke)
    assert_equal [["Selecciona un modo de juego.", false]], title
    normal = "#{t(:list_entry, :name => 'Modo Normal', :n => 1, :tot => 4)}, #{t(:mk_on)}"
    assert_equal [["#{normal}. Sin reglas especiales.", false]], steps[0]
    perma = "#{t(:list_entry, :name => 'Modo Permadeath', :n => 2, :tot => 4)}, #{t(:mk_off)}"
    assert_equal [["#{perma}. Si se debilita, no revive.", true]], steps[1]
    assert_equal [[t(:mk_on), true]], steps[2]
    assert_includes kept, "Selecciona un modo de juego."
    assert_includes kept, t(:mk_on)
    assert_includes kept, "Si se debilita"
    assert_equal [[t(:list_entry, :name => "Terminar", :n => 4, :tot => 4), true]], steps[4]
    assert_equal [[t(:list_entry, :name => "Terminar", :n => 4, :tot => 4), true]], steps[5]
    assert_nil gone
  end

  test "below full, a selector's note waits on the info key" do
    steps, kept_row = played(:selector_medium)
    assert_equal [["#{t(:list_entry, :name => 'Movimientos aleatorios', :n => 1, :tot => 3)}, #{t(:mk_on)}", false]], steps[0]
    assert_equal steps[0][0][0], kept_row
  end

  test "the sandbox selector, which builds itself, pairs each option with its own note" do
    title, steps = played(:selector_sandbox)
    assert_equal [["¿Cómo quieres jugar?", false]], title
    assert_equal [["#{t(:list_entry, :name => 'Original', :n => 1, :tot => 2)}. Vive los eventos.", false]], steps[0]
    assert_equal [["#{t(:list_entry, :name => 'Libre', :n => 2, :tot => 2)}. Omite los eventos.", true]], steps[1]
  end

  test "a selector with no title says nothing for one" do
    title, steps = played(:selector_adv)
    assert_equal [], title
    assert_equal [["#{t(:list_entry, :name => 'Uno', :n => 1, :tot => 1)}. Primero.", false]], steps[0]
  end

  test "the shop of Pokemon keeps the entry the panel paints for the info key, and other shops stay core's" do
    line, kept, kept_row, other, other_row, closing = played(:mart)
    assert_equal "Pichu (Lv.5), 100 F", line
    assert_equal "Pichu (Lv.5), 100 F. Almacena electricidad.", kept
    assert_equal "Pichu (Lv.5), 100 F", kept_row
    assert_equal "Poción, $ 300", other
    assert_equal "Poción, $ 300", other_row
    assert_equal t(:pc_cancel), closing
  end

  test "the list of Pokedexes says its row again as a Pokedex returns" do
    first, same, back = played(:dex_list)
    assert_equal 1, first.length
    assert_includes first[0][0], "Johto"
    assert_equal [], same
    assert_equal first[0][0], back[0][0]
  end

  test "a Pokedex's fade under the list does not count as a return for the pause menu; the list closing does" do
    assert_equal [0, 1], played(:dex_seam)
  end
end
