# Silph Co.'s floor pads, stairs and elevator entrances in Infinite Fusion Kanto (games/infinitefusion/silph_navigation.rb)
# on the shipped profile, over events shaped as the game's maps keep them and the game's names for those maps.
class InfiniteFusionSilphNavigationGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    require File.join(Harness::ROOT, "test", "support", "world_builder")

    # The names pbGetMapNameFromId gives the Silph Co. maps in the game (MapInfos): 1F and the elevator take the
    # building's; 6F is map 758, and map 664, which page 1 of two staircases still leads to, has none.
    SILPH_MAP_NAMES = { 121 => "Silph Co.", 212 => "Silph Co.", 660 => "2F", 661 => "3F", 662 => "4F", 663 => "5F",
                        758 => "6F", 665 => "7F", 666 => "8F", 667 => "9F", 668 => "10F", 757 => "11F" }

    def pbGetMapNameFromId(id)
      SILPH_MAP_NAMES[id].to_s
    end

    # A Silph Co. event as Game_Event keeps it: the map it stands on, its trigger and its pages, each a command list,
    # the second shown while switch 825 is on, as the game picks it.
    class SilphTarget < TestGameEvent
      attr_reader :trigger

      def initialize(map, id, name, point, tile, trigger, *lists)
        pages = lists.map do |list|
          TestPage.new(:trigger => trigger, :list => list.map { |code, parameters| TestCmd.new(code, parameters) })
        end
        pages[1].condition = TestCondition.new(:switch1_valid => true, :switch1_id => 825) if pages[1]
        active = ($game_switches[825] && pages[1]) || pages[0]
        super(:id => id, :name => name, :x => point[0], :y => point[1], :tile_id => tile, :pages => pages,
              :active_page => active)
        @map_id = map
        @trigger = trigger
      end
    end
  RUBY

  PLAY = <<-'RUBY'
    PokeAccess::Config.puzzle_assist = false

    # A touch event on map at id, drawn with tile, one page per destination map, each a transfer there.
    def touch(map, id, tile, *destinations)
      lists = destinations.map { |dest| [[201, [0, dest, 12, 6, 0, 1]], [0, []]] }
      SilphTarget.new(map, id, "EV#{id}", [10, 4], tile, 1, *lists)
    end

    def marker(map, commands)
      SilphTarget.new(map, 7, "Rock Et", [0, 0], 0, 4, commands)
    end

    # The names the profile's rule gives events built with switch 825 as given.
    def ruled(switch)
      $game_switches[825] = switch
      yield.map { |ev| PokeAccess::Locator.ruled_name(ev) }
    ensure
      $game_switches[825] = false
    end

    # The name the locator says for the 7F pad P (event 4), placed on that floor, leading to the map given.
    def office_pad(destination)
      $game_map.map_id = 665
      $game_map.events.clear
      pad = $game_map.events[4] = touch(665, 4, 734, destination)
      PokeAccess::World::Mechanics.forget
      World.next_frame
      [PokeAccess::Locator.ruled_name(pad), PokeAccess::Locator.target_name(pad)]
    ensure
      $game_map.events.clear
    end

    probe(:transfers) do
      PokeAccess::Config.language = :en
      ruled(false) do
        [touch(121, 13, 0, 212), touch(660, 2, 734, 666), touch(665, 6, 0, 666), touch(666, 4, 734, 666),
         touch(660, 7, 0, 121), touch(121, 1, 0, 108), touch(108, 2, 734, 666), touch(660, 19, 0, 666)]
      end
    end
    probe(:switch_stairs) do
      PokeAccess::Config.language = :en
      [false, true].map { |on| ruled(on) { [touch(663, 7, 0, 664, 758), touch(665, 7, 0, 664, 758)] } }
    end
    probe(:markers) do
      [
        marker(121, [[223, []], [116, []], [0, []]]),
        marker(121, [[101, ["Hello"]], [0, []]]),
        marker(108, [[223, []], [0, []]])
      ].map { |ev| PokeAccess::Locator.hidden?(ev) }
    end
    probe(:polish) do
      PokeAccess::Config.language = :pl
      ruled(false) { [touch(660, 2, 734, 666)] }.first
    end
    probe(:office_pad) do
      PokeAccess::Config.language = :en
      [office_pad(757), office_pad(666), PokeAccess::I18n.t(:ifx_silph_office_pad)]
    end
  RUBY

  profile "infinitefusion", WORLD, PLAY, "gamedata"

  test "Silph elevator, teleport and stairs receive different labels, each floor by the game's name for it" do
    assert_equal ["Elevator", "Teleport to 8F", "Stairs to 8F", "Teleport on 8F", "Stairs to Silph Co.", nil, nil, nil],
                 played(:transfers)
    assert_equal "Teleport na 8F", played(:polish)
  end

  test "the 5F and 7F stairs say 6F only on the page switch 825 shows, page 1 leading to map 664, gone from the game" do
    assert_equal [[nil, nil], ["Stairs to 6F", "Stairs to 6F"]], played(:switch_stairs)
  end

  test "the office pad keeps the puzzle's name, wherever its page leads" do
    office, to_floor, label = played(:office_pad)
    assert_equal [nil, label], office
    assert_equal [nil, label], to_floor
  end

  test "only the passive Silph marker is hidden" do
    assert_equal [true, false, false], played(:markers)
  end
end
