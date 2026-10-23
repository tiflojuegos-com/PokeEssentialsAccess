require "rbconfig"
require "tmpdir"

# The Uranium profile loaded whole in a process of its own (its overrides would reach every other test here), over
# stand-ins shaped as Uranium's own classes: its hooks bind, and each screen says what it paints.
class UraniumProfileTest < PokeAccessTest
  # The Uranium-shaped classes and functions, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    class UraBox; attr_accessor :text; def initialize(t = ""); @text = t; end; end
    def Kernel.pbMessage(message, *a); Kernel.pbMessageDisplay(UraBox.new, message); 0; end
    def Kernel.pbMessageDisplaySystem(pos, msgwindow, message, letterbyletter = true, commandProc = nil)
      return :no_window if !msgwindow
      msgwindow.text = message
      ret = nil
      ret = commandProc.call(msgwindow) if commandProc
      ret
    end
    def Kernel.pbMessageSystem(pos, black, message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
      msgwindowsave = UraBox.new
      Kernel.pbMessageDisplaySystem(pos, msgwindowsave, message, &block)
      0
    end
    class UraPagedBox
      def initialize; @textchars = []; @curchar = 0; @pause = false; end
      def text=(t); @textchars = t.to_s.chars; @curchar = 0; end
      def draw(n); @curchar = [n, @textchars.length].min; @pause = @curchar < @textchars.length; end
      def length; @textchars.length; end
      def pausing?; @pause; end
      def busy?; @curchar < @textchars.length; end
    end
    class GenCustomStyle; def initialize; end; end

    UraTrainer = Struct.new(:name, :party)
    class UraSave
      attr_reader :trainer, :nuzlocke, :randomizer
      def initialize(title, trainer, nuzlocke = false, randomizer = false)
        @title = title; @trainer = trainer; @nuzlocke = nuzlocke; @randomizer = randomizer
      end
      def title; @title; end
      def name; @trainer.name; end
      def map; "Route 3"; end
      def playtime; "5h 3m"; end
    end
    UraOldSave = Struct.new(:title)
    class UraSlot
      attr_reader :main, :auto
      def initialize(main, auto = nil, autonewer = false, same_time = false)
        @main = main; @auto = auto; @autonewer = autonewer; @same_time = same_time
      end
      def newer; @autonewer ? @auto : @main; end
      def autonewer?; @autonewer; end
      def same_time?; @same_time; end
    end
    class PokemonLoadPanel
      def initialize(index, title, savefile, viewport = nil)
        @index = index; @title = title; @savefile = savefile; @refreshBitmap = true
        refresh
      end
      def pbRefresh; @refreshBitmap = true; refresh; end
      def refresh
        return unless @refreshBitmap
        @refreshBitmap = false
        textpos = [[@title, 32, 10, 0, nil, nil]]
        if @savefile
          textpos.push(["Badges:", 32, 112, 0, nil, nil], ["2", 206, 112, 1, nil, nil])
          textpos.push(["Time:", 32, 176, 0, nil, nil], [@savefile.playtime, 206, 176, 1, nil, nil])
          textpos.push([@savefile.name, 112, 64, 0, nil, nil], [@savefile.map, 386, 10, 1, nil, nil])
        end
        pbDrawTextPositions(nil, textpos)
      end
    end
    class PokemonLoadScene
      def pbStartScene(commands, savefile = nil)
        @commands = commands
        @sprites = {}
        commands.each_with_index do |c, i|
          @sprites["panel#{i}"] = PokemonLoadPanel.new(i, c, (savefile && i == 0 ? savefile : nil))
          @sprites["panel#{i}"].pbRefresh
        end
      end
      def pbSetParty(trainer); @party = trainer.party; end
      def pbStartScene2; nil; end
      def pbDrawCurrentSaveFile(savefile = nil); pbDrawTextPositions(nil, [[savefile.title, 2, 0, 0]]) if savefile; end
      def pbDrawSaveCommands(savefiles, selected = nil)
        @savefiles = savefiles
        pbDrawTextPositions(nil, savefiles.map { |s| [s.newer.title, 256, 8, 2] })
        pbMoveSaveSel(selected) if selected != nil
      end
      def pbMoveSaveSel(index); @index = index; end
      def pbChooseAutoSubFile(index, saveslot)
        unless @sprites["mainsavefile"]
          @sprites["mainsavefile"] = UraBox.new
          @sprites["autosavefile"] = UraBox.new
          same = saveslot.same_time?
          rows = [saveslot.newer.name, "Normal Save", "Autosave", "01/02/26 10:00:00 AM",
                  same ? "01/02/26 10:00:00 AM" : "01/03/26 11:00:00 AM", "5h 3m", same ? "5h 3m" : "6h 0m"]
          rows.push("Newer") unless same
          pbDrawTextPositions(nil, rows.each_with_index.map { |t, i| [t, 100, 30 + i * 10, 2] })
        end
        @index = index
      end
    end

    class CheckboxOption
      attr_reader :name, :helptext, :disabledmsg
      def initialize(name, helptext, getProc, setProc, enabledProc = nil, disabledmsg = nil, unlockedProc = nil, lockedmsg = nil)
        @name = name; @helptext = helptext; @enabledProc = enabledProc; @disabledmsg = disabledmsg
        @unlockedProc = unlockedProc
      end
      def enabled?; @enabledProc ? @enabledProc.call : true; end
      def unlocked?; @unlockedProc ? @unlockedProc.call : true; end
    end
    UraRule = Struct.new(:name, :helptext)
    class Window_PokemonNuzOption < Window_DrawableCommand
      attr_reader :mustUpdateOptions
      attr_accessor :press
      def initialize(options, x, y, width, height, exitmessage)
        @options = options; @exitmessage = exitmessage; @optvalues = options.map { false }
        @mustUpdateOptions = false; @index = 0; @active = true
      end
      def [](i); @optvalues[i]; end
      def []=(i, value); @optvalues[i] = value; refresh; end
      def itemCount; @options.length + 1; end
      def update
        @mustUpdateOptions = false
        super
        return unless @press && self.active && self.index < @options.length
        @press = false
        o = @options[self.index]
        if o.enabled? && o.unlocked?
          self[self.index] = !self[self.index]
          @mustUpdateOptions = true
        elsif o.disabledmsg
          Kernel.pbMessage(o.disabledmsg)
        end
      end
    end
    class PokemonRulesetScene
      def pbStartScene; @sprites = { "title" => UraBox.new("Custom Game Settings") }; end
    end
    class GenderSelectorScene
      def selectBoy(first = false); @select = 0; end
      def selectNeutral; @select = 1; end
      def selectGirl; @select = 2; end
    end
    class Window_TextEntry
      def initialize(text = ""); @text = text; end
      def insert(ch); true; end
      def delete; true; end
      def update; nil; end
      def deleteAtCursor
        return false if @text.empty?
        @text = @text[0...-1]
        true
      end
    end

    class IconMenu; def setActive(flag); @active = flag; end; end
    class UraTeamPreview; attr_reader :party; def initialize(party); @party = party; end; end
    class PokemonMenu_Scene
      KEYS = %w[iconPokedex iconPokemon iconBag iconPokepod iconCard iconSave iconOption iconExit]
      attr_accessor :moves
      def pbStartScene
        @sprites = {}
        (KEYS + ["iconRun"]).each { |k| @sprites[k] = IconMenu.new }
        @textos = %w[POKÉDEX POKÉMON BAG POKÉPOD Vitor SAVE OPTIONS EXIT].map { |t| [[t, 254, 8, 2], ["Route 3", 256, 256, 2]] }
        @ret = 1
        @run = false
      end
      def unSelAll; KEYS.each { |k| @sprites[k].setActive(false) }; end
      def pbUpdateSelect(skip = false)
        ret = @ret
        loop do
          unSelAll
          @sprites[KEYS[ret]].setActive(true)
          pbDrawTextPositions(nil, @textos[ret])
          step = (@moves || []).shift
          if step == :right
            ret = (ret + 1) % 8
          elsif step == :run
            @run = !@run
            @sprites["iconRun"].setActive(@run)
          end
          break if skip || step.nil?
        end
        @ret = ret
      end
      def pbEndScene; @sprites = {}; end
    end

    class PokemonBag
      def self.pocketNames; ["", "Items", "Medicine", "Poke Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]; end
    end
    UraBagData = Struct.new(:pockets, :keyItemsSelected)
    class UraMart
      NAMES = { 1 => "Potion", 2 => "Super Potion", 50 => "TM01 Focus Punch", 600 => "Bicycle", 601 => "Town Map",
                602 => "Itemfinder" }
      def getDisplayName(i); NAMES[i]; end
      def getDescription(i); "About #{NAMES[i]}."; end
    end
    def pbIsImportantItem?(i); i >= 50; end
    def pbIsKeyItem?(i); i >= 600; end
    module ItemHandlers; def self.hasKeyItemHandler(i); [600, 602].include?(i); end; end
    class Window_DrawableCommandBag < SpriteWindow_SelectableEx
      def update; old = self.index; super; refresh if self.index != old; end
      def refresh; end
    end
    class Window_CommandKeyItems < Window_DrawableCommand; end
    class Window_PokemonBag < Window_DrawableCommandBag
      attr_reader :pocket
      attr_accessor :sortIndex
      def initialize(bag, pocket); super(); @bag = bag; @pocket = pocket; @sortIndex = -1; @adapter = UraMart.new; end
      def pocket=(value); @pocket = value; self.index = 0; end
    end
    class PokemonBag_Scene
      def initialize(win); @sprites = { "itemwindow" => win }; end
      def pbChooseItem; @sprites["itemwindow"].update; 0; end
      def pbDisplay(msg); UIHelper.pbDisplay(nil, msg); end
      def pbConfirm(msg); UIHelper.pbConfirm(nil, msg); end
      # The BW bag script's own copy of the helper, nested in the scene, which the scene's methods reach first.
      module UIHelper
        def self.pbDisplay(_helpwindow, _msg, _brief = false); :shown; end
        def self.pbConfirm(_helpwindow, _msg); true; end
      end
    end

    Object.send(:remove_const, :Window_Pokedex)
    class SpriteWindow_SelectableDex < SpriteWindow_Base
      def update; @index; end
    end
    class Window_DrawableCommandDex < SpriteWindow_SelectableDex
      def update; old = self.index; super; refresh if self.index != old; end
      def refresh; end
    end
    class Window_Pokedex < Window_DrawableCommandDex
      attr_accessor :commands
      def initialize(commands); super(); @commands = commands; end
    end
    class PokedexFormScene
      def pbStartScene(species)
        @species = species
        pbDrawTextPositions(nil, [["FORMS", 34, 8, 0], ["FORMS SEEN", 280, 222, 0], ["SHINY SEEN", 280, 254, 0],
                                  ["3", 462, 222, 0], ["1", 462, 254, 0]])
      end
      def pbChooseForm(plus); pbUpdate; end
      def pbUpdate; pbDrawTextPositions(nil, [["Bulbasaur", 354, 94, 0], ["Male Shiny", 365, 22, 2]]); end
    end
    class PokemonSummaryScene; remove_method :drawPageFive; end

    class UraSlider < SliderOption
      attr_reader :lowtext
      def initialize(name, optstart, optend, lowtext = nil); super(name, optstart, optend); @lowtext = lowtext; end
      def next(v); v + 5 > optend ? optend : v + 5; end
    end
  RUBY

  # The toolkit with the Uranium profile and the test's speech capture, Reset and nets, loaded after the world. With
  # PA_COVERAGE set (tools/coverage.rb), the mod's coverage in this process goes to <PA_COVERAGE>_uranium.json, in the
  # format test/test_helper.rb writes for the test processes.
  BOOT = <<-'RUBY'
    if ENV["PA_COVERAGE"]
      require "coverage"
      require "json"
      Coverage.setup(:lines => true, :branches => true, :eval => true)
      Coverage.resume
      at_exit do
        root = Harness::ROOT.tr("\\", "/") + "/"
        out = {}
        Coverage.result.each do |path, cov|
          rel = path.tr("\\", "/").sub(root, "")
          next unless rel =~ %r{\A(core|games|plugins|loader)/}
          branches = {}
          (cov[:branches] || {}).each do |cond, targets|
            targets.each { |t, n| branches["#{cond.inspect}|#{t.inspect}"] = n }
          end
          out[rel] = { "lines" => cov[:lines], "branches" => branches }
        end
        File.write("#{ENV['PA_COVERAGE']}_uranium.json", JSON.generate(out))
      end
    end
    PA_LOAD_ERRORS = Harness.load_all("uranium")
    %w[speak_capture poke_builder reset arity_net].each { |f| require File.join(Harness::ROOT, "test", "support", f) }
    SpeakCapture.install
  RUBY

  # The scope each scenario runs in, in the Uranium process: a fresh binding of one, with the scenarios' helpers.
  KIT = <<-'RUBY'
    class UraScope
      include SpeechHelpers

      # A binding of this scope, for one scenario's code.
      def fresh; binding; end

      # Runs the block with $Trainer as a trainer whose party is team, put back after.
      def with_party(team)
        saved = $Trainer
        $Trainer = UraTrainer.new("Vitor", team)
        yield
      ensure
        $Trainer = saved
      end

      # Runs the block with $Trainer as a Pokedex owner who has seen species 1 and 4 and caught 1, put back after.
      def with_dex_owner
        saved = $Trainer
        owner = Object.new
        def owner.seen?(species); [1, 4].include?(species); end
        def owner.owned?(species); species == 1; end
        $Trainer = owner
        yield
      ensure
        $Trainer = saved
      end

      # Runs the block with the info key down on every poll of the mod's keys and the game window focused, yielding
      # a poll; the keys are put back after.
      def with_info_key_down
        keys = PokeAccess::Keys
        saved = [keys.method(:key), keys.method(:focused?)]
        keys.define_singleton_method(:key) { |name| name == :info }
        keys.define_singleton_method(:focused?) { true }
        yield(lambda { keys.global_poll })
      ensure
        keys.define_singleton_method(:key, saved[0])
        keys.define_singleton_method(:focused?, saved[1])
      end

      # The team the menu's preview draws: Pika holding an item, Chu holding none.
      def menu_team; [Poke.build(:name => "Pika", :item => 5), Poke.build(:name => "Chu")]; end

      # The pause menu, open, its selection loop not run yet.
      def open_menu
        menu = PokemonMenu_Scene.new
        menu.pbStartScene
        menu
      end

      # The load screen opened with no save on offer, its speech cleared.
      def open_load_scene
        scene = PokemonLoadScene.new
        scene.pbStartScene(["Continue"])
        SpeakCapture.clear
        scene
      end

      # The other saves: Vitor's (Nuzlocke), Ana's whose autosave is the newer (Randomizer), Leo's (both rules) and
      # an older file that keeps no rules.
      def save_slots
        ana = UraSave.new("2: Ana", UraTrainer.new("Ana", []))
        ana_auto = UraSave.new("Autosave 2: Ana", UraTrainer.new("Ana", []), false, true)
        [UraSlot.new(UraSave.new("1: Vitor", UraTrainer.new("Vitor", []), true)), UraSlot.new(ana, ana_auto, true),
         UraSlot.new(UraSave.new("3: Leo", UraTrainer.new("Leo", []), true, true)), UraSlot.new(UraOldSave.new("4: Old"))]
      end

      # Ana's slot with both files, the autosave the newer unless main_newer, or saved at one time.
      def ana_slot(main_newer = false, same_time = false)
        main = UraSave.new("2: Ana", UraTrainer.new("Ana", []))
        UraSlot.new(main, UraSave.new("Autosave 2: Ana", UraTrainer.new("Ana", [])), !main_newer, same_time)
      end

      # The rules checklist: Nuzlocke, its Dupes Clause (greyed while Nuzlocke is off), a locked Randomizer, a Hard
      # Mode with no help, and a rule of another kind with neither prerequisite nor lock.
      def rules_checklist
        opts = [CheckboxOption.new("Nuzlocke", "Fainted Pokemon are dead.", nil, nil),
                CheckboxOption.new("  Dupes Clause", "Dupes are skipped.", nil, nil, proc { false },
                                   "Enable Nuzlocke first."),
                CheckboxOption.new("Randomizer", "All is random.", nil, nil, nil, nil, proc { false }),
                CheckboxOption.new("Hard Mode", "", nil, nil),
                UraRule.new("Monotype", "One type only.")]
        Window_PokemonNuzOption.new(opts, 0, 0, 0, 0, "Start Game")
      end

      # A bag: Items (Potion x3, TM01), Medicine (Repel x4, which the shop adapter does not name), Poke Balls empty,
      # Key Items (Bicycle registered, Town Map with no key-item handler, Itemfinder).
      def sample_bag
        UraBagData.new([[], [[1, 3], [50, 1]], [[25, 4]], [], [], [], [], [], [[600, 1], [601, 1], [602, 1]]], [600])
      end
    end
  RUBY

  # Runs each scenario after a reset, in the order given, and prints its outcome as a line the test reads back; the
  # nets' findings over all of them come last.
  RUNNER = <<-'RUBY'
    # Prints one outcome as a line the test reads back: the scenario's name and its value, marshalled in base64.
    def UraScope.report(name, result)
      dump = begin
        Marshal.dump(result)
      rescue StandardError => e
        Marshal.dump([:error, "its value cannot travel back: #{e.message}"])
      end
      puts "OUTCOME #{name} #{[dump].pack('m0')}"
      $stdout.flush
    end

    Marshal.load(File.binread(ARGV[0])).each do |name, code|
      result = begin
        Reset.before_test
        [:ok, eval(code, UraScope.new.fresh, "scenario #{name}")]
      rescue Exception => e
        [:error, ["#{e.class}: #{e.message}"].concat((e.backtrace || []).first(4)).join("\n  ")]
      end
      UraScope.report(name, result)
    end
    UraScope.report(:raw_texts, [:ok, SpeakCapture.raw_offenders.map { |_test, text| text }])
    UraScope.report(:arity_offenders, [:ok, ArityNet.offenders])
  RUBY

  # The classes built above that the mod hooks.
  SCREENS = %w[GenCustomStyle PokemonLoadPanel PokemonLoadScene Window_PokemonNuzOption PokemonRulesetScene
               GenderSelectorScene Window_TextEntry IconMenu PokemonMenu_Scene Window_DrawableCommandBag
               PokemonBag_Scene Window_DrawableCommandDex PokedexFormScene].freeze

  # The code of each scenario by name, run in the Uranium process.
  SCENARIOS = {}

  # Declares a scenario: code run in the Uranium process after a reset, whose last value comes back as its outcome.
  def self.scenario(name, code)
    raise ArgumentError, "#{self}: duplicate scenario #{name}" if SCENARIOS.key?(name)
    SCENARIOS[name] = code
  end

  scenario :load_errors, "PA_LOAD_ERRORS"
  test "loads with no error" do
    assert_equal [], outcome(:load_errors)
  end

  scenario :missing_hooks, "PokeAccess::Hooks.missing"
  test "binds every hook on the screens built here, reporting none of the stock pages they lack" do
    assert_equal [], outcome(:missing_hooks).select { |hook| SCREENS.include?(hook[/\A[^#]+/]) }
  end

  test "takes the stock summary's ribbon page as optional, where Uranium's summary has none" do
    refute_includes outcome(:missing_hooks), "PokemonSummaryScene#drawPageFive"
  end

  scenario :overrides, 'PokeAccess::Hooks.overrides.select { |o| o.include?("game_uranium") }.sort'
  test "replaces exactly its ten core readers" do
    assert_equal ["PokeAccess::DexEntry.gen6_info (game_uranium)", "PokeAccess::DexSearch.list (game_uranium)",
                  "PokeAccess::FieldMoves.can? (game_uranium)", "PokeAccess::LoadScreen.auto_sub (game_uranium)",
                  "PokeAccess::OptionHelp.read (game_uranium)", "PokeAccess::Options.value_of (game_uranium)",
                  "PokeAccess::Party.status_slot (game_uranium)", "PokeAccess::Summary.header_icons (game_uranium)",
                  "PokeAccess::Summary.painted_memo (game_uranium)",
                  "PokeAccess::SummaryGen6.stats_extras (game_uranium)"], outcome(:overrides)
  end

  scenario :system_message, <<-'RUBY'
    Kernel.pbMessageSystem(1, false, "What?\nPika is evolving!")
    SpeakCapture.log
  RUBY
  test "says a system message whole, queued" do
    assert_equal [["What? Pika is evolving!", false]], outcome(:system_message)
  end

  scenario :system_message_depth, <<-'RUBY'
    inside = nil
    shown = Kernel.pbMessageDisplaySystem(1, UraBox.new, "Pick one.", true,
                                          proc { |_w| inside = PokeAccess.message_depth; 3 })
    [shown, inside, PokeAccess.message_depth]
  RUBY
  test "is one message deeper while a system message shows, and back after it" do
    assert_equal [1, 0], outcome(:system_message_depth)[1, 2]
  end

  test "hands back what the game's system message returns" do
    assert_equal 3, outcome(:system_message_depth)[0]
  end

  scenario :system_message_unsaid, <<-'RUBY'
    no_window = Kernel.pbMessageDisplaySystem(1, nil, "Lost.")
    no_text = Kernel.pbMessageDisplaySystem(1, UraBox.new, nil, true, proc { |_w| :shown })
    [no_window, no_text, SpeakCapture.log]
  RUBY
  test "lets a system message with no window or no text through to the game, saying nothing" do
    assert_equal [:no_window, :shown, []], outcome(:system_message_unsaid)
  end

  scenario :system_message_paged, <<-'RUBY'
    PokeAccess::Config.dialogue_pages = true
    Kernel.pbMessageDisplaySystem(1, UraPagedBox.new, "Your Pokemon is now cured.", true,
                                  proc { |w| w.draw(12); PokeAccess::DialoguePages.poll; w.draw(w.length) })
    SpeakCapture.log
  RUBY
  test "with dialogue pages on, reads a system message page by page as drawn, the rest as it closes" do
    assert_equal [["Your Pokemon", true], ["is now cured.", true]], outcome(:system_message_paged)
  end

  scenario :system_message_at_once, <<-'RUBY'
    PokeAccess::Config.dialogue_pages = true
    Kernel.pbMessageDisplaySystem(1, UraPagedBox.new, "Your bag is now full.", false,
                                  proc { |w| w.draw(12); PokeAccess::DialoguePages.poll; w.draw(w.length) })
    SpeakCapture.log
  RUBY
  test "says a system message drawn at once whole, even with dialogue pages on" do
    assert_equal [["Your bag is now full.", false]], outcome(:system_message_at_once)
  end

  scenario :title, "GenCustomStyle.new; SpeakCapture.log"
  test "says the title prompt once as the custom title shows, interrupting" do
    prompt = "#{t(:title_screen)}. #{t(:title_press, :key => t(:key_enter))}"
    assert_equal [[prompt, true]], outcome(:title).select { |_text, interrupt| interrupt }
  end

  scenario :continue_panel, <<-'RUBY'
    team = [Poke.build(:species => 25), Poke.build(:species => 1)]
    save = UraSave.new("1: Vitor", UraTrainer.new("Vitor", team), true)
    scene = PokemonLoadScene.new
    scene.pbStartScene(["Continue", "New Game"], save)
    scene.pbSetParty(save.trainer)
    SpeakCapture.clear
    scene.pbStartScene2
    SpeakCapture.log
  RUBY
  test "opens the load screen on the continue panel as painted, with the saved team and rules, queued" do
    team = t(:load_party, :list => "Especie25, Especie1")
    assert_equal [["Route 3. Vitor. Badges: 2. Time: 5h 3m. #{team}. #{t(:ura_nuzlocke)}", false]],
                 outcome(:continue_panel)
  end

  scenario :no_save, <<-'RUBY'
    scene = PokemonLoadScene.new
    scene.pbStartScene(["New Game", "Options"])
    SpeakCapture.clear
    scene.pbStartScene2
    SpeakCapture.log
  RUBY
  test "says nothing as the load screen opens with no save on offer" do
    assert_equal [], outcome(:no_save)
  end

  scenario :panel_without_save, <<-'RUBY'
    PokeAccess::PaintCapture.sample { PokemonLoadPanel.new(1, "New Game", nil) }.map { |row| row[0] }
  RUBY
  test "leaves a panel without a save to paint as the game does" do
    assert_equal ["New Game"], outcome(:panel_without_save)
  end

  scenario :other_saves, <<-'RUBY'
    scene = open_load_scene
    scene.pbDrawSaveCommands(save_slots)
    (1..3).each { |i| scene.pbMoveSaveSel(i) }
    SpeakCapture.log
  RUBY
  test "says each other save by its slot's newest file and that file's rules, the first queued" do
    assert_equal [["1: Vitor, #{t(:ura_nuzlocke)}", false], ["Autosave 2: Ana, #{t(:ura_randomizer)}", true],
                  ["3: Leo, #{t(:ura_nuzlocke)}, #{t(:ura_randomizer)}", true], ["4: Old", true]], outcome(:other_saves)
  end

  scenario :other_saves_still, <<-'RUBY'
    scene = open_load_scene
    scene.pbDrawSaveCommands(save_slots)
    scene.pbMoveSaveSel(1)
    SpeakCapture.clear
    scene.pbMoveSaveSel(1)
    scene.pbMoveSaveSel(9)
    SpeakCapture.log
  RUBY
  test "says nothing for the save it is on already, or past the list" do
    assert_equal [], outcome(:other_saves_still)
  end

  scenario :other_saves_redrawn, <<-'RUBY'
    scene = open_load_scene
    scene.pbDrawSaveCommands(save_slots)
    scene.pbMoveSaveSel(1)
    SpeakCapture.clear
    scene.pbDrawSaveCommands(save_slots, 1)
    SpeakCapture.log
  RUBY
  test "says the save a redrawn list lands on once, queued" do
    assert_equal [["Autosave 2: Ana, #{t(:ura_randomizer)}", false]], outcome(:other_saves_redrawn)
  end

  scenario :chooser, <<-'RUBY'
    scene = open_load_scene
    slot = ana_slot
    [0, 1, 1].each { |side| scene.pbChooseAutoSubFile(side, slot) }
    SpeakCapture.log
  RUBY
  test "says each side of the normal and autosave chooser once as the cursor lands on it, Newer on the newer" do
    assert_equal [["Ana. Normal Save, 01/02/26 10:00:00 AM, 5h 3m", false],
                  ["Autosave, 01/03/26 11:00:00 AM, 6h 0m, Newer", true]], outcome(:chooser)
  end

  scenario :chooser_main_newer, <<-'RUBY'
    scene = open_load_scene
    slot = ana_slot(true)
    [0, 1].each { |side| scene.pbChooseAutoSubFile(side, slot) }
    SpeakCapture.lines
  RUBY
  test "puts Newer on the normal side when the normal save is the newer" do
    assert_equal ["Ana. Normal Save, 01/02/26 10:00:00 AM, 5h 3m, Newer", "Autosave, 01/03/26 11:00:00 AM, 6h 0m"],
                 outcome(:chooser_main_newer)
  end

  scenario :chooser_same_time, <<-'RUBY'
    scene = open_load_scene
    slot = ana_slot(false, true)
    [0, 1].each { |side| scene.pbChooseAutoSubFile(side, slot) }
    SpeakCapture.lines
  RUBY
  test "says both sides without Newer when they were saved at one time" do
    assert_equal ["Ana. Normal Save, 01/02/26 10:00:00 AM, 5h 3m", "Autosave, 01/02/26 10:00:00 AM, 5h 3m"],
                 outcome(:chooser_same_time)
  end

  scenario :checklist_rows, <<-'RUBY'
    win = rules_checklist
    win[3] = true
    (0..5).map { |i| win.index = i; PokeAccess::Menus.focused_text(win) }
  RUBY
  test "reads each rule as its name, the state its box shows and its help, the exit command last" do
    assert_equal ["Nuzlocke, #{t(:val_off)}. Fainted Pokemon are dead.",
                  "Dupes Clause, #{t(:ura_opt_unavailable)}. Dupes are skipped.",
                  "Randomizer, #{t(:ura_opt_locked)}. All is random.",
                  "Hard Mode, #{t(:val_on)}",
                  "Monotype, #{t(:val_off)}. One type only.",
                  "Start Game"], outcome(:checklist_rows)
  end

  scenario :checklist_moves, <<-'RUBY'
    win = rules_checklist
    win.update
    win.index = 1
    win.update
    SpeakCapture.log
  RUBY
  test "says each rule the cursor moves to, the first queued, and no state while no box flips" do
    assert_equal [["Nuzlocke, #{t(:val_off)}. Fainted Pokemon are dead.", false],
                  ["Dupes Clause, #{t(:ura_opt_unavailable)}. Dupes are skipped.", true]], outcome(:checklist_moves)
  end

  scenario :checklist_flips, <<-'RUBY'
    win = rules_checklist
    win.update
    (1..2).map do
      SpeakCapture.clear
      win.press = true
      win.update
      SpeakCapture.log.dup
    end
  RUBY
  test "says a flipped box's new state each time, interrupting" do
    assert_equal [[[t(:val_on), true]], [[t(:val_off), true]]], outcome(:checklist_flips)
  end

  scenario :checklist_greyed, <<-'RUBY'
    win = rules_checklist
    win.index = 1
    win.update
    SpeakCapture.clear
    win.press = true
    win.update
    SpeakCapture.log
  RUBY
  test "says why a greyed rule does not change, and no state" do
    assert_equal [["Enable Nuzlocke first.", false]], outcome(:checklist_greyed)
  end

  scenario :checklist_title, "PokemonRulesetScene.new.pbStartScene; SpeakCapture.log"
  test "says the checklist's title as it opens, queued" do
    assert_equal [["Custom Game Settings", false]], outcome(:checklist_title)
  end

  scenario :gender_pictures, <<-'RUBY'
    scene = GenderSelectorScene.new
    scene.selectBoy(true)
    scene.selectNeutral
    scene.selectGirl
    scene.selectBoy
    SpeakCapture.log
  RUBY
  test "names each picture of the gender selector, the boy at first queued and every later move interrupting" do
    assert_equal [[t(:gsel_boy), false], [t(:ura_gsel_neutral), true], [t(:gsel_girl), true], [t(:gsel_boy), true]],
                 outcome(:gender_pictures)
  end

  scenario :delete_char, 'Window_TextEntry.new("Vitor").deleteAtCursor; SpeakCapture.log'
  test "says a character deleted on the naming screen, interrupting" do
    assert_equal [[t(:te_deleted), true]], outcome(:delete_char)
  end

  scenario :delete_nothing, 'Window_TextEntry.new("").deleteAtCursor; SpeakCapture.log'
  test "says nothing when Delete has nothing to delete" do
    assert_equal [], outcome(:delete_nothing)
  end

  scenario :delete_holds_keys, <<-'RUBY'
    PokeAccess::Info.set_info(:text, "Ruta 3")
    with_info_key_down do |poll|
      Window_TextEntry.new("Vitor").deleteAtCursor
      SpeakCapture.clear
      poll.call
      held = SpeakCapture.lines.dup
      4.times { poll.call }
      [held, SpeakCapture.lines]
    end
  RUBY
  test "holds the mod's keys for the frames after a deletion, the info key reading again once the hold lapses" do
    assert_equal [[], ["Ruta 3"]], outcome(:delete_holds_keys)
  end

  scenario :menu_opens, <<-'RUBY'
    with_party(menu_team) do
      open_menu.pbUpdateSelect(true)
      [SpeakCapture.log, PokeAccess::Info.info_text]
    end
  RUBY
  test "opens the menu on its lit icon, the map line and the running icon's state, queued" do
    assert_equal [["POKÉMON. Route 3. #{t(:ura_run_state, :state => t(:val_off))}", false]], outcome(:menu_opens)[0]
  end

  test "puts the team with the item icons its preview draws on the info key while the menu is up" do
    assert_equal t(:ura_menu_team, :list => "Pika, #{t(:pty_item)}; Chu"), outcome(:menu_opens)[1]
  end

  scenario :menu_opens_running, <<-'RUBY'
    menu = open_menu
    menu.instance_variable_get(:@sprites)["iconRun"].setActive(true)
    menu.pbUpdateSelect(true)
    SpeakCapture.lines
  RUBY
  test "opens the menu with running on where its running icon is lit" do
    assert_equal ["POKÉMON. Route 3. #{t(:ura_run_state, :state => t(:val_on))}"], outcome(:menu_opens_running)
  end

  scenario :menu_moves, <<-'RUBY'
    with_party(menu_team) do
      menu = open_menu
      menu.pbUpdateSelect(true)
      SpeakCapture.clear
      menu.moves = [:right, :right, :run, :run]
      menu.pbUpdateSelect
      SpeakCapture.log
    end
  RUBY
  test "says each icon a move lights and each flip of the running toggle, interrupting" do
    assert_equal [["BAG", true], ["POKÉPOD", true], [t(:ura_run_state, :state => t(:val_on)), true],
                  [t(:ura_run_state, :state => t(:val_off)), true]], outcome(:menu_moves)
  end

  scenario :menu_back, <<-'RUBY'
    with_party(menu_team) do
      menu = open_menu
      menu.pbUpdateSelect(true)
      menu.moves = [:right, :right]
      menu.pbUpdateSelect
      PokeAccess::Info.set_info(:text, "Party screen")
      SpeakCapture.clear
      menu.pbUpdateSelect
      [SpeakCapture.log, PokeAccess::Info.info_text]
    end
  RUBY
  test "back from a screen, says the lit icon again without the map line, queued" do
    assert_equal [["POKÉPOD", false]], outcome(:menu_back)[0]
  end

  test "back from a screen, puts the team back on the info key" do
    assert_equal t(:ura_menu_team, :list => "Pika, #{t(:pty_item)}; Chu"), outcome(:menu_back)[1]
  end

  scenario :menu_back_on_first, <<-'RUBY'
    menu = open_menu
    menu.pbUpdateSelect(true)
    menu.moves = [:right] * 7
    menu.pbUpdateSelect
    SpeakCapture.clear
    menu.pbUpdateSelect
    SpeakCapture.log
  RUBY
  test "back from a screen opened from the first icon, says that icon again" do
    assert_equal [["POKÉDEX", false]], outcome(:menu_back_on_first)
  end

  scenario :menu_redraw, <<-'RUBY'
    menu = open_menu
    menu.pbUpdateSelect(true)
    SpeakCapture.clear
    menu.pbUpdateSelect(true)
    SpeakCapture.log
  RUBY
  test "says nothing again on a menu pass that only redraws the selection" do
    assert_equal [], outcome(:menu_redraw)
  end

  scenario :menu_no_map_line, <<-'RUBY'
    menu = open_menu
    menu.instance_variable_get(:@textos)[1] = [["POKÉMON", 254, 8, 2]]
    menu.pbUpdateSelect(true)
    SpeakCapture.lines
  RUBY
  test "opens on the icon's caption and the running state alone where the menu paints no map line" do
    assert_equal ["POKÉMON. #{t(:ura_run_state, :state => t(:val_off))}"], outcome(:menu_no_map_line)
  end

  scenario :menu_no_run_icon, <<-'RUBY'
    menu = open_menu
    menu.instance_variable_get(:@sprites).delete("iconRun")
    menu.pbUpdateSelect(true)
    SpeakCapture.lines
  RUBY
  test "leaves the running state out where the menu has no running icon" do
    assert_equal ["POKÉMON. Route 3"], outcome(:menu_no_run_icon)
  end

  scenario :menu_preview_team, <<-'RUBY'
    with_party(menu_team) do
      menu = open_menu
      menu.instance_variable_get(:@sprites)["teampreview"] = UraTeamPreview.new([Poke.build(:name => "Eevee")])
      menu.pbUpdateSelect(true)
      PokeAccess::Info.info_text
    end
  RUBY
  test "takes the team from the preview the menu draws, over the trainer's" do
    assert_equal t(:ura_menu_team, :list => "Eevee"), outcome(:menu_preview_team)
  end

  scenario :menu_no_team, <<-'RUBY'
    with_party([]) do
      menu = open_menu
      PokeAccess::Info.set_info(:text, "Route 3 notes")
      menu.pbUpdateSelect(true)
      PokeAccess::Info.info_text
    end
  RUBY
  test "leaves the info key as it was when the team is empty" do
    assert_equal "Route 3 notes", outcome(:menu_no_team)
  end

  scenario :menu_icon_outside, <<-'RUBY'
    menu = open_menu
    menu.pbUpdateSelect(true)
    SpeakCapture.clear
    menu.instance_variable_get(:@sprites)["iconBag"].setActive(true)
    SpeakCapture.log
  RUBY
  test "says nothing for an icon lit outside the selection loop" do
    assert_equal [], outcome(:menu_icon_outside)
  end

  scenario :menu_closes, <<-'RUBY'
    with_party(menu_team) do
      menu = open_menu
      menu.pbUpdateSelect(true)
      menu.pbEndScene
      PokeAccess::Info.info_text
    end
  RUBY
  test "takes the team off the info key as the menu closes" do
    assert_nil outcome(:menu_closes)
  end

  scenario :bag_opens, <<-'RUBY'
    win = Window_PokemonBag.new(sample_bag, 1)
    win.update
    win.index = 1
    win.update
    win.update
    SpeakCapture.log
  RUBY
  test "opens the bag on its pocket and first row, queued, then each row once, a machine without a count" do
    assert_equal [["Items. Potion: 3, #{list_place(1, 2)}", false], ["TM01 Focus Punch, #{list_place(2, 2)}", true]],
                 outcome(:bag_opens)
  end

  scenario :bag_messages, <<-'RUBY'
    scene = PokemonBag_Scene.new(Window_PokemonBag.new(sample_bag, 1))
    [scene.pbDisplay("Se tiraron 3 Pociones."), scene.pbConfirm("¿Tirar 3 Pociones?"), SpeakCapture.lines]
  RUBY
  test "says the bag's messages and questions, which go through its own nested copy of UIHelper" do
    assert_equal [:shown, true, ["Se tiraron 3 Pociones.", "¿Tirar 3 Pociones?"]], outcome(:bag_messages)
  end

  scenario :bag_claimed, "win = Window_PokemonBag.new(sample_bag, 1); win.update; PokeAccess.dedicated?(win)"
  test "claims the bag list from the generic reader" do
    assert_equal true, outcome(:bag_claimed)
  end

  scenario :bag_info, <<-'RUBY'
    Window_PokemonBag.new(sample_bag, 1).update
    [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  RUBY
  test "keeps the focused item with the description its panel shows for the info key" do
    assert_equal "Pocion. About Potion.", outcome(:bag_info)[0]
  end

  test "keeps the focused bag row whole for Ctrl+T" do
    assert_equal "Potion: 3, #{list_place(1, 2)}", outcome(:bag_info)[1]
  end

  scenario :bag_key_items, <<-'RUBY'
    win = Window_PokemonBag.new(sample_bag, 8)
    [0, 1, 2].each { |i| win.index = i; win.update }
    SpeakCapture.lines
  RUBY
  test "marks each key item by the icon its row shows: registered, registrable, or none without a handler" do
    assert_equal ["Key Items. Bicycle, #{t(:bag_registered)}, #{list_place(1, 3)}", "Town Map, #{list_place(2, 3)}",
                  "Itemfinder, #{t(:bag_registrable)}, #{list_place(3, 3)}"], outcome(:bag_key_items)
  end

  scenario :bag_registered_in_place, <<-'RUBY'
    bag = sample_bag
    win = Window_PokemonBag.new(bag, 8)
    win.index = 2
    win.update
    SpeakCapture.clear
    bag.keyItemsSelected.push(602)
    win.update
    SpeakCapture.log
  RUBY
  test "says a key item again in place when it is registered under the cursor" do
    assert_equal [["Itemfinder, #{t(:bag_registered)}, #{list_place(3, 3)}", true]], outcome(:bag_registered_in_place)
  end

  scenario :bag_brief, <<-'RUBY'
    PokeAccess::Config.verbosity = :brief
    Window_PokemonBag.new(sample_bag, 8).update
    SpeakCapture.lines
  RUBY
  test "leaves the key-item marks out at brief verbosity" do
    assert_equal ["Key Items. Bicycle"], outcome(:bag_brief)
  end

  scenario :bag_row_changes, <<-'RUBY'
    bag = sample_bag
    win = Window_PokemonBag.new(bag, 1)
    win.update
    SpeakCapture.clear
    bag.pockets[1][0] = [1, 2]
    win.update
    bag.pockets[1][0] = [2, 2]
    win.update
    SpeakCapture.log
  RUBY
  test "says a bag row again when its count or its item changes under the cursor" do
    assert_equal [["Potion: 2, #{list_place(1, 2)}", true], ["Super Potion: 2, #{list_place(1, 2)}", true]],
                 outcome(:bag_row_changes)
  end

  scenario :bag_unnamed_by_adapter, "Window_PokemonBag.new(sample_bag, 2).update; SpeakCapture.lines"
  test "names a bag row its shop adapter cannot name by the item's own name" do
    assert_equal ["Medicine. Repel: 4, #{list_place(1, 1)}"], outcome(:bag_unnamed_by_adapter)
  end

  scenario :bag_empty_pocket, <<-'RUBY'
    with_intl("It's empty." => "Está vacío.") { Window_PokemonBag.new(sample_bag, 3).update }
    SpeakCapture.lines
  RUBY
  test "says an empty pocket's message in the game's own words" do
    assert_equal ["Poke Balls. Está vacío."], outcome(:bag_empty_pocket)
  end

  scenario :bag_inactive, <<-'RUBY'
    win = Window_PokemonBag.new(sample_bag, 1)
    win.active = false
    win.update
    SpeakCapture.log
  RUBY
  test "says nothing while the bag list is inactive" do
    assert_equal [], outcome(:bag_inactive)
  end

  scenario :bag_moving, <<-'RUBY'
    win = Window_PokemonBag.new(sample_bag, 1)
    win.update
    SpeakCapture.clear
    win.sortIndex = 0
    win.update
    SpeakCapture.log
  RUBY
  test "says the bag row picked for moving with its mark" do
    assert_equal [["Potion: 3, #{t(:bag_moving)}, #{list_place(1, 2)}", true]], outcome(:bag_moving)
  end

  scenario :bag_back_from_item, <<-'RUBY'
    win = Window_PokemonBag.new(sample_bag, 1)
    win.update
    SpeakCapture.clear
    PokemonBag_Scene.new(win).pbChooseItem
    SpeakCapture.log
  RUBY
  test "says the focused bag row again, queued, back in the list after an item's menu" do
    assert_equal [["Potion: 3, #{list_place(1, 2)}", false]], outcome(:bag_back_from_item)
  end

  scenario :key_items_list, <<-'RUBY'
    win = Window_CommandKeyItems.new([600, 602])
    win.update
    win.index = 1
    win.update
    win.update
    SpeakCapture.log
  RUBY
  test "says each item of the registered key items list with its place, the first queued, a move cutting in, once" do
    assert_equal [[key_row("Item600", 1), false], [key_row("Item602", 2), true]], outcome(:key_items_list)
  end

  scenario :key_items_info, <<-'RUBY'
    win = Window_CommandKeyItems.new([600, 602])
    win.update
    win.index = 1
    win.update
    [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  RUBY
  test "keeps the focused key item's sheet for the info key" do
    assert_equal "Item602", outcome(:key_items_info)[0]
  end

  test "keeps the focused key item's row with its place for Ctrl+T" do
    assert_equal key_row("Item602", 2), outcome(:key_items_info)[1]
  end

  scenario :key_items_levels, <<-'RUBY'
    win = Window_CommandKeyItems.new([600, 602])
    vb_levels { [PokeAccess::UraniumKeyItems.row(win, 1), PokeAccess::Info.row_text] }
  RUBY
  test "says a key item's place from medium verbosity up, as the positions reading" do
    assert_equal ["Item602", key_row("Item602", 2), key_row("Item602", 2)], outcome(:key_items_levels).map { |l| l[0] }
  end

  test "keeps a key item's place for Ctrl+T at every verbosity" do
    assert_equal [key_row("Item602", 2)] * 3, outcome(:key_items_levels).map { |l| l[1] }
  end

  scenario :dex_list, <<-'RUBY'
    with_dex_owner do
      win = Window_Pokedex.new([[1, "Bulbasaur", 7, 69, 1, false], [7, "Squirtle", 5, 90, 8, true],
                                [4, "Charmander", 6, 60, 2, false]])
      [0, 1, 1, 2].each { |i| win.index = i; win.update }
      SpeakCapture.log
    end
  RUBY
  test "reads each Pokedex row once by the number painted and its state, an unseen species as unknown" do
    assert_equal [["1, Bulbasaur, #{t(:dex_caught)}", false], ["7, #{t(:dex_unknown)}", true],
                  ["2, Charmander, #{t(:dex_seen)}", true]], outcome(:dex_list)
  end

  scenario :dex_list_quiet, <<-'RUBY'
    with_dex_owner do
      win = Window_Pokedex.new([[1, "Bulbasaur", 7, 69, 1, false]])
      win.active = false
      win.update
      win.active = true
      win.index = 3
      win.update
      SpeakCapture.log
    end
  RUBY
  test "says nothing while the Pokedex list is inactive or its cursor is past the list" do
    assert_equal [], outcome(:dex_list_quiet)
  end

  scenario :dex_forms, <<-'RUBY'
    scene = PokedexFormScene.new
    scene.pbStartScene(1)
    scene.pbChooseForm(1)
    SpeakCapture.log
  RUBY
  test "says the forms page's counters as it opens, queued, then each form cycled to" do
    assert_equal [["FORMS. FORMS SEEN 3. SHINY SEEN 1", false], ["Bulbasaur, Male Shiny", true]], outcome(:dex_forms)
  end

  scenario :sliders, <<-'RUBY'
    fps = UraSlider.new("FPS", 40, 60)
    autosave = UraSlider.new("Autosave", 0, 60, "Off")
    stock = SliderOption.new("Volume", 0, 100)
    cases = { "FPS at 40" => [fps, 40], "FPS at 50" => [fps, 50], "Autosave at 0" => [autosave, 0],
              "Autosave at 30" => [autosave, 30], "a stock slider at 0" => [stock, 0] }
    cases.map { |what, (o, v)| [what, PokeAccess::Options.value_of(o, v)] }.to_h
  RUBY
  test "reads a slider as painted: its number, or the word the autosave slider paints at its floor" do
    { "FPS at 40" => "40", "FPS at 50" => "50", "Autosave at 0" => "Off", "Autosave at 30" => "30",
      "a stock slider at 0" => "0" }.each do |what, want|
      assert_equal want, outcome(:sliders)[what], "for #{what}"
    end
  end

  test "says no text with raw control codes in the Uranium process" do
    assert_equal [], outcome(:raw_texts)
  end

  test "hands no one-parameter block of the mod several values in the Uranium process" do
    assert_equal [], outcome(:arity_offenders)
  end

  # Every outcome of one Uranium process, run on first use over the scenarios in an order the seed shuffles:
  # { name => [:ok, value] or [:error, why] }, or the process's output when it reported none.
  def self.outcomes
    @outcomes ||= run_uranium(SCENARIOS.keys.shuffle)
  end

  # Runs the Uranium process over the named scenarios in order and reads back what it reports.
  def self.run_uranium(order)
    Dir.mktmpdir("pa-uranium") do |dir|
      cases = File.join(dir, "scenarios.bin")
      script = File.join(dir, "uranium.rb")
      File.binwrite(cases, Marshal.dump(order.map { |name| [name, SCENARIOS[name]] }))
      harness = File.join(Harness::ROOT, "test", "support", "harness")
      File.binwrite(script, ["require #{harness.inspect}", WORLD, BOOT, KIT, RUNNER].join("\n"))
      out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, script, cases], "rb", :err => [:child, :out],
                     :chdir => Harness::ROOT) { |io| io.read }
      found = out.scan(/^OUTCOME (\S+) (\S+)\r?$/)
      found.empty? ? out : found.map { |name, data| [name.to_sym, Marshal.load(data.unpack1("m0"))] }.to_h
    end
  end
  private_class_method :run_uranium

  private

  # What a scenario's code ended on in the Uranium process; a scenario that raised fails the test with its error.
  def outcome(name)
    all = self.class.outcomes
    flunk "the Uranium process reported no outcome:\n#{all[0, 2000]}" if all.is_a?(String)
    flunk "the Uranium process never reported #{name}" unless all.key?(name)
    kind, value = all[name]
    flunk "#{name} raised in the Uranium process: #{value}" unless kind == :ok
    value
  end

  # A text of the mod's in the language Reset pins.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The registered key items list's row for an item: its name and its place among the two the scenarios register.
  def key_row(name, n)
    t(:list_entry, :name => name, :n => n, :tot => 2)
  end
end
