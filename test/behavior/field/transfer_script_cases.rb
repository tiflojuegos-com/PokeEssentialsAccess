# Shared cases of transfer_script_test and transfer_script_gd_test: a script call is a door when a pattern, shipped or
# a profile's, captures digits for its map, read whole over its 655 lines; autorun and parallel pages never are.
module TransferScriptCases
  # A profile's pattern for a game's own door call, getToDungeon(<map>) and its regional twins.
  DUNGEON = /\bgetTo\w*Dungeon\s*\(\s*(\d+)/

  # Defines the shared cases and their helpers on base, the test class of one engine's pass.
  def self.define(base)
    base.class_eval do
      test "the shipped patterns read the map a pbTransfer call or a player_new_map_id assignment names" do
        calls = { "pbTransferPlayer(42,10,20)" => 42, "pbTransferWithTransition( 7, 3, 4)" => 7,
                  "$game_temp.player_new_map_id = 17" => 17, "pbMessage(\"42\")" => nil }
        assert_equal calls, calls.map { |call, _| [call, loc.transfer_script_dest(script_tile(call))] }.to_h
      end

      test "a sprite-less touch tile whose script transfers is a door: among the exits, in all, pinged as a door" do
        assert_equal [42, true, true, true, :door], door_state(script_tile("pbTransferPlayer(42,10,20)"))
      end

      test "a call no pattern knows is no door until a profile's pattern captures its map" do
        ev = script_tile("getToDungeon(319)")
        before = door_state(ev)
        after = with_pattern(TransferScriptCases::DUNGEON) { door_state(ev) }
        assert_equal [[nil, false, false, false, nil], [319, true, true, true, :door]], [before, after]
      end

      test "a profile's pattern adds to the shipped ones, which still answer" do
        with_pattern(TransferScriptCases::DUNGEON) do
          assert_equal 42, loc.transfer_script_dest(script_tile("pbTransferPlayer(42,10,20)"))
        end
      end

      test "a door a profile's pattern finds is named as an exit, not by its editor note" do
        with_pattern(TransferScriptCases::DUNGEON) do
          noted = tile([TestCmd.new(355, ["getToDungeon(319)"])], 1, "size(3,1)")
          assert_equal PokeAccess::I18n.t(:loc_exit), loc.target_name(noted)
        end
      end

      test "a pattern gives a destination only when its first group captures digits" do
        cases = { [/\bwarpTo\(\s*(\w+)/, "warpTo(12)"] => 12, [/\bwarpTo\(\s*(\w+)/, "warpTo(dungeonmaps)"] => nil,
                  [/\bteleportHome\b/, "teleportHome"] => nil }
        got = cases.map do |(re, call), _|
          [[re, call], with_pattern(re) { loc.transfer_script_dest(script_tile(call)) }]
        end
        assert_equal cases, got.to_h
      end

      test "a pattern's block answers where the call leads, a map id or the map with its landing" do
        { 319 => [319, nil, nil], [319, 7, 9] => [319, 7, 9], [319, 7] => [319, 7, nil] }.each do |answer, dest|
          with_pattern(/^\s*go_in\(/, lambda { |_m| answer }) do
            assert_equal dest, loc.script_transfer_dest("go_in(:TOWN)"), answer.inspect
            assert_equal [319, true, true, true, :door], door_state(script_tile("go_in(:TOWN)")), answer.inspect
          end
        end
      end

      test "a pattern's block gets the match" do
        with_pattern(/^\s*go_in\(\s*:(\w+)/, lambda { |m| m[1] == "MART" ? 5 : 6 }) do
          assert_equal [5, 6], ["go_in(:MART)", "go_in(:CENTER)"].map { |s| loc.script_transfer_map(s) }
        end
      end

      test "a call that names no map is still a door: said as an exit, and a route ends on it" do
        [[/^\s*go_back\b/, nil], [/^\s*go_back\b/, lambda { |_m| nil }], [/^\s*go_back\b/, lambda { |_m| raise "no" }],
         [/^\s*(go_back)\b/, nil]].each do |re, dest|
          with_pattern(re, dest) do
            ev = script_tile("go_back")
            assert_equal [nil, nil, nil], loc.script_transfer_dest("go_back")
            assert_equal [nil, true, true, true, :door], door_state(ev)
            assert_equal PokeAccess::I18n.t(:loc_exit), loc.target_name(tile([TestCmd.new(355, ["go_back"])], 1, "EV091"))
            assert_equal [:exit], touch_effect(ev)
          end
        end
      end

      test "a sign that also calls a door with no named map is a door" do
        with_pattern(/^\s*go_back\b/) do
          ev = tile([TestCmd.new(101, ["Hasta luego."]), TestCmd.new(355, ["go_back"])], 0)
          assert_equal [false, true], [loc.sign_event?(ev), loc.transfer_event?(ev)]
        end
      end

      test "of two patterns that match, the one that names a map wins whichever comes first" do
        with_pattern(/^\s*go_back\b/) do
          call = "go_back\npbTransferPlayer(42,10,20)"
          assert_equal [42, 10, 20], loc.script_transfer_dest(call)
        end
        with_pattern(/\bpbTransferPlayer\b/) do
          assert_equal [42, 10, 20], loc.script_transfer_dest("pbTransferPlayer(42,10,20)")
        end
      end

      test "a page that is not live or an autorun page is no door, however a pattern matches" do
        with_pattern(/^\s*go_back\b/) do
          assert_equal false, loc.transfer_event?(script_tile("go_back", 3))
          assert_equal false, loc.transfer_event?(script_tile("go_back", 4))
          assert_equal false, loc.transfer_event?(script_tile("pbMessage(\"go_back\")"))
        end
      end

      test "a call split across a 355 line and its 655 continuations is read whole" do
        calls = { ["pbTransferWithTransition(", "32,10,1,:DIRECTED)"] => 32,
                  ["pbTransferWithTransition(", "32,10,1,", ":DIRECTED, 8)"] => 32,
                  ["pbMessage(\"...\")", "$game_temp.player_new_map_id = 17"] => 17 }
        got = calls.map { |lines, _| [lines, loc.transfer_script_dest(tile(script_cmds(lines)))] }
        assert_equal calls, got.to_h
      end

      test "a continuation joins the call just before it, and the calls before that stay as they were" do
        lists = { [["pbMessage(1)"], ["pbTransferWithTransition(", "32,10,1)"]] => 32,
                  [["pbTransferPlayer(7,1,1)"], ["pbMessage(", "\"...\")"]] => 7 }
        got = lists.map { |calls, _| [calls, loc.transfer_script_dest(tile(script_cmds(*calls)))] }
        assert_equal lists, got.to_h
      end

      test "a continuation with no call before it is read as a call of its own" do
        assert_equal 5, loc.transfer_script_dest(tile([TestCmd.new(655, ["pbTransferPlayer(5,1,1)"])]))
      end

      test "an autorun or parallel page is never a door, whatever its script calls" do
        doors = { 0 => true, 1 => true, 2 => true, 3 => false, 4 => false }
        got = doors.map { |trig, _| [trig, loc.transfer_event?(script_tile("pbTransferPlayer(5,1,1)", trig))] }
        assert_equal doors, got.to_h
      end

      test "a tile that shows text is a sign, unless its script transfers: then it is a door" do
        text = TestCmd.new(101, ["Al otro lado del puente."])
        sign = tile([text], 0)
        door = tile([text, TestCmd.new(355, ["pbTransferPlayer(5,1,1)"])], 0)
        got = [sign, door].map { |ev| [loc.sign_event?(ev), loc.transfer_event?(ev)] }
        assert_equal [[true, false], [false, true]], got
      end

      test "a script transfer lands on pbTransfer's coordinates or on player_new_x and y, else on an unknown tile" do
        to17 = "$game_temp.player_new_map_id = 17"
        calls = { "pbTransferPlayer(42,10,20)" => [42, 10, 20],
                  "#{to17}\n$game_temp.player_new_x = 3\n$game_temp.player_new_y = 4" => [17, 3, 4],
                  "#{to17}\n$game_temp.player_new_x = 3" => [17, nil, nil], "pbTransferPlayer(42)" => [42, nil, nil],
                  "pbTransferPlayer(1)\npbTransferPlayer(42,10,20)" => [1, nil, nil], "pbMessage(1)" => nil,
                  "pbTransferPlayer(1)\n#{to17}" => [1, nil, nil] }
        assert_equal calls, calls.map { |call, _| [call, loc.script_transfer_dest(call)] }.to_h
      end

      private

      def loc; PokeAccess::Locator; end

      # A sprite-less tile on the map whose active page runs cmds, by touch unless trigger says otherwise.
      def tile(cmds, trigger = 1, name = "Entrada")
        World.touch(:id => 91, :x => 6, :y => 8, :name => name, :trigger => trigger, :list => cmds)
      end

      # The same tile running one script call.
      def script_tile(script, trigger = 1)
        tile([TestCmd.new(355, [script])], trigger)
      end

      # The commands of script calls, each given as its lines: the first on a 355, the rest on 655 continuations.
      def script_cmds(*calls)
        calls.flat_map { |lines| [TestCmd.new(355, [lines[0]])] + lines[1..-1].map { |l| TestCmd.new(655, [l]) } }
      end

      # What the locator and the soundscape make of a tile: its script destination, whether it is a door, among the
      # exits, in all, and the family it pings as.
      def door_state(ev)
        [loc.transfer_script_dest(ev), loc.transfer_event?(ev), loc.in_category?(ev, :exits),
         loc.in_category?(ev, :all), PokeAccess::Sound::Scene.family_of(ev)]
      end

      # What a route makes of stepping onto a tile from above.
      def touch_effect(ev)
        PokeAccess::Routes::Effects.touch_effect_of(PokeAccess::EventPages.outcome(ev, 2), 2, nil, $game_map.map_id)
      end

      # The block's value with re registered as a profile registers it, dest answering where it leads if given; the
      # patterns as they were put back after.
      def with_pattern(re, dest = nil)
        saved = PokeAccess::Locator::TRANSFER_SCRIPTS.dup
        PokeAccess::Locator.register_transfer_script(re, &dest)
        PokeAccess::Locator.clear_verdicts
        yield
      ensure
        PokeAccess::Locator::TRANSFER_SCRIPTS.replace(saved)
        PokeAccess::Locator.clear_verdicts
      end
    end
  end
end
