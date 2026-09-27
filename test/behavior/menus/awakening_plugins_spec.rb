require "rbconfig"
require "tmpdir"

# The third-party screens Awakening ships, read as its copies paint them and driven through the plugins' own hooks:
# raZ's encounter list, Marin's quest log and the Magic Gachapon.

# raZ's list and Marin's log run in a gen-6 process of their own, the Awakening profile loaded whole over classes
# shaped as its copies: in this one the stub Questlog (Africanvs's words) and Realidea's EncounterListUI already hold
# those names, and a hook binds once per name.
module AwakeningPluginsSpec
  # Awakening's 0239 window, whose constructor fills @encarray through getEncData (a last 7 for none) and only then
  # creates its icons; and its 0145 log, the stub's Marin log with Awakening's own cover counts and an empty list's
  # notice before an empty title. Declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
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
        PokeAccess::Keys.run_frame_pollers
        @sel_two = 0; @page = 0; @scene = 1; @mode = id
        list = (id == 0 ? @ongoing : @completed)
        list.each_with_index { |q, i| pbDrawOutlineText(nil, 11, -124 + 52 * i, 512, 384, q.name, nil, nil, 1) }
        empty = (id == 0 ? "No hay misiones en curso" : "No hay misiones completadas")
        pbDrawOutlineText(nil, 0, 0, 512, 384, empty, nil, nil, 1) if list.empty?
        pbDrawOutlineText(nil, 0, -112, 512, 384, "", nil, nil, 1)
      end
    end
  RUBY

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    T = PokeAccess::I18n
    check "the profile loads whole", ERRS.empty?, ERRS.first(3)

    PokeAccess::Util.define_singleton_method(:dex_owned?) { |sp| sp == 1 }
    PokeAccess::Util.define_singleton_method(:dex_seen?) { |sp| sp == 1 }
    tone = Struct.new(:red, :green, :blue, :gray)
    icon = Struct.new(:opacity, :tone)
    clear = tone.new(0, 0, 0, 0)
    loc = ($game_map.name rescue nil).to_s
    names = [PokeAccess::Data.species_name(1), PokeAccess::Data.species_name(4)]
    listed = lambda { |state| [PokeAccess::EncounterList.summary(loc, [[names[0], :dex_caught], [names[1], state]])] }

    EncounterListUI.species = [1, 4]
    EncounterListUI.icons = [icon.new(255, clear), icon.new(100, clear)]
    SpeakCapture.clear
    EncounterListUI.new
    check "encounter list: nothing is said as getEncData fills the list, before its icons exist", SpeakCapture.lines.empty?,
          SpeakCapture.lines
    PokeAccess::Keys.run_frame_pollers
    check "encounter list: the next frame reads it, a dimmed icon's species by name and not caught",
          SpeakCapture.lines == listed.call(:dex_not_caught), SpeakCapture.lines
    SpeakCapture.clear
    PokeAccess::Keys.run_frame_pollers
    check "encounter list: and once", SpeakCapture.lines.empty?, SpeakCapture.lines

    EncounterListUI.icons = [icon.new(255, clear), icon.new(255, tone.new(0, 0, 0, 255))]
    EncounterListUI.new
    PokeAccess::Keys.run_frame_pollers
    check "encounter list: Z's grey icon is a species not caught too, by name", SpeakCapture.lines == listed.call(:dex_not_caught),
          SpeakCapture.lines
    SpeakCapture.clear
    EncounterListUI.icons = [icon.new(255, clear), icon.new(255, clear)]
    EncounterListUI.new
    PokeAccess::Keys.run_frame_pollers
    check "encounter list: an icon at full opacity and colour keeps the Pokedex's state",
          SpeakCapture.lines == listed.call(:dex_unknown), SpeakCapture.lines
    SpeakCapture.clear
    EncounterListUI.species = nil
    EncounterListUI.new
    PokeAccess::Keys.run_frame_pollers
    check "encounter list: a map without encounters says so", SpeakCapture.lines == [T.t(:enc_none, :loc => loc)],
          SpeakCapture.lines

    quest = Struct.new(:name, :desc, :npc, :location, :completed)
    Questlog.quests = [quest.new("Mentas", "Busca mentas", "Liam", "Pueblo", true)]
    Questlog.steps = [[:pbSwitch, :DOWN], [:pbSwitch, :UP], [:pbList, 0]]
    SpeakCapture.clear
    Questlog.new
    lines = SpeakCapture.lines
    check "quest log: each category button as the constructor paints it", lines[0, 3] == ["En curso: 0", "Completadas: 1", "En curso: 0"],
          lines
    check "quest log: an empty list, the notice its pbList paints before an empty title", lines[3] == "No hay misiones en curso",
          lines
    check "quest log: and nothing else", lines.length == 4, lines
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('awakening')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    path = File.join(Dir.tmpdir, "pa_awakening_plugins_#{Process.pid}.rb")
    File.open(path, "wb") { |f| f.write(script) }
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, path], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end

# The list is read the frame after getEncData, once its icons exist, a dimmed or greyed icon's species named as not
# caught; the log says its category buttons and an empty list's notice as its constructor and pbList paint them.
Suite.define("awakening plugins: the encounter list and the quest log through their hooks, over Awakening's copies") do
  rows = AwakeningPluginsSpec.run
  if rows.is_a?(String)
    truthy "the awakening process ran its checks: #{rows[0, 600]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 10
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end

# Awakening's 0245 scene: refresh repaints the banner strip and the buttons for the cursor its ivars hold; each reward
# method hands its prize over through the reveal, rewardAnim, which a five-star prize of a banner's script also runs
# directly. No stub has this class, so plugins/magic_gachapon.rb is evaluated once more over it.
class GachaScene
  def initialize(banners)
    @banners = banners
    @banner_sel = 0
    @sel = 1
    @sprites = {}
  end

  def refresh
    :refreshed
  end

  def rewardAnim(_filename, _stars)
    :revealed
  end

  def pokeReward(poke, stars)
    rewardAnim("Graphics/Battlers/#{poke}", stars)
    :added
  end

  def itemReward(item, stars)
    rewardAnim("Graphics/Icons/#{item}", stars)
    :stored
  end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.join(Harness::ROOT, "plugins", "magic_gachapon.rb")
ensure
  $VERBOSE = verbose
end

# Up puts the three-button copy's cursor on the banner (@sel 3, a glow and no button), where left and right change
# banner; a reward method's prize is said once, by that method, and a reveal the banner runs directly says its tier.
Suite.define("gachapon: the banner said as the cursor goes up onto it, and a reveal no reward method said") do
  t = PokeAccess::I18n
  banner = Struct.new(:name)
  scene = GachaScene.new([banner.new("Estandarte de Liam"), banner.new("Estandarte de Lana")])
  scene.refresh
  SpeakCapture.clear
  scene.instance_variable_set(:@sel, 3)
  eq "the refresh keeps its own value", scene.refresh, :refreshed
  eq "up onto the banner: the banner", SpeakCapture.lines, [PokeAccess::Verbosity.list_entry("Estandarte de Liam", 1, 2)]
  SpeakCapture.clear
  scene.instance_variable_set(:@sel, 1)
  scene.refresh
  eq "down again: the button", SpeakCapture.lines, ["Tirar"]

  SpeakCapture.clear
  eq "a Pokemon prize keeps its own value", scene.pokeReward(25, 3), :added
  eq "its tier said once, not again by the reveal it runs", SpeakCapture.lines, [t.t(:gacha_stars, :n => 3)]
  SpeakCapture.clear
  scene.itemReward(:POTION, 4)
  eq "an item prize, which goes into the bag in silence, named with its tier and nothing more",
     SpeakCapture.lines, [t.t(:gacha_prize, :name => "Pocion", :n => 4)]
  SpeakCapture.clear
  eq "a reveal keeps its own value", scene.rewardAnim("Graphics/Battlers/150", 5), :revealed
  eq "one a banner runs directly says its tier", SpeakCapture.lines, [t.t(:gacha_stars, :n => 5)]
end

# pbColor(:GOLD) marks the characters' quests, :RED (272 in the script, 255 on screen) the bosses', :SUPERLIGHTBLUE
# the first one; :WHITE, the rest.
Suite.define("quest log: Awakening says the colour a quest's name is painted in, from medium") do
  t = PokeAccess::I18n
  quests = PokeAccess::Quests
  plain = quests.method(:color_mark)
  overrides = PokeAccess::Hooks.overrides.length
  load File.join(Harness::ROOT, "games", "awakening", "quests.rb")
  begin
    color = Struct.new(:red, :green, :blue)
    quest = Struct.new(:name, :completed, :color)
    gold = quest.new("Persefone", false, color.new(255.0, 160.0, 50.0))
    rows = vb_levels { quests.quest_row(gold) }
    eq "brief: the name", rows[0], "Persefone"
    eq "medium: its colour, then its state", rows[1], "Persefone, #{t.t(:awk_quest_gold)}, #{t.t(:qu_status_pending)}"
    eq "a boss's red, clamped as the screen draws it",
       quests.quest_row(quest.new("Matador", true, color.new(272, 67, 67))),
       "Matador, #{t.t(:awk_quest_red)}, #{t.t(:qu_status_done)}"
    eq "the first quest's light blue", PokeAccess::AwakeningQuests.mark(quest.new("Mercader", true, color.new(139, 247, 215))),
       t.t(:awk_quest_blue)
    eq "white marks nothing", quests.quest_row(quest.new("Mentas", false, color.new(255, 255, 255))),
       "Mentas, #{t.t(:qu_status_pending)}"
  ensure
    quests.define_singleton_method(:color_mark, plain)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
end
