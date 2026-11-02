# The Pokemon GS Vitro profile loaded whole, over doubles with the shape of its scripts: its field-move rules and words, the keys
# it reads and the ones that yield, the pause menu, the summary's rearranged pages and contest page, the party's marks, the bag's
# stones and hints, the quest detail, the region map's roamers, the encounter pages, the berry pots, the teleport menu, the title's
# warning, the controls screen, the Hall of Fame's ceremony and the starter selection. In a process of its own, since its overrides
# would reach every other test here.
class VitroProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    FOLLOW_EVENTNAME = "Dependent"
    EXPANDED_SUMMARY_INFO = true

    # The moves of its field rules and the memo page's icons, by the number each is stood for in these tests.
    module PBMoves
      WATERFALL = 1
      EMBER = 2
      SLASH = 3
      ROCKSMASH = 4
      STRENGTH = 5
      SUPERPOWER = 6
      SKULLBASH = 7
      IRONHEAD = 8
      ZENHEADBUTT = 9
      FLASH = 10
      SWEETSCENT = 11
      DEFOG = 12
      SOFTBOILED = 13
      MILKDRINK = 14
      HEALPULSE = 15
      LIFEDEW = 16
      SUNNYDAY = 17
      RAINDANCE = 18
      SANDSTORM = 19
      SNOWSCAPE = 20
      SURF = 21
      CUT = 22
      HEADBUTT = 23
      NAMES = { 21 => "Surf", 22 => "Corte", 2 => "Ascuas", 4 => "Golpe Roca", 5 => "Fuerza", 23 => "Golpe Cabeza",
                10 => "Destello", 11 => "Dulce Aroma", 12 => "Despejar", 13 => "Amortiguador", 17 => "Día Soleado",
                18 => "Danza Lluvia", 30 => "Placaje", 31 => "Arañazo" }
      def self.getName(id); NAMES[id] || "Mov#{id}"; end
    end
    def getConst(mod, sym); mod.const_defined?(sym) ? mod.const_get(sym) : nil; end

    # The party's compatibilities, as its pbCheckMove (0204_PSystem_Utilities) asks them: public at the top level, which it
    # calls on Kernel.
    $able_moves = []
    def pbCheckMove(move); $able_moves.include?(move) ? :a_pokemon : nil; end
    Object.send(:public, :pbCheckMove)

    def pbGetTimeNow; Time.local(2026, 11, 2, 9, 30); end
    def pbInSafari?; $in_safari; end
    def pbInBugContest?; $in_contest; end
    ContestState = Struct.new(:ballcount, :lastPokemon)
    $contest_state = ContestState.new(12, nil)
    def pbSafariState; $contest_state; end
    def pbBugContestState; $contest_state; end
    def pbHasDBand; $dynamax_band; end
    def pbHasTeraOrb; false; end
    def pbHiddenPower(_iv); [1, 70]; end
    def pbCanEvolveNow?(pk); pk.name == "Evolver"; end
    def clGetLevelMedia; 42; end
    def pbIsMegaStone?(item); item == 100; end
    def pbIsEvolutionItem?(item); item == 101; end
    $stone_asks = 0
    def pbCheckMegastoneSpecies(pk, _item); $stone_asks += 1; pk.name == "Mega" ? 1 : 0; end
    def pbCheckEvolution(pk, _item); $stone_asks += 1; pk.name == "Evolver" ? 1 : 0; end
    def pbGetContestMoveDescription(id); "Efecto #{id}"; end
    def drawFormattedTextEx2(_bitmap, _x, _y, _width, _height, _text, _base = nil, _shadow = nil, _outline = true); end
    def pbGetMessageFromHash(type, text); "#{type}:#{text}"; end
    module MessageTypes
      PlaceNames = 19
      PlaceDescriptions = 20
    end

    PBContestMoveData = Struct.new(:id) do
      def contestType; { 30 => "Tough", 32 => "Beauty", 33 => "Cool", 34 => "Smart" }[id] || "Cute"; end
      def hearts; id == 30 ? 3 : nil; end
      def jam; id == 30 ? 1 : nil; end
    end

    # The lens: its state, which the item and any running event change (0304_Eye of Truth).
    module LensOfTruth
      @active = false
      def self.active?; @active; end
      def self.toggle; @active = !@active; end
    end

    # The pause menu: entries [icon, label, function]; pbUpdate is its modal loop.
    class Menu2
      def initialize(items, selected = 0)
        @items = items
        @selected_item = selected
      end

      def redrawSelector; end
      def drawIcons; end
      def pbUpdate; yield if block_given?; end
    end

    # The summary as 0161_PScreen_Summary and 0234_Contest_Summary leave it, each page painted as they paint it.
    class PokemonSummaryScene
      attr_accessor :sprites

      def initialize(pokemon)
        @pokemon = pokemon
        @sprites = {}
      end

      def drawPage(_page); end

      def drawPageInfo
        pbDrawTextPositions(nil, [["N° Dex", 238, 176], [format("%03d #{@pokemon.name}", 25), 419, 176],
                                  ["Ash 00123", 390, 208]])
      end

      def drawPageData
        drawFormattedTextEx(nil, 238, 80, 268, "2 Enero, 2026<br>Encontrado con Nv. 5<br><c3=F83820,E09890>Ruta 29<br></c3>")
        pbDrawTextPositions(nil, [["Movimientos de Campo:", 238, 240]])
      end

      def drawPageStats
        pbDrawTextPositions(nil, [["Habilidad", 234, 284], ["Espesura", 342, 284]])
        drawFormattedTextEx2(nil, 234, 346, 272, 2, "Presiona C para más información.")
      end

      def drawPageStatsExpanded; yield if block_given?; end
      def drawPageMoves; end
      def drawPageRibbons; end

      def drawPageContestMoves
        pbDrawTextPositions(nil, [["Dulzura", 1, 1], ["Dureza", 1, 2], ["Belleza", 1, 3], ["Carisma", 1, 4], ["Ingenio", 1, 5],
                                  ["10", 2, 1], ["20", 2, 2], ["30", 2, 3], ["40", 2, 4], ["50", 2, 5], ["Brillo: 7", 66, 288]])
        pbDrawTextPositions(nil, [["Placaje", 256, 98], ["PP", 392, 130], ["35/35", 482, 130]])
      end

      def drawSelectedContestMove(_moveid); end

      def pbContestMoveSelection
        @sprites["movesel"] = Struct.new(:visible, :index).new(true, 0)
        drawSelectedContestMove(@pokemon.moves[0].id)
        pbUpdate
      end

      def pbUpdate; end
      def pbStartScene(_party, _partyindex); end
      def drawSelectedMove(_to_learn, _moveid); end
      def pbChooseMoveToForget(_move); end
    end

    # The party screen: pbStartScene paints the balanced level under the panels.
    class PokemonScreen_Scene
      def pbStartScene(party, _starthelptext, _annotations = nil, _multiselect = false); @party = party; end
    end

    class PokemonBag_Scene
      def pbStartScene(_bag, _choosing = false, _filter = nil, _reset = true); end
      def drawTMInfo(_move); end
    end

    # The region map: its sprites in a hash, its text repainted by update_text.
    class BetterRegionMap
      TileWidth = 16.0
      TileHeight = 16.0

      def initialize(window, data)
        @window = window
        @data = data
        @region = 0
      end

      def move_cursor_to(_x, _y); end
      def update_text; end
      def pbGetHealingSpot(_x, _y); end
      def main; yield if block_given?; end
      def dispose; end
    end
    RoamingSpecies = [[:RAIKOU, 40, 123]]
    module PBSpecies
      RAIKOU = 243
    end
    Spot = Struct.new(:x, :y)

    # Marin's SpriteHash: its sprites hold the map's scroll, which x and y tell.
    class ScrolledWindow
      attr_reader :x, :y

      def initialize(sprites, x, y)
        @sprites = sprites
        @x = x
        @y = y
      end

      def [](key); @sprites[key]; end
    end

    # The encounter list: drawAllTexts paints a page.
    class EncounterListUI
      def initialize(mapid = 3)
        @mapid = mapid
        @current_page = 0
      end

      def turn(page); @current_page = page; end
      def drawAllTexts(_page_name, _encounters = nil, _owned = 0); end
      def dispose; end
    end

    # The pots: @index over four arrays.
    class ItemBerryPots_Scene
      def initialize(plants)
        @berryData = plants
        @index = 0
      end

      def move(index); @index = index; pbUpdateCursor; end
      def pbUpdateCursor; end
      def pbBerryPlantVar(_idx); end
      def pbEndScene; end
    end

    # The teleport menu: pbRefresh repaints the destination under @index.
    class Teleport_Scene
      def initialize(destinations, unlocked)
        @destinations = destinations
        @unlocked = unlocked
        @index = 0
      end

      def pbUnlocked?(i); @unlocked.include?(i); end
      def move(index); @index = index; pbRefresh; end
      def pbRefresh; end
      def pbTransportar(_dest); end
    end

    # The language screen: updateSelection repaints the cursor, from its constructor on.
    class PokemonLanguageSelection
      def initialize
        @index = 0
        @languages = [["Español", ""], ["English", "english.dat"], ["French", "french.dat"]]
        updateSelection
      end

      def move(index); @index = index; updateSelection; end
      def updateSelection; end
    end

    # The warning: its constructor paints it and waits in pbMain.
    class SplashMessage
      def initialize
        drawFormattedTextEx(nil, 32, 48, 448, "<ac>Solo el enlace del blog oficial te garantiza la versión.")
        drawFormattedTextEx(nil, 16, 320, 480, "<ac>Juego creado por fans para fans.")
        pbMain
      end

      def pbMain; end
    end

    # The controls screen: each line painted beside the pictures of its keys.
    class ControlsDisplayScene
      PAGES = 2

      def drawPage(id = 0)
        if id == 0
          drawFormattedTextEx(nil, 88, 128, 400, "Confirmar una selección.")
          drawFormattedTextEx(nil, 88, 48, 400, "Mover el personaje principal.")
          drawFormattedTextEx(nil, 88, 300, 400, "Una línea sin tecla.")
          pbDrawImagePositions(nil, [["Graphics/Pictures/help/helpArrowKeys", 48, 48, 0, 0, -1, -1],
                                     ["Graphics/Pictures/help/helpCkey", 48, 140, 0, 0, -1, -1],
                                     ["Graphics/Pictures/help/helpSpacekey", 70, 140, 0, 0, -1, -1]])
        else
          drawFormattedTextEx(nil, 88, 48, 400, "Abrir el Log de Texto.")
          pbDrawImagePositions(nil, [["Graphics/Pictures/help/helpFkey", 68, 48, 0, 0, -1, -1]])
        end
      end

      def pbEndScene; end
    end

    # A window: its text set as it is made and set again as it is resized.
    class Window_AdvancedTextPokemon
      attr_reader :text

      def initialize(text = ""); self.text = text; end
      def text=(value); @text = value; end
    end

    # The ceremony: the windows of its HGSS style, in the order it writes them.
    class Jess_SalonFama
      def jsGen4_HGSS
        Window_AdvancedTextPokemon.new("<ac>¡Salón de la Fama!</ac> ")
        win = Window_AdvancedTextPokemon.new("<ac>Bulby</ac><ac>Bulbasaur ♂</ac> <ac> Nv. 50</ac> <ac>OT/Ash</ac>")
        win.text = win.text
        Window_AdvancedTextPokemon.new("<ac>¡Campeón de la Liga! ¡Felicidades!</ac> ")
      end
    end

    # The starter selection: the box says what it asks; pbConfirm holds its Yes and No.
    class DiegoWTsStarterSelection
      attr_accessor :endscene

      def initialize(pokemon = nil)
        @sprites = { "textbox" => Window_AdvancedTextPokemon.new("<ac>¿Cual quieres?</ac>") }
        @pokemon = pokemon
        @endscene = 0
      end

      def pbStartChoosing; end
      def pbAnimation; end
      def move(sel); @select = sel; pbAnimation; end
      def pbCloseScene; end

      def pbChoiceBoxes(switch)
        pbDrawTextPositions(nil, [["Sí", 442, 184], ["No", 442, 230]]) if switch == 0
        @choicesel = 1
        :boxes
      end

      def ask(text)
        @sprites["textbox"].text = text
        pbConfirm
      end

      def pbConfirm
        [0, 1, 2].each do |sel|
          @choicesel = sel
          PokeAccess::Frame.run_pollers
        end
        1
      end
      def pbChooseBall; ask("<ac>¿Quieres a Totodile, <br>del tipo Agua?</ac>"); end
    end

    class GenderSelectorScene
      def initialize(frames = [])
        @frames = frames
        @select = -1
      end

      def pbStartScene(_menuskin = false); end

      def pbUpdate
        @frames.each do |sel|
          @select = sel
          PokeAccess::Frame.run_pollers
        end
      end

      def pbEndScene; end
    end

    class QuestList_Scene
      def drawQuestDesc(_quest); end
      def drawOtherInfo(_quest); end
    end
    Window_Quest = Class.new

    # An event: its name, and the page the engine left it with.
    class FieldEvent
      attr_reader :name

      def initialize(name, page = :a_page)
        @name = name
        @page = page
        @event = Struct.new(:pages).new([:a_page])
      end
    end

    # What the map's readers hook, read in vitro_map_test.rb.
    class TarotAnimation
      def reveal_card(_sprite, _carta_name); end
      def dispose; end
    end

    class Game_Map
      def spawnPokemonEvent(_x, _y, _pokemon, _spawner_id, _encounter_type); end
    end

    class SubtitleSystem
      def show(_text, _duration = 120, _opts = {}); end
      def update; end
    end

    class PokeBattle_Battle
      def pbDisplayConfirm(_msg); end
    end

    class PokeBattle_BugContestBattle < PokeBattle_Battle
      def pbStorePokemon(_pokemon); end
    end
  RUBY

  PLAY = <<-'RUBY'
    # Runs the block with the party able to use just these moves.
    def with_moves(moves)
      was = $able_moves
      $able_moves = moves
      yield
    ensure
      $able_moves = was
    end

    # Runs the block under a verbosity level.
    def at_level(level)
      was = PokeAccess::Config.verbosity
      PokeAccess::Config.verbosity = level
      yield
    ensure
      PokeAccess::Config.verbosity = was
    end

    # Runs the block with the mod on and the game in front.
    def live
      keys = PokeAccess::Keys
      focus = keys.method(:focused?)
      on = keys.enabled
      keys.define_singleton_method(:focused?) { true }
      keys.instance_variable_set(:@enabled, true)
      yield keys
    ensure
      keys.define_singleton_method(:focused?, focus)
      keys.instance_variable_set(:@enabled, on)
    end

    # A Pokemon with what the pages ask: its moves as the game's objects, and the moves it can learn.
    def mon(opts = {})
      able = opts.delete(:able) || []
      types = opts.delete(:types) || []
      move = Struct.new(:id, :pp, :totalpp)
      pk = TestPoke.build({ :name => "Bulby", :happiness => 88, :moves => [move.new(30, 35, 35), move.new(0, 0, 0)] }.merge(opts))
      pk.define_singleton_method(:isCompatibleWithMove?) { |id| able.include?(id) }
      pk.define_singleton_method(:hasType?) { |t| types.include?(t) }
      pk
    end

    def rules_play
      probe(:profile_name) { PokeAccess::Game.profile_name }
      probe(:hints) { PokeAccess::Config.key_hint_letters }
      probe(:plain) { PokeAccess::World::Probe.plain? }
      probe(:labels) { [:a, :x, :l, :r].map { |b| PokeAccess::Config.rebind_labels[b] } }
      fm = PokeAccess::FieldMoves
      probe(:cut) do
        [[:SLASH], [:EMBER], [:SURF]].map { |moves| with_moves(moves) { fm.can?(:CUT) } }
      end
      probe(:surf) { [[:WATERFALL], [:SURF]].map { |moves| with_moves(moves) { fm.can?(:SURF) } } }
      probe(:strength) { [[:STRENGTH], [:SUPERPOWER], []].map { |moves| with_moves(moves) { fm.can?(:STRENGTH) } } }
      probe(:rock) { [[:ROCKSMASH], []].map { |moves| with_moves(moves) { fm.can?(:ROCKSMASH) } } }
      probe(:stock_moves) { [:WATERFALL, :DIVE].map { |move| PokeAccess::VitroFieldMoves.handles?(move) } }
      probe(:cut_name) do
        [with_moves([:SLASH, :EMBER]) { fm.name(:CUT) }, with_moves([:EMBER]) { fm.name(:CUT) }, with_moves([]) { fm.name(:CUT) },
         with_moves([:EMBER]) { fm.name(:SURF) }]
      end
      probe(:labels_of) do
        loc = PokeAccess::Locator
        [FieldEvent.new("Arbol"), FieldEvent.new("Roca"), FieldEvent.new("Cascada/size(5,1)"), FieldEvent.new("Arbol", nil),
         FieldEvent.new("Papelera")].map { |ev| loc.fieldmove_label(ev) }
      end
      probe(:thorns) { [PokeAccess::I18n.t(:loc_cut_tree), PokeAccess::I18n.t(:loc_rock_smash)] }
      probe(:waterfall_carry) do
        move = Struct.new(:code, :parameters)
        route = Struct.new(:list).new([move.new(37, []), move.new(14, [0, -2]), move.new(14, [0, -2]), move.new(12, []),
                                       move.new(38, []), move.new(0, [])])
        command = Struct.new(:code, :parameters, :indent)
        list = [command.new(111, [12, "pbUseWaterfall"], 0), command.new(209, [-1, route], 1), command.new(412, [], 0), command.new(0, [], 0)]
        ev = FieldEvent.new("Cascada/size(5,1)")
        ev.instance_variable_set(:@list, list)
        [:WATERFALL, :SURF].map { |known| with_moves([known]) { PokeAccess::Routes::Effects.touch_effects(ev, true, 900, 5, 5, true) } }
      end
      probe(:waterfall_page) do
        check = PokeAccess::EventPages::ScriptCondition
        [with_moves([:WATERFALL]) { check.evaluate("pbUseWaterfall", {}) }, with_moves([:SURF]) { check.evaluate("pbUseWaterfall", {}) }]
      end
      probe(:company) do
        person = [nil] * 8 + ["Alguien"]
        follower = [nil] * 8 + [FOLLOW_EVENTNAME]
        was = $PokemonGlobal
        $PokemonGlobal = Struct.new(:dependentEvents).new([follower])
        alone = PokeAccess::VitroFieldMoves.only_the_follower?
        $PokemonGlobal = Struct.new(:dependentEvents).new([follower, person])
        out = [alone, PokeAccess::VitroFieldMoves.only_the_follower?]
        $PokemonGlobal = was
        out
      end
    end

    def keys_play
      r = PokeAccess::Remap
      probe(:extras) { r.extras.map { |row| [row[0], row[1], row[2]] } }
      probe(:raw_names) { [:T, :B, :J, :P, :Y, :M, :F].map { |k| r.sym_for_extra(k) } }
      probe(:yields) { [:T, :J, :M, :B, :P, :Y].map { |k| r.extra_remapped?(k) } }
      probe(:alt_m) do
        live do |_keys|
          gaks = PokeAccess::Keyboard::GAKS
          down = []
          gaks.define_singleton_method(:call) { |vk| down.include?(vk) ? 0x8000 : 0 }
          begin
            [[0x4D], [], [0x12], [0x12, 0x4D], [0x12, 0x4D]].map do |held|
              down.replace(held)
              PokeAccess::Keyboard.snapshot
              r.update
              [Input.triggerex?(:M), PokeAccess::Keys.key(:coords)]
            end
          ensure
            down.clear
            r.update
            gaks.singleton_class.send(:remove_method, :call)
          end
        end
      end
      probe(:rebound) do
        live do |_keys|
          kept = PokeAccess::Config.rebinds
          PokeAccess::Config.rebinds = { :vitro_bag => 0x51 }
          begin
            [r.extra_remapped?(:B), r.extra_triggered?(:B)]
          ensure
            PokeAccess::Config.rebinds = kept
          end
        end
      end
    end

    def pause_play
      items = [["ball", "Equipo", "openParty"], ["bag", "Bolsa", "openBag"], ["save", "Guardar", "openSave"]]
      probe(:pause_bag) { said { Menu2.new(items, 1).redrawSelector } }
      probe(:pause_label) { said { Menu2.new(items, 2).redrawSelector } }
      probe(:trainer_out) { PokeAccess::Info.trainer_info }
      probe(:trainer_in) do
        line = nil
        Menu2.new(items).pbUpdate { line = PokeAccess::Info.trainer_info }
        line
      end
      probe(:trainer_safari) do
        line = nil
        $in_safari = true
        Menu2.new(items).pbUpdate { line = PokeAccess::Info.trainer_info }
        $in_safari = false
        line
      end
      probe(:trainer_contest) do
        line = nil
        $in_contest = true
        $contest_state.lastPokemon = Struct.new(:species, :level).new(1, 7)
        Menu2.new(items).pbUpdate { line = PokeAccess::Info.trainer_info }
        $in_contest = false
        $contest_state.lastPokemon = nil
        line
      end
      probe(:trainer_chain) do
        was = $PokemonTemp
        $PokemonTemp = Struct.new(:rescuechain).new([5, 1])
        line = nil
        Menu2.new(items).pbUpdate { line = PokeAccess::Info.trainer_info }
        outside = PokeAccess::VitroPause.chain
        $contest_state.lastPokemon = Struct.new(:species, :level).new(1, 7)
        with_catch = nil
        Menu2.new(items).pbUpdate { with_catch = PokeAccess::VitroPause.chain }
        $contest_state.lastPokemon = nil
        $PokemonTemp = Struct.new(:rescuechain).new([1, 1])
        single = nil
        Menu2.new(items).pbUpdate { single = PokeAccess::VitroPause.chain }
        $PokemonTemp = was
        [line, outside, with_catch, single, PokeAccess::Data.species_name(1)]
      end
    end

    def summary_play
      probe(:sheet) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        said do
          PokeAccess::PaintCapture.arm(:summary_egg)
          scene.drawPageInfo
        end
      end
      probe(:memo) do
        pk = mon(:able => [PBMoves::WATERFALL, PBMoves::SLASH, PBMoves::SUPERPOWER, PBMoves::DEFOG, PBMoves::SOFTBOILED,
                           PBMoves::SUNNYDAY, PBMoves::RAINDANCE], :types => [:WATER])
        said { PokemonSummaryScene.new(pk).drawPageData }
      end
      probe(:memo_empty) { said { PokemonSummaryScene.new(mon).drawPageData } }
      probe(:stats) { at_level(:full) { said { PokemonSummaryScene.new(mon).drawPageStats } } }
      probe(:moves_plain) { said { PokemonSummaryScene.new(mon).drawPageMoves } }
      probe(:moves_dynamax) do
        $dynamax_band = true
        pk = mon
        pk.define_singleton_method(:dynamax) { true }
        pk.define_singleton_method(:dynamax_lvl) { 6 }
        out = said { PokemonSummaryScene.new(pk).drawPageMoves }
        $dynamax_band = false
        out
      end
      probe(:contest) { at_level(:full) { said { PokemonSummaryScene.new(mon).drawPageContestMoves } } }
      probe(:contest_cursor) do
        scene = PokemonSummaryScene.new(mon)
        said { scene.drawPageContestMoves }
        [said { scene.pbContestMoveSelection }, PokeAccess::Info.info_text]
      end
      probe(:contest_types) do
        scene = PokemonSummaryScene.new(mon)
        said { scene.drawPageContestMoves }
        [31, 30, 32, 33, 34].map { |id| PokeAccess::VitroSummary.contest_type(scene, PBContestMoveData.new(id)) }
      end
      probe(:contest_no_hearts) do
        scene = PokemonSummaryScene.new(mon)
        said { scene.drawPageContestMoves }
        said { scene.drawSelectedContestMove(31) }
      end
      probe(:contest_short) do
        scene = PokemonSummaryScene.new(mon)
        row = ["x", :positions, 1, 1]
        [PokeAccess::VitroSummary.contest_page(scene, mon, [row] * 10).nil?, PokeAccess::VitroSummary.contest_page(scene, mon, [row] * 11).nil?]
      end
      probe(:dynamax_needs) do
        $dynamax_band = true
        without = PokeAccess::VitroSummary.dynamax(mon)
        $dynamax_band = false
        pk = mon
        pk.define_singleton_method(:dynamax) { true }
        pk.define_singleton_method(:dynamax_lvl) { 6 }
        [without, PokeAccess::VitroSummary.dynamax(pk)]
      end
      probe(:contest_back) do
        scene = PokemonSummaryScene.new(mon)
        said { scene.drawPageContestMoves }
        scene.pbContestMoveSelection
        said { scene.drawPageContestMoves }
      end
    end

    def party_play
      probe(:evolve_marks) { [PokeAccess::Party.panel_marks(mon(:name => "Evolver")), PokeAccess::Party.panel_marks(mon)] }
      probe(:level_line) do
        $game_variables[25] = 2
        [at_level(:medium) { said { PokemonScreen_Scene.new.pbStartScene([], "") } },
         at_level(:brief) { said { PokemonScreen_Scene.new.pbStartScene([], "") } }]
      end
    end

    def bag_play
      probe(:stones) do
        was = $Trainer
        $Trainer = Struct.new(:party).new([mon(:name => "Mega"), mon(:name => "Evolver"), mon])
        out = [PokeAccess::Menus.bag_marks(nil, 100), PokeAccess::Menus.bag_marks(nil, 101), PokeAccess::Menus.bag_marks(nil, 5)]
        $Trainer = Struct.new(:party).new([mon])
        out.push(PokeAccess::Menus.bag_marks(nil, 100))
        $Trainer = was
        out
      end
      probe(:stone_asks) do
        was = $Trainer
        $Trainer = Struct.new(:party).new([mon(:name => "Mega")])
        $stone_asks = 0
        2.times { PokeAccess::Menus.bag_marks(nil, 100) }
        once = $stone_asks
        PokeAccess::VitroBag.reset
        PokeAccess::Menus.bag_marks(nil, 100)
        $Trainer = was
        [once, $stone_asks]
      end
      probe(:bag_hints) do
        [at_level(:full) { said { PokemonBag_Scene.new.pbStartScene(nil) } },
         at_level(:brief) { said { PokemonBag_Scene.new.pbStartScene(nil) } }]
      end
    end

    def quests_play
      data = Object.new
      def data.getQuestDescription(_id); "Busca al profesor"; end
      def data.getStageDescription(_id, _stage); "Habla con él"; end
      def data.getStageLocation(_id, _stage); "Pueblo Primavera"; end
      def data.getQuestGiver(_id); "nil"; end
      def data.getQuestReward(_id); "Poción"; end
      $quest_data = data
      quest = Struct.new(:id, :stage, :location).new(:Quest1, 1, "En otro sitio")
      probe(:quest_first) { PokeAccess::QuestUI.description_lines(quest, :Quest1) }
      probe(:quest_second) { PokeAccess::QuestUI.other_lines(quest, :Quest1) }
      probe(:quest_translated) do
        Object.class_eval do
          alias_method :_intl_kept, :_INTL
          def _INTL(*args); ["", "nil"].include?(args[0]) ? args[0] : "T:#{args[0]}"; end
        end
        begin
          [PokeAccess::QuestUI.description_lines(quest, :Quest1), PokeAccess::QuestUI.other_lines(quest, :Quest1)]
        ensure
          Object.class_eval { alias_method :_INTL, :_intl_kept }
        end
      end
    end

    def map_play
      rows = [[3, 4, "Pueblo", "Lab", 1, 2, 3], [9, 9, "Ruta", "", 1, 2, 3]]
      data = [0, "map", rows]
      win = ScrolledWindow.new({ "roaming243" => Spot.new(16.0 * 3 + 8.0 - 240, 16.0 * 4 + 8.0 - 16) }, -240, -16)
      $PokemonGlobal = Struct.new(:roamPosition, :regionMapSel).new({ 0 => 12 }, [3, 4])
      scene = BetterRegionMap.new(win, data)
      probe(:map_rows) { PokeAccess::BetterMap.square_parts(scene, 3, 4).map { |part| part[0] } }
      probe(:map_other) { PokeAccess::BetterMap.square_parts(scene, 9, 9).map { |part| part[0] } }
      probe(:map_open) { said { scene.main } }
      probe(:map_none) do
        said { BetterRegionMap.new({}, data).main }.select { |line, _q| line.index(PokeAccess::I18n.t(:rmap_roamers, :list => "")) }
      end
    end

    def encounters_play
      seen = [1, 2]
      owned = [1]
      was = $Trainer
      trainer = Object.new
      trainer.define_singleton_method(:seen) { Hash.new(false).merge(1 => true, 2 => true) }
      trainer.define_singleton_method(:owned) { Hash.new(false).merge(1 => true) }
      util = PokeAccess::Util
      own = util.method(:dex_owned?)
      see = util.method(:dex_seen?)
      util.define_singleton_method(:dex_owned?) { |sp| owned.include?(sp) }
      util.define_singleton_method(:dex_seen?) { |sp| seen.include?(sp) }
      rows = [{ :species => 1 }, { :species => 2, :icon_type => :night }, { :species => 3, :icon_type => :rod }]
      probe(:enc_entries) { rows.map { |row| PokeAccess::VitroEncounters.entry(row) } }
      probe(:enc_page) do
        scene = EncounterListUI.new
        first = at_level(:full) { said { scene.drawAllTexts("Terrestres", rows, 1) } }
        scene.turn(1)
        [first, at_level(:full) { said { scene.drawAllTexts("Acuáticos", rows[0, 1], 1) } }]
      end
      probe(:enc_info) { PokeAccess::Info.info_text }
      probe(:enc_brief_info) do
        at_level(:brief) { EncounterListUI.new.drawAllTexts("Terrestres", rows, 1) }
        PokeAccess::Info.info_text
      end
      probe(:enc_none) do
        scene = EncounterListUI.new
        out = said { scene.drawAllTexts("Ninguno") }
        scene.turn(1)
        [out, PokeAccess::Info.info_text, said { scene.drawAllTexts("Ninguno") }]
      end
      util.define_singleton_method(:dex_owned?, own)
      util.define_singleton_method(:dex_seen?, see)
      $Trainer = was
    end

    def lens_play
      probe(:lens_item) { PokeAccess::FieldMoves.item_name(:DOWSINGMACHINE) }
      probe(:lens) do
        turn = lambda do
          LensOfTruth.toggle
          said { 2.times { PokeAccess::VitroLens.poll } }
        end
        [turn.call, turn.call]
      end
    end

    # The suite loads every plugin, and the game does not load the one for the newer pots: kept out of these lines.
    def silence_plugin_pots
      plugin = PokeAccess::BerryPots.singleton_class
      [:focus, :acted].each { |name| plugin.send(:define_method, name) { |_scene| nil } }
    end

    def small_screens_play
      probe(:pots) do
        silence_plugin_pots
        scene = ItemBerryPots_Scene.new([[3, 7, false, 0, 0, 0], 0, nil, [0, 0, false, 0, 0, 0]])
        [said { scene.move(0) }, said { scene.move(0) }, said { scene.move(1) }, said { scene.move(3) }, said { scene.pbBerryPlantVar(3) }]
      end
      probe(:pot_plant) { PokeAccess::Berry.state_parts([3, 7, false, 0, 0, 0]) }
      probe(:pots_info) do
        silence_plugin_pots
        scene = ItemBerryPots_Scene.new([[3, 7, false, 0, 0, 0], 0, nil, [0, 0, false, 0, 0, 0]])
        said { scene.move(1) }
        kept = PokeAccess::Info.info_text
        scene.pbEndScene
        [kept, PokeAccess::Info.info_text]
      end
      probe(:teleport_info) do
        scene = Teleport_Scene.new([{ :name => "Pueblo", :desc => "Tranquilo" }], [0])
        said { scene.move(0) }
        kept = PokeAccess::Info.info_text
        scene.pbTransportar(nil)
        [kept, PokeAccess::Info.info_text]
      end
      probe(:teleport) do
        scene = Teleport_Scene.new([{ :name => "Pueblo", :desc => "Tranquilo\nPequeño" }, { :name => "Cueva", :desc => ["Oscura"] }, { :name => "Isla" }], [0, 1])
        at_level(:full) do
          [said { scene.move(0) }, said { scene.move(1) }, said { scene.move(2) }, said { scene.move(2) }, PokeAccess::Verbosity.position(1, 3),
           PokeAccess::Verbosity.position(2, 3)]
        end
      end
      probe(:splash) { said { SplashMessage.new } }
      probe(:language) do
        scene = nil
        opening = at_level(:full) { said { scene = PokemonLanguageSelection.new } }
        [opening, at_level(:full) { said { scene.move(1) } }, at_level(:brief) { said { scene.move(2) } }, said { scene.updateSelection }]
      end
      probe(:controls) do
        scene = ControlsDisplayScene.new
        at_level(:full) do
          [said { scene.drawPage }, said { scene.drawPage(1) }, PokeAccess::Info.info_text, PokeAccess::Verbosity.position(1, 2),
           PokeAccess::Verbosity.position(2, 2)]
        end
      end
      probe(:controls_map) do
        kept = PokeAccess::Config.rebinds
        path = "Graphics/Pictures/help/helpMkey"
        out = [PokeAccess::VitroControls.key_name(path)]
        PokeAccess::Config.rebinds = { :vitro_map => 0x4E }
        out.push(PokeAccess::VitroControls.key_name(path))
        PokeAccess::Config.rebinds = kept
        out
      end
      probe(:hall) { said { Jess_SalonFama.new.jsGen4_HGSS } }
      probe(:hall_after) { said { Window_AdvancedTextPokemon.new("Otra cosa") } }
      probe(:starter) do
        scene = DiegoWTsStarterSelection.new
        opening = at_level(:full) { said { scene.pbStartChoosing } }
        balls = at_level(:full) { [said { scene.move(2) }, said { scene.move(3) }, said { scene.move(3) }, said { scene.move(1) }] }
        boxes = scene.pbChoiceBoxes(0)
        asked = said { scene.pbChooseBall }
        [opening, balls, boxes, asked]
      end
      probe(:starter_back) do
        scene = DiegoWTsStarterSelection.new
        said { scene.move(2) }
        scene.pbChooseBall
        said { scene.move(2) }
      end
      probe(:starter_chosen) do
        scene = DiegoWTsStarterSelection.new
        said { scene.move(2) }
        scene.endscene = 1
        scene.pbChooseBall
        said { scene.move(2) }
      end
      probe(:starter_closed) do
        scene = DiegoWTsStarterSelection.new
        said { scene.move(2) }
        kept = PokeAccess::Info.info_text
        scene.pbCloseScene
        [kept, PokeAccess::Info.info_text]
      end
      probe(:gender) do
        opening = at_level(:medium) { said { GenderSelectorScene.new.pbStartScene } }
        [opening, said { GenderSelectorScene.new([-1, 0, 0, 1]).pbUpdate }]
      end
    end

    rules_play
    keys_play
    pause_play
    summary_play
    party_play
    bag_play
    quests_play
    map_play
    encounters_play
    lens_play
    small_screens_play
  RUBY

  profile "vitro", WORLD, PLAY

  test "loads whole, and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
  end

  test "goes by its own name, with RPG Maker XP's letters, its buttons told and its passability plain" do
    assert_equal "vitro", played(:profile_name)
    assert_equal PokeAccess::KeyHints::RGSS_LETTERS, played(:hints)
    assert_equal true, played(:plain)
    assert_equal [:vitro_btn_a, :vitro_btn_x, :vitro_btn_l, :vitro_btn_r], played(:labels)
  end

  test "Cut takes a Pokemon for Slash or Ember and no badge, and Surf one for Waterfall, not for Surf" do
    assert_equal [true, true, false], played(:cut)
    assert_equal [true, false], played(:surf)
    assert_equal [true, true, false], played(:strength)
    assert_equal [true, false], played(:rock)
  end

  test "Waterfall and Dive stay stock" do
    assert_equal [false, false], played(:stock_moves)
  end

  test "the thorns offer Cut, or Ember in a party with no one for Cut, and any other obstacle its move" do
    corte, ascuas, none, surf = played(:cut_name)
    assert_equal ["Corte", "Ascuas", "Corte", "Surf"], [corte, ascuas, none, surf]
  end

  test "its own events are named while they stand, and nothing else" do
    assert_equal [:loc_cut_tree, :loc_rock_smash, :surf_waterfall, nil, nil], played(:labels_of)
  end

  test "a Cascada's page crosses with a Pokemon for Waterfall, for the route finder too" do
    assert_equal [true, false], played(:waterfall_page)
    able, unable = played(:waterfall_carry)
    assert_equal [:carry, 0, -5, true, nil], able[8], "two jumps of two tiles and a step, the way its route plays them"
    assert_equal({}, unable)
  end

  test "core's tree is said as the thorns the game says, and any other line stands" do
    assert_equal [t(:perseida_thorns), t(:loc_rock_smash)], played(:thorns)
  end

  test "only someone other than the following Pokemon bars the water" do
    assert_equal [true, false], played(:company)
  end

  test "the remap screen takes its six raw letters, named as the game reads them" do
    assert_equal [[:vitro_save, :T, :vitro_key_t], [:vitro_bag, :B, :vitro_key_b], [:vitro_quests, :J, :vitro_key_j],
                  [:vitro_party, :P, :vitro_key_p], [:vitro_gear, :Y, :vitro_key_y], [:vitro_map, :M, :vitro_key_m]],
                 played(:extras)
    assert_equal [:vitro_save, :vitro_bag, :vitro_quests, :vitro_party, :vitro_gear, :vitro_map, nil], played(:raw_names)
  end

  test "the game's T, J and M ship on Alt, as the mod's keys keep the letters, and its other letters stay" do
    assert_equal [true, true, true, false, false, false], played(:yields)
  end

  test "Alt + M opens the map once and takes the press from the coordinates, and M alone stays theirs" do
    assert_equal [[false, true], [false, false], [false, false], [true, false], [false, false]], played(:alt_m)
  end

  test "a letter given another key answers that key alone" do
    assert_equal [true, false], played(:rebound)
  end

  test "a pause entry says the word painted under its icon, not the mod's for that icon" do
    assert_equal [["Bolsa", true]], played(:pause_bag)
    assert_equal [["Guardar", true]], played(:pause_label)
  end

  test "the info key adds the map's name and the time only while the menu is up" do
    assert_includes played(:trainer_in), "Mapa"
    assert_includes played(:trainer_in), "09:30"
    refute_includes played(:trainer_out).to_s, "09:30"
  end

  test "the info key says what the panel paints in the Safari, the contest and a rescue chain" do
    assert_includes played(:trainer_safari), "Balls: 12"
    assert_includes played(:trainer_contest), "Balls: 12"
    assert_includes played(:trainer_contest), "Lv. 7"
    line, outside, with_catch, single, species = played(:trainer_chain)
    assert_includes line, "Cadena de 5, #{species}"
    assert_equal [nil, nil, nil], [outside, with_catch, single], "with the menu closed, a contest's catch in its corner, or one rescue"
    refute_includes played(:trainer_in), "Balls"
  end

  test "the data sheet takes the Pokedex number joined to the species, and says the friendship the bar shows" do
    line = played(:sheet)[0][0]
    assert_includes line, t(:sum_dex, :n => "025")
    assert_includes line, t(:mui_happiness_value, :n => 88, :max => 255)
  end

  test "the memo page says how it was met, a sentence a line, then the field moves its icons show" do
    line = played(:memo)[0][0]
    assert_includes line, "2 Enero, 2026. Encontrado con Nv. 5. Ruta 29."
    assert_includes line, "Movimientos de Campo: Surf, Corte, Fuerza, Despejar, Amortiguador, Danza Lluvia"
    refute_includes line, t(:mui_happiness_value, :n => 88, :max => 255)
    refute_includes line, "Día Soleado", "the weather move of a type the Pokemon is not"
    refute_includes line, "Ascuas"
  end

  test "a Pokemon with no field moves goes without their label" do
    refute_includes played(:memo_empty)[0][0], "Movimientos de Campo"
  end

  test "the stats page keeps the key hint this game paints with its own text call" do
    assert_includes played(:stats)[0][0], t(:sm_eviv)
    assert_includes played(:stats)[0][0], "Presiona C para más información."
  end

  test "the moves page says the Dynamax level only with the band" do
    refute_includes played(:moves_plain)[0][0], "Dinamax"
    assert_includes played(:moves_dynamax)[0][0], t(:dmax_level, :n => 6)
  end

  test "the contest page says each stat with its value, the sheen, and the moves with their contest type" do
    line = played(:contest)[0][0]
    assert_includes line, "Concursos."
    assert_includes line, "Concursos. Dulzura 10, Dureza 20, Belleza 30, Carisma 40, Ingenio 50. Brillo: 7."
    assert_includes line, "Placaje. Dureza. #{t(:mv_pp, :pp => 35, :tot => 35)}"
  end

  test "the contest cursor says the move's type, hearts and effect, and the info key keeps them past the frame" do
    said, info = played(:contest_cursor)
    assert_equal 1, said.length
    assert_equal "Placaje. TIPO Dureza. EXHIBICIÓN 3. INHIBICIÓN 1. Efecto 30", said[0][0].sub(/\.\z/, "")
    assert_equal true, said[0][1]
    assert_equal said[0][0], info
  end

  test "each contest type goes by the name the radar paints for it" do
    assert_equal %w[Dulzura Dureza Belleza Carisma Ingenio], played(:contest_types)
  end

  test "a move with no hearts says none, and a page with less than the radar paints says nothing" do
    assert_includes played(:contest_no_hearts)[0][0], "EXHIBICIÓN 0. INHIBICIÓN 0"
    assert_equal [true, false], played(:contest_short)
  end

  test "the Dynamax meter takes both a Pokemon that can and the band" do
    assert_equal [nil, nil], played(:dynamax_needs)
  end

  test "leaving the contest cursor says the page again" do
    assert_equal 1, played(:contest_back).length
  end

  test "the party panel marks a member that can evolve, and the balanced level is said from medium, as it opens" do
    assert_equal [[t(:vitro_can_evolve)], []], played(:evolve_marks)
    medium, brief = played(:level_line)
    assert_includes medium.map { |line, _q| line }, "Nv. Medio 42 (R: 3)"
    refute_includes brief.map { |line, _q| line }, "Nv. Medio 42 (R: 3)"
  end

  test "a stone's row says who can use it, by the check its ball is drawn from, and any other row nothing" do
    mega, evolution, other, nobody = played(:stones)
    assert_equal [[:vitro_stone_able, { :names => "Mega" }]], mega
    assert_equal [[:vitro_stone_able, { :names => "Evolver" }]], evolution
    assert_equal [], other
    assert_equal [:vitro_stone_nobody], nobody
  end

  test "a stone asks the game once per team and item, until the screen's cache is forgotten" do
    assert_equal [1, 2], played(:stone_asks)
  end

  test "the bag's sorting keys are said as it opens, only while key hints are said" do
    full, brief = played(:bag_hints)
    assert_equal [["[Z] Organizar Auto. [A] Organizar", false]], full.select { |line, _q| line.index("Organizar") }
    assert_equal [], brief.select { |line, _q| line.index("Organizar") }
  end

  test "the quest pages say what this copy paints, not the stage count, where it began nor the time" do
    assert_equal [t(:quest_overview, :text => "Busca al profesor"), t(:quest_task, :text => "Habla con él")], played(:quest_first)
    assert_equal [t(:quest_location, :text => "Pueblo Primavera"), t(:quest_giver, :who => t(:quest_unset)),
                  t(:quest_reward, :what => "Poción")], played(:quest_second)
    first, second = played(:quest_translated)
    assert_equal [t(:quest_overview, :text => "T:Busca al profesor"), t(:quest_task, :text => "T:Habla con él")], first
    assert_equal [t(:quest_location, :text => "T:Pueblo Primavera"), t(:quest_giver, :who => t(:quest_unset)),
                  t(:quest_reward, :what => "T:Poción")], second
  end

  test "a map square says its place through the game's translations, and the roamer its icon stands on" do
    assert_equal ["19:Pueblo", "20:Lab", "Especie243"], played(:map_rows)
    assert_equal ["19:Ruta"], played(:map_other)
  end

  test "the map says each roamer with its place as it opens, and nothing with none drawn" do
    line = t(:rmap_roamers, :list => t(:rmap_roamer, :name => "Especie243", :place => "19:Pueblo"))
    assert_includes played(:map_open), [line, false]
    assert_equal [], played(:map_none)
  end

  test "an encounter row goes by its Pokedex state, with the word of the icon it carries" do
    assert_equal [["Especie1", :dex_caught], ["Especie2 #{t(:vitro_enc_night)}", :dex_seen],
                  ["Especie3 #{t(:vitro_enc_rod)}", :dex_unknown]], played(:enc_entries)
  end

  test "an encounter page is said with its count, the first queued and each turn cutting in" do
    first, turned = played(:enc_page)
    assert_equal 1, first.length
    assert_equal false, first[0][1]
    assert_includes first[0][0], "Mapa 3 : Terrestres"
    assert_includes first[0][0], t(:rea_enc_owned, :n => 1)
    assert_equal true, turned[0][1]
    assert_includes turned[0][0], "Acuáticos"
    assert_includes played(:enc_info), "Acuáticos"
    assert_includes played(:enc_brief_info), t(:dex_caught), "the info key keeps the whole page at any level"
  end

  test "a map with no wild Pokemon is said as the game says it" do
    said, info, again = played(:enc_none)
    assert_equal [["Mapa 3 : Ninguno. ¡Esta zona no tiene Pokémon salvajes!", false]], said
    assert_equal said[0][0], info
    assert_equal [], again
  end

  test "the lens says when it turns on and off, once, by the item that works it" do
    item = played(:lens_item)
    assert_equal [[[t(:vitro_lens_on, :item => item), true]], [[t(:vitro_lens_off, :item => item), false]]], played(:lens)
  end

  test "the pots say each one and its plant as the cursor moves, and again after acting on one" do
    first, same, empty, stage_zero, acted = played(:pots)
    plant = played(:pot_plant).join(", ")
    assert_equal [["#{t(:bpots_pot, :n => 1, :total => 4)}, #{plant}", false]], first
    assert_equal [], same
    assert_equal [["#{t(:bpots_pot, :n => 2, :total => 4)}, #{t(:bpots_empty)}", true]], empty
    assert_equal [["#{t(:bpots_pot, :n => 4, :total => 4)}, #{t(:bpots_empty)}", true]], stage_zero
    assert_equal [["#{t(:bpots_pot, :n => 4, :total => 4)}, #{t(:bpots_empty)}", false]], acted
  end

  test "the info key keeps the pot and the destination under the cursor, until their screens close" do
    pot, after_pots = played(:pots_info)
    assert_equal "#{t(:bpots_pot, :n => 2, :total => 4)}, #{t(:bpots_empty)}", pot
    refute_equal pot, after_pots
    destination, after_menu = played(:teleport_info)
    assert_includes destination, "Pueblo. Tranquilo"
    refute_equal destination, after_menu
  end

  test "the teleport menu says each destination as painted with its place, a locked one as unknown" do
    first, second, locked, same, place_one, place_two = played(:teleport)
    assert_includes first[0][0], place_one
    assert_includes second[0][0], place_two
    assert_equal false, first[0][1]
    assert_includes first[0][0], "Pueblo. Tranquilo. Pequeño"
    assert_includes second[0][0], "Cueva. Oscura"
    assert_equal true, locked[0][1]
    refute_includes locked[0][0], "Isla"
    assert_equal [], same
  end

  test "the info key keeps the starter's ball until the screen closes" do
    kept, after = played(:starter_closed)
    assert_includes kept, t(:dh_starter_ball_middle)
    refute_equal kept, after
  end

  test "the title's warning is said as it paints, queued" do
    assert_equal [["Solo el enlace del blog oficial te garantiza la versión. Juego creado por fans para fans.", false]],
                 played(:splash)
  end

  test "the language screen says its title with the first row, then each row it moves to" do
    opening, moved, brief, same = played(:language)
    assert_equal [["IDIOMA / LANGUAGE / LANGUE / SPRACHE. #{t(:list_entry, :name => "Español", :n => 1, :tot => 3)}", false]], opening
    assert_equal [[t(:list_entry, :name => "English", :n => 2, :tot => 3), true]], moved
    assert_equal [["French", true]], brief
    assert_equal [], same
  end

  test "the controls screen says each line after the keys beside it, the log by the key that opens it" do
    first, second, info, place_one, place_two = played(:controls)
    assert_includes first[0][0], place_one
    assert_includes second[0][0], place_two
    assert_equal false, first[0][1]
    assert_includes first[0][0], "#{t(:vitro_key_arrows)}: Mover el personaje principal."
    assert_includes first[0][0], "C, #{t(:vitro_key_space)}: Confirmar una selección. Una línea sin tecla."
    assert_operator first[0][0].index("Mover"), :<, first[0][0].index("Confirmar")
    assert_equal true, second[0][1]
    assert_includes second[0][0], "W: Abrir el Log de Texto."
    assert_equal second[0][0], info
  end

  test "the controls screen says the key the map is on" do
    assert_equal ["#{t(:key_alt)} M", "N"], played(:controls_map)
  end

  test "the ceremony says each window's text once, in order, queued, and nothing outside it" do
    assert_equal [["¡Salón de la Fama!", false], ["Bulby Bulbasaur ♂ Nv. 50 OT/Ash", false],
                  ["¡Campeón de la Liga! ¡Felicidades!", false]], played(:hall)
    assert_equal [], played(:hall_after)
  end

  test "the starter selection says what it asks, the ball under the cursor, and the question once" do
    opening, balls, boxes, asked = played(:starter)
    assert_equal false, opening[0][1]
    assert_includes opening[0][0], "¿Cual quieres?"
    assert_includes opening[0][0], t(:dh_starter_keys, :key => "C")
    assert_equal false, balls[0][0][1]
    assert_includes balls[0][0][0], t(:dh_starter_ball_middle)
    assert_equal true, balls[1][0][1]
    assert_includes balls[1][0][0], t(:dh_starter_ball_right)
    assert_equal [], balls[2]
    assert_includes balls[3][0][0], t(:dh_starter_ball_left)
    assert_equal :boxes, boxes
    assert_equal ["¿Quieres a Totodile, del tipo Agua?", false], asked[0]
    assert_equal [["Sí", false], ["No", true]], asked[1, 2]
  end

  test "a No says the ball again, and a choice made says nothing more" do
    assert_equal 1, played(:starter_back).length
    assert_equal [], played(:starter_chosen)
  end

  test "the gender selector is read by its plugin here too, with the mod's title where the copy paints none" do
    opening, lit = played(:gender)
    assert_equal [["#{t(:gsel_help)}. #{t(:gsel_help_hint)}", false]], opening
    assert_equal [[t(:gsel_boy), false], [t(:gsel_girl), true]], lit
  end
end
