# Enhanced Pokemon UI: the IV ratings, the shiny leaves and the happiness meter, each said where its settings draw it
# on the summary and in the PC panel; the legacy data menu read as painted; the all-stats page as its table paints it.

# The plugin's legacy data menu, a loop of its own over the summary: the frames the test hands it in legacy_frames.
class PokemonSummary_Scene
  attr_accessor :legacy_frames
  def pbLegacyMenu; @legacy_frames ? @legacy_frames.call(self) : nil; end
end

# The plugin's hook binds at load to a method that exists then: its pbLegacyMenu block is evaluated again, at its own
# line, over the method above.
mui_path = File.join(Harness::ROOT, "plugins", "enhanced_pokemon_ui.rb")
mui_src = Harness.source(mui_path)
mui_at = mui_src.index(/^PokeAccess::Hooks\.around_hook\("PokemonSummary_Scene", :pbLegacyMenu/)
eval(mui_src[mui_at..-1][/\A.*?^end\r?\n/m], TOPLEVEL_BINDING, mui_path, mui_src[0, mui_at].count("\n") + 1)

class EnhancedPokemonUiGdTest < PokeAccessTest
  T = PokeAccess::I18n
  UI = PokeAccess::EnhancedPokemonUI
  Stat = Struct.new(:id, :name)
  STATS = [Stat.new(:HP, "PS"), Stat.new(:ATTACK, "Ataque"), Stat.new(:DEFENSE, "Defensa"),
           Stat.new(:SPECIAL_ATTACK, "At. Esp."), Stat.new(:SPECIAL_DEFENSE, "Def. Esp."), Stat.new(:SPEED, "Velocidad")].freeze
  IVS = { :HP => 31, :ATTACK => 30, :DEFENSE => 0, :SPECIAL_ATTACK => 27, :SPECIAL_DEFENSE => 20, :SPEED => 5 }.freeze
  GRADES = "PS S, Ataque A, Defensa F, At. Esp. B, Def. Esp. C, Velocidad D"
  SUMMARY = [:SUMMARY_IV_RATINGS, :SUMMARY_SHINY_LEAF, :SUMMARY_HAPPINESS_METER].freeze
  STORAGE = [:STORAGE_IV_RATINGS, :STORAGE_SHINY_LEAF].freeze
  PAGE_ONE = [["PIKA'S LEGACY", 295, 100], ["General", 256, 152], ["Items consumed:", 38, 196], ["3", 474, 196],
              ["Moves learned:", 38, 228], ["7", 474, 228]].freeze
  PAGE_TWO = [["PIKA'S LEGACY", 295, 100], ["Battle History", 256, 152], ["Opponents defeated:", 38, 196],
              ["12", 474, 196]].freeze

  test "ends the stats page with each stat's grade, in the plugin's order" do
    with_ui(:SUMMARY_IV_RATINGS => true) do
      assert_equal stats_page(T.t(:mui_iv_ratings, :list => GRADES)), PokeAccess::SummaryGameData.stats_text(poke)
    end
  end

  test "grades each IV by the plugin's bands, at their edges" do
    edges = { :HP => 25, :ATTACK => 24, :DEFENSE => 17, :SPECIAL_ATTACK => 16, :SPECIAL_DEFENSE => 1, :SPEED => 30 }
    with_ui({}) do
      assert_equal T.t(:mui_iv_ratings, :list => "PS B, Ataque C, Defensa C, At. Esp. D, Def. Esp. D, Velocidad A"),
                   UI.iv_ratings(poke(0, edges))
    end
  end

  test "says no grades for IVs it cannot read, or where the stats cannot be walked" do
    unread = poke
    unread.iv = nil
    with_ui(:SUMMARY_IV_RATINGS => true) do
      assert_equal stats_page, PokeAccess::SummaryGameData.stats_text(unread), "IVs it cannot read"
      walk = GameData::Stat.method(:each_main)
      begin
        GameData::Stat.define_singleton_method(:each_main) { |&_b| nil }
        assert_equal stats_page, PokeAccess::SummaryGameData.stats_text(poke), "no stats to walk"
      ensure
        GameData::Stat.define_singleton_method(:each_main, walk)
      end
    end
  end

  test "in the star style, says each IV as the star it draws, on the stats page and in the PC panel" do
    s = lambda { |n| T.t(:"mui_iv_star_#{n}") }
    stars = T.t(:mui_iv_stars, :list => "PS #{s.call(5)}, Ataque #{s.call(4)}, Defensa #{s.call(0)}, " \
                                        "At. Esp. #{s.call(3)}, Def. Esp. #{s.call(2)}, Velocidad #{s.call(1)}")
    with_ui(:SUMMARY_IV_RATINGS => true, :STORAGE_IV_RATINGS => true, :IV_DISPLAY_STYLE => 0) do
      assert_equal stats_page(stars), PokeAccess::SummaryGameData.stats_text(poke), "the stats page"
      assert_equal pc_panel(stars), PokeAccess::Party.pc_details(poke), "the PC panel"
    end
  end

  test "in the letter style, keeps the letters" do
    with_ui(:SUMMARY_IV_RATINGS => true, :IV_DISPLAY_STYLE => 1) do
      assert_equal stats_page(T.t(:mui_iv_ratings, :list => GRADES)), PokeAccess::SummaryGameData.stats_text(poke)
    end
  end

  test "counts the shiny leaves in the summary header" do
    with_ui(:SUMMARY_SHINY_LEAF => true) do
      assert_equal T.t(:mui_leaves, :n => 3), PokeAccess::Summary.header_icons(poke(3))
    end
  end

  test "puts the leaves after the header's other icons" do
    pk = poke(3)
    pk.shiny = true
    with_ui(:SUMMARY_SHINY_LEAF => true) do
      assert_equal "#{T.t(:pk_shiny)}, #{T.t(:mui_leaves, :n => 3)}", PokeAccess::Summary.header_icons(pk)
    end
  end

  test "adds the leaves and the grades to the PC panel, in that order" do
    with_ui(:STORAGE_SHINY_LEAF => true, :STORAGE_IV_RATINGS => true) do
      assert_equal pc_panel(T.t(:mui_leaves, :n => 3), T.t(:mui_iv_ratings, :list => GRADES)),
                   PokeAccess::Party.pc_details(poke(3))
    end
  end

  test "says six leaves as the crown, and no leaves as none" do
    { 6 => T.t(:mui_leaf_crown), 1 => T.t(:mui_leaves, :n => 1), 0 => nil }.each do |n, want|
      want.nil? ? assert_nil(UI.leaves(poke(n)), "#{n} leaves") : assert_equal(want, UI.leaves(poke(n)), "#{n} leaves")
    end
    assert_nil UI.leaves(Poke.build), "a Pokemon with no leaves to give"
  end

  test "draws no grades, leaves or meter with its settings off, on the summary or in the PC panel" do
    pk = poke(3)
    with_ui({}) do
      assert_equal stats_page, PokeAccess::SummaryGameData.stats_text(pk), "the stats page"
      assert_equal "", PokeAccess::Summary.header_icons(pk), "the header"
      [false, true].each do |figures|
        with_figures(figures) do
          assert_equal first_page, PokeAccess::SummaryGameData.info_text(pk), "the first page, figures #{figures}"
        end
      end
      assert_equal pc_panel, PokeAccess::Party.pc_details(pk), "the PC panel"
    end
  end

  test "ends the first page with the share of the meter filled, after the leaves its header counts" do
    with_figures(false) do
      with_ui(:SUMMARY_SHINY_LEAF => true, :SUMMARY_HAPPINESS_METER => true) do
        assert_equal "#{first_page(T.t(:mui_leaves, :n => 3))} #{T.t(:mui_happiness, :n => 80)}",
                     PokeAccess::SummaryGameData.info_text(poke(3))
      end
    end
  end

  test "rounds the share of the meter and caps it at the full bar" do
    with_figures(false) do
      { 0 => 0, 1 => 0, 2 => 1, 127 => 50, 128 => 50, 204 => 80, 255 => 100, 300 => 100 }.each do |happiness, share|
        pk = poke
        pk.happiness = happiness
        assert_equal T.t(:mui_happiness, :n => share), UI.happiness(pk), "happiness #{happiness}"
      end
    end
  end

  test "on Anil's first page, says the figures its page writes beside the meter" do
    with_ui(:SUMMARY_HAPPINESS_METER => true) do
      assert_equal "#{first_page} #{T.t(:mui_happiness_value, :n => 204, :max => 255)}",
                   PokeAccess::SummaryGameData.info_text(poke)
    end
  end

  test "draws no meter for an egg or a shadow Pokemon, and says none for a happiness it cannot read" do
    egg = poke
    def egg.egg?; true; end
    shadow = poke
    def shadow.shadowPokemon?; true; end
    unread = poke
    def unread.happiness; raise "no happiness"; end
    with_figures(false) do
      { "an egg" => egg, "a shadow Pokemon" => shadow, "an unreadable happiness" => unread }.each do |what, pk|
        assert_nil UI.happiness(pk), what
      end
    end
  end

  test "says no first page it cannot read, though the meter is on" do
    pk = poke
    def pk.level; raise "no level"; end
    with_ui(:SUMMARY_HAPPINESS_METER => true) { assert_nil PokeAccess::SummaryGameData.info_text(pk) }
  end

  test "reads a legacy page as painted, a line per row, queued" do
    assert_equal [["PIKA'S LEGACY. General. Items consumed: 3. Moves learned: 7", false]], legacy([PAGE_ONE])
  end

  test "says nothing while the legacy menu paints nothing new" do
    assert_equal [["PIKA'S LEGACY. General. Items consumed: 3. Moves learned: 7", false]], legacy([PAGE_ONE, []])
  end

  test "says the next legacy page interrupting" do
    assert_equal [["PIKA'S LEGACY. General. Items consumed: 3. Moves learned: 7", false],
                  ["PIKA'S LEGACY. Battle History. Opponents defeated: 12", true]], legacy([PAGE_ONE, PAGE_TWO])
  end

  test "reads nothing painted once the legacy menu has closed" do
    legacy([PAGE_ONE])
    SpeakCapture.clear
    UI.legacy_poll
    pbDrawTextPositions(nil, PAGE_TWO)
    UI.legacy_poll
    assert_nothing_spoken
  end

  test "answers what the legacy menu answers" do
    scene = PokemonSummary_Scene.new(poke)
    scene.legacy_frames = lambda { |_s| :closed }
    assert_equal :closed, scene.pbLegacyMenu
  end

  test "says each stat's value, IV and EV on the all-stats page, then the effort total, and no nature" do
    pk = poke
    pk.ev = { :HP => 4, :ATTACK => 252, :DEFENSE => 0, :SPECIAL_ATTACK => 0, :SPECIAL_DEFENSE => 0, :SPEED => 252 }
    row = lambda { |stat, tot, iv, ev| T.t(:sm_allstats_row, :stat => stat, :tot => tot, :iv => iv, :ev => ev) }
    rows = [row.call("PS", 40, 31, 4), row.call("Ataque", 30, 30, 252), row.call("Defensa", 28, 0, 0),
            row.call("At. Esp.", 32, 27, 0), row.call("Def. Esp.", 26, 20, 0), row.call("Velocidad", 35, 5, 252),
            T.t(:sm_ev_total, :n => 508)]
    with_ui({}) { assert_equal "#{T.t(:sm_stats)}. #{rows.join('. ')}", PokeAccess::SummaryGameData.allstats_text(pk) }
  end

  private

  # Chispa with IVS (or ivs), 204 happiness and n shiny leaves (six are the crown).
  def poke(leaves = 0, ivs = IVS)
    pk = Poke.build(:name => "Chispa", :happiness => 204, :iv => ivs.dup)
    pk.define_singleton_method(:shiny_leaf) { leaves }
    pk.define_singleton_method(:shiny_crown?) { leaves == 6 }
    pk
  end

  # The stats page of such a Pokemon, its stats and ability at Poke.build's defaults (the engine names ability 1
  # "Ability1"), with the given sentences between them.
  def stats_page(*extras)
    stats = T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    (["#{T.t(:sm_stats)}. #{stats}"] + extras + [T.t(:sum_ability, :a => "Ability1")]).join(" ")
  end

  # The first page of such a Pokemon, the given header icons after its name and level, then no item, a loaned
  # trainer and an unknown ID.
  def first_page(*icons)
    ([T.t(:sum_data_of, :name => "Chispa ♂", :level => 25)] + icons.map { |i| "#{i}." } +
     [T.t(:sum_item, :i => T.t(:sum_none)), T.t(:sum_ot, :name => T.t(:sum_loaned)),
      T.t(:sum_id, :id => T.t(:pdx_unknown_short))]).join(" ")
  end

  # The PC panel of such a Pokemon, its ability and no item, with the given rows after them.
  def pc_panel(*extras)
    [[T.t(:pc_ability, :a => "Ability1"), :full], [T.t(:pc_no_item), :medium]] + extras
  end

  # The legacy menu's loop run over frames, each painting its rows (none for an empty one) before the frame's poll;
  # what it said.
  def legacy(frames)
    scene = PokemonSummary_Scene.new(poke)
    scene.legacy_frames = lambda do |_s|
      frames.each do |rows|
        pbDrawTextPositions(nil, rows) unless rows.empty?
        UI.legacy_poll
      end
    end
    SpeakCapture.clear
    scene.pbLegacyMenu
    SpeakCapture.log.dup
  end

  # Runs the block with every setting of the plugin off but those given, and the stats walkable; its value. Both put
  # back after.
  def with_ui(settings)
    all = Hash[(SUMMARY + STORAGE).map { |k| [k, false] }].merge(settings)
    saved = {}
    had_each = GameData::Stat.respond_to?(:each_main)
    GameData::Stat.define_singleton_method(:each_main) { |&b| STATS.each(&b) } unless had_each
    all.each do |k, v|
      saved[k] = ::Settings.const_defined?(k, false) ? [::Settings.const_get(k)] : nil
      ::Settings.send(:remove_const, k) if saved[k]
      ::Settings.const_set(k, v)
    end
    yield
  ensure
    all.each_key do |k|
      ::Settings.send(:remove_const, k) if ::Settings.const_defined?(k, false)
      ::Settings.const_set(k, saved[k][0]) if saved[k]
    end
    class << GameData::Stat; remove_method :each_main; end unless had_each
  end

  # Runs the block with happiness_figures? forced: the plugin's bar alone (false) or the figures beside it (true).
  def with_figures(on)
    saved = UI.method(:happiness_figures?)
    UI.define_singleton_method(:happiness_figures?) { on }
    yield
  ensure
    UI.define_singleton_method(:happiness_figures?, saved)
  end
end
