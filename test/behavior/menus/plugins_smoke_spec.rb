# The wiring of the plugins/ layer: the readers get the classes they hook, their files (this repo's own) are evaluated
# again so the hooks bind, and the hooked methods are driven as the game does. Extractors need no replay:
# Menus.focused_text resolves the class on every call. The classes are removed after each suite.
PLUGIN_SCENES = {
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
  # The two modal-loop scenes record the scene SceneWatcher holds while their loop runs, the proof the hook bound.
  "Log" => lambda {
    Class.new do
      attr_reader :held
      def update; @held = PokeAccess::TextLogReader.instance_variable_get(:@scene); :closed; end
    end
  },
  "Incubadora" => lambda { Class.new { def refresh; :refreshed; end; def dispose; :disposed; end } },
  "HallOfFameViewerScene" => lambda { Class.new { def update_display; :redrawn; end } },
  "AlbumFotos_Scene" => lambda {
    Class.new do
      attr_reader :held
      def pbUpdateAlbum; @held = PokeAccess::PhotoAlbumReader.instance_variable_get(:@scene); :album_closed; end
    end
  },
  "BerrydexInfo_Scene" => lambda { Class.new { def drawPage(_page); :page_drawn; end } },
  "PlaceDecoration_Scene" => lambda { Class.new { def pbUpdate; :updated; end } },
  "RSESTarterChoice" => lambda { Class.new { def pbUpdate; :starter_drawn; end } },
  # The HGSS dex list hooks a class every game has; the plugin shows in a list sprite answering dexlist and index.
  "PokemonPokedex_Scene" => lambda { Class.new { def pbRefresh; :dex_drawn; end } },
  "WindowTextEntryKeyboardPerKey" => lambda {
    Class.new do
      def insert(_ch); :inserted; end
      def delete; :deleted; end
    end
  },
  "Ekans_Interface_Game" => lambda {
    Class.new do
      def update_score_display
        pbDrawTextPositions(nil, [["Puntuación: 3", 256, 6, 2, nil, nil]])
        :score_drawn
      end
    end
  }
}

# The plugin files the hand-built suite drives with real fixtures, speech included; the derived suite covers the
# rest. No plugin file is required here: the harness has loaded them, and a second load reassigns their constants.
PLUGIN_HOOK_FILES = %w[item_crafting gender_selection text_log incubator hall_of_fame_bw photo_album
                       berrydex secret_bases rse_starters hgss_dexlist bag_search_entry ekans_snake]

# Every plugin file evaluated twice: with its manifest probe, recording each (class, method) it hooks, then on
# stand-ins with all of them; each hook binds, returns the sentinel, raises nothing and is no NO-DUMP site. On the
# way out a class another spec defined gets back the method a new hook wrapped, since the hook's chain goes too.
Suite.define("plugins: every hook in plugins/ binds and survives a drive, on stand-ins derived from the manifest and the file itself") do
  root = Harness::ROOT
  pdir = File.join(root, "plugins")
  table = eval(File.read(File.join(pdir, "manifest.rb")))
  files = Dir.glob(File.join(pdir, "*.rb")).sort.reject { |f| File.basename(f) == "manifest.rb" }
  hook_rx = /(after_hook|before_hook|around_hook|SceneWatcher\.(reader|wire)|MenuReturn\.bare|read_on_open)\s*\(\s*"/
  hookish = files.select { |f| File.read(f) =~ hook_rx }.map { |f| File.basename(f, ".rb") }

  hooks = PokeAccess::Hooks
  chains = hooks.instance_variable_get(:@chains)
  chain_snap = {}
  chains.each { |k, v| chain_snap[k] = v.dup }
  bodies = hooks.fn_bodies
  body_snap = {}
  bodies.each { |k, v| body_snap[k] = v.dup }
  pollers = PokeAccess::Keys.instance_variable_get(:@frame_pollers)
  poller_snap = pollers ? pollers.dup : nil
  listeners = PokeAccess::MenuReturn.instance_variable_get(:@listeners)
  listener_snap = listeners.dup
  extractors_len = PokeAccess::Menus::EXTRACTORS.length
  made = []

  ensure_const = lambda do |name|
    parent = Object
    segs = name.split("::")
    segs.each_with_index do |seg, i|
      if parent.const_defined?(seg, false)
        parent = parent.const_get(seg, false)
      else
        c = (i == segs.length - 1) ? Class.new : Module.new
        parent.const_set(seg, c)
        made.push([parent, seg])
        parent = c
      end
    end
    parent
  end
  owned = {}
  give = lambda do |name, meths|
    k = ensure_const.call(name)
    next unless made.any? { |par, seg| par.const_get(seg, false).equal?(k) }
    owned[name] = k
    meths.each do |m|
      next if k.method_defined?(m) || k.private_method_defined?(m)
      k.send(:define_method, m) { |*_a| :pa_smoke }
    end
  end

  recorded = Hash.new { |h, k| h[k] = {} }
  per_file = Hash.new { |h, k| h[k] = [] }
  current = nil
  meta = class << hooks; self; end
  meta.send(:alias_method, :pa_smoke_wrap, :wrap)
  meta.send(:define_method, :wrap) do |cname, meth, *rest, &mw|
    recorded[cname.to_s][meth.to_s] = true
    per_file[current].push("#{cname}##{meth}") if current
    pa_smoke_wrap(cname, meth, *rest, &mw)
  end

  load_errors = []
  evaluate = lambda do |f|
    current = File.basename(f, ".rb")
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      eval(File.read(f), TOPLEVEL_BINDING, f)
    rescue Exception => e
      load_errors.push("#{current}: #{e.class}: #{e.message[0, 100]}")
    ensure
      $VERBOSE = verbose
      current = nil
    end
  end

  begin
    table.each do |_name, probe|
      cname, pmeth = probe.to_s.split("#", 2)
      give.call(cname, pmeth ? [pmeth] : [])
    end
    files.each { |f| evaluate.call(f) }
    eq "every plugin file evaluates with its probe present", load_errors, []
    eq "every hook-carrying file registered something with its probe present",
       hookish.reject { |n| per_file[n].any? }, []

    recorded.each { |cname, meths| give.call(cname, meths.keys) }
    hooks.missing.clear
    files.each { |f| evaluate.call(f) }
    eq "and evaluates again with the full stand-ins", load_errors, []

    unbound = []
    wrong = []
    raised = []
    recorded.each do |cname, meths|
      k = owned[cname]
      next unless k
      meths.keys.each do |m|
        key = "#{cname}##{m}"
        unbound.push(key) unless chains.has_key?(key)
        next if m == "initialize"
        obj = (k.allocate rescue nil)
        next if obj.nil?
        begin
          r = obj.send(m)
          wrong.push("#{key} -> #{r.inspect}") unless r == :pa_smoke
        rescue Exception => e
          raised.push("#{key}: #{e.class}: #{e.message[0, 80]}")
        end
      end
    end
    truthy "the two passes saw a realistic number of registrations (#{recorded.length} classes)", recorded.length >= 30
    eq "every registration on a stand-in bound", unbound.sort, []
    eq "driving each hooked method returns the plugin's own value through the wrapper", wrong.sort, []
    eq "with no exception escaping a hook body", raised.sort, []

    no_dump = {}
    File.read(File.join(root, "test", "static", "loop_census.txt")).each_line do |l|
      no_dump[$1] = true if l =~ /^(\S+#\S+) = NO-DUMP/
    end
    short = lambda { |key| cls, m = key.split("#", 2); "#{cls.split('::').last}##{m}" }
    ghosts = recorded.map { |c, ms| ms.keys.map { |m| "#{c}##{m}" } }.flatten.select { |key| no_dump[short.call(key)] }
    eq "no plugin hooks a method no surveyed game defines (NO-DUMP in loop_census)", ghosts.sort, []
  ensure
    meta.send(:alias_method, :wrap, :pa_smoke_wrap)
    meta.send(:remove_method, :pa_smoke_wrap)
    made.reverse_each { |par, seg| par.send(:remove_const, seg) if par.const_defined?(seg, false) }
    chains.keys.each do |key|
      next chains[key].replace(chain_snap[key]) if chain_snap.has_key?(key)
      cname, meth = key.split("#", 2)
      k = meth && PokeAccess.const_at(cname)
      orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
      k.send(:alias_method, meth, orig) if k.is_a?(Module) && (k.method_defined?(orig) || k.private_method_defined?(orig))
      chains.delete(key)
    end
    bodies.keys.each { |k| body_snap.has_key?(k) ? bodies[k].replace(body_snap[k]) : bodies.delete(k) }
    pollers.replace(poller_snap) if pollers && poller_snap
    listeners.replace(listener_snap)
    PokeAccess::Menus::EXTRACTORS.slice!(extractors_len..-1) if PokeAccess::Menus::EXTRACTORS.length > extractors_len
    hooks.missing.clear
    SpeakCapture.clear
  end
end

Suite.define("plugins: every reader in plugins/ actually binds to the class its plugin ships") do
  made = []
  begin
    PLUGIN_SCENES.each do |name, build|
      next if Object.const_defined?(name)
      Object.const_set(name, build.call)
      made.push(name)
    end
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      PLUGIN_HOOK_FILES.each do |f|
        path = File.join(Harness::ROOT, "plugins", "#{f}.rb")
        eval(File.read(path), TOPLEVEL_BINDING, path)
      end
    ensure
      $VERBOSE = verbose
    end

    eq "no plugin hook reported a method it expected and did not find",
       PokeAccess::Hooks.missing.select { |m| PLUGIN_SCENES.keys.any? { |c| m.to_s.index("#{c}#") == 0 } }, []

    craft = ItemCraft_Scene.new
    adapter = Object.new
    adapter.define_singleton_method(:getName) { |_i| "Pocion" }
    adapter.define_singleton_method(:getNamePlural) { |_i| "Pociones" }
    adapter.define_singleton_method(:getQuantity) { |_i| 4 }
    craft.instance_variable_set(:@adapter, adapter)
    craft.instance_variable_set(:@stock, [[:POTION, [:BERRY, 2]]])

    SpeakCapture.clear
    eq "the redraw hook preserves the plugin's return value", craft.pbRedrawMenu(0, 1), :menu_drawn
    spoke "the focused recipe is read from the list", /Pocion/
    SpeakCapture.clear
    craft.pbRedrawMenu(0, 1)
    silent "a redraw that changed nothing stays silent"

    SpeakCapture.clear
    craft.refreshNumbers(0, 3)
    spoke "raising the amount reads the plural and the count",
          /#{Regexp.escape(PokeAccess::I18n.t(:craft_amount, :name => "Pociones", :n => 3))}/
    spoke "with what the ingredients cost at that amount",
          /#{Regexp.escape(PokeAccess::I18n.t(:craft_ingredient, :name => "Pocion", :have => 4, :need => 6))}/
    SpeakCapture.clear
    eq "the amount hook preserves its return value too", craft.refreshNumbers(0, 3), :numbers_drawn
    silent "and the same amount again is silent"

    sel = PokemonGenderSelection.new
    SpeakCapture.clear
    sel.main_method
    spoke "the gender picker explains its two unlabelled pictures on open",
          /#{Regexp.escape(PokeAccess::I18n.t(:gsel_help))}/
    sel.instance_variable_set(:@select, 2)
    SpeakCapture.clear
    eq "and its per-frame input hook keeps the plugin's return value", sel.input, :input_done
    spoke "the highlighted choice is spoken", /#{Regexp.escape(PokeAccess::I18n.t(:gsel_boy))}/

    per_key = WindowTextEntryKeyboardPerKey.new
    SpeakCapture.clear
    eq "the bag searcher's insert hook keeps the plugin's return value", per_key.insert("q"), :inserted
    spoke "and echoes the typed character", /\Aq\z/
    SpeakCapture.clear
    eq "its delete hook keeps the return value too", per_key.delete, :deleted
    spoke "and says the deletion", /#{Regexp.escape(PokeAccess::I18n.t(:te_deleted))}/

    hof = HallOfFameViewerScene.new
    mon = Object.new
    mon.define_singleton_method(:name) { "Rocoso" }
    mon.define_singleton_method(:speciesName) { "Onix" }
    mon.define_singleton_method(:level) { 51 }
    hof.instance_variable_set(:@hallEntry, [mon])
    hof.instance_variable_set(:@hallIndex, 0)
    hof.instance_variable_set(:@pokemonIndex, 0)
    SpeakCapture.clear
    eq "the hall viewer hook preserves its return value", hof.update_display, :redrawn
    spoke "and reads the focused team member", /Rocoso/

    inc = Incubadora.new
    inc.instance_variable_set(:@index, 0)
    SpeakCapture.clear
    eq "the incubator hook preserves its return value", inc.refresh, :refreshed
    spoke "and the focused slot is read", /#{Regexp.escape(PokeAccess::I18n.t(:hatch_slot_empty, :n => 1))}/
    eq "closing the incubator keeps its own return value", inc.dispose, :disposed
    eq "and takes its slot off the info key", PokeAccess::Info.row_text, nil

    deco = PlaceDecoration_Scene.new
    deco.instance_variable_set(:@cursor_x, 4)
    deco.instance_variable_set(:@cursor_y, 7)
    SpeakCapture.clear
    eq "the decoration cursor hook preserves its return value", deco.pbUpdate, :updated
    spoke "and the tile under it is read", /#{Regexp.escape(PokeAccess::I18n.t(:mg_rowcol, :row => 7, :col => 4))}/

    log = Log.new
    eq "the message log's modal loop is wrapped without changing its result", log.update, :closed
    truthy "and the log scene was held for its duration", log.held.equal?(log)
    eq "then released on the way out", PokeAccess::TextLogReader.instance_variable_get(:@scene), nil

    album = AlbumFotos_Scene.new
    eq "the album's loop keeps its result too", album.pbUpdateAlbum, :album_closed
    truthy "and its scene was held as well", album.held.equal?(album)
    eq "and released", PokeAccess::PhotoAlbumReader.instance_variable_get(:@scene), nil

    starter = RSESTarterChoice.new
    sp = Object.new
    sp.define_singleton_method(:name) { "Treecko" }
    starter.instance_variable_set(:@species_cache, [sp, sp, sp])
    starter.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    eq "the starter carousel hook preserves its return value", starter.pbUpdate, :starter_drawn
    spoke "and the focused starter is named with its place in the row",
          /#{Regexp.escape(PokeAccess::I18n.t(:list_entry, :name => "Treecko", :n => 2, :tot => 3))}/

    dex = PokemonPokedex_Scene.new
    plugin_list = Object.new
    plugin_list.define_singleton_method(:index) { 0 }
    plugin_list.define_singleton_method(:dexlist) { [{ :species => :BULBASAUR, :number => 1 }] }
    dex.instance_variable_set(:@sprites, { "pokedex" => plugin_list })
    SpeakCapture.clear
    eq "the dex list hook preserves its return value", dex.pbRefresh, :dex_drawn
    truthy "and the focused row is read", SpeakCapture.lines.length == 1
    SpeakCapture.clear
    dex.pbRefresh
    silent "a repaint on the same row stays silent"

    stock = PokemonPokedex_Scene.new
    stock.instance_variable_set(:@sprites, { "pokedex" => Object.new })
    SpeakCapture.clear
    stock.pbRefresh
    silent "and a game with the STOCK pokedex says nothing here, though the hook bound there too"

    ekans = Ekans_Interface_Game.new
    SpeakCapture.clear
    eq "the Ekans score hook keeps its return value", ekans.update_score_display, :score_drawn
    eq "and says the score as the game paints it", SpeakCapture.lines, ["Puntuación: 3"]

    berry = BerrydexInfo_Scene.new
    berry.instance_variable_set(:@berry, :ORANBERRY)
    SpeakCapture.clear
    eq "the berry detail page keeps its return value", berry.drawPage(1), :page_drawn
    spoke "and the page is announced with its section",
          /#{Regexp.escape(PokeAccess::I18n.t(:bdx_section, :name => PokeAccess::I18n.t(:bdx_page_info)))}/
    SpeakCapture.clear
    berry.drawPage(1)
    silent "redrawing the same page stays silent"
  ensure
    made.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    SpeakCapture.clear
  end
end

# The plugin extractors are dispatched to (focused_text resolves the class on each call); each expected line is one
# the generic reader could not produce.
Suite.define("plugins: the window extractors are dispatched to, not just registered") do
  made = []
  mk = lambda do |name, ivars|
    unless Object.const_defined?(name)
      Object.const_set(name, Class.new { attr_accessor :index })
      made.push(name)
    end
    w = Object.const_get(name).new
    w.index = 0
    ivars.each { |k, v| w.instance_variable_set(k, v) }
    w
  end

  begin
    rules = mk.call("Window_CommandPokemon_Challenge",
                    { :@commands => ["Nuzlocke"], :@text_key => [1] })
    eq "the rule editor's toggle reaches the player, which the generic reader never had",
       PokeAccess::Menus.focused_text(rules), "Nuzlocke, #{PokeAccess::I18n.t(:val_on)}"

    dex = mk.call("Window_Berrydex", { :@commands => [[:ORANBERRY, "Aranja", 7]] })
    eq "the generic reader cannot read a triple at all, so this can only be ours",
       PokeAccess::Menus.focused_text(dex), PokeAccess::I18n.t(:bdx_unknown, :num => 7)

    unless Object.const_defined?("SecretBag")
      Object.const_set("SecretBag", Module.new do
        def self.pocket_count; 2; end
        def self.pocket_names; ["Muebles", "Adornos"]; end
      end)
      made.push("SecretBag")
    end
    bag = Object.new
    bag.define_singleton_method(:current_pocket_size) { |_p| 3 }
    bag.define_singleton_method(:max_pocket_size) { |_p| 8 }
    pockets = mk.call("Window_BasePocketsList", { :@bag => bag })
    eq "the secret-base category says how full it is",
       PokeAccess::Menus.focused_text(pockets),
       "Muebles, #{PokeAccess::I18n.t(:sb_qty, :cur => 3, :max => 8)}"

    pockets.index = 2
    eq "and the row past the last category is the cancel button",
       PokeAccess::Menus.focused_text(pockets), PokeAccess::I18n.t(:pc_cancel)

    quest = Object.new
    quest.define_singleton_method(:id) { :RESCATE }
    quest.define_singleton_method(:story) { true }
    quest.define_singleton_method(:new) { true }
    saved_qd = ($quest_data rescue nil)
    begin
      qd = Object.new
      qd.define_singleton_method(:getName) { |_id| "Rescatar al profesor" }
      $quest_data = qd
      journal = mk.call("Window_Quest", { :@quests => [quest] })
      eq "the quest is named, and the two marks the list only PAINTS are spoken",
         PokeAccess::Menus.focused_text(journal),
         "Rescatar al profesor, #{PokeAccess::I18n.t(:quest_story)}, #{PokeAccess::I18n.t(:quest_new)}"
    ensure
      $quest_data = saved_qd
    end

  ensure
    made.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    SpeakCapture.clear
  end
end
