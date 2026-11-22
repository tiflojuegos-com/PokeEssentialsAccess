class InfiniteFusionSilphNavigationGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    class SilphTarget
      Command = Struct.new(:code, :parameters, :indent)
      attr_reader :id, :name, :x, :y, :tile_id, :character_name, :trigger
      def initialize(map, id, name, point, tile, trigger, list)
        @map_id, @id, @name = map, id, name
        @x, @y = point
        @tile_id, @character_name, @trigger = tile, "", trigger
        @list = list.map { |code, parameters| Command.new(code, parameters, 0) }
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    PokeAccess::Config.puzzle_assist = false
    locator = PokeAccess::Locator
    target = lambda do |map, id, floor, tile|
      SilphTarget.new(map, id, "EV001", [10, 4], tile, 1, [[201, [0, floor, 12, 6, 0, 1]], [0, []]])
    end
    marker = lambda do |map, commands|
      SilphTarget.new(map, 7, "Rock Et", [0, 0], 0, 4, commands)
    end
    probe(:transfers) do
      PokeAccess::Config.language = :en
      [
        target.call(121, 13, 212, 0),
        target.call(660, 2, 666, 734),
        target.call(665, 6, 666, 0),
        target.call(666, 4, 666, 734),
        target.call(121, 1, 108, 0),
        target.call(108, 2, 666, 734),
        target.call(660, 19, 666, 0)
      ].map { |ev| locator.ruled_name(ev) }
    end
    probe(:markers) do
      [
        marker.call(121, [[223, []], [116, []], [0, []]]),
        marker.call(121, [[101, ["Hello"]], [0, []]]),
        marker.call(108, [[223, []], [0, []]])
      ].map { |ev| locator.hidden?(ev) }
    end
    probe(:polish) do
      PokeAccess::Config.language = :pl
      locator.ruled_name(target.call(660, 2, 666, 734))
    end
  RUBY

  profile "infinitefusion", WORLD, PLAY, "gamedata"

  test "Silph elevator, teleport and stairs receive different labels" do
    assert_equal ["Elevator", "Teleport to 8F", "Stairs to 8F", "Teleport on 8F", nil, nil, nil], played(:transfers)
    assert_equal "Teleport na 8F", played(:polish)
  end

  test "only the passive Silph marker is hidden" do
    assert_equal [true, false, false], played(:markers)
  end
end
