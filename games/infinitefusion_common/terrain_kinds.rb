# Infinite Fusion's own terrain tags that are a standard surface under another name: its other grasses (clovers, dry
# grass, flowers and a fourth, all with wild encounters), the middle of its tall grass, its deep sand and beach, its
# river water and its suspended bridges. Each is classed as the core's kind, so routes, the surface labels and the
# grass step meet it as that surface. Its snow, mud and cliffs carry the core's own ids; the tags with no standard
# surface (cut grass, the top of the tall grass) stay unclassed.
module PokeAccess
  module IFTerrainKinds
    # The game's tag id => the core's kind.
    KINDS = {
      :Grass_alt1 => :grass, :Grass_alt2 => :grass, :Grass_alt3 => :grass, :Grass_alt4 => :grass,
      :TallGrassMiddle => :tall_grass, :DeepSand => :sand, :Beach => :sand, :RiverWater => :water,
      :SuspendedBridgeVertical => :bridge, :SuspendedBridgeHHorizontal => :bridge
    }

    # The kind of a raw tag value this table names, or nil; an Integer (no tag object) names none.
    def self.kind(t)
      return nil if t.is_a?(Integer) || !t.respond_to?(:id)
      KINDS[(t.id rescue nil)]
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::World::Terrain", :kind_of) do |_terrain, original, args|
    PokeAccess::IFTerrainKinds.kind(args[0]) || original.call
  end
end
