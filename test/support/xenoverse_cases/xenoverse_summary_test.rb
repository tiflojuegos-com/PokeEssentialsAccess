require_relative '../xenoverse_standalone'
def drawTextExH(bitmap, x, y, width, lines, text, base, shadow, height)
  :original_paragraph
end
load File.join(Harness::ROOT, 'games/xenoverse/summary.rb')

# Drive the real shared hooks with the rows NewSummary paints, not the stock
# harness's memo-page layout. Each publication still passes through core.
PokeAccess::Hooks.before_hook('PokemonSummaryScene', :drawPageTwo) do |scene, _args|
  pbDrawTextPositions(nil, [['Actual stats', 260, 80, 0, nil]])
  paragraph = PokeAccess.ivar(scene, :@xenoverse_ability)
  drawTextExH(nil, 263, 291, 231, 2, paragraph, nil, nil, 18) if paragraph
end
PokeAccess::Hooks.before_hook('PokemonSummaryScene', :drawPageFour) do |scene, _args|
  rows = PokeAccess.ivar(scene, :@xenoverse_memo)
  pbDrawTextPositions(nil, rows) if rows
  paragraph = PokeAccess.ivar(scene, :@xenoverse_paragraph)
  drawTextExH(nil, 270, 206, 223, 3, paragraph, nil, nil, 24) if paragraph
end

class XenoverseSummaryTest < PokeAccessTest
  include PeaStandaloneMethods
  def setup
    super
    PokeAccess::Config.language = :en
    moves = [Struct.new(:id, :pp, :totalpp).new(1, 12, 15), Struct.new(:id, :pp, :totalpp).new(2, 20, 25)]
    @pokemon = Poke.build(:name => 'Actual partner', :ev => [1, 2, 3, 4, 5, 6], :iv => [7, 8, 9, 10, 11, 12], :moves => moves)
    @scene = PokemonSummaryScene.new(@pokemon)
  end

  def test_stats_moves_and_painted_memo_follow_the_real_game_order
    @scene.drawPageTwo(@pokemon)
    assert_match(/^#{Regexp.escape(PokeAccess::I18n.t(:sm_stats))}\./, SpeakCapture.lines.last)
    assert_includes SpeakCapture.lines.last, 'HP: EV 1, IV 7'
    assert_includes SpeakCapture.lines.last, 'Special Attack: EV 5, IV 11'
    assert_includes SpeakCapture.lines.last, 'Speed: EV 4, IV 10'
    @scene.drawPageThree(@pokemon)
    assert_match(/^Moves:/, SpeakCapture.lines.last)
    assert_includes SpeakCapture.lines.last, '12 of 15'
    @scene.instance_variable_set(:@xenoverse_memo, [['Actual nature', 270, 85, 0, nil],
      ['Actual date', 270, 107, 0, nil], ['Actual obtained place', 270, 129, 0, nil]])
    @scene.drawPageFour(@pokemon)
    assert_equal 'Trainer Memo. Actual nature. Actual date. Actual obtained place.', SpeakCapture.lines.last
    assert_equal [false, true, true], SpeakCapture.log.map { |row| row[1] }
    assert_equal :pokemon, PokeAccess::Info.instance_variable_get(:@kind)
    refute PokeAccess::PaintCapture.armed?(:xenoverse_summary_memo)
  end

  def test_redraw_is_silent_and_revisiting_reads_again
    @scene.drawPageTwo(@pokemon)
    SpeakCapture.clear
    @scene.drawPageTwo(@pokemon)
    assert_nothing_spoken
    @scene.drawPageThree(@pokemon)
    @scene.drawPageTwo(@pokemon)
    assert_equal 2, SpeakCapture.lines.length
  end

  def test_memo_without_paint_uses_real_pokemon_data
    @scene.drawPageFour(@pokemon)
    assert_match(/^#{Regexp.escape(PokeAccess::I18n.t(:sm_memo))}\./, SpeakCapture.lines.last)
    refute_spoken(/\AMoves:/)
  end

  def test_custom_paragraph_is_read_in_screen_order_without_leaking_to_other_screens
    @scene.instance_variable_set(:@xenoverse_memo, [['Actual nature', 270, 85, 0, nil]])
    @scene.instance_variable_set(:@xenoverse_paragraph, "Actual hatch date\nActual hatch place\nActual characteristic.")
    @scene.drawPageFour(@pokemon)
    assert_equal 'Trainer Memo. Actual nature. Actual hatch date. Actual hatch place. Actual characteristic.', SpeakCapture.lines.last
    SpeakCapture.clear
    assert_equal :original_paragraph, drawTextExH(nil, 0, 0, 20, 1, 'Unrelated paragraph', nil, nil, 24)
    assert_nothing_spoken
    @scene.instance_variable_set(:@xenoverse_memo, nil)
    @scene.instance_variable_set(:@xenoverse_paragraph, nil)
    @scene.drawPageFour(@pokemon)
    refute_includes SpeakCapture.lines.last, 'Unrelated paragraph'
  end

  def test_ability_description_is_taken_from_the_custom_paragraph_renderer
    description = 'Actual ability description painted by the custom renderer.'
    with_singleton(PokeAccess::Data, :ability_description, lambda { |_id| description }) do
      @scene.instance_variable_set(:@xenoverse_ability, description)
      @scene.drawPageTwo(@pokemon)
      assert_includes SpeakCapture.lines.last, description
      @scene.instance_variable_set(:@xenoverse_ability, nil)
      @scene.drawPageTwo(@pokemon)
      refute_includes SpeakCapture.lines.last, description
    end
  end

  def test_move_details_and_first_data_page_keep_the_shared_readers
    @scene.drawPageOne(@pokemon)
    assert_equal 1, SpeakCapture.lines.length
    @scene.drawSelectedMove(@pokemon, 0, @pokemon.moves.first.id)
    assert_equal 2, SpeakCapture.lines.length
    assert_equal :move, PokeAccess::Info.instance_variable_get(:@kind)
  end

  def test_an_unrelated_scene_and_egg_page_keep_the_original_publication
    scene = Object.new
    PokeAccess::Summary.speak_page(scene, @pokemon, 2, 'Actual unrelated screen')
    assert_equal ['Actual unrelated screen'], SpeakCapture.lines
    SpeakCapture.clear
    PokeAccess::Summary.speak_page(@scene, @pokemon, :egg, 'Actual egg text', true)
    assert_equal ['Actual egg text'], SpeakCapture.lines
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
