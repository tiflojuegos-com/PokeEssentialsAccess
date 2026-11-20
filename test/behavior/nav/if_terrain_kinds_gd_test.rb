# Infinite Fusion's own terrain tags that are a standard surface under another name (games/infinitefusion_common/
# terrain_kinds.rb): its other grasses, the middle of its tall grass, its sands, its river water and its suspended
# bridges take the core's kind, and every other tag is classed as the core classes it.

# The common's file, evaluated once as boot does, its profile name taken back out.
if_kinds_path = File.join(Harness::ROOT, "games", "infinitefusion_common", "terrain_kinds.rb")
if_kinds_profiles = PokeAccess::Game.profiles.dup
if_kinds_name = PokeAccess::Game.instance_variable_get(:@profile_name)
begin
  eval(Harness.source(if_kinds_path), TOPLEVEL_BINDING, if_kinds_path)
ensure
  PokeAccess::Game.profiles.replace(if_kinds_profiles)
  PokeAccess::Game.instance_variable_set(:@profile_name, if_kinds_name)
end

class IfTerrainKindsGdTest < PokeAccessTest
  Terrain = PokeAccess::World::Terrain
  # A modern terrain tag stand-in: its id and its number.
  Tag = Struct.new(:id, :id_number)

  test "classes the game's other grasses as grass, with the grass bit" do
    [[:Grass_alt1, 24], [:Grass_alt2, 25], [:Grass_alt3, 26], [:Grass_alt4, 47]].each do |id, n|
      tag = Tag.new(id, n)
      assert_equal :grass, Terrain.kind_of(tag), id.to_s
      assert_equal Terrain::GRASS, Terrain.bits_of(tag) & Terrain::GRASS, id.to_s
    end
  end

  test "classes the middle of the tall grass, the sands, the river and the suspended bridges as their surfaces" do
    { :TallGrassMiddle => :tall_grass, :DeepSand => :sand, :Beach => :sand, :RiverWater => :water,
      :SuspendedBridgeVertical => :bridge, :SuspendedBridgeHHorizontal => :bridge }.each do |id, kind|
      assert_equal kind, Terrain.kind_of(Tag.new(id, 40)), id.to_s
    end
  end

  test "leaves the standard tags, the game's tags with no standard surface and bare numbers to the core" do
    assert_equal :grass, Terrain.kind_of(Tag.new(:Grass, 2)), "a standard id"
    assert_equal :bridge, Terrain.kind_of(Tag.new(:Bridge, 4)), "a standard id renumbered"
    { :Snow => [44, :snow], :Cliff => [45, :cliff], :Mud => [46, :mud] }.each do |id, (n, kind)|
      assert_equal kind, Terrain.kind_of(Tag.new(id, n)), "#{id}: a standard id with no standard number"
    end
    assert_nil Terrain.kind_of(Tag.new(:CutGrass, 35)), "no standard surface"
    assert_nil Terrain.kind_of(Tag.new(:TallGrassTop, 36)), "the tall grass's top row, with no encounters"
    assert_equal :grass, Terrain.kind_of(2), "a bare number"
  end
end
