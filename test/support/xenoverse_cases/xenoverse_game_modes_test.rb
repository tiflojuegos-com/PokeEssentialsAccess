require_relative '../xenoverse_standalone'

module Kernel
  def pbDrawOutlineText(*args); :original_paint; end
  module_function :pbDrawOutlineText
end

class GameModeScreen
  Sprite = Struct.new(:bitmap)
  attr_reader :selected
  def initialize(labels = ['Actual classic label', 'Actual modern label'])
    @sprites = { 'classicinfo' => Sprite.new(Object.new), 'info' => Sprite.new(Object.new) }
    @selected = 0
    labels.each_with_index do |label, index|
      pbDrawOutlineText(@sprites['classicinfo'].bitmap, 0, index * 78, 200, 40, label)
    end
    drawInfo(0)
  end
  def drawInfo(index = 0)
    @selected = index
    # Paint out of order, just as a layout reader should tolerate.
    pbDrawOutlineText(@sprites['info'].bitmap, 20, 76, 200, 28, 'second row')
    pbDrawOutlineText(@sprites['info'].bitmap, 20, 48, 200, 28, index == 0 ? 'Classic description' : 'Modern description')
    :original_info
  end
  def unrelated_paint
    pbDrawOutlineText(Object.new, 0, 0, 200, 40, 'Unrelated bitmap')
  end
  def endscene; :original_end; end
end

ORIGINAL_OUTLINE_RESULT = Object.new.send(:pbDrawOutlineText, Object.new, 0, 0, 200, 40, 'Unrelated bitmap')
load File.join(Harness::ROOT, 'games/xenoverse/game_modes.rb')

class XenoverseGameModesTest < PokeAccessTest
  def test_initial_option_and_actual_description_in_reading_order
    scene = GameModeScreen.new
    assert_equal ['Actual classic label. Classic description second row'], SpeakCapture.lines
    assert_equal 0, scene.selected
    assert_equal :original_end, scene.endscene
  end

  def test_changes_return_and_repeat_have_normal_cursor_semantics
    scene = GameModeScreen.new
    SpeakCapture.clear
    assert_equal :original_info, scene.drawInfo(1)
    scene.drawInfo(1)
    assert_equal ['Actual modern label. Modern description second row'], SpeakCapture.lines
    scene.drawInfo(0)
    assert_equal ['Actual modern label. Modern description second row', 'Actual classic label. Classic description second row'], SpeakCapture.lines
    assert_equal 0, scene.selected
    scene.endscene
  end

  def test_reads_painted_localization_without_own_mode_names
    scene = GameModeScreen.new(['First localized option', 'Second localized option'])
    assert_equal ['First localized option. Classic description second row'], SpeakCapture.lines
    scene.drawInfo(1)
    assert_equal 'Second localized option. Modern description second row', SpeakCapture.lines.last
    scene.endscene
  end

  def test_unrelated_paint_and_closed_scene_are_silent
    scene = GameModeScreen.new
    SpeakCapture.clear
    assert_equal ORIGINAL_OUTLINE_RESULT, scene.unrelated_paint
    scene.endscene
    scene.drawInfo(1)
    assert_nothing_spoken
  end

  def test_reopening_reads_initial_option_again_without_changing_difficulty
    $difficulty = :unchanged_by_reader
    scene = GameModeScreen.new
    scene.endscene
    SpeakCapture.clear
    reopened = GameModeScreen.new
    assert_equal ['Actual classic label. Classic description second row'], SpeakCapture.lines
    assert_equal :unchanged_by_reader, $difficulty
    reopened.endscene
  end

  def test_invalid_index_does_not_invent_a_selection
    scene = GameModeScreen.new
    SpeakCapture.clear
    scene.drawInfo(-1)
    scene.drawInfo(2)
    assert_nothing_spoken
    assert_equal 2, scene.selected
    scene.endscene
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
