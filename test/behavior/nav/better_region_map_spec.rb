# The BetterRegionMap addon, the region map the two Infinite Fusion games install instead of the standard
# one. It is a class of its own, with its own loop and its own cursor in a global, and the mod's region-map
# hooks never bound to it -- the whole screen was silent and nothing said so, because the class those hooks
# name does exist in those games.
#
# The stub copies the real shape, including the two things a generic reader gets wrong: the point rows carry
# a place name AND a point of interest, and the flyable set is a hash the screen built for itself under its
# own rules (this screen has a fly-anywhere mode the standard one does not).
module PaBetterRig
  # The screen keeps its cursor in a global the harness's $PokemonGlobal does not carry, so the accessor is
  # added here rather than in the shared stub: only this one screen uses it.
  def self.arm_global
    return if $PokemonGlobal.respond_to?(:regionMapSel)
    def $PokemonGlobal.regionMapSel; @pa_sel ||= [0, 0]; end
    def $PokemonGlobal.regionMapSel=(v); @pa_sel = v; end
  end

  class Scene
    attr_accessor :data, :spots, :region
    def initialize(rows, spots)
      @data = [nil, nil, rows]
      @spots = spots
      @region = 0
    end
    def move_cursor_to(x, y); $PokemonGlobal.regionMapSel = [x, y]; end
    def update_text; @painted = true; end
    def pbGetHealingSpot(_x, _y); nil; end
  end
end

Suite.define("nav/better map: the square is read with its place, its point of interest and its fly icon") do
  bm = PokeAccess::BetterMap
  PaBetterRig.arm_global
  saved = ($PokemonGlobal.regionMapSel rescue nil)
  begin
    rows = [[3, 4, "Pueblo Paleta", "Laboratorio"], [5, 4, "Ruta 1", nil]]
    scene = PaBetterRig::Scene.new(rows, { [3, 4] => [1, 2, 3] })

    eq "a named square with a point of interest reads both, plus the fly icon the screen drew",
       bm.square_text(scene, 3, 4),
       "Pueblo Paleta, Laboratorio, #{PokeAccess::I18n.t(:brm_fly)}"
    eq "a named square with none of either is just its name", bm.square_text(scene, 5, 4), "Ruta 1"

    # Silence here would make the map feel dead: the cursor DID move, and the screen shows that even where
    # it has no name to put under it.
    eq "a square with no row at all is named by its coordinates",
       bm.square_text(scene, 9, 9), PokeAccess::I18n.t(:brm_square, :x => 9, :y => 9)
  ensure
    ($PokemonGlobal.regionMapSel = saved rescue nil)
  end
end

Suite.define("nav/better map: the cursor provider is picked by shape and the flyable set is the screen's own") do
  tm = PokeAccess::TownMap
  PaBetterRig.arm_global
  saved = ($PokemonGlobal.regionMapSel rescue nil)
  begin
    rows = [[3, 4, "Pueblo Paleta", nil], [5, 4, "Ruta 1", nil], [7, 4, "Ciudad Verde", nil]]
    # pbGetHealingSpot answers nil for every square: the generic rule would find NO fly point at all. The
    # screen still drew two icons, because it applies its own fly-anywhere rule -- so the set it built is
    # the only honest answer, and offering fewer places than the screen shows is as wrong as offering more.
    scene = PaBetterRig::Scene.new(rows, { [3, 4] => [1, 2, 3], [7, 4] => [1, 2, 3] })
    $PokemonGlobal.regionMapSel = [5, 4]

    eq "the provider that handles it is the one for this addon", tm.provider_for(scene)[0], "better_region_map"
    eq "the cursor comes from the global the screen keeps it in", tm.cursor(scene), [5, 4]
    eq "every row is a candidate", tm.points(scene).sort, [[3, 4], [5, 4], [7, 4]]
    eq "but only the squares the screen marked can be flown to", tm.fly_points(scene).sort, [[3, 4], [7, 4]]

    truthy "moving the cursor reports success", tm.move(scene, 7, 4)
    eq "and lands where it was told", tm.cursor(scene), [7, 4]
  ensure
    ($PokemonGlobal.regionMapSel = saved rescue nil)
  end
end
