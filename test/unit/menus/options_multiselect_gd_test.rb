# The multiselect option of Sky's options screen (core/menus/v22/options_v22.rb): a row of items browsed with left and
# right and ticked with the use key, said as the item under its cursor and whether it is ticked, from the list's own
# value; said again when the cursor moves or the item is ticked, never twice for the same.
class OptionsMultiselectGdTest < PokeAccessTest
  V22 = PokeAccess::OptionsV22

  # The options list as far as the reader goes: its option hashes, the values it edits and the focused row.
  class List
    attr_accessor :index
    def initialize(options, values); @options = options; @values = values; @index = 0; end
  end

  ITEMS = ["A", "B", "Opción D"]

  test "says the item under the cursor and whether it is ticked" do
    list = multiselect(1, [1])
    assert_equal "B, #{PokeAccess::I18n.t(:mk_on)}", V22.value_text(list, 0, list.instance_variable_get(:@options)[0])
    list = multiselect(2, [1])
    assert_equal "Opción D, #{PokeAccess::I18n.t(:mk_off)}", V22.value_text(list, 0, list.instance_variable_get(:@options)[0])
  end

  test "reads the items an option keeps under :items" do
    list = multiselect(0, [], { :items => ITEMS })
    assert_equal "Multi: A, #{PokeAccess::I18n.t(:mk_off)}", V22.line(list)
  end

  test "a value the list has not built, or a cursor past the items, gives no value and the name alone" do
    [nil, { :cursor => 7, :selections => [] }].each do |value|
      list = List.new([option], [value])
      assert_equal "Multi", V22.line(list), "for #{value.inspect}"
    end
  end

  test "moving the cursor and ticking an item are said, an unchanged row is not" do
    list = multiselect(0, [])
    V22.poll(list)
    V22.poll(list)
    list.instance_variable_get(:@values)[0] = { :cursor => 1, :selections => [], :scroll => 0 }
    V22.poll(list)
    list.instance_variable_get(:@values)[0] = { :cursor => 1, :selections => [1], :scroll => 0 }
    V22.poll(list)
    off = PokeAccess::I18n.t(:mk_off)
    assert_equal [["Multi: A, #{off}", true], ["Multi: B, #{off}", true], ["Multi: B, #{PokeAccess::I18n.t(:mk_on)}", true]],
                 SpeakCapture.log
  end

  private

  # The multiselect option as the screen builds it from its menu handler.
  def option(params = ITEMS)
    { :name => "Multi", :type => :multiselect, :parameters => params, :get_proc => proc { [] } }
  end

  # A list on one multiselect option whose value has its cursor at cursor and ticks the given items.
  def multiselect(cursor, ticked, params = ITEMS)
    List.new([option(params)], [{ :cursor => cursor, :selections => ticked, :scroll => 0 }])
  end
end
