# The region map of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/region_map_rv.rb) draws an
# icon for each roaming Pokemon still loose (RoamingSpecies, one entry per roamer, its icon the scene's roaming<i>
# sprite centred on its square).
Harness.load_common("rv_common")

module RvMapRig
  Pic = Struct.new(:width, :height)
  Icon = Struct.new(:x, :y, :bitmap)

  # A map scene with the square size and the sprites that engine uses.
  class Roaming
    SQUAREWIDTH = 16
    SQUAREHEIGHT = 16

    def initialize(sx, sy)
      map = Icon.new(0, 0, Pic.new(480, 320))
      left = (Graphics.width - 480) / 2
      top = (Graphics.height - 320) / 2
      mark = Pic.new(24, 24)
      icon = Icon.new(SQUAREWIDTH / 2 - 12 + sx * SQUAREWIDTH + left, SQUAREHEIGHT / 2 - 12 + sy * SQUAREHEIGHT + top, mark)
      @sprites = { "map" => map, "roaming0" => icon }
    end

    def pbGetMapLocation(_x, _y); "Route 1"; end
  end

  # A map with none of those icons.
  class Plain
    def initialize; @sprites = {}; end
  end
end

RoamingSpecies = [{ :species => 384, :roamgraphic => "Graphics/Pictures/rayquazaMarker" }] unless defined?(RoamingSpecies)

Suite.define("region map: a square with a roaming Pokemon's icon names it after the place") do
  scene = RvMapRig::Roaming.new(5, 3)
  name = PokeAccess::Data.species_name(384)
  eq "the square the icon sits on says the roamer", PokeAccess::RegionMap.square_text(scene, "Route 1", 5, 3), "Route 1, #{name}"
  eq "another square does not", PokeAccess::RegionMap.square_text(scene, "Route 1", 6, 3), "Route 1"
  eq "a map with no such icons is as before", PokeAccess::RegionMap.square_text(RvMapRig::Plain.new, "Route 1", 5, 3), "Route 1"
end
