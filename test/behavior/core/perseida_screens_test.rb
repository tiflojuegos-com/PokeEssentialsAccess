# Perseida's own screens and minigames, loaded with its whole profile over doubles with the shape of its scripts: the sign's
# pages of the summary, the Pokegear, the type choice, the gachapon's counter and prizes, the notices, the claw machine, the
# ghost gym's checklist and rooms, the crossings, the title, the workbench's key bar, the quests' colours and key bar, the
# PC trade, the party menu's star powers and the money codes of its messages.
class PerseidaScreensTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    ACTIVARMANA = 47
    VARMANA = 121

    def pbMaxMana; 200; end

    # 0055_Messages: its money counts in hundredths, and its units.
    def pbGoldCountDisplay; 12.5; end
    def pbGoldUnit(complete = false); complete ? " Coronas" : "<s> C</s>"; end
    def drawFormattedTextEx2(_bitmap, _x, _y, _width, _height, _text, _base = nil, _shadow = nil, _outline = true); end

    # 0235_Quest_Config: a colour by its name, as the string a quest keeps.
    def colorQuest(color); "hex-#{color}"; end

    # 0216_Menu_CometryEating and 0300_Bank.
    def cometryNotification; :slid; end
    BankWindow = Struct.new(:text)
    def pbDisplayBankWindow(_msgwindow, _goldwindow); BankWindow.new("Ahorros:\n<ar>12.5 C</ar>"); end

    module PBItems
      FICHAGATIBOX = 449
    end

    # The sign's page as drawInfoZodiac paints it, its description after the rest; the power's page is a modal loop.
    class PokemonSummaryScene
      def drawInfoZodiac(pokemon)
        pbDrawTextPositions(nil, [["Objeto", 66, 318], ["Ninguno", 16, 352], [pokemon.name, 46, 12], ["5", 46, 42],
                                  ["Signo: #{pokemon.pbGetBirthsignName}", 238, 90],
                                  ["Poder: #{pokemon.pbGetPowerName2}", 238, 284]])
        drawFormattedTextEx2(nil, 238, 316, 276, 0, "Pulsa C o Espacio para ver mas información.")
        drawFormattedTextEx2(nil, 238, 124, 276, 0, "<c3=98a1ff,3050c8>Sube el Ataque.</c3>")
      end

      def drawInfoPageZodiac(pokemon)
        pbUpdate
        yield pokemon if block_given?
      end
    end

    # The Pokegear: its rows named by MenuHandlers, its update run by its loop each frame.
    module MenuHandlers
      NAMES = { :MAPA => "Mapa", :PHONE => "Telefono" }
      def self.getName(ref); NAMES[ref]; end
    end

    class PokemonMenu2_Scene
      attr_accessor :index

      def initialize(entries)
        @entries = entries
        @index = 0
      end

      def update; end
    end

    # The screen that runs it, whole in one call, and the pause menu it opens from.
    class PokemonMenu2
      def pbStartPokemonMenu2; :closed; end
    end

    class Menu2
      def initialize(items)
        @items = items
        @selected_item = 0
      end

      def redrawSelector; end
      def pbUpdate; yield if block_given?; end
    end

    # The type choice: pictures named by @items, the selector redrawn by its loop; pbStartScene draws it once too.
    class SeleccionTipo
      attr_accessor :selected_item

      def initialize
        @items = [["Normal", "Normal"], ["Fighting", "Lucha"]]
        @selected_item = 0
      end

      def pbStartScene; redrawSelector; end
      def redrawSelector; end
    end

    # The gachapon: three buttons, its loop in update.
    Banner = Struct.new(:name, :rewards, :stars, :description)

    class GachaScene
      attr_accessor :sel

      def initialize(banners)
        @banners = banners
        @sprites = {}
        @sel = 1
        @banner_sel = 0
      end

      def refresh; end
      def dispose; end
      def summaryWindow(_width, _interpad); end
      def rewardAnim(_filename, _stars); end
      def itemReward(_item, _stars); end
    end

    # The claw machine: its hand at 42 at rest, its turns painted as it opens and on each throw.
    Hand = Struct.new(:y)

    class ClawMachine
      attr_accessor :item

      def pbStartScene(chance)
        @chances = chance
        @chance = 0
        @claw = { "clawhand" => Hand.new(42) }
        pbDrawText
      end

      def pbDrawText; end
      def pbMain; yield self if block_given?; end
      def pbEndScene; end

      def drop
        @chance += 1
        pbDrawText
        @claw["clawhand"].y = 222
      end

      def lift; @claw["clawhand"].y = 42; end
    end

    # The checklist: a tick for each evidence (ch0-4) and ghost (fan5-9), by the frame src_rect shows.
    Tick = Struct.new(:src_rect)
    TickRect = Struct.new(:x)

    class Phasmophobia
      attr_accessor :selected

      def initialize
        @selected = 0
        @sprites = {}
        (0...5).each { |i| @sprites["ch#{i}"] = Tick.new(TickRect.new(0)) }
        (5...10).each { |i| @sprites["fan#{i}"] = Tick.new(TickRect.new(0)) }
      end

      def tick(key, frame); @sprites[key].src_rect.x = frame; end
      def show; yield self if block_given?; end
    end

    # The crossing: pbStartScene runs it whole.
    class Seagallop_Scene
      def pbStartScene(_mirror, _boatpic); :crossed; end
    end

    # The title: the credits cyclePics fades in, and the style that takes the keys after its intro.
    class Scene_Intro
      def initialize(pics); @pics = pics; end
      def cyclePics(_pics); :faded; end
    end

    class GenSevenStyle
      def intro; :played; end
    end

    # The workbench: rows [item, ingredients, yield], its adapter naming them.
    class CraftAdapter
      def getName(item); item.to_s; end
      def getQuantity(_item); 3; end
    end

    class ItemCraft_Scene
      def initialize(stock)
        @stock = stock
        @adapter = CraftAdapter.new
      end

      def pbRedrawItem(_index, _volume); end
    end

    # The quests: the list's rows by their colour, and the heading and key bar pbStartScene paints.
    Quest = Struct.new(:id, :stage, :location, :story, :new, :color)

    class QuestBook
      def getName(id); "Mision #{id}"; end
    end
    $quest_data = QuestBook.new

    class Window_Quest
      def initialize(quests); @quests = quests; end
    end

    class QuestList_Scene
      def initialize
        @quests_text = ["Activas"]
        @current_quest = 0
      end

      def pbStartScene
        pbDrawTextPositions(nil, [["Misiones Activas", 6, -2]])
        drawFormattedTextEx(nil, 38, 312, 452, "<c2=hex-blue>FLECHAS:</c2> Mover Cursor")
        drawFormattedTextEx(nil, 38, 344, 452, "<c2=hex-blue>Q/W:</c2> Saltar inicio/final de la lista")
      end

      def swapQuestType; pbDrawTextPositions(nil, [["Misiones Activas", 6, -2]]); end
      def pbQuest(_quest); end
    end

    # A trade from the PC picks in the storage box, whose selection loop asks again after each refusal.
    class PokemonStorageScene
      def pbSelectBox(_party); :selected; end
    end

    class PokemonStorageScreen
      def initialize(scene); @scene = scene; end

      def pbChooseTradePoke(_tradepoke, _ableProc)
        yield if block_given?
        2.times { @scene.pbSelectBox(nil) }
        [0, 1]
      end
    end

    GymMap = Struct.new(:map_id)

    # The party's menu: a row's second field as @colorKey, 1 painted blue.
    class Window_CommandPokemonColor
      attr_accessor :index

      def initialize(commands, keys)
        @commands = commands
        @colorKey = keys
        @index = 0
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    # A Pokemon of this game, with its sign and star power.
    def signed(opts = {})
      pk = TestPoke.build({ :name => "Bulby", :happiness => 88 }.merge(opts))
      pk.define_singleton_method(:pbGetBirthsignName) { "Vena" }
      pk.define_singleton_method(:pbGetPowerName2) { "Luz Negra" }
      pk.define_singleton_method(:pbGetPowerDesc2) { "<c3=98a1ff,3050c8>Cura al equipo.</c3>" }
      pk.define_singleton_method(:hasMegaForm?) { opts[:mega] ? true : false }
      pk
    end

    def summary_play
      probe(:sign_page) do
        pk = signed
        scene = PokemonSummaryScene.new(pk)
        [said { scene.drawInfoZodiac(pk) }, said { scene.drawInfoZodiac(pk) }]
      end
      probe(:power_page) do
        pk = signed(:mega => true)
        scene = PokemonSummaryScene.new(pk)
        scene.drawInfoZodiac(pk)
        kept = nil
        opened = said { scene.drawInfoPageZodiac(pk) { kept = PokeAccess::Info.instance_variable_get(:@kind) } }
        scene.pbUpdate
        closed = PokeAccess::Info.instance_variable_get(:@kind)
        [opened, kept, said { scene.drawInfoZodiac(pk) }.length, closed]
      end
      probe(:power_plain) { said { PokemonSummaryScene.new(signed).drawInfoPageZodiac(signed) } }
      probe(:sheet) do
        shadow = signed
        shadow.define_singleton_method(:isShadow?) { true }
        [PokeAccess::Info.summary_text(signed), PokeAccess::Info.summary_text(signed(:mega => true)),
         PokeAccess::Info.summary_text(shadow)]
      end
      probe(:sign_mega) do
        pk = signed(:mega => true)
        said { PokemonSummaryScene.new(pk).drawInfoZodiac(pk) }
      end
    end

    def pokegear_play
      probe(:gear) do
        PokeAccess::NeoMenu.consume_return?
        scene = PokemonMenu2_Scene.new([:MAPA, :PHONE])
        first = said { scene.update }
        kind = PokeAccess::Info.instance_variable_get(:@kind)
        same = said { scene.update }
        scene.index = 1
        moved = said { scene.update }
        PokeAccess::NeoMenu.mark_return
        [first, kind, same, moved, said { scene.update }]
      end
      probe(:gear_closes) do
        menu = Menu2.new([["Menu_pokegear", "Pokegear", "openPokedexII"]])
        back = nil
        ret = nil
        menu.pbUpdate do
          menu.redrawSelector
          back = said { ret = PokemonMenu2.new.pbStartPokemonMenu2 }
        end
        [back, ret, said { PokemonMenu2.new.pbStartPokemonMenu2 }]
      end
    end

    def type_choice_play
      probe(:type_choice) do
        scene = SeleccionTipo.new
        opened = said { scene.pbStartScene }
        first = said { scene.redrawSelector }
        same = said { scene.redrawSelector }
        scene.selected_item = 1
        [opened, first, same, said { scene.redrawSelector }]
      end
    end

    def gacha_play
      was = $PokemonBag
      $PokemonBag = Object.new
      $PokemonBag.define_singleton_method(:pbQuantity) { |item| item == :FICHAGATIBOX ? 3 : 0 }
      banner = Banner.new("Antiguos Eventos", ["Graphics/Battlers/FrontShiny/163", "Graphics/Icons/item280",
                                               "Graphics/Battlers/Front/200_10"], [5, 4, 5],
                          "<u><b>Premios obtenibles:</b></u>\n\n***** Hoothoot Variolor 5% *****\n\n" \
                          "**** Master Ball 25% ****\n\n¡Y muchos objetos más!")
      probe(:gacha_refresh) do
        scene = GachaScene.new([banner])
        said { scene.refresh }
      end
      probe(:gacha_info) { said { GachaScene.new([banner]).summaryWindow(439, 5) } }
      probe(:gacha_prize) { said { GachaScene.new([banner]).itemReward(PBItems::FICHAGATIBOX, 5) } }
      $PokemonBag = was
    end

    def notices_play
      probe(:cometry) { [said { cometryNotification }, cometryNotification] }
      probe(:bank) do
        window = nil
        [said { window = pbDisplayBankWindow(nil, nil) }, window.class.name]
      end
    end

    def claw_play
      probe(:claw) do
        scene = ClawMachine.new
        opened = said { scene.pbStartScene(5) }
        rows = []
        before_first = said { scene.pbDrawText }
        scene.pbMain do
          rows.push(said { PokeAccess::Frame.run_pollers })
          rows.push(said { scene.drop })
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.lift
          rows.push(said { PokeAccess::Frame.run_pollers })
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.item = 12
          rows.push(said { scene.drop })
          scene.lift
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.item = nil
          rows.push(said { scene.drop })
          scene.lift
          rows.push(said { PokeAccess::Frame.run_pollers })
        end
        kept = PokeAccess::Info.instance_variable_get(:@kind)
        scene.pbEndScene
        [opened, rows, kept, PokeAccess::Info.instance_variable_get(:@kind), before_first]
      end
    end

    def checklist_play
      probe(:checklist) do
        opened = nil
        scene = nil
        opened = said { scene = Phasmophobia.new }
        rows = []
        scene.show do
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.tick("ch0", 20)
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.selected = 5
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.tick("fan5", 40)
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.tick("fan5", 60)
          rows.push(said { PokeAccess::Frame.run_pollers })
          (6..9).each do |row|
            scene.selected = row
            rows.push(said { PokeAccess::Frame.run_pollers })
          end
        end
        [opened, rows, PokeAccess::Info.instance_variable_get(:@kind)]
      end
    end

    # Runs one frame's pollers in the gym with this state, answering what they said.
    def gym_frame(switches = {}, variables = {})
      switches.each { |id, value| $game_switches[id] = value }
      variables.each { |id, value| $game_variables[id] = value }
      said { PokeAccess::Frame.run_pollers }
    end

    def gym_play
      map = $game_map
      switches = $game_switches
      variables = $game_variables
      $game_map = GymMap.new(107)
      $game_switches = Hash.new(false)
      $game_variables = Hash.new(0)
      PokeAccess::Cursor.reset_global
      probe(:gym) do
        rows = []
        rows.push(gym_frame({ 234 => true, 235 => true, 237 => true }, { 127 => 3, 128 => 100, 132 => 1 }))
        rows.push(gym_frame({ 230 => true }))
        rows.push(gym_frame({}, { 132 => 3 }))
        rows.push(gym_frame)
        rows.push(gym_frame({ 239 => true }))
        rows.push(gym_frame({ 238 => true }))
        rows.push(gym_frame({}, { 128 => 91 }))
        rows.push(gym_frame({}, { 128 => 90 }))
        rows.push(gym_frame({}, { 133 => 1 }))
        rows.push(gym_frame({}, { 133 => 0 }))
        rows.push(gym_frame({}, { 132 => 1 }))
        rows.push(gym_frame({ 230 => false }, { 132 => 3, 128 => 50 }))
        rows.push(gym_frame({ 230 => true }))
        rows
      end
      probe(:gym_each_evidence) do
        [234, 235, 236, 237].map do |switch|
          [234, 235, 236, 237].each { |id| $game_switches[id] = id == switch }
          $game_switches[238] = false
          $game_switches[239] = true
          PokeAccess::PerseidaGhostGym.shown_here
        end
      end
      probe(:gym_sanity) do
        $game_switches[230] = true
        with = PokeAccess::Info.trainer_info
        $game_map = GymMap.new(5)
        [with, PokeAccess::Info.trainer_info, PokeAccess::PerseidaGhostGym.sanity]
      end
      $game_map = map
      $game_switches = switches
      $game_variables = variables
    end

    def crossing_play
      probe(:crossing) do
        scene = Seagallop_Scene.new
        ret = nil
        [said { ret = scene.pbStartScene(false, "waterBoat") }, said { scene.pbStartScene(true, "empoleon") }, ret]
      end
    end

    def title_play
      probe(:title) do
        scene = Scene_Intro.new(["intro1", "intro2", "intro0"])
        style = GenSevenStyle.new
        [said { scene.cyclePics(["intro1", "intro2", "intro0"]) }, said { style.intro }, style.intro]
      end
    end

    def craft_play
      probe(:craft_bar) do
        scene = ItemCraft_Scene.new([[:POTION, [:ORANBERRY, 1], 2], [:ETHER, [:ORANBERRY, 1]]])
        [said { scene.pbRedrawItem(0, 1) }, said { scene.pbRedrawItem(1, 1) }]
      end
    end

    def quests_play
      probe(:quest_rows) do
        window = Window_Quest.new([Quest.new(3, 1, nil, false, false, colorQuest("cyan")),
                                   Quest.new(4, 1, nil, false, false, colorQuest("orange")),
                                   Quest.new(5, 1, nil, false, false, colorQuest(nil))])
        (0..2).map { |i| PokeAccess::QuestUI.text(window, i) }
      end
      probe(:quest_opening) do
        scene = QuestList_Scene.new
        [said { scene.pbStartScene }, said { scene.swapQuestType }]
      end
    end

    def trade_play
      probe(:trade) do
        scene = PokemonStorageScene.new
        ret = nil
        opening = nil
        line = said { ret = PokemonStorageScreen.new(scene).pbChooseTradePoke(:a, nil) { opening = said {} } }
        [opening, line, ret, said { scene.pbSelectBox(nil) }]
      end
    end

    def money_play
      probe(:money_codes) do
        [PokeAccess.clean("Son 25\\MP, ¿vale?"), PokeAccess.clean("Cuesta 3\\mp."), PokeAccess.clean("Tienes \\PM."),
         PokeAccess.clean("\\tg[Mamá]\\G\\MGMuy bien"), PokeAccess.clean("Sin codigos")]
      end
    end

    # What the screens that write key hints say with key hints left out.
    def brief_play
      probe(:brief) do
        was = PokeAccess::Config.verbosity
        PokeAccess::Config.verbosity = :brief
        pk = signed
        row = [said { PokemonSummaryScene.new(pk).drawInfoZodiac(pk) }, said { ClawMachine.new.pbStartScene(5) },
               said { Phasmophobia.new }, said { QuestList_Scene.new.pbStartScene },
               said { ItemCraft_Scene.new([[:POTION, [:ORANBERRY, 1]]]).pbRedrawItem(0, 1) }]
        PokeAccess::Config.verbosity = was
        row
      end
    end

    def party_menu_play
      probe(:party_menu) do
        win = Window_CommandPokemonColor.new(["Datos", "Destello", "Tributo(80)"], [nil, 1, 1])
        (0..2).map do |i|
          win.index = i
          PokeAccess::Menus.focused_text(win)
        end
      end
    end

    summary_play
    pokegear_play
    type_choice_play
    gacha_play
    notices_play
    claw_play
    checklist_play
    gym_play
    crossing_play
    title_play
    craft_play
    quests_play
    trade_play
    money_play
    party_menu_play
    brief_play
  RUBY

  profile "perseida", WORLD, PLAY

  ENTRY = lambda { |name, n, tot| PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => tot) }

  test "the screens' hooks all bind" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    assert_equal [], played(:absent_functions) & %w[cometryNotification pbDisplayBankWindow drawFormattedTextEx2]
  end

  test "with key hints left out, the screens say what they show and no keys" do
    sign, claw, checklist, quests, craft = played(:brief)
    assert_equal [["Signo: Vena. Sube el Ataque. Poder: Luz Negra", false]], sign
    assert_equal [[t(:perseida_claw_title, :max => 5), false]], claw
    assert_equal [["Usando la evidencia obtenida, selecciona a uno de los posibles fantasmas.", false]], checklist
    assert_equal [["Misiones Activas", true]], quests
    refute_includes craft[0][0], "C: Crear"
  end

  test "the sign's page is said as painted, top to bottom, without what stays on the left, and once" do
    page, again = played(:sign_page)
    assert_equal [["Signo: Vena. Sube el Ataque. Poder: Luz Negra. Pulsa C o Espacio para ver mas información.", false]], page
    assert_equal [], again
  end

  test "the star power's page cuts in with its mega line, is kept for the info key, and the sign's page comes back" do
    opened, kept, back, closed = played(:power_page)
    assert_equal [["Poder: Luz Negra. Cura al equipo. Este Pokémon puede cambiar de forma tras utilizar su Poder Estelar.", true]],
                 opened
    assert_equal :text, kept, "through the page's own loop"
    assert_equal :pokemon, closed
    assert_equal 1, back
    assert_equal [["Poder: Luz Negra. Cura al equipo.", true]], played(:power_plain)
  end

  test "the data sheet says the sign, but a Shadow Pokemon's has none" do
    sheet, mega, shadow = played(:sheet)
    assert_includes sheet, "Signo de Bulby: Vena"
    refute_includes sheet, t(:perseida_mega_able)
    assert_includes mega, "Signo de Bulby: Vena, #{t(:perseida_mega_able)}"
    refute_includes shadow, "Signo de"
  end

  test "the sign's page says the mark over its token on a Pokemon that can Mega Evolve" do
    assert_equal [["Signo: Vena. Sube el Ataque. Poder: Luz Negra. #{t(:perseida_mega_able)}. " \
                   "Pulsa C o Espacio para ver mas información.", false]], played(:sign_mega)
  end

  test "a command window says a star power as such and a field move as core does" do
    assert_equal ["Datos", "Destello, #{t(:mn_field_move)}", "Tributo(80), #{t(:perseida_star_power)}"], played(:party_menu)
  end

  test "the Pokegear says its rows, the first queued, and the row again when an entry returns" do
    first, kind, same, moved, back = played(:gear)
    assert_equal [[ENTRY.call("Mapa", 1, 2), false]], first
    assert_equal :trainer, kind
    assert_equal [], same
    assert_equal [[ENTRY.call("Telefono", 2, 2), true]], moved
    assert_equal [[ENTRY.call("Telefono", 2, 2), false]], back
  end

  test "closing the Pokegear says the pause menu's entry again, and from the map nothing" do
    back, ret, from_map = played(:gear_closes)
    assert_equal 1, back.length
    assert_includes back[0][0], "Pokegear"
    assert_equal :closed, ret
    assert_equal [], from_map
  end

  test "the type choice says its question, then each type under the selector" do
    opened, first, same, moved = played(:type_choice)
    assert_equal [["Escoge el tipo con el que seas más afin.", false]], opened
    assert_equal [[ENTRY.call("Normal", 1, 2), false]], first
    assert_equal [], same
    assert_equal [[ENTRY.call("Lucha", 2, 2), true]], moved
  end

  test "the gachapon counts the tokens of the bag and names the prizes its pictures show" do
    line = played(:gacha_refresh)[0][0]
    assert_includes line, t(:perseida_gacha_tokens, :name => "Item449", :n => 3)
    refute_includes line, t(:gacha_coins, :n => 0)
    assert_includes line, t(:gacha_prize, :name => "Especie163, #{t(:pk_shiny)}", :n => 5)
    assert_includes line, t(:gacha_prize, :name => "Item280", :n => 4)
    assert_includes line, t(:gacha_prize, :name => "Especie200", :n => 5)
    assert_includes line, "Tirar"
  end

  test "a banner's description says each tier as stars, with no asterisks" do
    line = played(:gacha_info)[0][0]
    assert_includes line, "Premios obtenibles:"
    assert_includes line, t(:gacha_prize, :name => "Hoothoot Variolor 5%", :n => 5)
    assert_includes line, t(:gacha_prize, :name => "Master Ball 25%", :n => 4)
    refute_includes line, "*"
  end

  test "an item prize is named with its stars, its reveal saying nothing more" do
    assert_equal [[t(:gacha_prize, :name => "Item449", :n => 5), true]], played(:gacha_prize)
  end

  test "Cometry's banner says she wants a word, and the savings window its amount" do
    cometry, value = played(:cometry)
    assert_equal [[t(:perseida_cometry_notice), false]], cometry
    assert_equal :slid, value
    said, window = played(:bank)
    assert_equal [["Ahorros: 12.5 C", false]], said
    assert_equal "BankWindow", window
  end

  test "the claw machine says its turns and how it plays, each throw, and a throw that comes back empty" do
    opened, rows, kept, cleared, before_first = played(:claw)
    assert_equal [], before_first, "the count painted before the first throw"
    title = t(:perseida_claw_title, :max => 5)
    hint = t(:perseida_claw_hint, :key => "C", :back => "X")
    assert_equal [["#{title} #{hint}", false]], opened
    assert_equal [[], [[t(:perseida_claw_turn, :n => 1, :max => 5), true]], [], [[t(:perseida_claw_miss), false]], [],
                  [[t(:perseida_claw_turn, :n => 2, :max => 5), true]], [],
                  [[t(:perseida_claw_turn, :n => 3, :max => 5), true]], [[t(:perseida_claw_miss), false]]], rows
    assert_equal :text, kept
    refute_equal :text, cleared
  end

  test "the checklist says what it asks, each row by its tick, and each ghost with its evidence" do
    opened, rows, kind_after = played(:checklist)
    refute_equal :text, kind_after, "the info key lets go of the row when it closes"
    assert_equal [["Usando la evidencia obtenida, selecciona a uno de los posibles fantasmas. " +
                   t(:perseida_ghost_keys, :key => "C", :back => "X"), false]], opened
    frosslass = lambda do |state|
      t(:perseida_ghost_row, :name => "Frosslass", :state => t(state),
                             :list => "Orbes Espectrales, Temperaturas heladas, Reacciona a caja de música")
    end
    assert_equal [["Territorial, #{t(:perseida_ghost_unmarked)}", false]], rows[0]
    assert_equal [["Territorial, #{t(:perseida_ghost_marked)}", true]], rows[1]
    assert_equal [[frosslass.call(:perseida_ghost_open), true]], rows[2]
    assert_equal [[frosslass.call(:perseida_ghost_out), true]], rows[3]
    assert_equal [[frosslass.call(:perseida_ghost_chosen), true]], rows[4]
    others = [["Houndstone", "Territorial, Orbes Espectrales, Huellas de Ectoplasma"],
              ["Spiritomb", "Territorial, Orbes Espectrales, Temperaturas heladas"],
              ["Mismagius", "Territorial, Huellas de Ectoplasma, Reacciona a caja de música"],
              ["Gengar", "Huellas de Ectoplasma, Temperaturas heladas, Reacciona a caja de música"]]
    others.each_with_index do |(name, list), i|
      row = t(:perseida_ghost_row, :name => name, :state => t(:perseida_ghost_open), :list => list)
      assert_equal [[row, true]], rows[5 + i]
    end
  end

  test "the gym says what the ghost's room shows, the lights, the sanity and the hunt, while it runs" do
    rows = played(:gym)
    shown = lambda { |list| [[t(:perseida_ghost_shown, :list => list), false]] }
    assert_equal [], rows[0], "not running yet"
    assert_equal [], rows[1], "the state it starts in"
    assert_equal shown.call("Orbes Espectrales, Huellas de Ectoplasma"), rows[2], "entering the ghost's room"
    assert_equal [], rows[3]
    assert_equal shown.call("Orbes Espectrales, Huellas de Ectoplasma, Reacciona a caja de música"), rows[4], "the music box on"
    assert_equal shown.call("Huellas de Ectoplasma, Reacciona a caja de música") +
                 [[t(:perseida_ghost_lights_on), false]], rows[5], "the lights on hide the orbs"
    assert_equal [], rows[6], "the sanity between tens"
    assert_equal [[t(:perseida_ghost_sanity, :n => 90), false]], rows[7]
    assert_equal [[t(:perseida_ghost_hunt_on), false]], rows[8]
    assert_equal [[t(:perseida_ghost_hunt_off), false]], rows[9]
    assert_equal [], rows[10], "leaving the room"
    assert_equal [], rows[11], "the gym over"
    assert_equal shown.call("Huellas de Ectoplasma, Reacciona a caja de música"), rows[12], "another attempt, in the ghost's room"
  end

  test "each evidence shows by its own switch" do
    assert_equal [[1], [2], [3], [4]], played(:gym_each_evidence)
  end

  test "the info key says the sanity in the gym alone" do
    with, without, value = played(:gym_sanity)
    assert_includes with, t(:perseida_ghost_sanity, :n => 50)
    refute_includes without, t(:perseida_ghost_sanity, :n => 50)
    assert_nil value
  end

  test "each crossing is said as it starts, Empoleon's by its picture" do
    boat, empoleon, ret = played(:crossing)
    assert_equal [[t(:dh_gallop_sea), false]], boat
    assert_equal [[t(:perseida_gallop_empoleon), false]], empoleon
    assert_equal :crossed, ret
  end

  test "the title says its credits, a backdrop nothing, and the prompt when its intro ends" do
    credits, prompt, value = played(:title)
    lines = credits.uniq
    assert_equal 2, lines.length, "the suite loads every plugin, luka_title with its hook on the same method"
    assert_includes lines[0][0], "pokemonperseida.blogspot.com"
    assert_includes lines[1][0], "@Clara_Dragon"
    assert_equal [false, false], lines.map { |_text, cut| cut }
    assert_equal 1, prompt.length
    assert_includes prompt[0][0], t(:title_screen)
    assert_equal false, prompt[0][1]
    assert_equal :played, value
  end

  test "the workbench says its key bar after the first recipe alone" do
    first, second = played(:craft_bar)
    assert_equal 1, first.length
    assert_includes first[0][0], "C: Crear, Z: Lista de Recetas, X: Salir"
    assert_operator first[0][0].index("POTION"), :<, first[0][0].index("C: Crear")
    refute_includes second[0][0], "C: Crear"
  end

  test "a quest's row says the colour it is painted in, and one with the default colour none" do
    cyan, orange, plain = played(:quest_rows)
    assert_includes cyan, t(:perseida_quest_cyan)
    assert_includes orange, t(:perseida_quest_orange)
    assert_equal "Mision 5", plain
  end

  test "the quest list says its key bar after the heading on opening, and not on changing tab" do
    opening, tab = played(:quest_opening)
    assert_equal [["Misiones Activas", true], ["FLECHAS: Mover Cursor. Q/W: Saltar inicio/final de la lista", false]], opening
    assert_equal [["Misiones Activas", true]], tab
  end

  test "a trade from the PC says what the box is for, and keeps what it answers" do
    opening, line, ret, plain_box = played(:trade)
    assert_equal [], opening, "the box's first slot cuts in, so it waits for that"
    assert_equal [[t(:perseida_trade_pick), false]], line
    assert_equal [0, 1], ret
    assert_equal [], plain_box, "the PC's own box says nothing of it"
  end

  test "its messages' money codes say the game's unit, and the money in Crowns" do
    assert_equal ["Son 25 Coronas, ¿vale?", "Cuesta 3 C.", "Tienes 12.5 C.", "Mamá: Muy bien", "Sin codigos"], played(:money_codes)
  end
end
