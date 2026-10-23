# The v22 town map (TownMapV22): the place under the cursor named once, as the screen paints it; a blank point silent
# but parting two visits of a place. Its hook is evaluated again over a stand-in of the game's screen so it binds.
module UI
  # v22's town map screen cut down to its cursor: set_cursor_pos refreshes on a move as the game's does, and
  # get_point_data answers the point under the cursor, nil off every point.
  class TownMapVisuals
    def initialize(points)
      @points = points
      @cursor_pos = { :x => 0, :y => 0 }
    end

    def set_cursor_pos(new_x, new_y)
      changed = (@cursor_pos[:x] != new_x) || (@cursor_pos[:y] != new_y)
      @cursor_pos[:x] = new_x
      @cursor_pos[:y] = new_y
      refresh_on_cursor_move if changed
    end

    def refresh_on_cursor_move; end

    def get_point_data
      @points.find { |pt| pt[:position] == [@cursor_pos[:x], @cursor_pos[:y]] }
    end
  end
end

class TownMapV22GdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "core", "nav", "v22", "town_map_v22.rb")
  NAMES = { "Pallet Town" => "Pueblo Paleta", "Viridian City" => "Ciudad Verde", "Home" => "Casa de \\PN" }

  # Evaluates the file's hook registration at its own lines, binding it to the screen's class as it stands.
  # param file the name the code runs under; evaluated again under the file's own, it would reset that file's coverage
  def self.register_hook(file = PATH)
    src = Harness.source(PATH)
    found = src.match(/^PokeAccess::Hooks\.after_hook\("UI::TownMapVisuals".*?^end\r?\n/m)
    eval(found[0], TOPLEVEL_BINDING, file, src[0, found.begin(0)].count("\n") + 1)
  end
  private_class_method :register_hook
  register_hook

  test "moving the cursor onto a place names it in the game's words, cutting in" do
    map = town_map([1, 1, "Pallet Town"])
    translated { map.set_cursor_pos(1, 1) }
    assert_equal [["Pueblo Paleta", true]], SpeakCapture.log
  end

  test "a redraw on the same place says nothing again" do
    map = town_map([1, 1, "Pallet Town"])
    translated do
      map.set_cursor_pos(1, 1)
      SpeakCapture.clear
      map.refresh_on_cursor_move
    end
    assert_nothing_spoken
  end

  test "a square off every place says nothing" do
    map = town_map([1, 1, "Pallet Town"])
    translated { map.set_cursor_pos(2, 1) }
    assert_nothing_spoken
  end

  test "moving from one place onto the next names the new one" do
    map = town_map([1, 1, "Pallet Town"], [2, 1, "Viridian City"])
    translated do
      map.set_cursor_pos(1, 1)
      SpeakCapture.clear
      map.set_cursor_pos(2, 1)
    end
    assert_equal [["Ciudad Verde", true]], SpeakCapture.log
  end

  test "sweeping off a place and back onto it names it again" do
    map = town_map([1, 1, "Pallet Town"])
    translated do
      map.set_cursor_pos(1, 1)
      map.set_cursor_pos(2, 1)
      SpeakCapture.clear
      map.set_cursor_pos(1, 1)
    end
    assert_equal [["Pueblo Paleta", true]], SpeakCapture.log
  end

  test "a map opened afresh names the place under its cursor again" do
    translated do
      town_map([1, 1, "Pallet Town"]).set_cursor_pos(1, 1)
      SpeakCapture.clear
      town_map([1, 1, "Pallet Town"]).set_cursor_pos(1, 1)
    end
    assert_equal [["Pueblo Paleta", true]], SpeakCapture.log
  end

  test "says the player's name where the place's name has \\PN" do
    map = town_map([1, 1, "Home"])
    translated { map.set_cursor_pos(1, 1) }
    assert_equal [["Casa de #{$player.name}", true]], SpeakCapture.log
  end

  test "says a place's name as written where the game's messages cannot translate it" do
    map = town_map([1, 1, "Pallet Town"])
    with_messages(lambda { |_type, _id| raise NameError, "no region location names" }) { map.set_cursor_pos(1, 1) }
    assert_equal [["Pallet Town", true]], SpeakCapture.log
  end

  test "a point with no name, or one that translates to nothing, says nothing" do
    [[{ :position => [1, 1], :real_name => nil }, {}],
     [{ :position => [1, 1], :real_name => "Nowhere" }, { "Nowhere" => "" }]].each do |point, names|
      SpeakCapture.clear
      map = UI::TownMapVisuals.new([point])
      with_messages(lambda { |_type, id| names.key?(id) ? names[id] : id }) { map.set_cursor_pos(1, 1) }
      assert_nothing_spoken "for #{point.inspect}"
    end
  end

  test "a screen whose point data cannot be read says nothing" do
    unreadable = { "raises" => lambda { raise "no point data" }, "answers no Hash" => lambda { [:real_name, "Pallet Town"] } }
    unreadable.each do |how, data|
      map = town_map([1, 1, "Pallet Town"])
      map.define_singleton_method(:get_point_data, &data)
      translated { map.set_cursor_pos(1, 1) }
      assert_nothing_spoken "when the point data #{how}"
    end
  end

  test "files no missing hook for a v22 screen without the cursor refresh" do
    hooked = UI::TownMapVisuals.instance_method(:refresh_on_cursor_move)
    UI::TownMapVisuals.send(:remove_method, :refresh_on_cursor_move)
    missing = PokeAccess::Hooks.missing.dup
    self.class.send(:register_hook, "town_map_v22.rb, its hook again")
    assert_equal missing, PokeAccess::Hooks.missing
  ensure
    UI::TownMapVisuals.send(:define_method, :refresh_on_cursor_move, hooked)
    PokeAccess::Hooks.missing.replace(missing) if missing
  end

  test "says a game variable's value where the place's name has \\v[n], as the screen paints it" do
    $game_variables[5] = 3
    map = town_map([1, 1, "Route \\v[5]"])
    with_messages(lambda { |_type, id| id }) { map.set_cursor_pos(1, 1) }
    assert_equal [["Route 3", true]], SpeakCapture.log
  end

  private

  # A v22 town map screen over the given points, each [x, y, real name].
  def town_map(*points)
    UI::TownMapVisuals.new(points.map { |x, y, name| { :position => [x, y], :real_name => name } })
  end

  # Runs the block with the game's region location names translating NAMES, any other name left as it is.
  def translated(&blk)
    with_messages(lambda { |_type, id| NAMES.key?(id) ? NAMES[id] : id }, &blk)
  end

  # Runs the block with pbGetMessageFromHash answering region location names through answer (type, id), and any
  # other message type as the stub does; the stub's own function is put back after.
  def with_messages(answer)
    Object.send(:alias_method, :town_map_v22_message, :pbGetMessageFromHash)
    Object.send(:define_method, :pbGetMessageFromHash) do |type, id|
      type == MessageTypes::REGION_LOCATION_NAMES ? answer.call(type, id) : town_map_v22_message(type, id)
    end
    Object.send(:private, :pbGetMessageFromHash)
    yield
  ensure
    Object.send(:alias_method, :pbGetMessageFromHash, :town_map_v22_message)
    Object.send(:remove_method, :town_map_v22_message)
  end
end
