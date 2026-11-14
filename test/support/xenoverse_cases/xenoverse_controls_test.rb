require_relative '../xenoverse_standalone'

class CommandScreen
  Page = Struct.new(:bitmap, :x) do
    def disposed?; false; end
  end
  attr_reader :sprites
  def initialize(second = false)
    @sprites = {'page1' => Page.new(Object.new, 0), 'page2' => Page.new(Object.new, 512)}
    first = ['Actual movement', 'Actual confirm', 'Actual cancel', 'Actual run', 'Actual registered item']
    second_rows = ['Actual MN', 'Actual achievements', 'Actual dex', 'Actual map']
    [first, second ? second_rows : nil].each_with_index do |labels, page|
      next unless labels
      pbDrawTextPositions(@sprites["page#{page + 1}"].bitmap,
        labels.each_with_index.map { |label, i| [label, 360, 60 + i * 50, 2, nil] })
    end
    @page = 0
    PokeAccess::Frame.run_pollers
    yield self if block_given?
  end
  def page(number, x = 0)
    @page = number
    @sprites["page#{number + 1}"].x = x
    PokeAccess::Frame.run_pollers
  end
end
load File.join(Harness::ROOT, 'games/xenoverse/controls.rb')

class XenoverseControlsTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
  end

  def test_actual_page_labels_and_picture_keys_are_read_once_and_available_on_info
    CommandScreen.new do |_screen|
      text = SpeakCapture.lines.last
      assert_includes text, 'Up / Down / Left / Right: Actual movement'
      assert_includes text, 'C / Enter / Space: Actual confirm'
      assert_includes text, 'X / Escape: Actual cancel'
      assert_includes text, 'Z: Actual run'
      assert_includes text, 'F5: Actual registered item'
      assert_equal text, PokeAccess::Info.info_text
      PokeAccess::Frame.run_pollers
      assert_equal 1, SpeakCapture.lines.length
    end
    assert_nil PokeAccess::Info.row_text
  end

  def test_second_page_waits_for_actual_sprite_arrival_and_returns_to_page_one
    CommandScreen.new(true) do |screen|
      SpeakCapture.clear
      screen.page(1, 250)
      assert_nothing_spoken
      screen.page(1)
      assert_equal ['W: Actual MN. A: Actual achievements. S: Actual dex. D: Actual map'], SpeakCapture.lines
      screen.page(0)
      assert_equal 2, SpeakCapture.lines.length
      assert_equal [true, true], SpeakCapture.log.map { |row| row[1] }
    end
  end

  def test_rebound_actions_replace_the_pictured_keys
    PokeAccess::Config.rebinds = {:c => 0x56, :b => 0x42, :a => 0x4A, :r => 0x4B}
    CommandScreen.new(true) do |screen|
      assert_includes SpeakCapture.lines.last, 'V: Actual confirm'
      assert_includes SpeakCapture.lines.last, 'B: Actual cancel'
      assert_includes SpeakCapture.lines.last, 'J: Actual run'
      screen.page(1)
      assert_includes SpeakCapture.lines.last, 'K: Actual MN'
    end
  end

  def test_unrelated_paint_missing_page_exception_and_reopen
    assert_raises(RuntimeError) do
      CommandScreen.new do |screen|
        SpeakCapture.clear
        pbDrawTextPositions(Object.new, [['Unrelated text', 360, 60, 2, nil]])
        screen.page(1)
        assert_nothing_spoken
        raise 'Actual game failure'
      end
    end
    assert_nil PokeAccess::Info.row_text
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
    CommandScreen.new { assert_equal 1, SpeakCapture.lines.length }
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
