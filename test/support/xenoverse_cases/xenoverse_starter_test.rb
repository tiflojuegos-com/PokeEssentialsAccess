require_relative '../xenoverse_standalone'
load File.join(ENV.fetch('ESSENTIAL_PEA_SOURCE'), 'plugins/starter_selection.rb')
class PokeBattle_Pokemon; end unless Object.const_defined?(:PokeBattle_Pokemon)

class SceltaStarter
  Sprite = Struct.new(:bitmap, :visible, :opacity)
  Pokemon = Struct.new(:name, :type1, :type2)
  attr_reader :data, :select
  def initialize
    @select, @selected, @confirm = 1, false, 1
    @sprites = {}
    %w[confirm si siSel no noSel shyleonDet trishoutDet shulongDet].each do |name|
      @sprites[name] = Sprite.new(Object.new, false, 255)
    end
    @data = { 'pkmn_0' => Pokemon.new('First real species', 11, 11),
              'pkmn_1' => Pokemon.new('Middle real species', 10, 0),
              'pkmn_2' => Pokemon.new('Third real species', 9, 15) }
    %w[si siSel].each { |name| paint(name, 'Actual affirmative') }
    %w[no noSel].each { |name| paint(name, 'Actual negative') }
    gettinginput
    input_action
  end
  def paint(name, text)
    pbDrawTextPositions(@sprites[name].bitmap, [[text, 40, 6, 2, nil]])
  end
  def input_action
    show_detail
    gettinginput
    :original_action
  end
  def show_detail
    %w[shyleonDet trishoutDet shulongDet].each_with_index do |name, index|
      @sprites[name].visible = index == @select
    end
  end
  def move_to(index)
    @select = index
    show_detail
    gettinginput
  end
  def confirm_at(index)
    @selected, @confirm = true, index
    paint('confirm', 'Actual question for ' + @data["pkmn_#{@select}"].name + '?')
    gettinginput
  end
  def decline
    @selected = false
    show_detail
    gettinginput
  end
  def hide_detail
    @sprites['trishoutDet'].visible = false
    PokeAccess::Cursor.reset(self, :xenoverse_starter)
  end
  def gettinginput; :original_input; end
  def closescene; :original_close; end
end

load File.join(Harness::ROOT, 'games/xenoverse/starter.rb')

class XenoverseStarterTest < PokeAccessTest
  include PeaStandaloneMethods
  def setup
    super
    PokeAccess::Config.language = :en
    PokeAccess::Config.verbosity = :full
  end

  def test_initial_name_and_both_actual_types_then_all_three_positions_without_idle_repeats
    scene = SceltaStarter.new
    middle = 'Middle real species, ' + PokeAccess::Data.pokemon_types(scene.data['pkmn_1']).join('/')
    assert_equal [middle], SpeakCapture.lines
    assert_equal :original_input, scene.gettinginput
    assert_equal 1, SpeakCapture.lines.length
    scene.move_to(2)
    assert_spoken_once(/Third real species/)
    scene.move_to(0)
    assert_spoken_once(/First real species/)
    assert_equal 3, SpeakCapture.lines.length
    assert_equal :original_close, scene.closescene
  end

  def test_actual_question_and_negative_affirmative_choices_and_return
    scene = SceltaStarter.new
    SpeakCapture.clear
    scene.confirm_at(1)
    assert_equal ['Actual question for Middle real species? Actual negative'], SpeakCapture.lines
    scene.gettinginput
    assert_equal 1, SpeakCapture.lines.length
    scene.confirm_at(0)
    assert_equal 'Actual affirmative', SpeakCapture.lines.last
    scene.decline
    assert_match(/Middle real species/, SpeakCapture.lines.last)
    assert_equal 3, SpeakCapture.lines.length
    scene.closescene
  end

  def test_reader_never_creates_a_pokemon_or_rerolls_random_state
    scene = SceltaStarter.new
    originals = scene.data.values.dup
    srand(829)
    expected = 3.times.map { rand }
    srand(829)
    attempts = 0
    SpeakCapture.clear
    with_singleton(PokeBattle_Pokemon, :new, lambda { |*args| attempts += 1; raise 'Reader must use existing Pokemon objects' }) do
      scene.move_to(2)
      scene.move_to(0)
      scene.move_to(1)
    end
    assert_equal expected, 3.times.map { rand }
    assert_equal 0, attempts
    assert_equal 3, SpeakCapture.lines.length
    originals.each_with_index { |pokemon, index| assert_same pokemon, scene.data.values[index] }
    scene.closescene
  end

  def test_brief_reading_keeps_types_available_to_the_info_key
    PokeAccess::Config.verbosity = :brief
    captured = []
    scene = nil
    with_singleton(PokeAccess::Info, :set_info, lambda { |kind, pokemon, text| captured.push([kind, pokemon, text]) }) do
      scene = SceltaStarter.new
    end
    assert_equal ['Middle real species'], SpeakCapture.lines
    assert_same scene.data['pkmn_1'], captured.last[1]
    assert_match(/Middle real species, /, captured.last[2])
    assert_equal :pokemon, captured.last[0]
    scene.closescene
  end

  def test_hidden_detail_and_closed_scene_are_silent
    scene = SceltaStarter.new
    SpeakCapture.clear
    scene.hide_detail
    scene.gettinginput
    assert_nothing_spoken
    scene.closescene
    scene.move_to(2)
    assert_nothing_spoken
  end

  def test_invalid_selection_is_not_invented_or_repaired
    scene = SceltaStarter.new
    SpeakCapture.clear
    [3, -1, nil].each do |index|
      scene.move_to(index)
      index.nil? ? assert_nil(scene.select) : assert_equal(index, scene.select)
    end
    assert_nothing_spoken
    scene.closescene
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
