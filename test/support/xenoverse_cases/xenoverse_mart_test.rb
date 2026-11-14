require_relative '../xenoverse_standalone'

# Reproduce NewMart's real local-index/paint boundary. The legacy command
# window remains hidden and never supplies a selection to this fixture.
class PokemonMartScene
  attr_accessor :test_steps, :test_result, :test_rows
  def xenoverse_test_choose
    @test_steps.each do |step|
      if step.respond_to?(:call)
        step.call(self)
      else
        drawItemInfo(step)
        @test_rows.push(PokeAccess::Info.row_text)
      end
    end
    @test_result
  end
  if method_defined?(:pbChooseBuyItem__pa_orig_PokemonMartScene)
    alias_method :pbChooseBuyItem__pa_orig_PokemonMartScene, :xenoverse_test_choose
  else
    alias_method :pbChooseBuyItem, :xenoverse_test_choose
  end
  def drawItemInfo(index)
    @test_painted_index = index
    :paint_result
  end
end
load File.join(Harness::ROOT, 'games/xenoverse/mart.rb')

class XenoverseMartTest < PokeAccessTest
  Adapter = Struct.new(:names, :prices, :quantities, :money, :point_prices) do
    def getDisplayName(item); names.fetch(item); end
    def getDisplayPrice(item); "$ #{prices.fetch(item)}"; end
    def getQuantity(item); quantities.fetch(item, 0); end
    def getMoney; money; end
    def getBattlePrice(item); point_prices.fetch(item); end
    def getDescription(item); "Visible description for #{names.fetch(item)}."; end
  end

  def setup
    super
    @old_trainer = $Trainer
    PokeAccess::Config.language = :en
    PokeAccess::Config.verbosity = :medium
    @adapter = Adapter.new({101 => 'Grid Ball', 102 => 'Grid Potion', 103 => 'Grid Repel'},
                           {101 => 200, 102 => 300, 103 => 350}, {101 => 3}, 4884,
                           {101 => 7, 102 => 0, 103 => 12})
    @scene = scene(@adapter)
  end

  def teardown
    $Trainer = @old_trainer
    super
  end

  def scene(adapter, buying = true, points = false)
    value = PokemonMartScene.allocate
    value.instance_variable_set(:@stock, [101, 102, 103])
    value.instance_variable_set(:@adapter, adapter)
    value.instance_variable_set(:@buying, buying)
    value.instance_variable_set(:@bpmode, points)
    value.test_steps, value.test_rows, value.test_result = [], [], :original_choice
    value
  end

  def choose(*steps)
    @scene.test_steps = steps
    @scene.pbChooseBuyItem
  end

  def test_registered_loop_reads_actual_indices_and_preserves_return_and_data
    before = Marshal.dump(@adapter)
    assert_equal :original_choice, choose(0, 1, 2, 1)
    assert_equal 4, SpeakCapture.lines.length
    ['Grid Ball', 'Grid Potion', 'Grid Repel', 'Grid Potion'].zip(SpeakCapture.lines).each do |name, line|
      assert_includes line, name
    end
    assert_includes SpeakCapture.lines[0], '$ 200'
    assert_includes SpeakCapture.lines[1], '$ 300'
    assert_includes SpeakCapture.lines[2], '$ 350'
    assert_equal [false, true, true, true], SpeakCapture.log.map { |row| row[1] }
    assert_equal before, Marshal.dump(@adapter)
    assert_equal [101, 102, 103], @scene.instance_variable_get(:@stock)
  end

  def test_idle_and_boundary_redraws_deduplicate_but_reopening_reads_again
    2.times { choose(0, 0, 0) }
    assert_equal 2, SpeakCapture.lines.length
    assert_equal [false, false], SpeakCapture.log.map { |row| row[1] }
  end

  def test_description_full_row_and_balance_survive_brief_verbosity
    PokeAccess::Config.verbosity = :brief
    descriptions = []
    choose(0, lambda { |_scene| descriptions.push(PokeAccess::Info.noted_item_desc(101)) })
    assert_equal ['Visible description for Grid Ball.'], descriptions
    assert_includes @scene.test_rows[0], 'You have: 3'
    assert_includes @scene.test_rows[0], 'Money 4884'
    refute_includes SpeakCapture.lines[0], 'You have:'
    refute_includes SpeakCapture.lines[0], 'Money'
  end

  def test_first_medium_row_has_balance_and_later_rows_keep_it_for_full_read
    choose(0, 1)
    assert_includes SpeakCapture.lines[0], 'Money 4884'
    refute_includes SpeakCapture.lines[1], 'Money'
    assert_includes @scene.test_rows[1], 'Money 4884'
    assert_includes @scene.test_rows[1], 'You have: 0'
  end

  def test_same_index_refresh_tracks_changed_prices_quantities_and_money
    choose(0, lambda { |_scene|
      @adapter.prices[101] = 123
      @adapter.quantities[101] = 4
      @adapter.money = 4761
    }, 0)
    assert_equal 2, SpeakCapture.lines.length
    assert_includes SpeakCapture.lines[1], '$ 123'
    assert_includes SpeakCapture.lines[1], 'You have: 4'
    assert_includes @scene.test_rows.last, 'Money 4761'
  end

  def test_compacted_stock_reads_current_item_instead_of_old_index_name
    choose(0, lambda { |value| value.instance_variable_get(:@stock).shift }, 0)
    assert_includes SpeakCapture.lines.last, 'Grid Potion'
    refute_includes SpeakCapture.lines.last, 'Grid Ball'
  end

  def test_bp_mode_uses_actual_point_price_and_balance_including_zero_price
    $Trainer = Struct.new(:battle_points).new(88)
    @scene.instance_variable_set(:@bpmode, true)
    def @adapter.getDisplayPrice(_item); raise 'Cash price must not be used'; end
    def @adapter.getMoney; raise 'Cash balance must not be used'; end
    choose(0, 1)
    assert_includes SpeakCapture.lines[0], 'Points: 7'
    assert_includes SpeakCapture.lines[0], 'Points: 88'
    assert_includes SpeakCapture.lines[1], 'Points: 0'
    refute_includes SpeakCapture.lines.join, '$'
  end

  def test_hidden_legacy_window_or_outside_paint_never_publishes_a_row
    assert_equal :paint_result, @scene.drawItemInfo(0)
    assert_nothing_spoken
    other = scene(@adapter)
    choose(lambda { |_value| other.drawItemInfo(1) })
    assert_nothing_spoken
  end

  def test_sell_bag_is_left_to_its_own_reader
    @scene.instance_variable_set(:@buying, false)
    PokeAccess::Info.set_info(:text, 'Actual sell bag', 'Actual sell bag')
    choose(0)
    assert_nothing_spoken
    assert_equal 'Actual sell bag', PokeAccess::Info.info_text
  end

  def test_invalid_indices_and_empty_stock_do_not_invent_a_cancel_or_item
    choose(-1, nil, '0', 3, 100)
    assert_nothing_spoken
    @scene.instance_variable_set(:@stock, [])
    choose(0)
    assert_nothing_spoken
  end

  def test_close_clears_item_row_and_later_quantity_paint_is_not_a_grid_read
    choose(0)
    assert_nil PokeAccess::Info.row_text
    SpeakCapture.clear
    @scene.drawItemInfo(1)
    assert_nothing_spoken
    assert_nil PokeAccess::Info.row_text
  end

  def test_original_failure_is_propagated_and_closes_reader_scope
    error = assert_raises(RuntimeError) { choose(0, lambda { |_value| raise 'Original shop failure' }) }
    assert_equal 'Original shop failure', error.message
    assert_nil PokeAccess::Info.row_text
    SpeakCapture.clear
    @scene.drawItemInfo(1)
    assert_nothing_spoken
  end

  def test_provider_failure_does_not_change_the_original_choice_result
    def @adapter.getDisplayName(_item); raise 'Broken original item provider'; end
    assert_equal :original_choice, choose(0)
    assert_nothing_spoken
    assert_nil PokeAccess::Info.row_text
  end

  def test_nested_chooser_restores_the_outer_focused_row_without_repeating_it
    other = scene(@adapter)
    other.test_steps = [1]
    choose(0, lambda { |_value|
      assert_equal :original_choice, other.pbChooseBuyItem
      assert_includes PokeAccess::Info.row_text, 'Grid Ball'
    }, 0)
    assert_equal 2, SpeakCapture.lines.length
    assert_includes SpeakCapture.lines[0], 'Grid Ball'
    assert_includes SpeakCapture.lines[1], 'Grid Potion'
    assert_nil PokeAccess::Info.row_text
  end
end
