require "json"
require "rbconfig"
require "tmpdir"

# The third-party screens Awakening ships, read through the plugins' hooks over its copies: raZ's encounter list and
# Marin's quest log (in a child process), the Magic Gachapon, and the colour its quest log paints a quest's name in.

# Awakening's 0245 scene: refresh repaints the banner strip and the buttons for the cursor its ivars hold; each reward
# method hands its prize over through the reveal, rewardAnim, which a five-star prize of a banner's script also runs
# directly.
class GachaScene
  def initialize(banners)
    @banners = banners
    @banner_sel = 0
    @sel = 1
    @sprites = {}
  end

  def refresh; :refreshed; end
  def dispose; :disposed; end
  def summaryWindow; :summary_closed; end
  def rewardAnim(_filename, _stars); :revealed; end

  def pokeReward(poke, stars)
    rewardAnim("Graphics/Battlers/#{poke}", stars)
    :added
  end

  def itemReward(item, stars)
    rewardAnim("Graphics/Icons/#{item}", stars)
    :stored
  end
end

# No stub has GachaScene, so plugins/magic_gachapon.rb, evaluated at boot, bound no hook: its hook registrations (the
# file from its first PokeAccess::Hooks line on) are evaluated once more over this one, its module kept as boot left it.
File.join(Harness::ROOT, "plugins", "magic_gachapon.rb").tap do |path|
  src = Harness.source(path)
  at = src.index(/^PokeAccess::Hooks\./)
  eval(src[at..-1], TOPLEVEL_BINDING, path, src[0, at].count("\n") + 1)
end

class AwakeningPluginsTest < PokeAccessTest
  T = PokeAccess::I18n
  Banner = Struct.new(:name, :description)
  Quest = Struct.new(:name, :completed, :color)
  Colour = Struct.new(:red, :green, :blue)

  # Awakening's 0239 window, whose constructor fills @encarray through getEncData (a last 7 for none) and only then
  # creates its icons; and its 0145 log, the stub's Marin log with Awakening's own cover counts and an empty list's
  # notice before an empty title. Declared in the child before the toolkit loads, so its hooks find them.
  CHILD_WORLD = <<-'RUBY'
    class EncounterListUI
      class << self
        attr_accessor :species, :icons
      end

      def initialize
        @encarray = []
        @pkmnsprite = []
        getEncData
        @pkmnsprite = (EncounterListUI.icons || []).dup unless @encarray.last == 7
      end

      def getEncData
        @encarray = EncounterListUI.species ? EncounterListUI.species.dup : [7]
      end
    end

    class Questlog
      def initialize
        @page = 0; @sel_one = 0; @sel_two = 0; @scene = 0; @mode = 0
        @ongoing = (Questlog.quests || []).reject { |q| q.completed }
        @completed = (Questlog.quests || []).select { |q| q.completed }
        pbDrawOutlineText(nil, 0, -112, 512, 384, "Misiones", nil, nil, 1)
        pbDrawOutlineText(nil, 0, -36, 512, 384, "En curso: " + @ongoing.size.to_s, nil, nil, 1)
        pbDrawOutlineText(nil, 0, 20, 512, 384, "Completadas: " + @completed.size.to_s, nil, nil, 1)
        pbUpdate
      end

      def pbList(id)
        PokeAccess::Frame.run_pollers
        @sel_two = 0; @page = 0; @scene = 1; @mode = id
        list = (id == 0 ? @ongoing : @completed)
        list.each_with_index { |q, i| pbDrawOutlineText(nil, 11, -124 + 52 * i, 512, 384, q.name, nil, nil, 1) }
        empty = (id == 0 ? "No hay misiones en curso" : "No hay misiones completadas")
        pbDrawOutlineText(nil, 0, 0, 512, 384, empty, nil, nil, 1) if list.empty?
        pbDrawOutlineText(nil, 0, -112, 512, 384, "", nil, nil, 1)
      end
    end
  RUBY

  # The child's scenarios, on a map named Bosque Verde where species 1 is caught and 4 unseen: each keeps what was
  # said as [text, interrupt] pairs, and the result goes out as one JSON line with the load errors and the info key.
  CHILD_SCENARIOS = <<-'RUBY'
    def $game_map.name; "Bosque Verde"; end
    PokeAccess::Util.define_singleton_method(:dex_owned?) { |sp| sp == 1 }
    PokeAccess::Util.define_singleton_method(:dex_seen?) { |sp| sp == 1 }
    tone = Struct.new(:red, :green, :blue, :gray)
    icon = Struct.new(:opacity, :tone)
    clear = tone.new(0, 0, 0, 0)
    said = {}
    record = lambda { |key| said[key] = SpeakCapture.log.map { |t, i| [t, i] }; SpeakCapture.clear }

    SpeakCapture.clear
    EncounterListUI.species = [1, 4]
    EncounterListUI.icons = [icon.new(255, clear), icon.new(100, clear)]
    EncounterListUI.new
    record.call("filled")
    PokeAccess::Frame.run_pollers
    record.call("dimmed")
    PokeAccess::Frame.run_pollers
    record.call("next_frame")
    EncounterListUI.icons = [icon.new(255, clear), icon.new(255, tone.new(0, 0, 0, 255))]
    EncounterListUI.new
    PokeAccess::Frame.run_pollers
    record.call("grey")
    EncounterListUI.icons = [icon.new(255, clear), icon.new(255, clear)]
    EncounterListUI.new
    PokeAccess::Frame.run_pollers
    record.call("plain")
    EncounterListUI.icons = []
    EncounterListUI.new
    PokeAccess::Frame.run_pollers
    record.call("unfinished")
    EncounterListUI.species = nil
    EncounterListUI.new
    PokeAccess::Frame.run_pollers
    record.call("none")
    PokeAccess::Config.verbosity = :brief
    EncounterListUI.species = [1, 4]
    EncounterListUI.icons = [icon.new(255, clear), icon.new(255, clear)]
    EncounterListUI.new
    PokeAccess::Frame.run_pollers
    record.call("brief")
    info = PokeAccess::Info.info_text
    PokeAccess::Config.verbosity = :full

    quest = Struct.new(:name, :desc, :npc, :location, :completed)
    Questlog.quests = [quest.new("Mentas", "Busca mentas", "Liam", "Pueblo", true)]
    Questlog.steps = [[:pbSwitch, :DOWN], [:pbSwitch, :UP], [:pbList, 0]]
    Questlog.new
    record.call("quest_log")
    puts "RESULT " + JSON.generate("errors" => ERRS, "said" => said, "info" => info)
  RUBY

  # The child's result, { "errors", "said", "info" }, from one child per test process.
  def self.child
    @child ||= run_child
  end

  # Runs CHILD_WORLD, the whole Awakening profile and CHILD_SCENARIOS in a gen-6 process of their own (in this one
  # Realidea's EncounterListUI and the stub Questlog, Africanvs's words, already hold those names, and a hook binds once
  # per name); the parsed result, or the child's raw output when it printed none.
  def self.run_child
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\nrequire 'json'\n#{CHILD_WORLD}\n" \
             "ERRS = Harness.load_all('awakening')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHILD_SCENARIOS}"
    Dir.mktmpdir("pa-awakening-plugins") do |dir|
      path = File.join(dir, "child.rb")
      File.open(path, "wb") { |f| f.write(script) }
      out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, path], :err => [:child, :out]) { |io| io.read }
      out = out.to_s.force_encoding("UTF-8")
      line = out[/^RESULT (.*)$/, 1]
      line ? JSON.parse(line) : out
    end
  end
  private_class_method :run_child

  # Awakening's color_mark, from games/awakening/quests.rb evaluated once per process: the core's, the overrides and
  # the profiles are put back at once, and with_awakening_quests installs this one for a test.
  def self.awakening_color_mark
    @awakening_color_mark ||= begin
      quests = PokeAccess::Quests
      core = quests.method(:color_mark)
      overrides = PokeAccess::Hooks.overrides.length
      profiles = PokeAccess::Game.profiles.dup
      path = File.join(Harness::ROOT, "games", "awakening", "quests.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      mark = quests.method(:color_mark)
      quests.define_singleton_method(:color_mark, core)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
      mark
    end
  end

  test "the Awakening profile loads whole over classes shaped as its copies" do
    assert_equal [], child["errors"]
  end

  test "the encounter list says nothing as getEncData fills it, before its icons exist" do
    assert_equal [], said("filled")
  end

  test "the encounter list is read the next frame, a dimmed icon's species by name and not caught" do
    assert_equal [[encounters(:dex_not_caught), true]], said("dimmed")
  end

  test "the encounter list is read once" do
    assert_equal [], said("next_frame")
  end

  test "the encounter list takes Pokemon Z's grey icon for a species not caught too" do
    assert_equal [[encounters(:dex_not_caught), true]], said("grey")
  end

  test "the encounter list keeps the Pokedex's state for an icon at full opacity and colour" do
    assert_equal [[encounters(:dex_unknown), true]], said("plain")
  end

  test "the encounter list drops unread a window that drew no icons for its species" do
    assert_equal [], said("unfinished")
  end

  test "the encounter list of a map without encounters says so" do
    assert_equal [[T.t(:enc_none, :loc => "Bosque Verde"), true]], said("none")
  end

  test "the encounter list keeps the whole list on the info key whatever the level says" do
    assert_equal [["Bosque Verde: Especie1, #{T.t(:dex_unknown)}", true]], said("brief"), "at brief"
    assert_equal encounters(:dex_unknown), child["info"], "the info key"
  end

  test "the quest log says each category button with the count its cover paints" do
    assert_equal [["En curso: 0", true], ["Completadas: 1", true], ["En curso: 0", true]], said("quest_log").first(3)
  end

  test "the quest log says an empty list by the notice its pbList paints before an empty title, and nothing else" do
    assert_equal [["No hay misiones en curso", true]], said("quest_log").drop(3)
  end

  test "the gachapon says as it opens the banner with its place, the focused button and the coins it spends" do
    with_coins(120) { gacha.refresh }
    assert_equal [["#{banner_entry('Estandarte de Liam', 1)}. Tirar. #{T.t(:gacha_coins, :n => 120)}", true]],
                 SpeakCapture.log
  end

  test "the gachapon says the banner alone as the cursor goes up onto it" do
    scene = opened_gacha
    scene.instance_variable_set(:@sel, 3)
    scene.refresh
    assert_equal [[banner_entry("Estandarte de Liam", 1), true]], SpeakCapture.log
  end

  test "the gachapon says the button alone as the cursor comes back down" do
    scene = opened_gacha
    scene.instance_variable_set(:@sel, 3)
    scene.refresh
    SpeakCapture.clear
    scene.instance_variable_set(:@sel, 1)
    scene.refresh
    assert_equal [["Tirar", true]], SpeakCapture.log
  end

  test "the gachapon says the banner it changes to" do
    scene = opened_gacha
    scene.instance_variable_set(:@sel, 3)
    scene.instance_variable_set(:@banner_sel, 1)
    scene.refresh
    assert_equal [[banner_entry("Estandarte de Lana", 2), true]], SpeakCapture.log
  end

  test "the gachapon says nothing on a redraw with nothing changed" do
    opened_gacha.refresh
    assert_nothing_spoken
  end

  test "the gachapon says its coins again, after the focused button, once a pull spends them" do
    scene = gacha
    with_coins(120) { scene.refresh }
    SpeakCapture.clear
    with_coins(100) { scene.refresh }
    assert_equal [["Tirar. #{T.t(:gacha_coins, :n => 100)}", true]], SpeakCapture.log
  end

  test "the gachapon says a Pokemon prize's tier once, its name left to the game's message" do
    gacha.pokeReward(25, 3)
    assert_equal [[T.t(:gacha_stars, :n => 3), true]], SpeakCapture.log
  end

  test "the gachapon names an item prize with its tier, and the reveal it runs adds nothing" do
    gacha.itemReward(:POTION, 4)
    assert_equal [[T.t(:gacha_prize, :name => "Pocion", :n => 4), true]], SpeakCapture.log
  end

  test "the gachapon says the tier of a reveal a banner runs directly" do
    gacha.rewardAnim("Graphics/Battlers/150", 5)
    assert_equal [[T.t(:gacha_stars, :n => 5), true]], SpeakCapture.log
  end

  test "the gachapon's Info button says the focused banner's description" do
    GachaScene.new([Banner.new("Estandarte de Liam", "Liam aparece más a menudo.")]).summaryWindow
    assert_equal [["Liam aparece más a menudo.", true]], SpeakCapture.log
  end

  test "closing the gachapon takes its text off the info key" do
    PokeAccess::Info.set_info(:text, "Destacados")
    gacha.dispose
    assert_nil PokeAccess::Info.info_text
  end

  test "the gachapon's hooked methods return what the game's own return" do
    scene = gacha
    { [:refresh] => :refreshed, [:dispose] => :disposed, [:summaryWindow] => :summary_closed,
      [:rewardAnim, "Graphics/Battlers/150", 5] => :revealed, [:pokeReward, 25, 3] => :added,
      [:itemReward, :POTION, 4] => :stored }.each do |call, value|
      assert_equal value, scene.send(*call), "GachaScene##{call[0]}"
    end
  end

  test "Awakening's quest log says from medium the colour a quest's name is painted in, between its name and state" do
    rows = with_awakening_quests do
      vb_levels { PokeAccess::Quests.quest_row(Quest.new("Persefone", false, Colour.new(255.0, 160.0, 50.0))) }
    end
    marked = "Persefone, #{T.t(:awk_quest_gold)}, #{T.t(:qu_status_pending)}"
    assert_equal ["Persefone", marked, marked], rows
  end

  test "Awakening's quest log tells gold, red and light blue apart, a boss's red clamped as the screen draws it" do
    { [255, 160, 50] => :awk_quest_gold, [272, 67, 67] => :awk_quest_red,
      [139, 247, 215] => :awk_quest_blue }.each do |rgb, mark|
      row = with_awakening_quests { PokeAccess::Quests.quest_row(Quest.new("Mercader", true, Colour.new(*rgb))) }
      assert_equal "Mercader, #{T.t(mark)}, #{T.t(:qu_status_done)}", row, "for #{rgb.inspect}"
    end
  end

  test "Awakening's quest log marks nothing for white, a colour near a mark, or no colour" do
    [Colour.new(255, 255, 255), Colour.new(254, 160, 50), nil].each do |colour|
      row = with_awakening_quests { PokeAccess::Quests.quest_row(Quest.new("Mentas", false, colour)) }
      assert_equal "Mentas, #{T.t(:qu_status_pending)}", row, "for #{colour.inspect}"
    end
  end

  private

  # The child's result, failing the test with the child's output when it gave none.
  def child
    result = self.class.child
    flunk "the awakening process gave no result: #{result[0, 600]}" unless result.is_a?(Hash)
    result
  end

  # What a scenario of the child said, as [text, interrupt] pairs.
  def said(key)
    child["said"][key]
  end

  # The list the map's two species make as said in full: Especie1 caught, Especie4 in the state given.
  def encounters(state)
    second = state == :dex_unknown ? T.t(:dex_unknown) : "Especie4 #{T.t(state)}"
    "#{T.t(:enc_type, :type => 'Bosque Verde', :n => 2)}: Especie1 #{T.t(:dex_caught)}, #{second}"
  end

  # A gachapon over two banners, the cursor on its Pull button.
  def gacha
    GachaScene.new([Banner.new("Estandarte de Liam"), Banner.new("Estandarte de Lana")])
  end

  # A banner of gacha's two, with its place in the strip.
  def banner_entry(name, place)
    T.t(:list_entry, :name => name, :n => place, :tot => 2)
  end

  # A gachapon as it opened, with no coins, what it said then cleared.
  def opened_gacha
    scene = gacha
    scene.refresh
    SpeakCapture.clear
    scene
  end

  # Runs the block with the player holding coins gachapon coins, the method taken back after.
  def with_coins(coins)
    $PokemonGlobal.define_singleton_method(:gachaCoins) { coins }
    yield
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :gachaCoins)
  end

  # Runs the block with Awakening's color_mark in the quest log, the core's put back after; the block's value.
  def with_awakening_quests
    quests = PokeAccess::Quests
    core = quests.method(:color_mark)
    quests.define_singleton_method(:color_mark, self.class.awakening_color_mark)
    yield
  ensure
    quests.define_singleton_method(:color_mark, core)
  end
end
