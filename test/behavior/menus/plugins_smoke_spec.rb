# The WIRING of the plugins/ layer, which nothing tested. Every reader there has a spec for its logic, and
# all of them call the pure function directly -- so the class name and the method name, the two things that
# a real audit found broken over and over (a nested class, an empty subclass, a renamed method), were the
# one part CI never looked at. Renaming "Log" to "LogXXX" inside text_log.rb left the whole suite green.
#
# This gives the readers the classes they hook, replays the registrations that ran and bound nothing before
# those classes existed, and then drives the hooked methods the way the game does. Modelled on
# dbk_smoke_spec, which already does exactly this for the Sky battle plugin.
#
# Extractors need no replay: Menus.focused_text resolves the class name on every call, so creating the
# window class is enough for the dispatch to find it. Only hooks bind once at load.
#
# Scope, honestly: under the gen-6 stubs there is no GameData layer, so a reader whose text comes from
# GameData (the berry detail page, the decoration names) can be shown to BIND but not to speak -- defining
# a GameData stand-in is not an option, it would flip Engine.gamedata? for the whole run. The classes are
# created and removed inside these suites so no later suite inherits them.
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
  # The two modal-loop scenes report what the around-hook did WHILE they ran: SceneWatcher holds the scene
  # for the duration of the loop method, so the holder's @scene during the call is the proof it bound.
  "Log" => lambda {
    Class.new do
      attr_reader :held
      def update; @held = PokeAccess::TextLogReader.instance_variable_get(:@scene); :closed; end
    end
  },
  "Incubadora" => lambda { Class.new { def refresh; :refreshed; end } },
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
  # The HGSS dex list reopens a class EVERY game has, so the hook binding proves nothing on its own: what
  # says the plugin is there is the list sprite answering to dexlist/index, which the stock window does not.
  "PokemonPokedex_Scene" => lambda { Class.new { def pbRefresh; :dex_drawn; end } },
  "WindowTextEntryKeyboardPerKey" => lambda {
    Class.new do
      def insert(_ch); :inserted; end
      def delete; :deleted; end
    end
  }
}

# The extractor-only plugins are NOT required here: the harness loads every reader, and require does not
# know about a file already brought in with eval, so a second load would reassign whatever constants it
# defines.
# What the smoke does below is different and still needed: it RE-EVALUATES the hook-carrying files
# after building fake scene classes, because a hook whose class did not exist at load time never bound.

# The plugin files the hand-built suite below drives with REAL fixtures, so their speech is proven and not
# only their binding. Every other hook-carrying file is covered by the derived suite that follows: there is
# no exemption list any more, a new plugin is covered the moment its file and its manifest line exist.
PLUGIN_HOOK_FILES = %w[item_crafting gender_selection text_log incubator hall_of_fame_bw photo_album
                       berrydex secret_bases rse_starters hgss_dexlist bag_search_entry]

# The derived half: every plugin file is evaluated twice against stand-ins built from plugins/manifest.rb
# and from the file's OWN registrations.
#
# Pass 1 gives each plugin only its manifest probe (the class, plus the probed method when the probe is a
# Class#method) and RECORDS every (class, method) the hook funnel is asked for while the file evaluates --
# that is what the plugin binds to once its plugin is present, gates included. Pass 2 hands it stand-ins
# carrying all of those methods (each returning a sentinel), evaluates the file again and checks, per
# registration: it bound (its chain exists), driving the method still returns the sentinel through the
# wrapper with no exception escaping the hook body, and no dump marks the site NO-DUMP in loop_census.txt
# -- the method the plugin hooks exists in some surveyed game's copy of it, which is the renamed-method
# check a stand-in cannot make on its own.
#
# The evaluation is the harness's own eval of this repo's files (test/support/harness.rb): no external input.
#
# What this does NOT prove is speech: a bare stand-in has no state to read. That is the hand-built suite
# below. Everything the two passes register is undone on the way out (chains, pollers, listeners,
# extractors, the stand-in constants), so no later suite inherits a duplicate.
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
  pollers = PokeAccess::Keys.instance_variable_get(:@frame_pollers)
  poller_snap = pollers ? pollers.dup : nil
  listeners = PokeAccess::MenuReturn.instance_variable_get(:@listeners)
  listener_snap = listeners.dup
  extractors_len = PokeAccess::Menus::EXTRACTORS.length
  made = []

  # The constant for a possibly namespaced name, created when absent (intermediates become modules).
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
    chains.keys.each { |k| chain_snap.has_key?(k) ? chains[k].replace(chain_snap[k]) : chains.delete(k) }
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
      # eval is the harness's own loading mechanism (test/support/harness.rb): it evaluates THIS repo's
      # files by absolute path under Harness::ROOT, never external input. Replaying a registration is the
      # only way to bind a hook whose class did not exist when the file first loaded.
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

    # --- item_crafting: the pilot of the whole layer, and until now the only reader with NO spec at all.
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

    # --- the rest: bound, driven, and speaking. Each is its own plugin's real entry point.
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

    deco = PlaceDecoration_Scene.new
    deco.instance_variable_set(:@cursor_x, 4)
    deco.instance_variable_set(:@cursor_y, 7)
    SpeakCapture.clear
    eq "the decoration cursor hook preserves its return value", deco.pbUpdate, :updated
    spoke "and the tile under it is read", /#{Regexp.escape(PokeAccess::I18n.t(:mg_rowcol, :row => 7, :col => 4))}/

    # The two modal-loop readers bind through SceneWatcher: the proof it took is that the scene was HELD
    # while the loop ran (that is what lets the per-frame poll read it), and released afterwards.
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
          /#{Regexp.escape(PokeAccess::I18n.t(:rse_starter, :name => "Treecko", :n => 2, :tot => 3))}/

    # The dex list: the plugin's sprite answers to dexlist/index, the stock window does not, and that is
    # both the read and the gate -- so this asserts the plugin case AND that a stock Pokedex stays quiet.
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

# Extractors are the other half of the layer and fail the same silent way. focused_text resolves the class
# name on each call, so the dispatch is provable without replaying anything -- and each assertion is chosen
# so the GENERIC reader could not have produced it, which is what tells "our extractor ran" apart from
# "something read the list".
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

    # The quest journal keeps its list in @quests and resolves the name through the plugin's own data
    # object, so the generic reader found neither -- it read the window as nothing at all.
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
