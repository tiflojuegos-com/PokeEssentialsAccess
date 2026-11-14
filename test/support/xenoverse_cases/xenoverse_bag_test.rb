require_relative '../xenoverse_standalone'

class NewBagScreen
  Sprite = Struct.new(:bitmap, :opacity) do
    def disposed?; false; end
  end
  attr_reader :curPocket, :index
  attr_accessor :s
  def pbStartScene(bag)
    @bag = bag
    @pocketNames = ['Actual items', 'Actual empty pocket']
    @pockets = [[[17, 2], [18, 1]], []]
    @curPocketIndex, @index, @switching = 0, 0, false
    @curPocket = @pockets[0]
    drawItemInfo
    :original_start
  end
  def drawItemInfo
    pbDrawTextPositions(Object.new, [["Painted item #{@curPocket[@index][0]}", 16, 198, 0, nil]])
  end
  def update; :original_update; end
  def updatePocket(pocket)
    @curPocketIndex, @index = pocket, 0
    @curPocket = @pockets[pocket]
    drawItemInfo unless @curPocket.empty?
    :original_pocket
  end
  def pbChangeSelection
    drawItemInfo if @index.is_a?(Integer) && @index >= 0 && @curPocket[@index]
    :original_selection
  end
  def pbRefresh; :original_refresh; end
  def pbDisplay(text); yield self if block_given?; :original_display; end
  def pbShowCommands(text, commands)
    @cmdid = 0
    yield self if block_given?
    @cmdid
  end
  def pbChooseNumber(text, quantity)
    @s = {'qtbg' => Sprite.new(Object.new, 255)}
    yield self if block_given?
    quantity
  end
  def pbConfirm(text)
    @s = {'yes' => Sprite.new(Object.new, 255), 'no' => Sprite.new(Object.new, 175)}
    pbDrawTextPositions(@s['yes'].bitmap, [['Actual yes', 44, 5, 2, nil]])
    pbDrawTextPositions(@s['no'].bitmap, [['Actual no', 44, 5, 2, nil]])
    yield self if block_given?
    false
  end
  def pbEndScene; :original_end; end
end
load File.join(Harness::ROOT, 'games/xenoverse/bag.rb')

class XenoverseBagTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
    PokeAccess::Config.verbosity = :full
    @bag = Struct.new(:registeredItem).new(0)
    @scene = NewBagScreen.new
    assert_equal :original_start, @scene.pbStartScene(@bag)
  end
  def teardown
    @scene.pbEndScene
    super
  end
  def pulse; PokeAccess::XenoverseBag.modal_poll; end

  def test_actual_painted_item_quantity_navigation_and_empty_pocket
    assert_match(/Actual items pocket.*Painted item 17.*2/, SpeakCapture.lines.last)
    before = Marshal.dump(@scene.curPocket)
    SpeakCapture.clear
    assert_equal :original_update, @scene.update
    assert_nothing_spoken
    @scene.instance_variable_set(:@index, 1)
    assert_equal :original_selection, @scene.pbChangeSelection
    assert_match(/Painted item 18/, SpeakCapture.lines.last)
    refute_match(/Actual items pocket/, SpeakCapture.lines.last)
    assert_equal before, Marshal.dump(@scene.curPocket)
    assert_equal :original_pocket, @scene.updatePocket(1)
    assert_equal 'Actual empty pocket pocket. No items of this kind', SpeakCapture.lines.last
    @scene.update
    assert_equal 2, SpeakCapture.lines.length
    @scene.updatePocket(0)
    assert_match(/Actual items pocket.*Painted item 17/, SpeakCapture.lines.last)
  end

  def test_quantity_registration_and_moving_mode_change_under_stationary_cursor
    SpeakCapture.clear
    @scene.curPocket[0][1] = 4
    @scene.pbRefresh
    assert_match(/4/, SpeakCapture.lines.last)
    @bag.registeredItem = 17
    @scene.pbRefresh
    assert_match(/registered/, SpeakCapture.lines.last)
    @scene.instance_variable_set(:@switching, true)
    @scene.pbChangeSelection
    assert_match(/moving/, SpeakCapture.lines.last)
    assert_equal 3, SpeakCapture.lines.length
    assert_equal [[17, 4], [18, 1]], @scene.curPocket
  end

  def test_actual_commands_dialogue_and_return_without_parent_poll_duplicates
    SpeakCapture.clear
    modal = nil
    result = @scene.pbShowCommands('Actual question', ['Actual use', 'Actual cancel']) do |scene|
      modal = PokeAccess::XenoverseBag.instance_variable_get(:@modal)
      pulse
      scene.update
      scene.instance_variable_set(:@cmdid, 1)
      pulse
      pulse
    end
    assert_equal 1, result
    assert_nil PokeAccess::Cursor.current(modal, :xenoverse_bag_modal)
    @scene.update
    assert_equal ['Actual question', 'Actual use', 'Actual cancel'], SpeakCapture.lines[0, 3]
    assert_match(/Painted item 17/, SpeakCapture.lines[3])
    assert_equal 4, SpeakCapture.lines.length
    assert_equal :original_display, @scene.pbDisplay('Actual item result') { pulse }
    assert_includes SpeakCapture.lines, 'Actual item result'
  end

  def test_confirmation_reads_actual_painted_labels_and_settled_selection
    SpeakCapture.clear
    result = @scene.pbConfirm('Actual confirm?') do |scene|
      pulse
      scene.s['yes'].opacity, scene.s['no'].opacity = 210, 220
      pulse
      scene.s['yes'].opacity, scene.s['no'].opacity = 175, 255
      pulse
      pulse
    end
    assert_equal false, result
    @scene.update
    assert_equal ['Actual confirm?', 'Actual yes', 'Actual no'], SpeakCapture.lines[0, 3]
    assert_equal 4, SpeakCapture.lines.length
  end

  def test_quantity_comes_from_actual_paint_including_zero_and_suppresses_duplicates
    SpeakCapture.clear
    result = @scene.pbChooseNumber('Actual quantity?', 7) do |scene|
      ['x000', 'x001', 'x001', 'x007'].each do |text|
        pbDrawTextPositions(scene.s['qtbg'].bitmap, [[text, 130, 5, 1, nil]])
        pulse
      end
    end
    assert_equal 7, result
    @scene.update
    assert_equal ['Actual quantity?', 'quantity: 0', 'quantity: 1', 'quantity: 7'], SpeakCapture.lines[0, 4]
    assert_equal 5, SpeakCapture.lines.length
  end

  def test_return_waits_for_the_callers_real_item_action_before_reading_quantity
    SpeakCapture.clear
    @scene.pbDisplay('Actual removal result') { pulse }
    assert_equal ['Actual removal result'], SpeakCapture.lines
    # As in the real game's Toss branch, inventory changes after pbDisplay.
    @scene.curPocket[0][1] = 1
    @scene.pbRefresh
    assert_equal 2, SpeakCapture.lines.length
    assert_includes SpeakCapture.lines.last, 'Painted item 17 ×1'
    refute_includes SpeakCapture.lines.last, 'Painted item 17 ×2'
  end

  def test_invalid_and_closed_state_are_silent_and_original_failures_propagate
    SpeakCapture.clear
    [-1, 3, nil].each do |index|
      @scene.instance_variable_set(:@index, index)
      @scene.update
      index.nil? ? assert_nil(@scene.index) : assert_equal(index, @scene.index)
    end
    assert_nothing_spoken
    @scene.instance_variable_set(:@index, 0)
    assert_raises(RuntimeError) { @scene.pbDisplay('Actual before failure') { raise 'Original failure' } }
    assert_equal :original_end, @scene.pbEndScene
    SpeakCapture.clear
    @scene.update
    pulse
    assert_nothing_spoken
  end

  def test_empty_pocket_info_is_cleared_only_when_its_own_bag_closes
    @scene.instance_variable_set(:@curPocket, [])
    @scene.pbRefresh
    assert_equal :text, PokeAccess::Info.instance_variable_get(:@kind)
    PokeAccess::XenoverseBag.close(Object.new)
    assert_equal :text, PokeAccess::Info.instance_variable_get(:@kind)
    @scene.pbEndScene
    assert_nil PokeAccess::Info.instance_variable_get(:@kind)
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
