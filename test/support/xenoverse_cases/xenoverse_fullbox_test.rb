require_relative '../xenoverse_standalone'

class Fullbox
  def self.makeSprite(first, second = nil)
    $original_fullbox_args = [first, second]
    :original_bitmap
  end
end

load File.join(Harness::ROOT, 'games/xenoverse/fullbox.rb')

class XenoverseFullboxTest < PokeAccessTest
  Box = Struct.new(:name, :visible, :active)
  def wrapper(name, visible = true, active = true)
    value = Object.new
    value.instance_variable_set(:@mugname, Box.new(name, visible, active))
    value
  end
  def setup
    super
    $fullbox_mugshots = {}
  end
  def teardown
    $fullbox_mugshots = nil
    super
  end

  def test_resolved_rows_are_read_once_and_original_arguments_return_are_preserved
    first = 'Actual resolved first row'
    second = 'and second row.'
    assert_equal :original_bitmap, Fullbox.makeSprite(first, second)
    assert_equal ['Actual resolved first row and second row.'], SpeakCapture.lines
    assert_same first, $original_fullbox_args[0]
    assert_same second, $original_fullbox_args[1]
    assert_equal 'Actual resolved first row', first
    assert_equal 'Actual resolved first row and second row.', PokeAccess.last_dialogue
  end

  def test_one_visible_active_name_is_read_and_inactive_old_portraits_are_ignored
    $fullbox_mugshots = { 'left' => wrapper('Versil'), 'right' => wrapper('Old speaker', true, false),
                          'out_left' => [wrapper('Hidden speaker', false)] }
    Fullbox.makeSprite('The real dialogue.')
    assert_equal ['Versil: The real dialogue.'], SpeakCapture.lines
    assert_equal 'Versil: The real dialogue.', PokeAccess.last_dialogue
  end

  def test_ambiguous_or_missing_speaker_keeps_the_dialogue
    $fullbox_mugshots = { 'left' => wrapper('First'), 'right' => wrapper('Second') }
    Fullbox.makeSprite('Both portraits visible.')
    assert_equal ['Both portraits visible.'], SpeakCapture.lines
    SpeakCapture.clear
    $fullbox_mugshots = nil
    Fullbox.makeSprite('Narration without a portrait.')
    assert_equal ['Narration without a portrait.'], SpeakCapture.lines
  end

  def test_plain_name_punctuation_is_preserved_and_hidden_names_use_existing_translation
    $fullbox_mugshots = { 'left' => wrapper('Name, Junior') }
    Fullbox.makeSprite('First text.')
    assert_equal ['Name, Junior: First text.'], SpeakCapture.lines
    SpeakCapture.clear
    $fullbox_mugshots = { 'left' => wrapper('???') }
    Fullbox.makeSprite('Another text.')
    assert_equal [PokeAccess::I18n.t(:msg_speaker_unknown) + ': Another text.'], SpeakCapture.lines
  end

  def test_empty_pages_do_not_invent_speech_or_prevent_original_paint
    assert_equal :original_bitmap, Fullbox.makeSprite('', nil)
    Fullbox.makeSprite(' ', "\n")
    assert_nothing_spoken
    assert_equal [' ', "\n"], $original_fullbox_args
  end

  def test_later_page_and_speaker_change_are_not_globally_deduplicated
    $fullbox_mugshots = { 'left' => wrapper('First') }
    Fullbox.makeSprite('Yes.')
    $fullbox_mugshots = { 'left' => wrapper('Second') }
    Fullbox.makeSprite('Yes.')
    assert_equal ['First: Yes.', 'Second: Yes.'], SpeakCapture.lines
    assert_equal 'Second: Yes.', PokeAccess.last_dialogue
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
