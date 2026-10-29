# The BW Summary Screen's pictures on the stats page (plugins/bw_summary.rb), as Dark Horizon draws them through the
# Level Based Mixed EV System's copies of the two methods: a letter grade per stat for its IVs and a bar of six steps
# per stat for its EVs, orange once the total is at its limit. Each is said after the stats of the page drawn.

# The two rating draws on the summary stand-in: each paints its pictures in one pbDrawImagePositions batch, at the
# stats' rows (y 82 to 260), in whatever order the test hands them.
class PokemonSummary_Scene
  attr_accessor :bw_grades, :bw_bars

  def pbDisplayIVRating
    pbDrawImagePositions(nil, @bw_grades || [])
    :grades
  end

  def pbDisplayEVRating
    pbDrawImagePositions(nil, @bw_bars || [])
    :bars
  end
end

summary_src = Harness.source(File.join(Harness::ROOT, "plugins", "bw_summary.rb"))
summary_from = summary_src.index("[[:pbDisplayIVRating")
summary_to = summary_src.index("PokeAccess::Hooks.override(PokeAccess::SummaryGameData")
eval(summary_src[summary_from...summary_to], TOPLEVEL_BINDING, "plugins/bw_summary.rb",
     summary_src[0, summary_from].count("\n") + 1)

class BwSummaryGdTest < PokeAccessTest
  T = PokeAccess::I18n
  DIR = "Graphics/Pictures/Summary/"
  ROWS = [82, 132, 164, 196, 228, 260].freeze
  STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze

  test "the stats page says each stat's IV grade and EV bar after its stats, in the rows' order however painted" do
    scene = stats_page(Poke.build(:name => "Sombra"), grades(%w[S A B C D F]).reverse, bars(%w[6_max 0 01 3 0 5]))
    scene.drawPage(3)
    want = [grade_line(%w[S A B C D F]), bar_line([6, 0, :low, 3, 0, 5])].join(" ")
    assert_spoken_once(/\A#{Regexp.escape(T.t(:sm_stats))}\. .*#{Regexp.escape(want)}/)
  end

  test "an orange bar short of full says the EV total is at its limit, a full one alone does not" do
    { "full and limit bars" => [%w[6_max 0 01_max 3_max 0 5_max], true],
      "a full bar alone" => [%w[6_max 0 0 0 0 0], false] }.each do |what, (shown, limit)|
      SpeakCapture.clear
      pk = Poke.build
      stats_page(pk, [], bars(shown)).pbDisplayEVRating
      line = PokeAccess::BWSummary.extras(pk).last.to_s
      assert_equal limit, line.end_with?(T.t(:bw_ev_limit)), what
    end
  end

  test "a page drawn with the grades alone says no bars, even after a draw that left bars unsaid" do
    pk = Poke.build
    scene = stats_page(pk, grades(%w[A A A A A A]), bars(%w[1 1 1 1 1 1]))
    scene.pbDisplayEVRating
    scene.bw_bars = []
    scene.on_draw = lambda { |_page| scene.pbDisplayIVRating }
    scene.drawPage(3)
    assert_spoken_once(/#{Regexp.escape(grade_line(%w[A A A A A A]))}/)
    refute_spoken(/#{Regexp.escape(bar_line([1, 1, 1, 1, 1, 1]))}/)
  end

  test "pictures drawn for one Pokemon are not said on another's page" do
    scene = stats_page(Poke.build, grades(%w[S S S S S S]), [])
    scene.pbDisplayIVRating
    assert_equal [], PokeAccess::BWSummary.extras(Poke.build)
  end

  test "a draw short of one picture per stat says nothing of that kind" do
    pk = Poke.build
    stats_page(pk, grades(%w[S A B C D F])[0, 5], []).pbDisplayIVRating
    assert_equal [], PokeAccess::BWSummary.extras(pk)
  end

  test "each draw is said once, and a stats page with no draw adds nothing" do
    pk = Poke.build
    stats_page(pk, grades(%w[B B B B B B]), []).pbDisplayIVRating
    first = PokeAccess::BWSummary.extras(pk)
    assert_equal [[grade_line(%w[B B B B B B])], []], [first, PokeAccess::BWSummary.extras(pk)]
  end

  test "the draws hand back what the game's own methods answer" do
    scene = stats_page(Poke.build, grades(%w[S S S S S S]), bars(%w[0 0 0 0 0 0]))
    assert_equal [:grades, :bars], [scene.pbDisplayIVRating, scene.pbDisplayEVRating]
  end

  private

  # A summary on the stats page for pk, whose page three draws the grades, then the bars.
  def stats_page(pk, grade_rows, bar_rows)
    scene = PokemonSummary_Scene.new(pk)
    scene.bw_grades = grade_rows
    scene.bw_bars = bar_rows
    scene.on_draw = lambda do |page|
      next unless page == 3
      scene.pbDisplayIVRating
      scene.pbDisplayEVRating
    end
    scene
  end

  # The grade pictures for the six rows, top to bottom.
  def grades(letters)
    letters.each_with_index.map { |l, i| ["#{DIR}Rating#{l}", 288, ROWS[i], 0, 0, -1, -1] }
  end

  # The EV bar pictures for the six rows, top to bottom, by their file's step ("01", "3_max"...).
  def bars(steps)
    steps.each_with_index.map { |s, i| ["#{DIR}EVbar#{s}", 232, ROWS[i], 0, 0, -1, -1] }
  end

  # The grades sentence for the six stats.
  def grade_line(letters)
    T.t(:mui_iv_ratings, :list => STATS.each_with_index.map { |s, i| "#{stat_label(s)} #{letters[i]}" }.join(", "))
  end

  # The bars sentence for the six stats: a number of steps, or :low for a sliver.
  def bar_line(steps)
    list = STATS.each_with_index.map do |s, i|
      steps[i] == :low ? T.t(:bw_ev_bar_low, :stat => stat_label(s)) : T.t(:bw_ev_bar, :stat => stat_label(s), :n => steps[i])
    end
    T.t(:bw_ev_bars, :list => list.join(", "))
  end

  # A stat's name as the data gives it.
  def stat_label(stat)
    PokeAccess::Data.stat_name(stat)
  end
end
