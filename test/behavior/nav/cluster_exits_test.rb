# Locator.cluster_exits: a wide doorway (door tiles side by side or at a corner, to one landing) collapses into its
# tile nearest the player (fewest steps away in the walk order), known by its least id; other events pass through.
class ClusterExitsTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "collapses a wide doorway into its tile nearest the player, passing the other events through" do
    d1, d2, d3 = doorway
    npc = World.event(:id => 4, :kind => :npc, :x => 3, :y => 3)
    sign = World.event(:id => 5, :kind => :sign, :x => 4, :y => 3)
    assert_equal [d1, npc, sign], Loc.cluster_exits([d1, d2, d3, npc, sign], 10, 5)
  end

  test "lets the tile nearest the player stand for the doorway from its other end" do
    d1, d2, d3 = doorway
    assert_equal [d3], Loc.cluster_exits([d1, d2, d3], 12, 5)
  end

  test "lets the tile the fewest steps away stand for the doorway in the walk order, the nearest in the near order" do
    $game_map.load_grid(["#########",
                         "#@.#....#",
                         "#..#....#",
                         "#..#....#",
                         "#.......#",
                         "#########"])
    above = door(1, 4, 1)
    below = door(2, 4, 2)
    { :near => [above], :walk => [below] }.each do |order, kept|
      PokeAccess::Config.target_order = order
      assert_equal kept, Loc.cluster_exits([above, below], 1, 1), "in the #{order} order"
    end
  end

  test "knows every tile of a wide doorway by the least id among them" do
    d1, d2, d3 = doorway
    Loc.cluster_exits([d3, d2, d1], 12, 5)
    assert_equal [[:event, 1], [:event, 1], [:event, 1]], [d1, d2, d3].map { |d| Loc.identity(d) }
  end

  test "keeps a door across the room apart, though it leads to the same place" do
    d1, d2, d3 = doorway
    far = door(6, 25, 5)
    assert_equal [d1, far], Loc.cluster_exits([d1, d2, d3, far], 10, 5)
  end

  test "merges door tiles that touch at a corner" do
    a = door(1, 10, 5)
    b = door(2, 11, 6)
    assert_equal [a], Loc.cluster_exits([a, b], 10, 5)
  end

  test "merges side-by-side doors whose landings lie within a tile of each other" do
    a = door(1, 10, 5, [5, 1, 4])
    b = door(2, 11, 5, [5, 2, 5])
    assert_equal [a], Loc.cluster_exits([a, b], 10, 5)
  end

  test "keeps side-by-side doors apart when they lead elsewhere" do
    { "another map" => [6, 1, 1], "a landing two tiles to the side" => [5, 3, 1],
      "a landing two tiles down" => [5, 1, 3] }.each do |what, dest|
      a = door(1, 10, 5, [5, 1, 1])
      b = door(2, 11, 5, dest)
      assert_equal [a, b], Loc.cluster_exits([a, b], 10, 5), what
    end
  end

  test "merges side-by-side doors that call the same transfer script" do
    a = scripted_door(1, 10, 5, "pbTransferWithTransition(7, 3, 4)")
    b = scripted_door(2, 11, 5, "pbTransferWithTransition(7, 3, 4)")
    assert_equal [a], Loc.cluster_exits([a, b], 10, 5)
  end

  test "keeps apart side-by-side doors whose scripts take the player to other maps" do
    a = scripted_door(1, 10, 5, "pbTransferWithTransition(7, 3, 4)")
    b = scripted_door(2, 11, 5, "pbTransferWithTransition(8, 3, 4)")
    assert_equal [a, b], Loc.cluster_exits([a, b], 10, 5)
  end

  test "merges side-by-side exits by name drawn with one doorway sprite" do
    a = named_exit(1, 10, 5, "doors3")
    b = named_exit(2, 11, 5, "doors3")
    assert_equal [a], Loc.cluster_exits([a, b], 10, 5)
  end

  test "keeps side-by-side exits by name with two doorway sprites apart" do
    a = named_exit(1, 10, 5, "doors3")
    b = named_exit(2, 11, 5, "stairs1")
    assert_equal [a, b], Loc.cluster_exits([a, b], 10, 5)
  end

  test "returns a single event, or a list without two doors, as it came" do
    npc = World.event(:id => 4, :kind => :npc, :x => 3, :y => 3)
    sign = World.event(:id => 5, :kind => :sign, :x => 4, :y => 3)
    d = door(1, 10, 5)
    [[npc], [npc, sign], [d, npc]].each do |list|
      assert_same list, Loc.cluster_exits(list, 0, 0), list.map { |e| e.id }.inspect
    end
  end

  test "returns the list as it came when an event fails to be read" do
    d1, d2, d3 = doorway
    def d2.x; raise "gone"; end
    list = [d1, d2, d3]
    assert_same list, Loc.cluster_exits(list, 10, 5)
  end

  test "passes through an event it cannot tell a door, still collapsing the doorway" do
    d1, d2, d3 = doorway
    odd = World.event(:id => 7, :kind => :npc, :x => 3, :y => 3)
    def odd.id; raise "gone"; end
    assert_equal [d1, odd], Loc.cluster_exits([d1, d2, d3, odd], 10, 5)
  end

  private

  # A player-touch door on (x, y), event id, transferring to [map, x, y].
  def door(id, x, y, dest = [5, 1, 1])
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0] + dest)])
  end

  # Three door tiles side by side, (10..12, 5), to one landing: events 1, 2 and 3, in the near order, which counts from
  # the tile a test passes rather than from where the player stands.
  def doorway
    PokeAccess::Config.target_order = :near
    [door(1, 10, 5), door(2, 11, 5), door(3, 12, 5)]
  end

  # A player-touch door on (x, y) whose script line transfers the player.
  def scripted_door(id, x, y, script)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(355, [script])])
  end

  # An exit by name, Salida, drawn with sprite and running a script that is no transfer.
  def named_exit(id, x, y, sprite)
    World.touch(:id => id, :name => "Salida", :x => x, :y => y, :sprite => sprite,
                :list => [TestCmd.new(355, ["pbCaveExit"])])
  end
end
