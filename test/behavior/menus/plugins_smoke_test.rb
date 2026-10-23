# The plugins/ layer wired to the games' classes: every plugin file loads and binds to stand-ins of what it hooks,
# each reader speaks as the method it hooks runs and hands back that method's value, each extractor is dispatched to.
require File.expand_path("../../static/reference_names", File.dirname(__FILE__))

class PluginsSmokeTest < PokeAccessTest
  class << self
    # The derived drive's findings, kept for the process once worked out.
    attr_accessor :drive
  end

  PLUGINS = File.join(Harness::ROOT, "plugins")

  # The registration calls of a hook-carrying plugin file, as its source writes them.
  HOOK_CALL = /(after_hook|before_hook|around_hook|SceneWatcher\.(reader|wire)|MenuReturn\.bare|read_on_open)\s*\(\s*"/

  # Module#name, which a plugin module may shadow with a function of its own (SkyBag.name).
  MODULE_NAME = Module.instance_method(:name)

  # What evaluating every plugin file twice and driving each hooked method found: the load errors of each pass, the
  # hooks each file registered in the first, the methods hooked per class, the hooked methods that did not bind,
  # that handed back another value, or that raised, and the methods the first pass reported missing.
  Drive = Struct.new(:probe_errors, :stand_in_errors, :per_file, :hooked, :unbound, :wrong, :raised, :missing)

  # The game classes the readers hook, each built afresh for a test; their methods answer values of their own, which
  # the hooks must hand back. The two loop scenes poll a frame inside their loop, as the real ones do; the quest log
  # is a copy with its cover (the manifest's probe) and none of the loop, list and page loads its reader hooks.
  STAND_INS = {
    "ItemCraft_Scene" => lambda {
      Class.new do
        def pbRedrawItem(_index, _volume); :item_drawn; end
        def pbRedrawMenu(_index, _volume); :menu_drawn; end
        def refreshNumbers(_index, _volume); :numbers_drawn; end
      end
    },
    "PokemonGenderSelection" => lambda {
      Class.new do
        def main_method; :picked; end
        def input; :input_done; end
      end
    },
    "WindowTextEntryKeyboardPerKey" => lambda {
      Class.new do
        def insert(_ch); :inserted; end
        def delete; :deleted; end
      end
    },
    "HallOfFameViewerScene" => lambda { Class.new { def update_display; :redrawn; end } },
    "Incubadora" => lambda {
      Class.new do
        def refresh; :refreshed; end
        def dispose; :disposed; end
      end
    },
    "PlaceDecoration_Scene" => lambda { Class.new { def pbUpdate; :updated; end } },
    "Log" => lambda {
      Class.new do
        def update
          PokeAccess::Frame.run_pollers
          :closed
        end
      end
    },
    "AlbumFotos_Scene" => lambda {
      Class.new do
        def obtener_archivo_captura(_index); nil; end
        def pbUpdateAlbum
          PokeAccess::Frame.run_pollers
          :album_closed
        end
      end
    },
    "RSESTarterChoice" => lambda { Class.new { def pbUpdate; :starter_drawn; end } },
    "PokemonPokedex_Scene" => lambda {
      Class.new do
        def pbRefresh; :dex_drawn; end
        def pbDexEntry(_index); :entry_closed; end
      end
    },
    "Ekans_Interface_Game" => lambda {
      Class.new do
        def update_score_display
          pbDrawTextPositions(nil, [["Puntuación: 3", 256, 6, 2, nil, nil]])
          :score_drawn
        end
      end
    },
    "BerrydexInfo_Scene" => lambda { Class.new { def drawPage(_page); :page_drawn; end } },
    "Questlog" => lambda { Class.new { def pbMain; :cover_drawn; end } }
  }.freeze

  # Plugin files with a fault each, for the drive's own checks: one raises as it loads, one keeps its only hook in a
  # branch that never runs, and one hooks a scene with a hook that swallows the value, one that raises, one that
  # registers on its first evaluation only and one bound without :optional to a method the scene's probe lacks.
  PLANTED = {
    "broken" => "raise 'planted'\n",
    "silent" => "if false\n  PokeAccess::Hooks.after_hook(\"PaPlantedSilent\", :pbNever) { |_s, _r, _a| nil }\nend\n",
    "planted" => <<-RUBY
      PokeAccess::Hooks.around_hook("PaPlantedScene", :pbSwallow, :optional => true) { |_s, nxt, _a| nxt.call; :other }
      PokeAccess::Hooks.around_hook("PaPlantedScene", :pbRaise, :optional => true) { |_s, _nxt, _a| raise "planted" }
      PokeAccess::Hooks.after_hook("PaPlantedScene", :pbStrict) { |_s, _r, _a| nil }
      unless Object.const_defined?(:PA_PLANTED_ONCE)
        Object.const_set(:PA_PLANTED_ONCE, true)
        PokeAccess::Hooks.after_hook("PaPlantedScene", :pbOnce, :optional => true) { |_s, _r, _a| nil }
      end
    RUBY
  }.freeze

  # A plugin file hooking, without :optional, the method its own probe names, on a class another plugin's probe
  # names first.
  SHARED = { "second" => "PokeAccess::Hooks.after_hook(\"PaSharedScene\", :pbSecond) { |_s, _r, _a| nil }\n" }.freeze

  test "every plugin file evaluates with only the manifest's probes standing in" do
    assert_equal [], derived_drive.probe_errors
  end

  test "every plugin file evaluates again with every class it hooks standing in" do
    assert_equal [], derived_drive.stand_in_errors
  end

  test "every hook-carrying plugin file registers a hook when its manifest probe stands in" do
    assert_equal [], registering_nothing(plugin_files, derived_drive)
  end

  test "every hook binds to the stand-in of the class it names" do
    drive = derived_drive
    assert_operator drive.hooked.length, :>=, 30, "the classes hooked across the plugin files"
    assert_equal [], drive.unbound.sort
  end

  test "every hooked method hands back its own value through its hooks" do
    assert_equal [], derived_drive.wrong.sort
  end

  test "no hook raises out of a hooked method driven on a bare stand-in" do
    assert_equal [], derived_drive.raised.sort
  end

  test "no plugin hook reports a method its class lacks, every plugin hook binding optionally" do
    assert_equal [], derived_drive.missing
  end

  test "no plugin hooks a method no surveyed game or reference copy defines (NO-DUMP in the loop census)" do
    census = File.read(File.join(Harness::ROOT, "test", "static", "loop_census.txt"))
    assert_equal [], no_dump_hooks(derived_drive.hooked, census)
  end

  test "the drive reports planted faults: a file that fails or hooks nothing, and a hook missing, unbound, " \
       "swallowing or raising" do
    found, silent = drive_sources(PLANTED, :planted => "PaPlantedScene#pbSwallow")
    assert_equal({ :probe_errors => ["broken: RuntimeError: planted"],
                   :stand_in_errors => ["broken: RuntimeError: planted"], :silent => ["silent"],
                   :missing => ["PaPlantedScene#pbStrict"], :unbound => ["PaPlantedScene#pbOnce"],
                   :wrong => ["PaPlantedScene#pbSwallow -> :other"],
                   :raised => ["PaPlantedScene#pbRaise: RuntimeError: planted"] },
                 { :probe_errors => found.probe_errors, :stand_in_errors => found.stand_in_errors, :silent => silent,
                   :missing => found.missing, :unbound => found.unbound, :wrong => found.wrong,
                   :raised => found.raised })
  end

  test "the drive stands in each probe's method where two plugins probe the same class" do
    found = drive_sources(SHARED, :first => "PaSharedScene#pbFirst", :second => "PaSharedScene#pbSecond").first
    assert_equal [], found.missing
  end

  test "the census check names a hooked method the census gives no surveyed game, unless a reference copy has it" do
    census = "Scene_A#pbShown = 4\nScene_A#pbGhost = NO-DUMP\nWindow_B#refresh = NO-DUMP\n" \
             "BlocUnownScene#moveCursor = NO-DUMP\n"
    hooked = { "Scene_A" => { "pbShown" => true, "pbGhost" => true }, "UI::Window_B" => { "refresh" => true },
               "BlocUnownScene" => { "moveCursor" => true } }
    assert_equal ["Scene_A#pbGhost", "Window_B#refresh"], no_dump_hooks(hooked, census)
  end

  test "reports no hook missing on a quest log copy without the loop and the list and page loads its reader hooks" do
    before = PokeAccess::Hooks.missing.dup
    added = with_plugin("easy_questing", "Questlog") { PokeAccess::Hooks.missing - before }
    assert_equal [], added
  end

  test "reads the focused recipe as the workbench redraws its list, handing back the redraw's value" do
    ret = with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k).pbRedrawMenu(0, 1) }
    assert_equal [:menu_drawn, [["Poción", true]]], [ret, SpeakCapture.log]
  end

  test "puts the item the focused recipe makes on the info key" do
    info = with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      workbench(k).pbRedrawMenu(0, 1)
      PokeAccess::Info.info_text
    end
    assert_equal "Pocion", info, "item 1 as the game's item data names it"
  end

  test "says nothing when the workbench redraws its list on the same recipe" do
    with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      craft = workbench(k)
      2.times { craft.pbRedrawMenu(0, 1) }
    end
    assert_equal ["Poción"], SpeakCapture.lines
  end

  test "says nothing for a recipe index off the workbench's list" do
    with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      craft = workbench(k)
      [1, -1, nil].each { |index| craft.pbRedrawMenu(index, 1) }
    end
    assert_nothing_spoken
  end

  test "reads the amount and what the ingredients cost at it as the amount changes, handing back its value" do
    ret = with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k).refreshNumbers(0, 3) }
    assert_equal [:numbers_drawn, [[three_potions, true]]], [ret, SpeakCapture.log]
  end

  test "puts the craft's detail on the row Ctrl+T repeats" do
    row = with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      workbench(k).refreshNumbers(0, 3)
      PokeAccess::Info.row_text
    end
    assert_equal three_potions, row
  end

  test "says nothing when the amount is redrawn unchanged" do
    with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      craft = workbench(k)
      2.times { craft.refreshNumbers(0, 3) }
    end
    assert_equal [three_potions], SpeakCapture.lines
  end

  test "reads the craft's detail at its amount as a one-call workbench redraws it whole, handing back its value" do
    ret = with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k).pbRedrawItem(0, 2) }
    cost = t(:craft_ingredient, :name => "Repelente", :have => 4, :need => 4)
    head = t(:craft_amount, :name => "Pociones", :n => 2)
    assert_equal [:item_drawn, [[t(:craft_detail, :head => head, :list => cost), true]]], [ret, SpeakCapture.log]
  end

  test "reads a single craft by its item's singular name" do
    with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k).pbRedrawItem(0, 1) }
    cost = t(:craft_ingredient, :name => "Repelente", :have => 4, :need => 2)
    assert_equal [t(:craft_detail, :head => "Poción", :list => cost)], SpeakCapture.lines
  end

  test "with the workbench's list showing, an amount redraw says nothing and the recipe is read again" do
    with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      craft = workbench(k)
      craft.instance_variable_set(:@pantalla, 0)
      craft.pbRedrawMenu(0, 1)
      craft.refreshNumbers(0, 3)
      craft.pbRedrawMenu(0, 1)
    end
    assert_equal ["Poción", "Poción"], SpeakCapture.lines
  end

  test "names the craft from the game's item data, its stock unsaid, where the workbench keeps no adapter" do
    with_plugin("item_crafting", "ItemCraft_Scene") do |k|
      craft = workbench(k, nil)
      craft.pbRedrawMenu(0, 1)
      craft.refreshNumbers(0, 3)
    end
    assert_equal ["Pocion", t(:craft_amount, :name => "Pocion", :n => 3)], SpeakCapture.lines
  end

  test "names the craft in the plural the game's item data gives, where the workbench keeps no adapter" do
    with_item_data("Poción", "Pociones") do
      with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k, nil).refreshNumbers(0, 3) }
    end
    assert_equal [t(:craft_amount, :name => "Pociones", :n => 3)], SpeakCapture.lines
  end

  test "says nothing for a craft whose item the game's data cannot name" do
    with_item_data(nil, nil) do
      with_plugin("item_crafting", "ItemCraft_Scene") do |k|
        craft = workbench(k, nil)
        craft.pbRedrawMenu(0, 1)
        craft.refreshNumbers(0, 3)
      end
    end
    assert_nothing_spoken
  end

  test "leaves the stock unsaid where the workbench's adapter cannot count" do
    with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k, adapter(:counts => false)).refreshNumbers(0, 3) }
    assert_equal [t(:craft_amount, :name => "Pociones", :n => 3)], SpeakCapture.lines
  end

  test "says only what an ingredient takes where the adapter cannot tell how many the player has" do
    with_plugin("item_crafting", "ItemCraft_Scene") { |k| workbench(k, adapter(:have => nil)).refreshNumbers(0, 3) }
    need = t(:craft_ingredient_need, :name => "Repelente", :need => 6)
    assert_equal [t(:craft_detail, :head => t(:craft_amount, :name => "Pociones", :n => 3), :list => need)],
                 SpeakCapture.lines
  end

  test "explains the gender picker's two unlabelled pictures as it opens, handing back its value" do
    ret = with_plugin("gender_selection", "PokemonGenderSelection") { |k| k.new.main_method }
    assert_equal [:picked, [["#{t(:gsel_help)}. #{t(:gsel_help_hint)}", true]]], [ret, SpeakCapture.log]
  end

  test "says the highlighted look from the gender picker's per-frame input, handing back its value" do
    ret = with_plugin("gender_selection", "PokemonGenderSelection") do |k|
      picker = k.new
      picker.instance_variable_set(:@select, 2)
      picker.input
    end
    assert_equal [:input_done, [[t(:gsel_boy), true]]], [ret, SpeakCapture.log]
  end

  test "echoes each character typed in the bag searcher, a space as its word, handing back the insert's value" do
    rets = with_plugin("bag_search_entry", "WindowTextEntryKeyboardPerKey") do |k|
      box = k.new
      [box.insert("q"), box.insert(" "), box.insert("")]
    end
    assert_equal [[:inserted] * 3, [["q", true], [t(:key_space), true]]], [rets, SpeakCapture.log]
  end

  test "says a deletion in the bag searcher, handing back the delete's value" do
    ret = with_plugin("bag_search_entry", "WindowTextEntryKeyboardPerKey") { |k| k.new.delete }
    assert_equal [:deleted, [[t(:te_deleted), true]]], [ret, SpeakCapture.log]
  end

  test "reads the focused team member as the Hall of Fame viewer redraws, handing back its value" do
    ret = with_plugin("hall_of_fame_bw", "HallOfFameViewerScene") do |k|
      viewer = k.new
      viewer.instance_variable_set(:@hallEntry, [member("Rocoso", "Onix", 51)])
      viewer.instance_variable_set(:@hallIndex, 0)
      viewer.instance_variable_set(:@pokemonIndex, 0)
      viewer.update_display
    end
    line = [t(:hofbw_entry, :n => 1), t(:list_pos, :i => 1, :n => 1), "Rocoso", "Onix", t(:hofbw_level, :n => 51),
            t(:hofbw_caught, :map => t(:hofbw_unknown_place))].join(", ")
    assert_equal [:redrawn, [[line, true]]], [ret, SpeakCapture.log]
  end

  test "reads the focused incubator slot as the incubator refreshes, queued as its first read" do
    ret = with_plugin("incubator", "Incubadora") { |k| incubator(k).refresh }
    assert_equal [:refreshed, [[t(:hatch_slot_empty, :n => 1), false]]], [ret, SpeakCapture.log]
  end

  test "takes the incubator slot off the info key as the incubator closes, handing back its value" do
    seen = with_plugin("incubator", "Incubadora") do |k|
      box = incubator(k)
      box.refresh
      [box.dispose, PokeAccess::Info.info_text, PokeAccess::Info.row_text]
    end
    assert_equal [:disposed, nil, nil], seen
  end

  test "reads the tile under the decorating cursor as the scene updates, handing back its value" do
    ret = with_plugin("secret_bases", "PlaceDecoration_Scene") do |k|
      scene = k.new
      scene.instance_variable_set(:@cursor_x, 4)
      scene.instance_variable_set(:@cursor_y, 7)
      scene.pbUpdate
    end
    assert_equal [:updated, [["#{t(:mg_rowcol, :row => 7, :col => 4)}, #{t(:sb_nothing)}", true]]],
                 [ret, SpeakCapture.log]
  end

  test "reads the message log's page on a frame of its loop and nothing once it closes, though the page moves" do
    ret = with_message_log([["Hola"], ["Adiós", "amigo"], ["Tercera"]]) do
      with_plugin("text_log", "Log") do |k|
        log = k.new
        log.instance_variable_set(:@pos, 2)
        log.instance_variable_set(:@lines, 2)
        closed = log.update
        log.instance_variable_set(:@pos, 3)
        PokeAccess::Frame.run_pollers
        closed
      end
    end
    assert_equal [:closed, [["Hola. Adiós amigo", false]]], [ret, SpeakCapture.log]
  end

  test "reads the album's focused slot on a frame of its loop and nothing once it closes, though the cursor moves" do
    ret = with_plugin("photo_album", "AlbumFotos_Scene") do |k|
      album = k.new
      { :@page => 0, :@photo => 1, :@numpages => 2 }.each { |iv, v| album.instance_variable_set(iv, v) }
      closed = album.pbUpdateAlbum
      album.instance_variable_set(:@photo, 2)
      PokeAccess::Frame.run_pollers
      closed
    end
    assert_equal [:album_closed, [["#{t(:alb_empty)}, #{t(:alb_page, :n => 1, :tot => 2)}", false]]],
                 [ret, SpeakCapture.log]
  end

  test "names the focused starter with its place in the row as the carousel updates, queued as its first read" do
    ret = with_plugin("rse_starters", "RSESTarterChoice") do |k|
      carousel = k.new
      starter = Struct.new(:name).new("Treecko")
      carousel.instance_variable_set(:@species_cache, [starter, starter, starter])
      carousel.instance_variable_set(:@index, 1)
      carousel.pbUpdate
    end
    assert_equal [:starter_drawn, [[t(:list_entry, :name => "Treecko", :n => 2, :tot => 3), false]]],
                 [ret, SpeakCapture.log]
  end

  test "reads the focused row of the HGSS dex list as it repaints, handing back its value" do
    ret = with_hgss_dex { |k| dex_list(k).pbRefresh }
    assert_equal [:dex_drawn, [[dex_row, true]]], [ret, SpeakCapture.log]
  end

  test "says nothing when the HGSS dex list repaints on the same row, a species only seen" do
    with_hgss_dex(false) do |k|
      scene = dex_list(k)
      2.times { scene.pbRefresh }
    end
    assert_equal [dex_row(false)], SpeakCapture.lines
  end

  test "reads the same row again as the HGSS dex list repaints back from a species entry, handing back its value" do
    ret = with_hgss_dex do |k|
      scene = dex_list(k)
      scene.pbRefresh
      back = scene.pbDexEntry(0)
      scene.pbRefresh
      back
    end
    assert_equal [:entry_closed, [dex_row, dex_row]], [ret, SpeakCapture.lines]
  end

  test "says nothing over a stock Pokedex, whose list sprite is not the plugin's" do
    ret = with_hgss_dex do |k|
      scene = k.new
      scene.instance_variable_set(:@sprites, { "pokedex" => Object.new })
      scene.pbRefresh
    end
    assert_equal [:dex_drawn, []], [ret, SpeakCapture.log]
  end

  test "says the Ekans score as the game paints it, handing back its value" do
    ret = with_plugin("ekans_snake", "Ekans_Interface_Game") { |k| k.new.update_score_display }
    assert_equal [:score_drawn, [["Puntuación: 3", true]]], [ret, SpeakCapture.log]
  end

  test "names the berry and the section of the page the berry detail draws, handing back its value" do
    ret = with_plugin("berrydex", "BerrydexInfo_Scene") { |k| berry_page(k).drawPage(1) }
    assert_equal [:page_drawn, [[oran_info, true]]], [ret, SpeakCapture.log]
  end

  test "says nothing when the berry detail redraws the same page" do
    with_plugin("berrydex", "BerrydexInfo_Scene") do |k|
      page = berry_page(k)
      2.times { page.drawPage(1) }
    end
    assert_equal [oran_info], SpeakCapture.lines
  end

  test "says a challenge rule with its toggle in words" do
    said = [[1], [0]].map do |keys|
      window("Window_CommandPokemon_Challenge", :@commands => ["Nuzlocke"], :@text_key => keys)
    end
    assert_equal ["Nuzlocke, #{t(:val_on)}", "Nuzlocke, #{t(:val_off)}"], said
  end

  test "says a berry not registered yet by its number alone" do
    said = window("Window_Berrydex", :@commands => [[:ORANBERRY, "Aranja", 7]])
    assert_equal t(:bdx_unknown, :num => 7), said
  end

  test "says a registered berry by its number and name" do
    said = with_registered_berries { window("Window_Berrydex", :@commands => [[:ORANBERRY, "Aranja", 7]]) }
    assert_equal t(:bdx_entry, :num => 7, :name => "Aranja"), said
  end

  test "says a secret base category with how full it is, and the row past the last as cancel" do
    said = with_secret_bag do
      [0, 2].map { |i| window("Window_BasePocketsList", { :@bag => decoration_bag }, i) }
    end
    assert_equal ["Muebles, #{t(:sb_qty, :cur => 3, :max => 8)}", t(:pc_cancel)], said
  end

  test "names a quest in the journal with the marks its list only paints" do
    quest = Struct.new(:id, :story, :new).new(:RESCATE, true, true)
    said = with_quest_names(:RESCATE => "Rescatar al profesor") { window("Window_Quest", :@quests => [quest]) }
    assert_equal "Rescatar al profesor, #{t(:quest_story)}, #{t(:quest_new)}", said
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The workbench's detail at an amount of three: the plural and the count, then what the two repels a craft takes
  # cost at that amount against the four held.
  def three_potions
    cost = t(:craft_ingredient, :name => "Repelente", :have => 4, :need => 6)
    t(:craft_detail, :head => t(:craft_amount, :name => "Pociones", :n => 3), :list => cost)
  end

  # The HGSS dex list's row for species 25: its painted number and name, then the owned mark, or the seen one.
  def dex_row(owned = true)
    "#{t(:dexlist_entry, :num => 25, :name => 'Especie25')}, #{t(owned ? :dex_caught : :dex_seen)}"
  end

  # The berry detail's first page on the Oran Berry, whose data the gen-6 engine lacks: its id and the section.
  def oran_info
    "ORANBERRY. #{t(:bdx_section, :name => t(:bdx_page_info))}"
  end

  # The plugin files, the manifest left out.
  def plugin_files
    Dir.glob(File.join(PLUGINS, "*.rb")).sort.reject { |f| File.basename(f) == "manifest.rb" }
  end

  # The manifest's detection probe per plugin, "Class" or "Class#method", as the loader reads it.
  def manifest_probes
    manifest = File.join(PLUGINS, "manifest.rb")
    eval(Harness.source(manifest), TOPLEVEL_BINDING, manifest)
  end

  # The names of the files among files whose source carries a hook call but that registered none in the drive's
  # first pass.
  def registering_nothing(files, drive)
    carrying = files.select { |f| Harness.source(f) =~ HOOK_CALL }.map { |f| File.basename(f, ".rb") }
    carrying.reject { |name| drive.per_file[name].any? }
  end

  # The hooked methods, "Class#method" with the class's last segment, that the loop census marks NO-DUMP (no surveyed
  # game defines them) and no reference copy defines either.
  # param hooked { class name => { method name => true } }
  def no_dump_hooks(hooked, census)
    no_dump = census.scan(/^(\S+#\S+) = NO-DUMP/).flatten
    sites = hooked.map { |cname, meths| meths.keys.map { |m| "#{cname.split('::').last}##{m}" } }.flatten
    (sites & no_dump).reject { |site| ReferenceNames.probe?(site) }.sort
  end

  # The drive over plugin files written from sources ({ name => source }) to a folder of their own, under the given
  # probes; answers what it found and the files it says hook nothing.
  def drive_sources(sources, probes)
    Dir.mktmpdir("pa-planted") do |dir|
      files = sources.map do |name, src|
        path = File.join(dir, "#{name}.rb")
        File.write(path, src)
        path
      end
      found = derive_and_drive(files, probes)
      [found, registering_nothing(files, found)]
    end
  ensure
    Object.send(:remove_const, :PA_PLANTED_ONCE) if Object.const_defined?(:PA_PLANTED_ONCE, false)
  end

  # Evaluates a plugin file as the loader does (its mutant, when one is being tried), silencing the warnings of its
  # constants assigned again; answers its load error as a one-line list, or [].
  def evaluate(path)
    verbose = $VERBOSE
    $VERBOSE = nil
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    []
  rescue Exception => e
    ["#{File.basename(path, '.rb')}: #{e.class}: #{e.message[0, 100]}"]
  ensure
    $VERBOSE = verbose
  end

  # Runs the block with the named stand-ins under their games' class names and the plugin file evaluated again, so its
  # hooks bind to them; yields the stand-in classes and answers the block's value. The mod and the games' own classes
  # are put back afterwards.
  def with_plugin(file, *names)
    keeping_the_mod do
      standing_in(names.map { |n| [n, STAND_INS.fetch(n).call] }) do |*classes|
        chains = PokeAccess::Hooks.instance_variable_get(:@chains)
        chains.keys.each { |key| chains.delete(key) if names.include?(key.split("#", 2)[0]) }
        assert_equal [], evaluate(File.join(PLUGINS, "#{file}.rb")), "#{file}.rb evaluates"
        yield(*classes)
      end
    end
  end

  # Runs the block with each [name, value] pair's value under that top-level constant; yields the values. The
  # games' own constants are put back afterwards.
  def standing_in(pairs)
    had = pairs.map { |name, _v| [name, Object.const_defined?(name, false) ? Object.const_get(name, false) : nil] }
    pairs.each do |name, value|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, value)
    end
    yield(*pairs.map { |_n, v| v })
  ensure
    (had || []).each do |name, value|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, value) if value
    end
  end

  # Runs the block, then puts the mod back as it was: every PokeAccess module's instance variables and constants (and
  # what the containers among them held), its functions, and the methods a hook new to the block wrapped on a class
  # that outlives it. Evaluating a plugin file again re-registers everything it registers, which this takes back.
  def keeping_the_mod
    state = mod_modules.map { |m| [m, ivars_of(m), consts_of(m), functions_of(m)] }
    held = {}
    state.each { |_m, ivars, consts, _f| (ivars.values + consts.values).each { |v| hold(v, held, 2) } }
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    keys = chains.keys
    yield
  ensure
    (chains.keys - keys).each { |key| unwrap(key) } if keys
    held.each_value { |obj, was| obj.replace(was) } if held
    state.each { |m, ivars, consts, funcs| put_back(m, ivars, consts, funcs) } if state
  end

  # PokeAccess and every module under it.
  def mod_modules(root = PokeAccess, seen = {})
    return [] if seen[root]
    seen[root] = true
    root.constants(false).inject([root]) do |all, c|
      v = (root.const_get(c, false) rescue nil)
      inside = v.is_a?(Module) && MODULE_NAME.bind(v).call.to_s.start_with?("PokeAccess")
      inside ? all.concat(mod_modules(v, seen)) : all
    end
  end

  def ivars_of(m)
    m.instance_variables.inject({}) { |h, iv| h.update(iv => m.instance_variable_get(iv)) }
  end

  def consts_of(m)
    m.constants(false).inject({}) { |h, c| h.update(c => (m.const_get(c, false) rescue nil)) }
  end

  # A module's functions, each as [its method, whether it is private].
  def functions_of(m)
    meta = m.singleton_class
    out = {}
    meta.instance_methods(false).each { |f| out[f] = [meta.instance_method(f), false] }
    meta.private_instance_methods(false).each { |f| out[f] = [meta.instance_method(f), true] }
    out
  end

  # Records an Array or Hash and its contents, and those of the containers in it down to depth, once each.
  def hold(v, held, depth)
    return unless (v.is_a?(Array) || v.is_a?(Hash)) && !v.frozen? && !held.key?(v.object_id)
    held[v.object_id] = [v, v.dup]
    return if depth <= 1
    (v.is_a?(Hash) ? v.values : v).each { |x| hold(x, held, depth - 1) }
  end

  # Puts a module's instance variables, constants and functions back as recorded, dropping the ones added since.
  def put_back(m, ivars, consts, funcs)
    (m.instance_variables - ivars.keys).each { |iv| m.send(:remove_instance_variable, iv) }
    ivars.each { |iv, v| m.instance_variable_set(iv, v) }
    (m.constants(false) - consts.keys).each { |c| m.send(:remove_const, c) }
    consts.each do |c, v|
      next if m.const_defined?(c, false) && m.const_get(c, false).equal?(v)
      m.send(:remove_const, c) if m.const_defined?(c, false)
      m.const_set(c, v)
    end
    meta = m.singleton_class
    added = meta.instance_methods(false) + meta.private_instance_methods(false) - funcs.keys
    added.each { |f| meta.send(:remove_method, f) }
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      funcs.each do |f, (um, priv)|
        next if meta.instance_method(f) == um
        meta.send(:define_method, f, um)
        meta.send(:private, f) if priv
      end
    ensure
      $VERBOSE = verbose
    end
  end

  # Puts back the method a hook wrapped on a class under key ("Class#method"), where the hook was the first there.
  def unwrap(key)
    cname, meth = key.split("#", 2)
    k = meth && PokeAccess.const_at(cname)
    return unless k.is_a?(Module)
    orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
    k.send(:alias_method, meth, orig) if k.method_defined?(orig) || k.private_method_defined?(orig)
  end

  # What derive_and_drive found, worked out by the first test that asks: the same for every test, as the drive puts
  # the mod back as it found it.
  def derived_drive
    PluginsSmokeTest.drive ||= derive_and_drive
  end

  # Evaluates every file twice, first with only the probes standing in, then with stand-ins for every class and
  # method the first pass hooked, and drives each hooked method of a stand-in; the mod is put back afterwards.
  # Answers what each step found.
  # param probes { plugin => "Class" or "Class#method" }, the manifest's by default
  def derive_and_drive(files = plugin_files, probes = manifest_probes)
    found = Drive.new([], [], Hash.new { |h, k| h[k] = [] }, Hash.new { |h, k| h[k] = {} }, [], [], [], [])
    keeping_the_mod do
      made = []
      owned = {}
      file = nil
      begin
        PokeAccess::Hooks.singleton_class.send(:alias_method, :pa_smoke_wrap, :wrap)
        PokeAccess::Hooks.define_singleton_method(:wrap) do |cname, meth, *rest, &mw|
          found.hooked[cname.to_s][meth.to_s] = true
          found.per_file[file].push("#{cname}##{meth}") if file
          pa_smoke_wrap(cname, meth, *rest, &mw)
        end
        probes.each_value do |probe|
          cname, meth = probe.to_s.split("#", 2)
          owned[cname] = stand_in(cname, meth ? [meth] : [], made)
        end
        reported = PokeAccess::Hooks.missing.dup
        files.each do |f|
          file = File.basename(f, ".rb")
          found.probe_errors.concat(evaluate(f))
          file = nil
        end
        found.missing.concat(PokeAccess::Hooks.missing - reported)
        found.hooked.each { |cname, meths| owned[cname] = stand_in(cname, meths.keys, made) }
        files.each { |f| found.stand_in_errors.concat(evaluate(f)) }
        drive_hooked(found, owned)
      ensure
        made.reverse_each { |parent, name| parent.send(:remove_const, name) if parent.const_defined?(name, false) }
      end
    end
    found
  end

  # The class under name, made (with any namespace missing) when absent; a class made here gets each method in meths
  # it does not define itself, answering :pa_smoke: a global function a test defines (pbShowCommands) is no method of
  # the game's class. Answers the class when it was made here, else nil.
  # param made the [parent, name] constants made so far, which the caller removes
  def stand_in(name, meths, made)
    parent = Object
    segs = name.split("::")
    segs.each_with_index do |seg, i|
      if parent.const_defined?(seg, false)
        parent = parent.const_get(seg, false)
      else
        fresh = (i == segs.length - 1) ? Class.new : Module.new
        parent.const_set(seg, fresh)
        made.push([parent, seg])
        parent = fresh
      end
    end
    return nil unless made.any? { |par, seg| par.const_get(seg, false).equal?(parent) }
    meths.each do |m|
      next if parent.method_defined?(m, false) || parent.private_method_defined?(m, false)
      parent.send(:define_method, m) { |*_a| :pa_smoke }
    end
    parent
  end

  # Drives each hooked method of a class made here on a bare instance, recording in found the hooks that did not
  # bind, the methods that handed back another value than their own, and those that raised.
  def drive_hooked(found, owned)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    found.hooked.each do |cname, meths|
      k = owned[cname]
      next unless k
      meths.keys.each do |m|
        key = "#{cname}##{m}"
        found.unbound.push(key) unless chains.has_key?(key)
        next if m == "initialize"
        begin
          r = k.allocate.send(m)
          found.wrong.push("#{key} -> #{r.inspect}") unless r == :pa_smoke
        rescue Exception => e
          found.raised.push("#{key}: #{e.class}: #{e.message[0, 80]}")
        end
      end
    end
  end

  # A workbench of one recipe, as a gen-6 copy keeps it inline: item 1 (a potion) made of two of item 25 (a repel),
  # with the given adapter, or none when nil.
  def workbench(k, ad = adapter)
    craft = k.new
    craft.instance_variable_set(:@adapter, ad) if ad
    craft.instance_variable_set(:@stock, [[1, [25, 2]]])
    craft
  end

  # The workbench's adapter, naming the potion and the repel in its own words ("Pociones" in the plural) and, unless
  # it cannot count, telling have for how many repels the player holds.
  # param opts :counts => false for an adapter without getQuantity; :have the count it tells (4 by default)
  def adapter(opts = {})
    names = { 1 => "Poción", 25 => "Repelente" }
    have = opts.key?(:have) ? opts[:have] : 4
    ad = Object.new
    ad.define_singleton_method(:getName) { |item| names[item] }
    ad.define_singleton_method(:getNamePlural) { |item| item == 1 ? "Pociones" : nil }
    ad.define_singleton_method(:getQuantity) { |item| item == 25 ? have : 0 } unless opts[:counts] == false
    ad
  end

  # Runs the block with the game's item data naming item 1 as name, plural as its plural (nil for none), and no
  # other item.
  def with_item_data(name, plural)
    data = Object.new
    data.define_singleton_method(:item_name) { |item| item == 1 ? name : nil }
    data.define_singleton_method(:item_name_plural) { |item| item == 1 ? plural : nil }
    Harness.with_provider(data) { yield }
  end

  # A team member as the Hall of Fame keeps it: nickname, species and level, nothing else.
  def member(name, species, level)
    mon = Object.new
    mon.define_singleton_method(:name) { name }
    mon.define_singleton_method(:speciesName) { species }
    mon.define_singleton_method(:level) { level }
    mon
  end

  # An incubator with its cursor on the first slot, which holds no egg.
  def incubator(k)
    box = k.new
    box.instance_variable_set(:@index, 0)
    box
  end

  # Runs the block with $PokemonGlobal.log answering entries, as the message history keeps them; put back afterwards.
  def with_message_log(entries)
    meta = $PokemonGlobal.singleton_class
    had = meta.method_defined?(:log) ? meta.instance_method(:log) : nil
    meta.send(:define_method, :log) { entries }
    yield
  ensure
    if had
      meta.send(:define_method, :log, had)
    else
      meta.send(:remove_method, :log)
    end
  end

  # Runs the HGSS dex list plugin over a stand-in Pokedex scene, with a player who has seen every species and owns
  # them unless owned is false.
  def with_hgss_dex(owned = true, &blk)
    player = Object.new
    player.define_singleton_method(:owned?) { |_species| owned }
    player.define_singleton_method(:seen?) { |_species| true }
    with_global(:$player, player) { with_plugin("hgss_dexlist", "PokemonPokedex_Scene", &blk) }
  end

  # A Pokedex scene showing the plugin's list sprite, its cursor on species 25, numbered 25.
  def dex_list(k)
    list = Object.new
    def list.index; 0; end
    def list.dexlist; [{ :species => 25, :number => 25 }]; end
    scene = k.new
    scene.instance_variable_set(:@sprites, { "pokedex" => list })
    scene
  end

  # A berry detail scene on the Oran Berry.
  def berry_page(k)
    scene = k.new
    scene.instance_variable_set(:@berry, :ORANBERRY)
    scene
  end

  # The focused row's text of a window of class name standing in with the given instance variables, its cursor on
  # index, as the menu reader dispatches it.
  def window(name, ivars, index = 0)
    k = Class.new { attr_accessor :index }
    standing_in([[name, k]]) do
      w = k.new
      w.index = index
      ivars.each { |iv, v| w.instance_variable_set(iv, v) }
      PokeAccess::Menus.focused_text(w)
    end
  end

  # A decoration bag holding three of eight in each category.
  def decoration_bag
    bag = Object.new
    def bag.current_pocket_size(_pocket); 3; end
    def bag.max_pocket_size(_pocket); 8; end
    bag
  end

  # Runs the block with every berry registered in the Berrydex (pbBerryRegistered? true), the game's own put back after.
  def with_registered_berries
    had = Object.private_method_defined?(:pbBerryRegistered?) || Object.method_defined?(:pbBerryRegistered?)
    Object.send(:alias_method, :pa_smoke_registered, :pbBerryRegistered?) if had
    Object.send(:define_method, :pbBerryRegistered?) { |_berry| true }
    Object.send(:private, :pbBerryRegistered?)
    yield
  ensure
    if had
      Object.send(:alias_method, :pbBerryRegistered?, :pa_smoke_registered)
      Object.send(:remove_method, :pa_smoke_registered)
    else
      Object.send(:remove_method, :pbBerryRegistered?)
    end
  end

  # Runs the block with the plugin's SecretBag listing two categories.
  def with_secret_bag(&blk)
    bag = Module.new
    def bag.pocket_count; 2; end
    def bag.pocket_names; ["Muebles", "Adornos"]; end
    standing_in([["SecretBag", bag]], &blk)
  end

  # Runs the block with $quest_data naming the quests by id.
  def with_quest_names(names, &blk)
    data = Object.new
    data.define_singleton_method(:getName) { |id| names[id] }
    with_global(:$quest_data, data, &blk)
  end

  # Runs the block with the global var set to value, put back afterwards.
  def with_global(var, value)
    set = eval("lambda { |v| #{var} = v }")
    had = eval(var.to_s)
    set.call(value)
    yield
  ensure
    set.call(had) if set
  end
end
