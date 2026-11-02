# The Pokemon Perseida profile loaded whole, over doubles with the shape of its scripts: its gems and bracelet for the field
# moves, its own words in core's lines, the keys it reads and the one that yields, the pause menu and the clock, the summary's
# page order and ribbons, the PC's IV letters, the party's mana, the bag's keys, the books, the gifts, the quest pages, the
# workbench's yield and the encounter pages. In a process of its own, since its overrides would reach every other test here.
class PerseidaProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "tile_world")

    # The switches of the gems, the maps its Surf refuses (0211_Menu_Config_Zoom), the mana (0217_Menu_ManaSystem) and the
    # follower's name (0317_Pokemon_Followpoke_Bezier).
    JOYA_NARANJA = 91
    JOYA_TURQUESA = 101
    NO_SURF_MAPS = [7]
    ACTIVARMANA = 47
    VARMANA = 121
    FOLLOW_EVENTNAME = "Dependent"

    # Its extra buttons (0185_PSystem_Controls) and the names of the keys items register to.
    module Input
      F = 30
      B2 = 33
      M = 36
      ITEMKEYSNAMES = ["F5", "F4", "F3"]
    end

    # The moves the party knows, as the game's finder asks for them: public at the top level, which it calls on Kernel.
    $party_moves = []
    def pbCheckMove(move); $party_moves.include?(move) ? :a_pokemon : nil; end
    Object.send(:public, :pbCheckMove)

    def pbMaxMana; 200; end
    def pbGoldUnit(complete = false); complete ? " Coronas" : "<s> C</s>"; end
    def pbGetTimeNow; Time.local(2026, 11, 1, 14, 5); end
    def drawFormattedTextEx2(_bitmap, _x, _y, _width, _height, _text, _base = nil, _shadow = nil, _outline = true); end

    # An event: its name, and the page the engine left it with.
    class FieldEvent
      attr_reader :name

      def initialize(name, page = :a_page)
        @name = name
        @page = page
        @event = Struct.new(:pages).new([:a_page])
      end
    end

    # The pause menu: entries [icon, label, function], drawn as icons; pbUpdate is its modal loop.
    class Menu2
      def initialize(items, selected = 0)
        @items = items
        @selected_item = selected
      end

      def redrawSelector; end
      def pbUpdate; yield if block_given?; end
    end

    # The clock: the same entries, on a ring.
    class ItemsM
      def initialize(items)
        @items = items
        @selected_item = 0
      end

      def pbStartScene; redrawSelector; end
      def redrawSelector; end
      def pbUpdate; yield if block_given?; end
      def pbEndScene; end
    end

    # The Pokegear, which opens from the pause menu.
    class PokemonMenu2
      def pbStartPokemonMenu2; yield if block_given?; end
    end

    RibbonCursor = Struct.new(:visible)

    # The summary as 0260_Signos_Summary leaves it: the stats on page two and the moves on page three.
    class PokemonSummaryScene
      attr_accessor :ribindex, :sprites

      def pbdrawRibDesc(pokemon); pokemon; end
    end

    # The party screen paints the mana as it opens and on each refresh.
    class PokemonScreen_Scene
      def pbStartScene(party, _starthelptext, _annotations = nil, _multiselect = false); @party = party; end
      def pbRefresh; end
    end

    # The book: a title and a text for each page.
    class Textbook_Scene
      def initialize(rows); @bookarray = rows; end
      def drawTextbookPage(page); @page = page; end
      def pbEndScene; end
    end

    # The gifts: three rows under the title, its loop over the frames a probe gives it.
    class MysteryGiftScene
      attr_accessor :selected

      def initialize
        @text = ["Recibir via Internet", "Recibir via Codigo", "Salir"]
        @selected = 0
      end

      def pbStartScene; end
      def showHideItems(show = true); show; end

      def pbMGCommands
        yield self if block_given?
      end
    end

    # The quest screen and its data.
    class QuestList_Scene
      def drawQuestDesc(quest); quest; end
      def drawOtherInfo(quest); quest; end
    end

    Quest = Struct.new(:id, :stage, :location)

    class QuestBook
      attr_accessor :giver, :reward

      def initialize
        @giver = "Falcar"
        @reward = "Una baya"
      end

      def getName(id); "Mision #{id}"; end
      def getQuestDescription(_id); "Busca la baya"; end
      def getStageDescription(_id, stage); "Etapa #{stage}"; end
      def getStageLocation(_id, _stage); "nil"; end
      def getQuestGiver(_id); @giver; end
      def getQuestReward(_id); @reward; end
    end
    $quest_data = QuestBook.new

    # The workbench: rows [item, ingredients, yield].
    class ItemCraft_Scene
      def initialize(stock); @stock = stock; end
    end

    # The paged encounter list.
    class EncounterListUI
      def initialize(species, name, none = false)
        @species = species
        @name = name
        @none = none
      end

      def loadEncounterData
        @none ? (@encounterArray = [7]) : (@num_enc = 1; @encounterArray = @species)
      end

      def loadCurrentPage; loadEncounterData; end
    end
  RUBY

  PLAY = <<-'RUBY'
    # A shore two steps from the player, two tiles of water, and (7, 1) beyond them, reached by water alone.
    STRAIT = ["#########",
              "#@..~~..#",
              "#########"]

    # Runs the block with a bag holding just these items.
    def with_bag(items)
      was = $PokemonBag
      $PokemonBag = Object.new
      $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
      yield
    ensure
      $PokemonBag = was
    end

    # Runs the block with the party knowing these moves.
    def with_moves(moves)
      was = $party_moves
      $party_moves = moves
      yield
    ensure
      $party_moves = was
    end

    # Runs the block under the brief verbosity, which leaves key hints out.
    def brief
      was = PokeAccess::Config.verbosity
      PokeAccess::Config.verbosity = :brief
      yield
    ensure
      PokeAccess::Config.verbosity = was
    end

    # Runs the block with these switches on and no others.
    def with_switches(*ids)
      was = $game_switches
      $game_switches = Hash.new(false)
      ids.each { |i| $game_switches[i] = true }
      yield
    ensure
      $game_switches = was
    end

    # Runs the block with this list of who walks along.
    def with_company(events)
      had = $PokemonGlobal.respond_to?(:dependentEvents)
      was = had ? $PokemonGlobal.dependentEvents : nil
      $PokemonGlobal.define_singleton_method(:dependentEvents) { events }
      yield
    ensure
      $PokemonGlobal.define_singleton_method(:dependentEvents) { was }
    end

    # Runs the block on STRAIT, on the player's last floor tile facing the water.
    def on_strait(map_id = 900, company = false)
      was = [$game_map, $game_player]
      $game_map = TileWorld.new(STRAIT, map_id)
      $game_player = TileWorldPlayer.new(3, 1)
      $game_player.direction = 6
      $game_player.define_singleton_method(:pbHasDependentEvents?) { company }
      PokeAccess::Pathfinder.invalidate_cache(true)
      PokeAccess::World::Epoch.touch(:tiles)
      yield
    ensure
      $game_map, $game_player = was
      PokeAccess::Pathfinder.invalidate_cache(true)
      PokeAccess::World::Epoch.touch(:tiles)
    end

    def water_cue
      PokeAccess::Config.surface_cues = true
      PokeAccess::Surfaces.reset_map_state
      said { PokeAccess::Surfaces.surfaces }
    end

    def field_moves_play
      fm = PokeAccess::FieldMoves
      probe(:cut) do
        [with_switches(JOYA_NARANJA) { fm.can?(:CUT) }, with_switches { with_moves([:CUT]) { fm.can?(:CUT) } }]
      end
      probe(:surf) do
        [with_switches(JOYA_TURQUESA) { on_strait { fm.can?(:SURF) } }, with_switches { with_moves([:SURF]) { on_strait { fm.can?(:SURF) } } },
         with_switches(JOYA_TURQUESA) { on_strait(7) { fm.can?(:SURF) } }]
      end
      probe(:rock_smash) do
        [with_bag([:BRAZALFUERZA]) { fm.can?(:ROCKSMASH) }, with_bag([]) { with_moves([:ROCKSMASH]) { fm.can?(:ROCKSMASH) } }]
      end
      probe(:waterfall) { with_moves([:WATERFALL]) { fm.can?(:WATERFALL) } }
      probe(:unreadable) do
        was = $game_switches
        $game_switches = nil
        begin
          fm.can?(:CUT)
        ensure
          $game_switches = was
        end
      end
      probe(:clearers) { [fm.clearer(:move => :CUT), fm.clearer(:move => :SURF), fm.name(:ROCKSMASH), fm.name(:STRENGTH)] }
      probe(:stock_name) { PokeAccess::Data.move_name(PokeAccess::Data.move_id(:STRENGTH)) }
      probe(:bracelet_name) { fm.item_name(:BRAZALFUERZA) }
      probe(:gate_line) do
        ev = FieldEvent.new("Arbol")
        [PokeAccess::I18n.t(PokeAccess::Locator.fieldmove_label(ev)), PokeAccess::Locator.fieldmove_label(FieldEvent.new("Arbol", nil)),
         PokeAccess::Locator.fieldmove_label(FieldEvent.new("Apricorn tree"))]
      end
      probe(:company) do
        follower = [nil] * 8 + ["Dependent"]
        person = [nil] * 8 + ["Blazer"]
        [[[follower], true], [[follower, person], true], [[], false]].map do |events, along|
          with_company(events) { on_strait(900, along) { PokeAccess::Pathfinder.surf_with_company? } }
        end
      end
      probe(:water_cues) do
        [with_switches(JOYA_TURQUESA) { on_strait { water_cue } }, with_switches { on_strait { water_cue } }]
      end
      probe(:pushes) do
        effects = PokeAccess::Routes::Effects
        pulls = effects.instance_variable_get(:@pull_scripts)
        rule = effects.instance_variable_get(:@push_rules).find { |re, _move, _ready| re =~ "pbPushThisBoulder" }
        [pulls.any? { |re| re =~ "pbPushThisBoulder" && re =~ "pbPushThisEvent" }, rule && rule[1], rule.nil?]
      end
    end

    def words_play
      probe(:words) do
        t = PokeAccess::I18n
        [t.t(:fs_lens_on), t.t(:fs_lens_off), t.t(:loc_cut_tree), t.t(:loc_surf_here), t.t(:loc_surf_toward, :dir => "al norte"),
         t.t(:loc_surf_company), t.t(:loc_dismount_route), t.t(:loc_dismount_here, :dir => "al norte"), t.t(:loc_dismount_spot),
         t.t(:surf_ahead)]
      end
      probe(:crowns) { [PokeAccess::I18n.t(:tr_money, :n => 1250), PokeAccess::I18n.t(:tr_money, :n => 300), PokeAccess::I18n.t(:tr_money, :n => 1)] }
      probe(:plain_line) { PokeAccess::I18n.t(:pk_shiny) }
      probe(:size_events) do
        [PokeAccess::World::Events.area(5, 3, nil, nil, "Vena sizeC(3,1)"), PokeAccess::World::Events.area(5, 3, nil, nil, "Boquete sizeC(3,2)").length,
         PokeAccess::World::Events.area(5, 3, nil, nil, "Roca").length, "Vena sizeC(3,1)".gsub(PokeAccess::Locator::EDITOR_NOTE_RE, "")]
      end
    end

    def keys_play
      r = PokeAccess::Remap
      probe(:extra_buttons) { [r.sym_for_button(Input::F), r.sym_for_button(Input::B2), r.sym_for_button(Input::M), r.sym_for_button(Input::A), r.sym_for_button(999)] }
      probe(:hints) { PokeAccess::Config.key_hint_letters }
      probe(:labels) { [:x, :y, :z, :l, :r].map { |b| PokeAccess::Config.rebind_labels[b] } }
      probe(:extras) { r.extras.map { |row| [row[0], row[1], row[2]] } }
      probe(:plain) { PokeAccess::World::Probe.plain? }
      probe(:m_key) do
        kept = PokeAccess::Config.rebinds
        out = [r.remapped_button?(Input::M), r.remapped_button?(Input::F), r.bound_code(:clara_map)]
        PokeAccess::Config.rebinds = { :clara_map => 0x4E }
        out.push(r.bound_code(:clara_map))
        PokeAccess::Config.rebinds = kept
        out
      end
      probe(:alt_m) do
        keys = PokeAccess::Keys
        focus = keys.method(:focused?)
        on = keys.enabled
        gaks = PokeAccess::Keyboard::GAKS
        down = []
        keys.define_singleton_method(:focused?) { true }
        keys.instance_variable_set(:@enabled, true)
        gaks.define_singleton_method(:call) { |vk| down.include?(vk) ? 0x8000 : 0 }
        begin
          [[0x4D], [], [0x12], [0x12, 0x4D], [0x12, 0x4D]].map do |held|
            down.replace(held)
            PokeAccess::Keyboard.snapshot
            r.update
            [Input.trigger?(Input::M), PokeAccess::Keys.key(:coords)]
          end
        ensure
          down.clear
          r.update
          gaks.singleton_class.send(:remove_method, :call)
          keys.define_singleton_method(:focused?, focus)
          keys.instance_variable_set(:@enabled, on)
        end
      end
    end

    ITEMS = [["Menu_bag", "Mochila", "openBag"], ["Menu_options", "Opciones", "openOptions"], ["Menu_star", "Cometry", "textos_star"]]

    def pause_play
      probe(:pause_focus) { said { Menu2.new(ITEMS, 0).redrawSelector } }
      probe(:pause_no_key) { said { Menu2.new(ITEMS, 1).redrawSelector } }
      probe(:pause_star) { said { Menu2.new(ITEMS, 2).redrawSelector } }
      probe(:pause_brief) do
        brief { said { Menu2.new(ITEMS, 0).redrawSelector } }
      end
      $game_variables[VARMANA] = 120
      probe(:trainer_out) { with_switches { PokeAccess::Info.trainer_info } }
      probe(:trainer_menu) do
        line = nil
        with_switches(ACTIVARMANA) { Menu2.new(ITEMS, 0).pbUpdate { line = PokeAccess::Info.trainer_info } }
        line
      end
      probe(:after_menu) { with_switches(ACTIVARMANA) { PokeAccess::Info.trainer_info } }
      probe(:trainer_nested) do
        lines = []
        with_switches(ACTIVARMANA) do
          Menu2.new(ITEMS, 0).pbUpdate do
            PokemonMenu2.new.pbStartPokemonMenu2 { lines << PokeAccess::Info.trainer_info }
            ItemsM.new([]).pbUpdate { lines << PokeAccess::Info.trainer_info }
            lines << PokeAccess::Info.trainer_info
          end
        end
        lines
      end
      probe(:clock_dial) do
        rows = [["Joya Azul", "Joya Azul", "openCristal"]]
        [with_switches(JOYA_TURQUESA, JOYA_NARANJA) { said { ItemsM.new(rows).pbStartScene } },
         with_switches { said { ItemsM.new(rows).pbStartScene } }]
      end
      probe(:clock_info) do
        ItemsM.new([["Joya Azul", "Joya Azul", "openCristal"]]).redrawSelector
        PokeAccess::Info.info_text
      end
      probe(:clock_row) do
        menu = ItemsM.new([["Joya Azul", "Joya Azul", "openCristal"]])
        menu.redrawSelector
        row = PokeAccess::Info.row_text
        menu.pbEndScene
        [row, PokeAccess::Info.row_text]
      end
    end

    def mon(opts = {})
      TestPoke.build({ :name => "Bulby", :happiness => 88, :ev => [4, 252, 0, 6, 1, 247], :iv => [31, 30, 0, 29, 16, 17] }.merge(opts))
    end

    def summary_play
      probe(:letters) { [31, 30, 29, 25, 24, 17, 16, 1, 0].map { |iv| PokeAccess::PerseidaSummary.letter(iv) } }
      probe(:ivs) { PokeAccess::PerseidaSummary.ivs(mon) }
      probe(:page_two) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        [said { scene.drawPageTwo(pk) }, said { scene.drawPageTwo(pk) }]
      end
      probe(:page_three) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        said { scene.drawPageThree(pk) }
      end
      probe(:page_four) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        said { scene.drawPageFour(pk) }
      end
      probe(:magnific) do
        pk = mon
        pk.define_singleton_method(:isMagnific?) { true }
        [PokeAccess::Summary.header_icons(pk), PokeAccess::Summary.header_icons(mon)]
      end
      probe(:stats_expected) do
        pk = mon
        PokeAccess::SummaryGen6.stats_text(pk, [PokeAccess::Data.ability_name(pk.ability)])
      end
      probe(:moves_expected) { PokeAccess::Summary.moves_text(mon) }
      probe(:back_from_moves) do
        pk = mon
        scene = PokemonSummaryScene.new(pk)
        scene.drawPageThree(pk)
        scene.pbMoveSelection
        scene.drawPageFour(pk)
        said { scene.drawPageThree(pk) }.length
      end
      probe(:ribbon) do
        pk = mon(:ribbons => [1, 2])
        scene = PokemonSummaryScene.new(pk)
        scene.ribindex = 0
        scene.pbRibbonSelection
        first = said { scene.pbdrawRibDesc(pk) }
        repeat = said { scene.pbdrawRibDesc(pk) }
        scene.ribindex = 1
        second = said { scene.pbdrawRibDesc(pk) }
        scene.ribindex = 2
        past = said { scene.pbdrawRibDesc(pk) }
        [first, repeat, second, past]
      end
      probe(:ribbon_back) do
        pk = mon(:ribbons => [1, 2])
        scene = PokemonSummaryScene.new(pk)
        said { scene.drawPageFive(pk) }
        same = said { scene.drawPageFive(pk) }
        scene.pbRibbonSelection
        [same, said { scene.drawPageFive(pk) }.length]
      end
      probe(:ribbon_parts) { [PokeAccess::Summary.ribbon_parts(1), PokeAccess::Summary.ribbon_parts(2)] }
      probe(:detail_focus) do
        scene = PokemonSummaryScene.new(mon)
        none = PokeAccess::SummaryGen6.detail_focused?(scene)
        scene.instance_variable_set(:@sprites, { "ribsel" => RibbonCursor.new(true) })
        on = PokeAccess::SummaryGen6.detail_focused?(scene)
        scene.instance_variable_set(:@sprites, { "ribsel" => RibbonCursor.new(false) })
        [none, on, PokeAccess::SummaryGen6.detail_focused?(scene)]
      end
      probe(:pc_details) do
        pk = mon
        pk.define_singleton_method(:hasBirthsign?) { true }
        pk.define_singleton_method(:pbGetBirthsignName) { "Vena" }
        pk.define_singleton_method(:hasMegaForm?) { true }
        PokeAccess::Party.pc_details(pk).select { |_t, level| level == :full }.map { |t, _l| t }
      end
      probe(:pc_no_sign) do
        pk = mon
        pk.define_singleton_method(:hasBirthsign?) { false }
        PokeAccess::Party.pc_details(pk).map { |t, _l| t }.grep(/#{PokeAccess::I18n.t(:perseida_sign, :name => "")}/).length
      end
    end

    def party_play
      probe(:party_mana) do
        $game_variables[VARMANA] = 120
        scene = PokemonScreen_Scene.new
        opened = said { scene.pbStartScene([], "") }
        same = said { scene.pbRefresh }
        $game_variables[VARMANA] = 20
        changed = said { scene.pbRefresh }
        [opened, same, changed]
      end
      probe(:party_mana_brief) do
        scene = PokemonScreen_Scene.new
        brief { said { scene.pbRefresh } }
      end
      probe(:blessed) do
        pk = mon
        pk.define_singleton_method(:isBlessed?) { true }
        [PokeAccess::Party.panel_marks(pk).include?(PokeAccess::I18n.t(:perseida_blessed)),
         PokeAccess::Party.panel_marks(mon).include?(PokeAccess::I18n.t(:perseida_blessed))]
      end
    end

    def bag_play
      bag = Object.new
      bag.define_singleton_method(:registeredItem) { [nil, 7, nil] }
      probe(:bag_key) { [PokeAccess::Menus.bag_marks(bag, 7), PokeAccess::Menus.bag_marks(bag, 8)] }
      probe(:bag_plain) { PokeAccess::Menus.bag_registered?(bag, 7) }
    end

    def books_play
      rows = ["Tomo I", "<c3=112233,445566>Texto uno</c3>", "Tomo II", "Texto dos", "Tomo III", "Texto tres"]
      probe(:book) do
        scene = Textbook_Scene.new(rows)
        [said { scene.drawTextbookPage(0) }, said { scene.drawTextbookPage(0) }, said { scene.drawTextbookPage(2) }, PokeAccess::Info.info_text]
      end
      probe(:book_closed) do
        scene = Textbook_Scene.new(rows)
        scene.drawTextbookPage(0)
        scene.pbEndScene
        PokeAccess::Info.instance_variable_get(:@kind)
      end
      probe(:book_past) { said { Textbook_Scene.new(rows).drawTextbookPage(8) } }
    end

    def gift_play
      probe(:gift) do
        scene = MysteryGiftScene.new
        opened = said { scene.pbStartScene }
        rows = []
        scene.pbMGCommands do
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.selected = 2
          rows.push(said { PokeAccess::Frame.run_pollers })
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.showHideItems
          rows.push(said { PokeAccess::Frame.run_pollers })
          scene.showHideItems(false)
          rows.push(said { PokeAccess::Frame.run_pollers })
        end
        [opened, rows]
      end
    end

    def quests_play
      q = Quest.new(3, 2, "Pueblo Libra")
      scene = QuestList_Scene.new
      probe(:quest_one) { said { scene.drawQuestDesc(q) } }
      probe(:quest_two) { said { scene.drawOtherInfo(q) } }
      probe(:quest_unset) do
        $quest_data.giver = "nil"
        $quest_data.reward = ""
        said { scene.drawOtherInfo(q) }
      end
    end

    def crafting_play
      scene = ItemCraft_Scene.new([[:POTION, [:ORANBERRY, 1], 2], [:ETHER, [:ORANBERRY, 1]], [:ELIXIR, [:ORANBERRY, 1], 1]])
      probe(:yields) { (0..3).map { |i| PokeAccess::ItemCrafting.recipe_yield(scene, i) } }
    end

    def markers_play
      probe(:markers) do
        %w[red blue yellow green push other].map { |p| PokeAccess::QuestMarker.word(p) }
      end
    end

    def encounters_play
      probe(:enc_map) { ($game_map.name rescue nil).to_s }
      probe(:enc_none) { said { EncounterListUI.new([], "Hierba", true).loadEncounterData } }
      probe(:enc_data) { said { EncounterListUI.new([1, 2], "Hierba").loadEncounterData } }
      probe(:enc_page) { said { EncounterListUI.new([1, 2], "Hierba").loadCurrentPage } }
      probe(:enc_entries) do
        util = PokeAccess::Util
        owned = util.method(:dex_owned?)
        seen = util.method(:dex_seen?)
        util.define_singleton_method(:dex_owned?) { |sp| sp == 1 }
        util.define_singleton_method(:dex_seen?) { |sp| sp <= 2 }
        begin
          line = said { EncounterListUI.new([1, 2, 3], "Hierba").loadCurrentPage }[0][0]
          [[1, 2, 3].map { |sp| PokeAccess::EncounterPages.entry(sp) }, line, PokeAccess::Data.species_name(1)]
        ensure
          util.define_singleton_method(:dex_owned?, owned)
          util.define_singleton_method(:dex_seen?, seen)
        end
      end
    end

    probe(:profile_name) { PokeAccess::Game.profile_name }
    field_moves_play
    words_play
    keys_play
    pause_play
    summary_play
    party_play
    bag_play
    books_play
    gift_play
    quests_play
    crafting_play
    markers_play
    encounters_play
  RUBY

  profile "perseida", WORLD, PLAY

  test "loads whole, what it imports and every plugin, and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
  end

  test "goes by its own name, and its key hints are RPG Maker XP's letters and its passability plain" do
    assert_equal "perseida", played(:profile_name)
    assert_equal PokeAccess::KeyHints::RGSS_LETTERS, played(:hints)
    assert_equal true, played(:plain)
  end

  test "the orange gem alone clears thorns, whatever the party knows" do
    assert_equal [true, false], played(:cut)
  end

  test "the turquoise gem alone takes to the water, and not on a map its Surf refuses" do
    assert_equal [true, false, false], played(:surf)
  end

  test "the bracelet alone breaks rocks, and Waterfall stays stock" do
    assert_equal [true, false], played(:rock_smash)
    assert_equal true, played(:waterfall)
  end

  test "switches it cannot read are no answer, not a no" do
    assert_nil played(:unreadable)
  end

  test "an obstacle names the gem or the bracelet that clears it, and a stock move its move" do
    orange, turquoise, bracelet, strength = played(:clearers)
    assert_equal [t(:perseida_gem_orange), t(:perseida_gem_turquoise)], [orange, turquoise]
    assert_equal played(:bracelet_name), bracelet
    assert_equal played(:stock_name), strength
  end

  test "a tree named Arbol is the thorns' obstacle while it stands, and nothing else is" do
    assert_equal [t(:perseida_thorns), nil, nil], played(:gate_line)
  end

  test "only someone other than the following Pokemon bars the water" do
    assert_equal [true, false, true], played(:company)
  end

  test "water ahead is said sailable with the gem, and plain without it" do
    assert_equal [[[t(:perseida_sail_ahead), false]], [[t(:water_ahead), false]]], played(:water_cues)
  end

  test "the action key pulls what its pushes move, and a boulder asks for no Strength" do
    assert_equal [true, nil, false], played(:pushes)
  end

  test "core's lines go in the game's words" do
    want = [t(:edas_lens_on), t(:edas_lens_off), t(:perseida_thorns), t(:perseida_sail_here), t(:perseida_sail_toward, :dir => "al norte"),
            t(:perseida_sail_company), t(:perseida_dismount_route), t(:perseida_dismount_here, :dir => "al norte"), t(:perseida_dismount_spot),
            t(:perseida_sail_ahead)]
    assert_equal want, played(:words)
  end

  test "money is said in Crowns, a hundredth of what the game counts, with the game's own unit" do
    assert_equal ["12.5 Coronas", "3 Coronas", "0.01 Coronas"], played(:crowns)
  end

  test "any other line stands" do
    assert_equal t(:pk_shiny), played(:plain_line)
  end

  test "a sizeC event covers its size where it is acted on, and the note leaves its name" do
    assert_equal [[[5, 3], [6, 3], [7, 3]], 6, 1, "Vena"], played(:size_events)
  end

  test "its extra keys answer for the buttons its Input reads them by" do
    assert_equal [:text_log, :clara_bag, :clara_map, :a, nil], played(:extra_buttons)
  end

  test "the remap screen tells what its buttons do and takes its F, B, M and T keys" do
    assert_equal [:perseida_btn_x, :perseida_btn_y, :perseida_btn_z, :edas_btn_l, :perseida_btn_r], played(:labels)
    assert_equal [[:text_log, 0x46, :perseida_key_f], [:clara_bag, 0x42, :perseida_key_b], [:clara_map, 0x4D, :perseida_key_m],
                  [:clara_cometry, 0x54, :perseida_key_t]], played(:extras)
  end

  test "the game's M ships on Alt + M, until the remap screen gives it a key" do
    assert_equal [true, false, PokeAccess::Keyboard.with_alt(0x4D), 0x4E], played(:m_key)
  end

  test "Alt + M opens the map once and takes the press from the coordinates, and M alone stays theirs" do
    assert_equal [[false, true], [false, false], [false, false], [true, false], [false, false]], played(:alt_m)
  end

  test "a pause entry says its name and the key its icon paints; one painting none, or one it does not read, its name" do
    assert_equal [["Mochila, #{t(:perseida_pause_key, :key => 'B')}", true]], played(:pause_focus)
    assert_equal [["Opciones", true]], played(:pause_no_key)
    assert_equal [["Cometry", true]], played(:pause_star)
  end

  test "with key hints off a pause entry says its name" do
    assert_equal [["Mochila", true]], played(:pause_brief)
  end

  test "the info key adds the mana and, on these screens, the map's name and the time" do
    menu = played(:trainer_menu)
    assert_includes menu, t(:perseida_mana, :n => 120, :max => 200)
    assert_includes menu, "14:05"
    refute_includes played(:trainer_out), "14:05"
    refute_includes played(:trainer_out), t(:perseida_mana, :n => 120, :max => 200)
    refute_includes played(:after_menu), "14:05"
    refute_includes played(:after_menu), t(:perseida_mana, :n => 120, :max => 200)
  end

  test "the Pokegear opened from the menu paints no place nor mana, and the menu still does after a screen on it closes" do
    gear, clock, menu = played(:trainer_nested)
    mana = t(:perseida_mana, :n => 120, :max => 200)
    refute_includes gear, "14:05"
    refute_includes gear, mana
    assert_includes clock, "14:05"
    assert_includes menu, "14:05"
    assert_includes menu, mana
  end

  test "the info key on the clock says the trainer too" do
    assert_includes played(:clock_info), "Coronas"
  end

  test "the row key keeps the gem under the selector, until the clock closes" do
    row, after = played(:clock_row)
    assert_includes row, "Joya Azul"
    refute_includes after.to_s, "Joya Azul"
  end

  test "the clock's dial is said as it opens, only with gems on it" do
    with, without = played(:clock_dial)
    gems = t(:perseida_clock_gems, :list => "#{t(:perseida_gem_turquoise)}, #{t(:perseida_gem_orange)}")
    assert_equal gems, with.last[0]
    assert_equal false, with.last[1]
    refute(without.any? { |text, _i| text == gems })
  end

  test "each IV's letter is the icon the game draws for it" do
    assert_equal %w[S A B B C C D D F], played(:letters)
  end

  test "the IV letters go by the stat each rates, not the row the page draws it beside" do
    list = "#{t(:st_hp)} S, #{t(:st_atk)} A, #{t(:st_def)} F, #{t(:st_spatk)} D, #{t(:st_spdef)} C, #{t(:st_speed)} B"
    assert_equal t(:perseida_ivs, :list => list), played(:ivs)
  end

  test "page two says the stats with the EVs and letters, how to open the ability, and only once" do
    first, repeat = played(:page_two)
    stats = played(:stats_expected)
    assert_includes stats, t(:clara_evs, :list => "#{t(:st_hp)} 4, #{t(:st_atk)} 252, #{t(:st_def)} 0, #{t(:st_spatk)} 1, #{t(:st_spdef)} 247, #{t(:st_speed)} 6")
    assert_includes stats, played(:ivs)
    assert_equal [["#{stats} #{t(:perseida_info_hint, :key => 'C')}", false]], first
    assert_equal [], repeat
  end

  test "a magnific Pokemon's header says its mark after the others, and any other's stands" do
    with, without = played(:magnific)
    assert_equal [without, t(:perseida_magnific)].reject { |part| part.empty? }.join(", "), with
    refute_includes without, t(:perseida_magnific)
  end

  test "page three says the moves, and the page painted over it on leaving the cursor says nothing" do
    assert_equal [[played(:moves_expected), false]], played(:page_three)
    assert_equal [], played(:page_four)
  end

  test "leaving the move cursor says the moves again" do
    assert_equal 1, played(:back_from_moves)
  end

  test "the ribbon cursor says each ribbon with its place, the first queued, and past the last nothing" do
    first, repeat, second, past = played(:ribbon)
    a, b = played(:ribbon_parts)
    assert_equal [[PokeAccess.sentences([T_ENTRY.call(a[0], 1, 2), a[1]]), false]], first
    assert_equal [], repeat
    assert_equal [[PokeAccess.sentences([T_ENTRY.call(b[0], 2, 2), b[1]]), true]], second
    assert_equal [], past
  end

  test "leaving the ribbon cursor says the ribbons page again" do
    same, back = played(:ribbon_back)
    assert_equal [], same
    assert_equal 1, back
  end

  test "the info key answers for the ribbon while its cursor is up" do
    assert_equal [false, true, false], played(:detail_focus)
  end

  test "the PC's full details add the IV letters, the sign and whether it can Mega Evolve" do
    full = played(:pc_details)
    assert_includes full, played(:ivs)
    assert_includes full, t(:perseida_sign, :name => "Vena")
    assert_includes full, t(:perseida_mega_able)
  end

  test "a Pokemon with no sign says none in the PC" do
    assert_equal 0, played(:pc_no_sign)
  end

  test "the party's mana is said queued as it opens and when it changes, not at each refresh" do
    opened, same, changed = played(:party_mana)
    assert_equal [[t(:perseida_mana, :n => 120, :max => 200), false]], opened
    assert_equal [], same
    assert_equal [[t(:perseida_mana, :n => 20, :max => 200), false]], changed
  end

  test "a brief party reading leaves the mana out" do
    assert_equal [], played(:party_mana_brief)
  end

  test "a Pokemon with its star power on says so among the row's marks" do
    assert_equal [true, false], played(:blessed)
  end

  test "a bag row marks the key its item is registered to, for the core's plain mark" do
    assert_equal [[[:ins_bag_key, { :key => "F4" }]], []], played(:bag_key)
    assert_equal false, played(:bag_plain)
  end

  test "a book says each page once, title, place and text, the first queued and with how to turn pages" do
    first, repeat, second, held = played(:book)
    one = PokeAccess.sentences([t(:list_entry, :name => "Tomo I", :n => 1, :tot => 3), "Texto uno"])
    two = PokeAccess.sentences([t(:list_entry, :name => "Tomo II", :n => 2, :tot => 3), "Texto dos"])
    assert_equal [["#{one} #{t(:perseida_book_hint)}", false]], first
    assert_equal [], repeat
    assert_equal [[two, true]], second
    assert_equal two, held
  end

  test "closing a book takes it off the info key, and a page it lacks says nothing" do
    assert_nil played(:book_closed)
    assert_equal [], played(:book_past)
  end

  test "the gifts say their title, each row by the cursor, and the row again when they come back" do
    opened, rows = played(:gift)
    assert_equal [["Regalo misterioso", false]], opened
    assert_equal [[["Recibir via Internet", false]], [["Salir", true]], [], [], [["Salir", true]]], rows
  end

  test "the quest's first page says the overview and the goal, as this copy paints them" do
    want = "Mision 3. #{t(:quest_overview, :text => 'Busca la baya')}. #{t(:quest_task, :text => 'Etapa 2')}"
    assert_equal [[want, true]], played(:quest_one)
  end

  test "its second page says where, from whom, where it started and the reward, and no stage or time" do
    want = ["Mision 3", t(:quest_location, :text => t(:quest_unset)), t(:quest_giver, :who => "Falcar"),
            t(:quest_where, :where => "Pueblo Libra"), t(:quest_reward, :what => "Una baya")].join(". ")
    assert_equal [[want, true]], played(:quest_two)
  end

  test "a field it leaves blank is said unset on that page" do
    text = played(:quest_unset)[0][0]
    assert_includes text, t(:quest_giver, :who => t(:quest_unset))
    assert_includes text, t(:quest_reward, :what => t(:quest_unset))
  end

  test "a recipe's yield is its row's third field, above one" do
    assert_equal [2, nil, nil, nil], played(:yields)
  end

  test "each marker picture has its word, and an unknown one none" do
    assert_equal [:perseida_qm_red, :qm_excl_blue, :perseida_qm_question, :perseida_qm_green, :perseida_qm_push, nil], played(:markers)
  end

  test "the encounter list says a map with no wild Pokemon, and each page with its species" do
    assert_equal [[t(:enc_none, :loc => played(:enc_map)), true]], played(:enc_none)
    assert_equal [], played(:enc_data)
    page = played(:enc_page)
    assert_equal 1, page.length
    assert_includes page[0][0], t(:rea_enc_owned, :n => 0)
    assert_includes page[0][0], "Hierba"
    assert_equal true, page[0][1]
  end

  test "each species of a page goes by its Pokedex state, and the caught are counted" do
    entries, line, first = played(:enc_entries)
    assert_equal [:dex_caught, :dex_seen, :dex_unknown], entries.map { |_name, state| state }
    assert_equal first, entries[0][0]
    assert_includes line, first
    assert_includes line, t(:rea_enc_owned, :n => 1)
  end

  T_ENTRY = lambda { |name, n, tot| PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => tot) }
end
