require "rbconfig"

# The Uranium profile loaded whole in a process of its own (its override reaches every other suite here), over
# stand-ins shaped as Uranium's own classes: each hook binds and each screen says what it paints.
module UraniumProfileSpec
  # The Uranium-shaped classes and functions, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    class UraBox; attr_accessor :text; def initialize(t = ""); @text = t; end; end
    def Kernel.pbMessage(message, *a); Kernel.pbMessageDisplay(UraBox.new, message); 0; end
    def Kernel.pbMessageDisplaySystem(pos, msgwindow, message, letterbyletter = true, commandProc = nil)
      return if !msgwindow
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
    class UraSlot
      attr_reader :main, :auto
      def initialize(main, auto = nil, autonewer = false); @main = main; @auto = auto; @autonewer = autonewer; end
      def newer; @autonewer ? @auto : @main; end
      def autonewer?; @autonewer; end
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
          rows = [saveslot.newer.name, "Normal Save", "Autosave", "01/02/26 10:00:00 AM", "01/03/26 11:00:00 AM",
                  "5h 3m", "6h 0m", "Newer"]
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
      def insert(ch); true; end
      def delete; true; end
      def update; nil; end
      def deleteAtCursor; true; end
    end

    class IconMenu; def setActive(flag); @active = flag; end; end
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
      NAMES = { 1 => "Potion", 50 => "TM01 Focus Punch", 600 => "Bicycle", 602 => "Itemfinder" }
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

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    URA_I18N = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    mine = %w[PokemonLoadPanel#refresh PokemonLoadScene#pbStartScene2 PokemonLoadScene#pbDrawSaveCommands
              PokemonLoadScene#pbMoveSaveSel Window_PokemonNuzOption#update PokemonRulesetScene#pbStartScene
              GenderSelectorScene#selectBoy GenderSelectorScene#selectNeutral GenderSelectorScene#selectGirl
              Window_TextEntry#deleteAtCursor PokemonMenu_Scene#pbUpdateSelect IconMenu#setActive
              PokemonMenu_Scene#pbShowMenu PokemonMenu_Scene#pbEndScene Window_DrawableCommandBag#update
              Window_DrawableCommandDex#update PokedexFormScene#pbStartScene PokedexFormScene#pbUpdate]
    check "every hook of the profile binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine
    check "the stock form and ribbon pages are not missed where Uranium's screens have neither",
          (PokeAccess::Hooks.missing & %w[PokedexFormScene#pbRefresh PokemonSummaryScene#drawPageFive]).empty?,
          PokeAccess::Hooks.missing
    check "the system message function is wrapped", !PokeAccess::Hooks.fn_absent.include?("pbMessageDisplaySystem"),
          PokeAccess::Hooks.fn_absent
    ov = PokeAccess::Hooks.overrides.select { |o| o.include?("game_uranium") }
    check "its overrides are declared",
          ov.sort == ["PokeAccess::DexEntry.gen6_info (game_uranium)", "PokeAccess::DexSearch.list (game_uranium)",
                      "PokeAccess::LoadScreen.auto_sub (game_uranium)",
                      "PokeAccess::OptionHelp.read (game_uranium)", "PokeAccess::Options.value_of (game_uranium)",
                      "PokeAccess::Party.status_slot (game_uranium)", "PokeAccess::Summary.header_icons (game_uranium)",
                      "PokeAccess::Summary.painted_memo (game_uranium)",
                      "PokeAccess::SummaryGen6.stats_extras (game_uranium)"], ov

    SpeakCapture.clear
    Kernel.pbMessageSystem(1, false, "What?\nPika is evolving!")
    check "a system message is said", SpeakCapture.lines.last.to_s.index("Pika is evolving!") == 6, SpeakCapture.lines
    depth = nil
    r = Kernel.pbMessageDisplaySystem(1, UraBox.new, "Pick one.", true, proc { |_w| depth = PokeAccess.message_depth; 3 })
    check "one message deeper while shown, and back after", [r, depth, PokeAccess.message_depth] == [3, 1, 0],
          [r, depth, PokeAccess.message_depth]
    SpeakCapture.clear
    check "no window, nothing said", Kernel.pbMessageDisplaySystem(1, nil, "Lost.").nil? && SpeakCapture.lines.empty?,
          SpeakCapture.lines

    team = [Poke.build(:species => 25), Poke.build(:species => 1)]
    save = UraSave.new("1: Vitor", UraTrainer.new("Vitor", team), true)
    ls = PokemonLoadScene.new
    ls.pbStartScene(["Continue", "New Game"], save)
    ls.pbSetParty(save.trainer)
    SpeakCapture.clear
    ls.pbStartScene2
    said = SpeakCapture.lines.first.to_s
    want = ["Route 3", "Vitor", "Badges: 2", "Time: 5h 3m", PokeAccess::LoadPanel.team(save.trainer), URA_I18N.t(:ura_nuzlocke)]
    check "the continue panel opens as painted, with the team and its rule",
          want.all? { |w| said.index(w) } && !said.index("Continue"), said
    ana = UraSave.new("2: Ana", UraTrainer.new("Ana", []))
    ana_auto = UraSave.new("Autosave 2: Ana", UraTrainer.new("Ana", []), false, true)
    slots = [UraSlot.new(save), UraSlot.new(ana, ana_auto, true)]
    SpeakCapture.clear
    ls.pbDrawSaveCommands(slots)
    ls.pbMoveSaveSel(1)
    check "the other saves: each slot's newest file and its rules", SpeakCapture.log ==
          [["1: Vitor, #{URA_I18N.t(:ura_nuzlocke)}", false], ["Autosave 2: Ana, #{URA_I18N.t(:ura_randomizer)}", true]], SpeakCapture.log
    SpeakCapture.clear
    ls.pbChooseAutoSubFile(0, slots[1])
    ls.pbChooseAutoSubFile(1, slots[1])
    check "the normal and autosave sides, with play time and Newer on its side", SpeakCapture.lines ==
          ["Ana. Normal Save, 01/02/26 10:00:00 AM, 5h 3m", "Autosave, 01/03/26 11:00:00 AM, 6h 0m, Newer"], SpeakCapture.lines
    SpeakCapture.clear
    ls.pbDrawSaveCommands(slots, 1)
    check "the list redrawn on a chosen slot says that slot once", SpeakCapture.log ==
          [["Autosave 2: Ana, #{URA_I18N.t(:ura_randomizer)}", false]], SpeakCapture.log

    $ura_nuz = false
    opts = [CheckboxOption.new("Nuzlocke", "Fainted Pokemon are dead.", nil, nil),
            CheckboxOption.new("  Dupes Clause", "Dupes are skipped.", nil, nil, proc { $ura_nuz }, "Enable Nuzlocke first."),
            CheckboxOption.new("Randomizer", "All is random.", nil, nil, nil, nil, proc { false })]
    win = Window_PokemonNuzOption.new(opts, 0, 0, 0, 0, "Start Game")
    rows = (0..3).map { |i| win.index = i; PokeAccess::Menus.focused_text(win) }
    check "the checklist rows: name, box and help, then the exit command", rows ==
          ["Nuzlocke, #{URA_I18N.t(:val_off)}. Fainted Pokemon are dead.", "Dupes Clause, #{URA_I18N.t(:ura_opt_unavailable)}. Dupes are skipped.",
           "Randomizer, #{URA_I18N.t(:ura_opt_locked)}. All is random.", "Start Game"], rows
    win.index = 0
    win.press = true
    SpeakCapture.clear
    win.update
    check "a flipped box says its new state", SpeakCapture.log.last == [URA_I18N.t(:val_on), true], SpeakCapture.log
    win.index = 1
    win.press = true
    SpeakCapture.clear
    win.update
    check "a greyed rule's message is still said inside update", SpeakCapture.lines.include?("Enable Nuzlocke first."),
          SpeakCapture.lines
    SpeakCapture.clear
    PokemonRulesetScene.new.pbStartScene
    check "the checklist's title on opening", SpeakCapture.lines == ["Custom Game Settings"], SpeakCapture.lines

    g = GenderSelectorScene.new
    SpeakCapture.clear
    g.selectBoy(true)
    g.selectNeutral
    g.selectGirl
    check "the three pictures by name, the first queued", SpeakCapture.log ==
          [[URA_I18N.t(:gsel_boy), false], [URA_I18N.t(:ura_gsel_neutral), true], [URA_I18N.t(:gsel_girl), true]], SpeakCapture.log
    SpeakCapture.clear
    Window_TextEntry.new.deleteAtCursor
    check "the naming screen's Delete key", SpeakCapture.lines == [URA_I18N.t(:te_deleted)], SpeakCapture.lines

    m = PokemonMenu_Scene.new
    m.pbStartScene
    SpeakCapture.clear
    ura_team = [Poke.build(:name => "Pika", :item => 5), Poke.build(:name => "Chu")]
    $Trainer.instance_variable_set(:@ura_party, ura_team)
    def $Trainer.party; @ura_party; end
    m.pbUpdateSelect(true)
    run_off = URA_I18N.t(:ura_run_state, :state => URA_I18N.t(:val_off))
    check "the menu opens on its lit icon, the map line and the running icon's state",
          SpeakCapture.log == [["POKÉMON. Route 3. #{run_off}", false]], SpeakCapture.log
    team_line = URA_I18N.t(:ura_menu_team, :list => "Pika, #{URA_I18N.t(:pty_item)}; Chu")
    check "and the info key has the team with the item icons the preview draws", PokeAccess::Info.info_text == team_line,
          PokeAccess::Info.info_text
    SpeakCapture.clear
    m.moves = [:right, :right, :run]
    m.pbUpdateSelect
    check "each icon lit after a move, and the running toggle", SpeakCapture.lines ==
          ["BAG", "POKÉPOD", URA_I18N.t(:ura_run_state, :state => URA_I18N.t(:val_on))], SpeakCapture.lines
    SpeakCapture.clear
    PokeAccess::Info.set_info(:text, "Party screen")
    m.pbUpdateSelect
    check "back from a screen, the lit icon again without the map, and the team back on the info key",
          [SpeakCapture.lines, PokeAccess::Info.info_text] == [["POKÉPOD"], team_line], [SpeakCapture.lines, PokeAccess::Info.info_text]
    SpeakCapture.clear
    m.instance_variable_get(:@sprites)["iconBag"].setActive(true)
    check "outside the selection loop an icon says nothing", SpeakCapture.lines.empty? && PokeAccess::UraniumMenu.scene.nil?,
          SpeakCapture.lines
    m.pbEndScene
    check "the team leaves the info key with the menu", PokeAccess::Info.info_text.nil?, PokeAccess::Info.info_text

    ura_line = lambda { |parts| PokeAccess::Verbosity.line(:bag_item, parts) }
    bag = UraBagData.new([[], [[1, 3], [50, 1]], [], [], [], [], [], [], [[600, 1], [602, 1]]], [600])
    w = Window_PokemonBag.new(bag, 1)
    SpeakCapture.clear
    w.update
    w.index = 1
    w.update
    w.update
    check "the bag list: the pocket and first row queued, then a machine without a count, once", SpeakCapture.log ==
          [["Items. #{ura_line.call([['Potion: 3', :brief]])}", false], [ura_line.call([['TM01 Focus Punch', :brief]]), true]],
          SpeakCapture.log
    check "the list is claimed from the generic reader", PokeAccess.dedicated?(w), nil
    SpeakCapture.clear
    w.pocket = 8
    w.update
    w.index = 1
    w.update
    bag.keyItemsSelected.push(602)
    w.update
    check "key items with the icon's registered and registrable marks, and a registration heard in place",
          SpeakCapture.lines == ["Key Items. #{ura_line.call([['Bicycle', :brief], [URA_I18N.t(:bag_registered), :medium]])}",
                                 ura_line.call([['Itemfinder', :brief], [URA_I18N.t(:bag_registrable), :medium]]),
                                 ura_line.call([['Itemfinder', :brief], [URA_I18N.t(:bag_registered), :medium]])], SpeakCapture.lines
    SpeakCapture.clear
    w.pocket = 3
    w.update
    w.active = false
    w.pocket = 1
    w.update
    check "an empty pocket says the panel's message; an inactive list says nothing", SpeakCapture.lines ==
          ["Poke Balls. It's empty."], SpeakCapture.lines
    w.active = true
    w.update
    SpeakCapture.clear
    w.sortIndex = 0
    w.update
    check "the row picked for moving says so", SpeakCapture.lines ==
          [ura_line.call([['Potion: 3', :brief], [URA_I18N.t(:bag_moving), :brief]])], SpeakCapture.lines
    SpeakCapture.clear
    PokemonBag_Scene.new(w).pbChooseItem
    check "back in the list after an item's menu, the focused row again, queued", SpeakCapture.log ==
          [[ura_line.call([['Potion: 3', :brief], [URA_I18N.t(:bag_moving), :brief]]), false]], SpeakCapture.log
    keys = Window_CommandKeyItems.new([600, 602])
    SpeakCapture.clear
    keys.update
    keys.index = 1
    keys.update
    check "the registered key items list says each item by name", SpeakCapture.lines ==
          [600, 602].map { |i| PokeAccess.clean(PBItems.getName(i).to_s) } && !SpeakCapture.lines.include?(""),
          SpeakCapture.lines

    ura_saved = $Trainer
    $Trainer = Object.new
    def $Trainer.seen?(sp); [1, 4].include?(sp); end
    def $Trainer.owned?(sp); sp == 1; end
    dex = Window_Pokedex.new([[1, "Bulbasaur", 7, 69, 1, false], [7, "Squirtle", 5, 90, 8, true]])
    SpeakCapture.clear
    dex.update
    dex.index = 1
    dex.update
    dex.update
    rows = SpeakCapture.log
    check "the dex list: the first species queued with its number, an unseen one by the number painted",
          rows.length == 2 && rows[0][1] == false && rows[0][0].index("1, Bulbasaur") == 0 &&
          rows[1] == ["7, #{URA_I18N.t(:dex_unknown)}", true], rows
    $Trainer = ura_saved

    fs = PokedexFormScene.new
    SpeakCapture.clear
    fs.pbStartScene(1)
    fs.pbChooseForm(1)
    check "the forms page: its counters on opening, then each form cycled to", SpeakCapture.log ==
          [["FORMS. FORMS SEEN 3. SHINY SEEN 1", false], ["Bulbasaur, Male Shiny", true]], SpeakCapture.log

    vo = PokeAccess::Options
    check "the sliders read as painted: FPS unshifted, the autosave's word at its floor",
          [vo.value_of(UraSlider.new("FPS", 40, 60), 50), vo.value_of(UraSlider.new("Autosave", 0, 60, "Off"), 0),
           vo.value_of(UraSlider.new("Autosave", 0, 60, "Off"), 30)] == ["50", "Off", "30"],
          [vo.value_of(UraSlider.new("FPS", 40, 60), 50), vo.value_of(UraSlider.new("Autosave", 0, 60, "Off"), 0)]
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "require #{File.join(support, 'poke_builder').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("uranium profile: loaded whole over Uranium-shaped classes, every hook binds and does its part") do
  rows = UraniumProfileSpec.run
  if rows.is_a?(String)
    truthy "the profile process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 34
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
