# Soulstones 2's way out of the penthouse (games/soulstones2/naming.rb): the one event of its script that is a door.
naming = File.join(Harness::ROOT, "games", "soulstones2", "naming.rb")
eval(Harness.source(naming), TOPLEVEL_BINDING, naming)

class Ss2NamingGdTest < PokeAccessTest
  Loc = PokeAccess::Locator
  # The script the penthouse's exit and the game's naps share: the map comes from a variable.
  LEAVE = "$game_temp.player_new_map_id = pbGet(993)".freeze

  test "the penthouse's way out is a door, among the exits" do
    ev = tile("Leave B9K Penthouse")
    assert_equal [true, true], [Loc.transfer_event?(ev), Loc.in_category?(ev, :exits)]
  end

  test "a nap with the same script stays what it was" do
    ev = tile("Size(2,3)")
    assert_equal [false, false], [Loc.transfer_event?(ev), Loc.in_category?(ev, :exits)]
  end

  test "any other door is still one" do
    ev = World.touch(:id => 92, :x => 7, :y => 8, :name => "Entrada", :trigger => 1,
                     :list => [TestCmd.new(355, ["pbTransferPlayer(5,1,1)"])])
    assert_equal true, Loc.transfer_event?(ev)
  end

  private

  # A sprite-less touch tile running the shared script, under a name.
  def tile(name)
    World.touch(:id => 91, :x => 6, :y => 8, :name => name, :trigger => 1, :list => [TestCmd.new(355, [LEAVE])])
  end
end
