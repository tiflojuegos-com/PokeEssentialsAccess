# The info key keeps a machine's teaching label and each distinct description.
class MachineDescriptionTest < PokeAccessTest
  DESCRIPTION = "Damage increases with the target's weight."

  def setup
    super
    PokeAccess::Config.language = :en
  end

  test "an identical item and move description is spoken once" do
    assert_equal "TM86. #{DESCRIPTION} #{teaching}.", machine_line(DESCRIPTION, DESCRIPTION)
  end

  test "rendering codes and whitespace do not duplicate the same spoken description" do
    painted = "<b>Damage increases</b> with the target's\nweight."
    assert_equal "TM86. #{DESCRIPTION} #{teaching}.", PokeAccess.clean(machine_line(painted, DESCRIPTION))
  end

  test "distinct item and move descriptions are both retained" do
    assert_equal "TM86. A reusable teaching machine. #{teaching}. #{DESCRIPTION}",
                 machine_line("A reusable teaching machine.", DESCRIPTION)
  end

  test "a missing item description retains the move description" do
    assert_equal "TM86. #{teaching}. #{DESCRIPTION}", machine_line(nil, DESCRIPTION)
  end

  test "a missing move description retains the item description and teaching label" do
    assert_equal "TM86. #{DESCRIPTION} #{teaching}.", machine_line(DESCRIPTION, nil)
  end

  test "an ordinary item keeps its description and has no teaching label" do
    assert_equal "TM86. #{DESCRIPTION}", machine_line(DESCRIPTION, nil, :machine => nil)
  end

  test "the screen's noted description takes precedence when comparing the move" do
    assert_equal "TM86. #{DESCRIPTION} #{teaching}.",
                 machine_line("A reusable teaching machine.", DESCRIPTION, :noted => DESCRIPTION)
  end

  test "matching descriptions also stay single in Polish" do
    PokeAccess::Config.language = :pl
    assert_equal "TM86. #{DESCRIPTION} #{teaching}.", machine_line(DESCRIPTION, DESCRIPTION)
  end

  private

  def teaching
    PokeAccess::I18n.t(:it_teaches, :move => "Grass Knot")
  end

  def machine_line(item_description, move_description, options = {})
    data = PokeAccess::Data
    methods = {
      :item_name => lambda { |_id| "TM86" },
      :item_description => lambda { |_id| item_description },
      :move_name => lambda { |_id| "Grass Knot" },
      :move_description => lambda { |_id| move_description }
    }
    previous = {}
    methods.each { |name, body| previous[name] = data.method(name); data.define_singleton_method(name, body) }
    info = PokeAccess::Info
    machine = info.method(:machine_move)
    move = options.has_key?(:machine) ? options[:machine] : 85
    info.define_singleton_method(:machine_move) { |_id| move }
    info.note_item_desc(options[:noted] ? 1 : nil, options[:noted])
    info.item_info(1)
  ensure
    previous.each { |name, body| data.define_singleton_method(name, body) }
    info.define_singleton_method(:machine_move, machine)
    info.note_item_desc(nil, nil)
  end
end
