# Base Ranger 01's first floor (map 47) on the shipped profile: every wrong tile of a test is named by its type and left
# out with the assist, and the green teleport pad that sends the player back to the entrance is named and says so.
class RevivalRangerGdTest < PokeAccessTest
  test "names the second wrong tile of the Normal test and leaves it out with the assist" do
    on_map(47)
    place(2, 14, 14, "botontipo1")
    place(11, 11, 15, "")
    place(56, 11, 17, "")
    place(10, 11, 19, "")
    icon = t(:rv_ranger_icon, :type => type(:NORMAL))
    right = t(:rv_ranger_tile, :type => type(:FIGHTING))
    assert_equal [icon, right, t(:rv_ranger_tile, :type => type(:ELECTRIC)), t(:rv_ranger_tile, :type => type(:DRAGON))],
                 names, "in the map's order: event 56 (11, 17) shows Electric, event 10 (11, 19) Dragon"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [icon, right], names
  end

  test "keeps the routes off every wrong tile and the pad" do
    on_map(47)
    avoided = PokeAccess::World::Mechanics.instance.spec[:avoids].map { |ids| ids.keys }.flatten
    [10, 56, 17, 18, 26, 28, 31, 32, 33].each { |id| assert_includes avoided, id }
  end

  test "names the pad, and says the pad rather than a wrong type when it sends the player back" do
    on_map(47)
    pad = place(33, 41, 27, "")
    assert_equal :rv_ranger_pad, named_label(pad)
    assert_empty names, "named for the exits, not listed among the puzzles"
    on_map(46)
    assert_equal t(:rv_ranger_pad_back), PokeAccess::Puzzles.sent_back_line([41, 27, 47], [16, 22, 46], :map)
    assert_equal t(:rv_ranger_wrong), PokeAccess::Puzzles.sent_back_line([11, 17, 47], [16, 22, 46], :map)
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A type's name as the data provider gives it.
  def type(id); PokeAccess::Data.type_name(id); end

  # Declares the shipped puzzles and puts the player on map with every test still to pass.
  def on_map(map)
    Harness.load_puzzles("revival")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    (154..158).each { |s| $game_switches[s] = false }
    World.next_frame
  end

  # A touch event at (x, y) drawn with sprite, placed on the map.
  def place(id, x, y, sprite)
    page = TestPage.new(:trigger => 1, :sprite => sprite, :list => [TestCmd.new(201, [0, 46, 16, 22])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The label the map's declaration names an event by.
  def named_label(ev)
    entry = PokeAccess::World::Mechanics.instance.spec[:names].find { |n| n[:events][ev.id] }
    entry && entry[:label]
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map(&:name)
  end
end
