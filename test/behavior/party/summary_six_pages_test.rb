# The six-page summary Insurgence and Sevii share (plugins/summary_six_pages.rb): the core's page 4 is read as its EV &
# IV page, each stat in the page's own order, the nature its labels' tint shows and the ability with its description,
# and page 5 as its moves, only on a summary that draws a sixth page. Its ribbons page is tested with the Insurgence
# profile, in insurgence_profile_test.
class SummarySixPagesTest < PokeAccessTest
  T = PokeAccess::I18n
  Move = Struct.new(:id, :pp, :totalpp)

  # A six-page summary scene, as the plugin's probe finds it.
  class SixPageScene
    def drawPageSix(_pk = nil); end
  end

  test "says the EV & IV page's title, then each stat's EV and IV by the index its row paints, speed last" do
    assert_equal trained_page, PokeAccess::SummarySixPages.eviv_text(trained)
  end

  test "after the rows says the stats the nature tints and the ability with the description painted under it" do
    pk = Poke.build(:ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26], :nature => 3, :ability => 65)
    nature = T.t(:sm_nature_effect, :up => "Estadistica1", :down => "Estadistica4")
    ability = T.t(:sum_ability_desc, :a => "Habilidad65", :d => "msg65")
    said = with_ability_descriptions { PokeAccess::SummarySixPages.eviv_text(pk) }
    assert_equal "#{eviv_page} #{nature} #{ability}", said
  end

  test "a neutral nature, which tints no stat, and a Shadow Pokemon past heart stage 3 say no nature" do
    shadow = Poke.build(:nature => 3)
    [:shadowPokemon?, :isShadow?].each { |m| shadow.define_singleton_method(m) { true } }
    shadow.define_singleton_method(:heartStage) { 4 }
    [Poke.build(:nature => 6), shadow].each do |pk|
      assert_equal "#{eviv_rows_of(pk)} #{T.t(:sum_ability, :a => 'Habilidad1')}", PokeAccess::SummarySixPages.eviv_text(pk)
    end
  end

  test "gives no EV & IV page for a Pokemon it cannot read" do
    assert_nil PokeAccess::SummarySixPages.eviv_text(nil)
  end

  test "reads the core's page four as the EV & IV page" do
    args = [SixPageScene.new, trained, 4, "moves as the stock page four"]
    PokeAccess::SummarySixPages.repage(args)
    assert_equal trained_page, args[3]
  end

  test "reads the core's page five as the moves page" do
    args = [SixPageScene.new, trained, 5, "ribbons as the stock page five"]
    PokeAccess::SummarySixPages.repage(args)
    assert_equal moves_page, args[3]
  end

  test "reads page five as a moves page that says none when every slot is empty, as nil or as move 0" do
    args = [SixPageScene.new, Poke.build(:moves => [nil, Move.new(0, 0, 0)]), 5, "ribbons as the stock page five"]
    PokeAccess::SummarySixPages.repage(args)
    assert_equal T.t(:sm_no_moves), args[3]
  end

  test "leaves every other page as the core read it" do
    [1, 2, 3, 6, :egg].each do |page|
      args = [SixPageScene.new, trained, page, "as the core read it"]
      PokeAccess::SummarySixPages.repage(args)
      assert_equal "as the core read it", args[3], "page #{page}"
    end
  end

  test "leaves the pages of a summary with no sixth page as the core read them" do
    [4, 5].each do |page|
      args = [PokemonSummaryScene.new, trained, page, "as the core read it"]
      PokeAccess::SummarySixPages.repage(args)
      assert_equal "as the core read it", args[3], "page #{page}"
    end
  end

  test "the stock summary's page four is still its moves page with the plugin loaded" do
    pk = trained
    scene = PokemonSummaryScene.new
    scene.pbStartScene([pk], 0)
    SpeakCapture.clear
    scene.drawPage(4)
    assert_equal [[PokeAccess::Summary.moves_text(pk), true]], SpeakCapture.log
  end

  private

  # A Pokemon with a different EV and IV on each stat, by gen-6's index (speed is 3), knowing moves 33 and 85.
  def trained
    Poke.build(:ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26],
               :moves => [Move.new(33, 35, 35), Move.new(85, 15, 15)])
  end

  # The EV & IV page of trained up to its rows: the title, then the rows in the page's order.
  def eviv_page
    rows = [[:st_hp, 4, 31], [:st_atk, 252, 30], [:st_def, 0, 29], [:st_spatk, 0, 27], [:st_spdef, 248, 26], [:st_speed, 6, 28]]
    "#{T.t(:sm_eviv)}. " + rows.map { |key, ev, iv| T.t(:sm_eviv_row, :stat => T.t(key), :ev => ev, :iv => iv) }.join(". ") + "."
  end

  # The whole EV & IV page of trained: its rows, then its ability, with no description in the stub's data; its neutral
  # nature tints no stat.
  def trained_page
    "#{eviv_page} #{T.t(:sum_ability, :a => 'Habilidad1')}"
  end

  # The EV & IV page of a Pokemon built with no EVs nor IVs given, up to its rows.
  def eviv_rows_of(pk)
    "#{T.t(:sm_eviv)}. #{PokeAccess::Summary.eviv_rows(pk).join('. ')}."
  end

  # Runs the block with the ability description table the gen-6 data reads, which the engine stub lacks.
  def with_ability_descriptions
    had = MessageTypes.const_defined?(:AbilityDescs)
    MessageTypes.const_set(:AbilityDescs, 7) unless had
    yield
  ensure
    MessageTypes.send(:remove_const, :AbilityDescs) unless had
  end

  # The moves page of trained: each move and its type as the engine names them ("Mov<id>", "Tipo<n>"), and its PP.
  def moves_page
    T.t(:sm_moves, :list => "Mov33. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}, " \
                            "Mov85. #{T.t(:mv_type, :t => 'Tipo2')}. #{T.t(:mv_pp, :pp => 15, :tot => 15)}")
  end
end
