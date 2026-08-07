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
  "PokemonPokedex_Scene" => lambda { Class.new { def pbRefresh; :dex_drawn; end } }
}

# The extractor-only plugins are NOT required here: the harness loads every reader, and require does not
# know about a file already brought in with eval, so a second load would reassign whatever constants it
# defines.
# What the smoke does below is different and still needed: it RE-EVALUATES the hook-carrying files
# after building fake scene classes, because a hook whose class did not exist at load time never bound.

# The plugin files carrying hooks. The extractor-only ones above are absent on purpose: they bind nothing.
PLUGIN_HOOK_FILES = %w[item_crafting gender_selection text_log incubator hall_of_fame_bw photo_album
                       berrydex secret_bases rse_starters hgss_dexlist]

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
