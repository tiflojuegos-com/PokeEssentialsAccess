# Essentials BES's summary (plugins/bes_summary.rb, PokemonSummaryScene with drawPageInfo, drawPageData, drawPageStats,
# drawPageMoves and drawPageRibbons): each page is read as the gen-6 summary's, with the Gigantamax mark and the Tera
# type on page one, the Dynamax level and the friendship on the memo, the EVs and IVs on the stats, and the expanded
# view of the stats page said as it opens.

# The scene as BES draws it, each page cut down to the paint a test gives it; the stub scene the harness loads has the
# stock gen-6 pages, so these are added to it.
class PokemonSummaryScene
  def drawPageInfo; pbDrawTextPositions(nil, @info_paint) if @info_paint; end
  def drawPageData; drawFormattedTextEx(nil, 232, 78, 268, @memo_paint) if @memo_paint; end
  def drawPageStats; pbDrawTextPositions(nil, @stats_paint) if @stats_paint; end
  def drawPageMoves; end
  def drawPageRibbons; end

  def drawPageStatsExpanded
    drawPageStats
    @expanded_ran = true
  end
end

# The plugin's hooks, which the harness's own load of the file left unbound as the scene lacked these pages.
BES_SUMMARY_HOOKS = Harness.source(File.join(Harness::ROOT, "plugins", "bes_summary.rb"))
                           .scan(/^PokeAccess::Hooks\.\w+_hook\("PokemonSummaryScene".*?^end\n/m)
BES_SUMMARY_HOOKS.each { |hook| eval(hook, TOPLEVEL_BINDING, "plugins/bes_summary.rb") }

class BesSummaryTest < PokeAccessTest
  T = PokeAccess::I18n
  Move = Struct.new(:id, :pp, :totalpp)
  HINT = "Presiona C para más información."
  INFO_PAINT = [["N° Dex", 238, 80, 0], ["025", 435, 80, 2], ["Especie", 238, 112, 0], ["N° ID", 238, 208, 0],
                ["54321", 435, 208, 2]].freeze
  MEMO_PAINT = "<c3=404040,B0B0B0>Naturaleza <c3=F83820,E09890>Modesta<c3=404040,B0B0B0>\n12 mar, 2026\n"
  GAME_CONSTANTS = [:EXPANDED_SUMMARY_INFO, :NO_TERA_CRISTAL]

  def setup
    super
    set_game_constants(true)
  end

  def teardown
    GAME_CONSTANTS.each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    super
  end

  test "the plugin hooks the five pages and the expanded view" do
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    keys = %w[drawPageInfo drawPageData drawPageStats drawPageStatsExpanded drawPageMoves drawPageRibbons]
    assert_equal [true] * 6, keys.map { |m| chains.key?("PokemonSummaryScene##{m}") }
  end

  test "page one reads the data sheet with the dex number and the ID it painted, queued as the summary opens" do
    pk = Poke.build(:name => "Bulba")
    page_one(scene(pk, :@info_paint => INFO_PAINT))
    assert_equal [[PokeAccess::Info.summary_text(pk, "025", "54321"), false]], SpeakCapture.log
  end

  test "page one adds the Gigantamax mark the header draws and the Tera type beside the types" do
    pk = tera_poke(10)
    pk.define_singleton_method(:gmaxFactor?) { true }
    with_gimmicks(:pbHasTeraOrb => lambda { true }) { page_one(scene(pk, :@info_paint => INFO_PAINT)) }
    sheet = PokeAccess::Info.summary_text(pk, "025", "54321")
    assert_equal [["#{sheet} #{T.t(:dmax_factor)} #{T.t(:ss2_adv_tera, :t => 'Tipo10')}", false]], SpeakCapture.log
  end

  test "page one says no Tera type without the Tera Orb, for Ogerpon and Terapagos, or once the game's switch is on" do
    cases = { "no orb" => [1, lambda { false }, false], "terapagos" => [1024, lambda { true }, false],
              "ogerpon" => [1023, lambda { true }, false], "switch on" => [1, lambda { true }, true] }
    cases.each do |what, (species, orb, switch)|
      SpeakCapture.clear
      $game_switches[90] = switch
      pk = tera_poke(10, species)
      consts = lambda { |_mod, sym| { :OGERPON => 1023, :TERAPAGOS => 1024 }[sym] }
      GameFunctions.with(:pbHasTeraOrb => orb, :getConst => consts) { page_one(scene(pk, :@info_paint => INFO_PAINT)) }
      assert_equal [[PokeAccess::Info.summary_text(pk, "025", "54321"), false]], SpeakCapture.log, what
    end
  end

  test "page one says no Gigantamax mark for a Pokemon the game does not give one" do
    pk = Poke.build(:name => "Bulba")
    pk.define_singleton_method(:gmaxFactor?) { false }
    page_one(scene(pk, :@info_paint => INFO_PAINT))
    assert_equal [[PokeAccess::Info.summary_text(pk, "025", "54321"), false]], SpeakCapture.log
  end

  test "the memo page reads the paragraph painted, then the Dynamax level and the friendship its pictures show" do
    pk = Poke.build(:name => "Nox", :happiness => 120)
    pk.define_singleton_method(:dynamax) { 1 }
    pk.define_singleton_method(:dynamax_lvl) { 4 }
    with_gimmicks(:pbHasDBand => lambda { true }) { scene(pk, :@memo_paint => MEMO_PAINT).drawPageData }
    memo = "#{T.t(:sm_memo)}. Naturaleza Modesta. 12 mar, 2026."
    want = "#{memo} #{T.t(:dmax_level, :n => 4)} #{T.t(:mui_happiness_value, :n => 120, :max => 255)}"
    assert_equal [[want, false]], SpeakCapture.log
  end

  test "the memo page says no Dynamax level without the Dynamax Band, nor for a Pokemon that cannot" do
    able = Poke.build(:name => "Nox", :happiness => 120)
    able.define_singleton_method(:dynamax_lvl) { 4 }
    scene(able, :@memo_paint => MEMO_PAINT).drawPageData
    pk = Poke.build(:name => "Nox", :happiness => 120)
    pk.define_singleton_method(:dynamax) { 1 }
    pk.define_singleton_method(:dynamax_lvl) { 4 }
    with_gimmicks(:pbHasDBand => lambda { false }) { scene(pk, :@memo_paint => MEMO_PAINT).drawPageData }
    plain = "#{T.t(:sm_memo)}. Naturaleza Modesta. 12 mar, 2026. #{T.t(:mui_happiness_value, :n => 120, :max => 255)}"
    assert_equal [[plain, false], [plain, false]], SpeakCapture.log
  end

  test "the memo page says no friendship where the game paints no bar" do
    set_game_constants(false)
    scene(Poke.build(:name => "Nox"), :@memo_paint => MEMO_PAINT).drawPageData
    assert_equal [["#{T.t(:sm_memo)}. Naturaleza Modesta. 12 mar, 2026.", false]], SpeakCapture.log
  end

  test "the memo page with nothing painted is composed from the Pokemon, with its friendship" do
    pk = Poke.build(:name => "Nox", :happiness => 70)
    scene(pk).drawPageData
    memo = "#{T.t(:sm_memo)}. #{T.t(:sm_nature, :n => 'Naturaleza0')}. #{T.t(:sm_char_1)}."
    assert_equal [["#{memo} #{T.t(:mui_happiness_value, :n => 70, :max => 255)}", false]], SpeakCapture.log
  end

  test "the stats page reads the stats, their EVs and IVs, the ability and the key hint it paints" do
    pk = Poke.build(:name => "Nox", :ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26])
    scene(pk, :@stats_paint => [["Habilidad", 224, 284, 0]]).drawPageStats
    stats = T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    profile = PokeAccess::SummaryGen6.stats_extras(pk).join(" ")
    want = ["#{T.t(:sm_stats)}. #{stats}", profile, eviv(pk), T.t(:sum_ability, :a => 'Habilidad1')].reject { |s| s.empty? }.join(" ")
    assert_equal [[want, false]], SpeakCapture.log
  end

  test "the stats page says the key hint it paints while hints are said" do
    pk = Poke.build(:name => "Nox")
    scene(pk, :@stats_paint => [[HINT, 224, 316, 0]]).drawPageStats
    assert_match(/#{Regexp.escape(HINT)}\z/, SpeakCapture.lines.last)
  end

  test "the stats page says no EVs and IVs where the game paints no columns" do
    set_game_constants(false)
    scene(Poke.build(:name => "Nox")).drawPageStats
    refute_spoken(/#{Regexp.escape(T.t(:sm_eviv))}/)
  end

  test "the expanded view says the ability with its description and the Hidden Power type as it opens, once the stats were read" do
    pk = Poke.build(:name => "Nox", :ability => 65)
    s = scene(pk, :@stats_paint => [["Habilidad", 224, 284, 0]])
    with_ability_descriptions do
      s.drawPageStats
      SpeakCapture.clear
      s.drawPageStatsExpanded
    end
    detail = "#{T.t(:sum_ability_desc, :a => 'Habilidad65', :d => 'msg65')}. #{T.t(:sm_hidden_power, :t => 'Tipo0')}"
    assert_equal [[detail, true]], SpeakCapture.log
    assert s.instance_variable_get(:@expanded_ran), "the view ran"
  end

  test "closing the expanded view reads the stats page again" do
    pk = Poke.build(:name => "Nox")
    s = scene(pk, :@stats_paint => [["Habilidad", 224, 284, 0]])
    s.drawPageStats
    s.drawPageStatsExpanded
    SpeakCapture.clear
    s.drawPageStats
    assert_equal 1, SpeakCapture.log.length
    assert_match(/\A#{Regexp.escape(T.t(:sm_stats))}/, SpeakCapture.lines.first)
  end

  test "the moves page reads each move with its type and PP" do
    pk = Poke.build(:name => "Nox", :moves => [Move.new(33, 35, 35), Move.new(85, 15, 15)])
    scene(pk).drawPageMoves
    assert_equal [[PokeAccess::Summary.moves_text(pk), false]], SpeakCapture.log
    assert_match(/Mov33/, SpeakCapture.lines.first)
  end

  test "the ribbons page reads how many ribbons the Pokemon has" do
    pk = Poke.build(:name => "Nox", :ribbons => [1, 2, 3])
    scene(pk).drawPageRibbons
    assert_equal [[PokeAccess::SummaryGen6.ribbons_text(pk), false]], SpeakCapture.log
    assert_match(/#{Regexp.escape(T.t(:sm_ribbons, :n => 3))}/, SpeakCapture.lines.first)
  end

  test "turning through the five pages of one summary says each of them, the first queued and each turn cutting in" do
    pk = Poke.build(:name => "Nox", :moves => [Move.new(33, 35, 35)], :ribbons => [1])
    s = scene(pk, :@info_paint => INFO_PAINT)
    PokeAccess::PaintCapture.arm(:summary_egg)
    s.drawPageInfo
    [:drawPageData, :drawPageStats, :drawPageMoves, :drawPageRibbons].each { |page| s.send(page) }
    assert_equal 5, SpeakCapture.log.length
    assert_equal [false, true, true, true, true], SpeakCapture.log.map { |_, interrupt| interrupt }
  end

  test "a game that declares no switch against Terastallization says the Tera type" do
    Object.send(:remove_const, :NO_TERA_CRISTAL)
    with_gimmicks(:pbHasTeraOrb => lambda { true }) { page_one(scene(tera_poke(10), :@info_paint => INFO_PAINT)) }
    assert_includes SpeakCapture.lines.first, T.t(:ss2_adv_tera, :t => "Tipo10")
  end

  test "a page read again on the same Pokemon is not said twice" do
    pk = Poke.build(:name => "Nox", :moves => [Move.new(33, 35, 35)])
    s = scene(pk)
    s.drawPageMoves
    s.drawPageMoves
    assert_equal 1, SpeakCapture.log.length
  end

  test "another Pokemon's page is led by whose it is" do
    s = scene(Poke.build(:name => "Nox", :moves => [Move.new(33, 35, 35)]))
    s.drawPageMoves
    other = Poke.build(:name => "Bulba", :moves => [Move.new(33, 35, 35)])
    s.pokemon = other
    s.drawPageMoves
    assert_equal "#{PokeAccess::Summary.whose(other)}. #{PokeAccess::Summary.moves_text(other)}", SpeakCapture.lines.last
  end

  test "a box panel adds the Tera type its picture shows, under the conditions page one has" do
    pk = tera_poke(10)
    tera = T.t(:ss2_adv_tera, :t => "Tipo10")
    with_gimmicks(:pbHasTeraOrb => lambda { true }) { assert_includes PokeAccess::Party.pc_details(pk), tera }
    with_gimmicks(:pbHasTeraOrb => lambda { false }) { refute_includes PokeAccess::Party.pc_details(pk), tera }
  end

  test "a box panel of a Pokemon with no Tera type adds nothing" do
    pk = Poke.build(:name => "Bulba")
    with_gimmicks(:pbHasTeraOrb => lambda { true }) do
      refute_match(/teratipo/, PokeAccess::Party.pc_details(pk).flatten.join(" "))
    end
  end

  test "a party row says the pokerus its panel draws in the state slot, in a BES game only" do
    pk = Poke.build(:name => "Bulba")
    pk.define_singleton_method(:pokerusStage) { 1 }
    row = lambda { PokeAccess::Verbosity.whole { PokeAccess::Party.member_line(pk, :pokerus_slot => PokeAccess::Party.panel_pokerus?) } }
    assert_includes row.call, T.t(:pk_pokerus)
    Object.send(:remove_const, :EXPANDED_SUMMARY_INFO)
    refute_includes row.call, T.t(:pk_pokerus)
  end

  private

  def set_game_constants(expanded)
    GAME_CONSTANTS.each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
    Object.const_set(:EXPANDED_SUMMARY_INFO, expanded)
    Object.const_set(:NO_TERA_CRISTAL, 90)
  end

  def page_one(scene)
    PokeAccess::PaintCapture.arm(:summary_egg)
    scene.drawPageInfo
  end

  def scene(pk, ivars = {})
    s = PokemonSummaryScene.new(pk)
    ivars.each { |name, value| s.instance_variable_set(name, value) }
    s
  end

  def tera_poke(type, species = 1)
    pk = Poke.build(:name => "Bulba", :species => species)
    pk.define_singleton_method(:teratype) { type }
    pk
  end

  def eviv(pk)
    "#{T.t(:sm_eviv)}. #{PokeAccess::Summary.eviv_rows(pk).join('. ')}."
  end

  def with_gimmicks(map, &block)
    GameFunctions.with(map, &block)
  end

  def with_ability_descriptions
    had = MessageTypes.const_defined?(:AbilityDescs)
    MessageTypes.const_set(:AbilityDescs, 7) unless had
    yield
  ensure
    MessageTypes.send(:remove_const, :AbilityDescs) unless had
  end
end
