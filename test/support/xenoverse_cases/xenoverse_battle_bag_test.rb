require_relative '../xenoverse_standalone'

class NewBattleBag
  Rect = Struct.new(:x)
  Selection = Struct.new(:src_rect, :x)
  Panel = Struct.new(:x)
  def initialize
    @index, @lastUsed, @selPocket, @page = 0, 0, 0, -1
    @ret = nil
    @sprites = {'sel' => Selection.new(Rect.new(931), 26), 'confirm' => Panel.new(26)}
  end
  def getItemText(index); ['Actual Medicine', 'Actual Balls', 'Actual Berries', 'Actual Battle Items'][index]; end
  def show; :original_show; end
  def hide; :original_hide; end
  def update; :original_update; end
  def useItem?; block_given? ? yield(self) : false; end
  def set(name, value); instance_variable_set(name, value); end
  def selection(index); @sprites['sel'].src_rect.x = 931 + 465 * index; end
  def panel_x(value); @sprites['confirm'].x = value; end
  def selection_x(value); @sprites['sel'].x = value; end
end
load File.join(Harness::ROOT, 'games/xenoverse/battle_bag.rb')

class XenoverseBattleBagTest < PokeAccessTest
  include PeaStandaloneMethods
  def setup
    super
    PokeAccess::Config.language = :en
    @reader = PokeAccess::XenoverseBattleBag
    @bag = NewBattleBag.new
    @bag.show
  end
  def teardown
    @bag.hide
    super
  end
  def with_item_names(&block)
    with_singleton(PokeAccess::Data, :item_name, lambda { |id| "Actual item #{id}" }, &block)
  end

  def test_actual_pocket_labels_and_back_are_repeated_only_on_change
    assert_equal :original_update, @bag.update
    @bag.update
    [1, 2, 3, 5].each { |index| @bag.set(:@index, index); @bag.update }
    assert_equal ['Actual Medicine', 'Actual Balls', 'Actual Berries', 'Actual Battle Items', 'Back'], SpeakCapture.lines
    assert_equal 'Back', PokeAccess::Info.info_text
    assert_equal [false, true, true, true, true], SpeakCapture.log.map { |row| row[1] }
  end

  def test_reopen_queues_again_and_hidden_or_unrelated_bags_are_silent
    @bag.update; @bag.hide
    SpeakCapture.clear
    @bag.update; NewBattleBag.new.update
    assert_nothing_spoken
    @bag.show; @bag.update
    assert_equal ['Actual Medicine'], SpeakCapture.lines
    assert_equal false, SpeakCapture.log[0][1]
  end

  def test_live_quantity_changes_and_page_headers_follow_actual_grid
    @bag.set(:@selPocket, 3); @bag.set(:@pname, 'Actual balls')
    @bag.set(:@page, 0); @bag.set(:@pages, 2); @bag.set(:@item, 0)
    entries = [[17, 2], [18, 1]]
    @bag.set(:@pocket, entries)
    with_item_names do
      @bag.update; @bag.update
      entries[0][1] = 1
      @bag.update
      @bag.set(:@page, 1); @bag.set(:@item, 1); @bag.update
      @bag.set(:@back, true); @bag.update
    end
    assert_equal ['Actual balls, 1/2. Actual item 17, x2', 'Actual item 17, x1',
                  'Actual balls, 2/2. Actual item 18, x1', 'Back'], SpeakCapture.lines
    assert_equal 'Back', PokeAccess::Info.info_text
  end

  def test_last_item_and_empty_grid_do_not_invent_entries
    @bag.set(:@index, 4)
    @bag.update
    assert_equal [_INTL('ULTIMO STRUMENTO USATO')], SpeakCapture.lines
    SpeakCapture.clear
    with_item_names do
      @bag.set(:@lastUsed, 17); @bag.update
    end
    assert_equal ['last item, Actual item 17'], SpeakCapture.lines
    assert_equal :item, PokeAccess::Info.instance_variable_get(:@kind)
    SpeakCapture.clear
    @bag.set(:@selPocket, 3); @bag.set(:@pocket, []); @bag.set(:@item, 0)
    @bag.update
    assert_nothing_spoken
  end

  def test_confirmation_returns_the_game_choice_and_keeps_item_info
    @bag.set(:@ret, 17)
    [true, false].each do |choice|
      @bag.selection(0)
      SpeakCapture.clear
      result = @bag.useItem? do |bag|
        @reader.poll
        @reader.poll
        bag.selection(1); @reader.poll
        assert_equal :item, PokeAccess::Info.instance_variable_get(:@kind)
        assert_equal _INTL("DON'T USE"), PokeAccess::Info.row_text
        choice
      end
      assert_equal choice, result
      assert_equal [_INTL('USE'), _INTL("DON'T USE")], SpeakCapture.lines.last(2)
    end
    SpeakCapture.clear
    @reader.poll
    assert_nothing_spoken
  end

  def test_game_failure_and_invalid_selection_clear_confirmation_ownership
    @bag.set(:@ret, 17)
    assert_raises(RuntimeError) do
      @bag.useItem? do |bag|
        bag.selection(99); @reader.poll
        raise 'Actual game failure'
      end
    end
    SpeakCapture.clear
    @reader.poll
    assert_nothing_spoken
    @bag.set(:@ret, nil); @bag.set(:@index, 99); @bag.update
    assert_nothing_spoken
    @bag.hide
    assert_equal :battle_foe, PokeAccess::Info.instance_variable_get(:@kind)
  end

  def test_hidden_confirmation_does_not_read_a_previous_choice_during_reopening
    @bag.set(:@ret, 17)
    @bag.selection(1)
    @bag.panel_x(-494)
    @bag.useItem? do |bag|
      SpeakCapture.clear # Item description belongs to the opener, not the selector.
      @reader.poll
      assert_nothing_spoken
      bag.panel_x(26); bag.selection_x(512)
      @reader.poll
      assert_nothing_spoken
      bag.selection_x(26); bag.selection(0)
      @reader.poll
      assert_equal [_INTL('USE')], SpeakCapture.lines
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
