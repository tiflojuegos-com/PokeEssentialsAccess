require_relative '../xenoverse_standalone'

# Preserve the actual constructor's blocking-loop entry and repeated outer loop.
class Fullbox_Choice
  Option = Struct.new(:text, :color, :callback)
  attr_reader :original_options, :default, :cursor, :selected, :disposed
  def initialize(options, default = 0)
    @original_options, @default = options, default
    @cursor, @options = 0, options.map { |option| Object.new }
    self.loop
  end
  def loop; :original_loop; end
  def setSelection(value)
    return if value == @cursor
    @cursor = value
    @cursor = 0 if @cursor >= @options.length
    @cursor = @options.length - 1 if @cursor < 0
    :original_selection
  end
  def select(option = @cursor)
    @selected = option
    setSelection(0)
    option
  end
  def dispose; @disposed = true; :original_dispose; end
end

load File.join(Harness::ROOT, 'games/xenoverse/fullbox.rb')

class XenoverseFullboxChoiceTest < PokeAccessTest
  def options(*labels)
    labels.map { |label| Fullbox_Choice::Option.new(label, :untouched_color, :untouched_callback) }
  end
  def setup
    super
    @scene = nil
  end
  def teardown
    @scene.dispose if @scene
    super
  end
  def open(*labels)
    @scene = Fullbox_Choice.new(options(*labels), 2)
  end

  def test_opening_is_read_before_blocking_loop_without_choosing_or_mutating_options
    rows = options('Resolved Yes', 'Resolved No')
    @scene = Fullbox_Choice.new(rows, 2)
    assert_equal ['Resolved Yes'], SpeakCapture.lines
    assert_equal [['Resolved Yes', false]], SpeakCapture.log
    assert_same rows, @scene.original_options
    assert_equal 2, @scene.default
    assert_equal 0, @scene.cursor
    assert_nil @scene.selected
    assert_equal [:untouched_color, :untouched_callback], [rows[0].color, rows[0].callback]
  end

  def test_changes_wrap_both_directions_and_repeated_loop_does_not_repeat_the_row
    open('Yes', 'No', 'Maybe')
    assert_equal :original_loop, @scene.loop
    assert_equal :original_selection, @scene.setSelection(1)
    @scene.loop
    @scene.setSelection(1)
    @scene.setSelection(-1)
    @scene.setSelection(3)
    assert_equal ['Yes', 'No', 'Maybe', 'Yes'], SpeakCapture.lines
  end

  def test_resolved_localized_labels_are_used_for_arbitrary_lists_and_duplicate_rows
    open('Prima scelta', 'Prima scelta', 'Altra scelta')
    @scene.setSelection(1)
    @scene.setSelection(2)
    assert_equal ['Prima scelta', 'Prima scelta', 'Altra scelta'], SpeakCapture.lines
  end

  def test_current_row_is_available_on_info_and_cleared_before_terminal_animation
    open('Yes', 'No')
    @scene.setSelection(1)
    assert_equal 'No', PokeAccess::Info.row_text
    SpeakCapture.clear
    assert_equal 1, @scene.select
    assert_nothing_spoken
    refute_equal 'No', PokeAccess::Info.row_text
    assert_equal 1, @scene.selected
  end

  def test_dispose_and_old_scene_updates_are_silent_and_preserve_original_result
    open('Yes', 'No')
    assert_equal :original_dispose, @scene.dispose
    SpeakCapture.clear
    @scene.setSelection(1)
    @scene.loop
    assert_nothing_spoken
    assert_equal true, @scene.disposed
  end

  def test_reopening_resets_only_this_reader_and_reads_initial_choice_again
    open('Yes', 'No')
    @scene.dispose
    SpeakCapture.clear
    open('Yes', 'No')
    assert_equal ['Yes'], SpeakCapture.lines
  end

  def test_blank_or_nontext_options_do_not_invent_labels
    open('', nil, Object.new)
    @scene.setSelection(1)
    @scene.setSelection(2)
    assert_nothing_spoken
  end

  def test_new_active_choice_is_not_overwritten_by_an_old_scene
    old = open('Old first', 'Old last')
    open('New first', 'New last')
    SpeakCapture.clear
    old.setSelection(1)
    old.dispose
    @scene.setSelection(1)
    assert_equal ['New last'], SpeakCapture.lines
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
