require_relative '../xenoverse_standalone'

class PokemonGenderSelectScene
  attr_reader :updates
  def pbStartScene
    @select = 0
    @updates = 0
    pbDrawTextPositions(Object.new, [['Actual painted question?', 256, 16, 2, nil]])
    :original_start
  end
  def update
    @updates += 1
    :original_update
  end
  def pbEndScene; :original_end; end
end

load File.join(Harness::ROOT, 'games/xenoverse/gender.rb')

class XenoverseGenderTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
  end

  def test_actual_question_and_initial_choice_then_changes_without_idle_repeats
    scene = PokemonGenderSelectScene.new
    assert_equal :original_start, scene.pbStartScene
    assert_equal ['Actual painted question? Boy'], SpeakCapture.lines
    assert_equal :original_update, scene.update
    assert_equal 1, scene.updates
    assert_equal 1, SpeakCapture.lines.length
    scene.instance_variable_set(:@select, 1)
    scene.update
    scene.update
    assert_equal ['Actual painted question? Boy', 'Girl'], SpeakCapture.lines
    scene.instance_variable_set(:@select, 0)
    scene.update
    assert_equal ['Actual painted question? Boy', 'Girl', 'Boy'], SpeakCapture.lines
    assert_equal :original_end, scene.pbEndScene
  end

  def test_closed_and_unopened_scenes_do_not_read_or_take_over_the_current_one
    scene = PokemonGenderSelectScene.new
    scene.pbStartScene
    SpeakCapture.clear
    other = PokemonGenderSelectScene.new
    other.instance_variable_set(:@updates, 0)
    other.instance_variable_set(:@select, 1)
    other.update
    assert_nothing_spoken
    scene.pbEndScene
    scene.instance_variable_set(:@select, 1)
    scene.update
    assert_nothing_spoken
  end

  def test_reopening_reads_the_initial_choice_again
    scene = PokemonGenderSelectScene.new
    scene.pbStartScene
    scene.pbEndScene
    SpeakCapture.clear
    scene.pbStartScene
    assert_equal ['Actual painted question? Boy'], SpeakCapture.lines
    scene.pbEndScene
  end

  def test_invalid_indices_are_silent_and_are_not_repaired_by_the_reader
    scene = PokemonGenderSelectScene.new
    scene.pbStartScene
    SpeakCapture.clear
    [-1, 2, nil].each do |index|
      scene.instance_variable_set(:@select, index)
      scene.update
      actual = scene.instance_variable_get(:@select)
      index.nil? ? assert_nil(actual) : assert_equal(index, actual)
    end
    assert_nothing_spoken
    scene.pbEndScene
  end

  def test_existing_gender_labels_work_in_all_six_mod_languages
    [:en, :pl, :es, :fr, :de, :pt].each do |language|
      PokeAccess::Config.language = language
      refute_equal 'gsel_boy', PokeAccess::I18n.t(:gsel_boy)
      refute_equal 'gsel_girl', PokeAccess::I18n.t(:gsel_girl)
      SpeakCapture.clear
      scene = PokemonGenderSelectScene.new
      scene.pbStartScene
      assert_equal ['Actual painted question? ' + PokeAccess::I18n.t(:gsel_boy)], SpeakCapture.lines
      scene.instance_variable_set(:@select, 1)
      scene.update
      assert_equal PokeAccess::I18n.t(:gsel_girl), SpeakCapture.lines.last
      scene.pbEndScene
    end
  end

  def test_choice_speech_is_filed_as_menu_and_has_no_game_switch_side_effect
    categories = []
    PokeAccess::Speech.observe(:owned_gender_category) { |message| categories.push(message.category) }
    previous = $game_switches
    previous_values = (1..50).map { |index| previous[index] }
    scene = PokemonGenderSelectScene.new
    scene.pbStartScene
    scene.instance_variable_set(:@select, 1)
    scene.update
    assert_equal [:menu, :menu], categories
    assert_same previous, $game_switches
    assert_equal previous_values, (1..50).map { |index| $game_switches[index] }
    scene.pbEndScene
  ensure
    PokeAccess::Speech.unobserve(:owned_gender_category)
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
