# The obstacles a field move or a game's item clears (Routes::Effects.gate_at) and what the guides say at them: read
# by the event's name, by the field move its script calls when the name gives nothing away, or by a game's own rule
# (field_gate); named, with what clears it, under a game's own profile, and alone under the generic profile, whose
# game nobody checked (FieldMoves.named?).
class FieldGatesTest < PokeAccessTest
  test "an obstacle with no name of its own is read by the field move its branch tests" do
    ev = obstacle("EV030", [TestCmd.new(111, [12, "pbCut"])])
    assert_equal [:loc_cut_tree, :CUT, nil], gate_parts
    assert_equal t(:loc_cut_tree), PokeAccess::Locator.target_name(ev)
  end

  test "an obstacle named its own way keeps its name and is cleared all the same" do
    obstacle("Glass", [TestCmd.new(111, [12, "Kernel.pbRockSmash"])])
    assert_equal [:loc_rock_smash, :ROCKSMASH, nil], gate_parts
    move = PokeAccess::FieldMoves.name(:ROCKSMASH)
    assert_equal t(:loc_gate_use, :what => "Glass", :dir => t(:side_right), :move => move), text.hold(gate, 2, 1)
  end

  test "the editor's flags after a name do not hide a stock obstacle" do
    obstacle("Tree/NoShadow/", [])
    assert_equal [:loc_cut_tree, :CUT, nil], gate_parts
  end

  test "a rock's random encounter alone makes no obstacle" do
    obstacle("EV031", [TestCmd.new(355, ["Kernel.pbRockSmashRandomEncounter"])])
    assert_nil gate
  end

  test "a game's own obstacle is named by its label and cleared by its item" do
    PokeAccess::Routes::Effects.field_gate(/pbDeleteItem\(:HACHAENDEBLE/, :loc_bush, :HACHAENDEBLE)
    ev = obstacle("EV012", [TestCmd.new(355, ["$PokemonBag.pbDeleteItem(:HACHAENDEBLE,1)"])])
    assert_equal [:loc_bush, nil, :HACHAENDEBLE], gate_parts
    assert_equal t(:loc_bush), PokeAccess::Locator.target_name(ev)
    axe = PokeAccess::FieldMoves.item_name(:HACHAENDEBLE)
    right = t(:side_right)
    with_bag([]) do
      assert_equal t(:loc_gate_need, :what => t(:loc_bush), :dir => right, :move => axe), text.hold(gate, 2, 1)
      assert_equal t(:loc_gate_route_need, :what => t(:loc_bush), :move => axe), text.gate_route(gate)
    end
    with_bag([:HACHAENDEBLE]) do
      assert_equal t(:loc_gate_use, :what => t(:loc_bush), :dir => right, :move => axe), text.hold(gate, 2, 1)
      assert_equal t(:loc_gate_route, :what => t(:loc_bush), :move => axe), text.gate_route(gate)
    end
  end

  test "the generic profile says the obstacle without what clears it" do
    obstacle("Tree", [])
    tree = t(:loc_cut_tree)
    right = t(:side_right)
    assert_equal t(:loc_gate_use, :what => tree, :dir => right, :move => PokeAccess::FieldMoves.name(:CUT)),
                 text.hold(gate, 2, 1)
    load File.join(Harness::ROOT, "games", "generic", "constants.rb")
    assert_equal t(:loc_gate_bare, :what => tree, :dir => right), text.hold(gate, 2, 1)
    assert_equal t(:loc_gate_route_bare, :what => tree), text.gate_route(gate)
  end

  test "says an obstacle to the left or right with the side it lies on, and up or down as such" do
    obstacle("Glass", [TestCmd.new(111, [12, "Kernel.pbRockSmash"])])
    move = PokeAccess::FieldMoves.name(:ROCKSMASH)
    said = [[2, 1], [4, 1], [3, 2], [3, 0]].map { |x, y| text.hold(gate, x, y) }
    sides = [:side_right, :side_left, :side_up, :side_down]
    assert_equal sides.map { |s| t(:loc_gate_use, :what => "Glass", :dir => t(s), :move => move) }, said
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  def text; PokeAccess::Routes::Text; end

  def gate; PokeAccess::Routes::Effects.gate_at(3, 1); end

  # The gate's label, move and item, or nil with no gate.
  def gate_parts
    g = gate
    g && [g[:label], g[:move], g[:item]]
  end

  # Lays a corridor the player stands in at (2,1), closed at (3,1) by a solid event with this name and page.
  def obstacle(name, list)
    $game_map.load_grid(["#######", "#.@...#", "#######"])
    ev = World.touch(:id => 70, :name => name, :x => 3, :y => 1, :trigger => 0, :sprite => "obstacle", :list => list)
    ev.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end

  # Runs the block with a bag holding just these items.
  def with_bag(items)
    was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
    yield
  ensure
    $PokemonBag = was
  end

  def teardown
    World.clear_events
    $game_map.clear_grid
    super
  end
end
