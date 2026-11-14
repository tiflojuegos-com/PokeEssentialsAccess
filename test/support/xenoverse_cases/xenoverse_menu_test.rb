require_relative '../xenoverse_standalone'

class XenoverseMenuChild
  def open; :original_child; end
end
class NewMenu_Item
  attr_accessor :displayedName
  def initialize(label); @displayedName = label; end
  def select; XenoverseMenuChild.new.open; :original_select; end
end
class NewMenu
  attr_reader :items, :index
  def open
    @items = [nil, NewMenu_Item.new('Actual trainer'), nil, NewMenu_Item.new('Actual save'),
              NewMenu_Item.new('Actual controls'), NewMenu_Item.new('Actual options'), NewMenu_Item.new('Actual bag')]
    @index, @looping = 1, true
    update
    yield self if block_given?
    :original_open
  end
  def update; :original_update; end
  def handleInput; yield if block_given?; :original_input; end
  def move(index); @index = index; handleInput; end
  def close; @looping = false; :original_close; end
end
PokeAccess::Game.define('xenoverse-menu-child-test') do
  read_on_open('XenoverseMenuChild', :open) { |_scene| 'Actual child screen' }
end
load File.join(Harness::ROOT, 'games/xenoverse/menu.rb')

class XenoverseMenuTest < PokeAccessTest
  def setup
    super
    PokeAccess::Config.language = :en
  end

  def test_open_and_actual_sparse_navigation_without_repeated_idle_announcements
    menu = NewMenu.new
    assert_equal :original_open, menu.open { |scene|
      assert_equal ['Actual trainer'], SpeakCapture.lines
      assert_equal :original_update, scene.update
      assert_equal :original_input, scene.move(3)
      scene.handleInput
      scene.move(6)
      scene.move(1)
      assert_equal ['Actual trainer', 'Actual save', 'Actual bag', 'Actual trainer'], SpeakCapture.lines
      assert_equal 1, scene.index
      assert_equal [nil, 'Actual trainer', nil, 'Actual save', 'Actual controls', 'Actual options', 'Actual bag'],
        scene.items.map { |item| item && item.displayedName }
    }
  end

  def test_child_hooks_survive_both_containers_and_return_reads_current_label_once
    NewMenu.new.open do |scene|
      scene.move(3)
      SpeakCapture.clear
      result = nil
      scene.handleInput { result = scene.items[3].select }
      assert_equal :original_select, result
      assert_equal ['Actual child screen', 'Actual save'], SpeakCapture.lines
      scene.handleInput
      assert_equal 2, SpeakCapture.lines.length
    end
  end

  def test_invalid_and_empty_items_stay_silent_without_changing_selection
    NewMenu.new.open do |scene|
      SpeakCapture.clear
      [-1, 0, 2, 99, nil].each do |index|
        scene.move(index)
        index.nil? ? assert_nil(scene.index) : assert_equal(index, scene.index)
      end
      assert_nothing_spoken
    end
  end

  def test_close_and_exception_clear_ownership_and_reopening_reads_again
    scene = NewMenu.new
    scene.open do |menu|
      assert_equal :original_close, menu.close
      SpeakCapture.clear
      menu.move(3)
      assert_nothing_spoken
    end
    assert_raises(RuntimeError) { scene.open { raise 'Original menu failure' } }
    SpeakCapture.clear
    scene.move(3)
    assert_nothing_spoken
    scene.open { assert_equal ['Actual trainer'], SpeakCapture.lines }
  end

  def test_actual_dynamic_label_is_not_replaced_with_invented_translations
    [:en, :pl, :es, :fr, :de, :pt].each do |language|
      PokeAccess::Config.language = language
      NewMenu.new.open do |scene|
        SpeakCapture.clear
        scene.items[1].displayedName = 'Actual localized player label'
        scene.handleInput
        assert_equal ['Actual localized player label'], SpeakCapture.lines
      end
    end
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
