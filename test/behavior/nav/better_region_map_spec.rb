# The BetterRegionMap addon, the region map both Infinite Fusion games install instead of the standard one; the stub
# keeps its shape: point rows with a place name and a point of interest, and a flyable set the screen builds itself.
module PaBetterRig
  # Adds the regionMapSel cursor global, which only this screen uses, to the harness's $PokemonGlobal.
  def self.arm_global
    return if $PokemonGlobal.respond_to?(:regionMapSel)
    def $PokemonGlobal.regionMapSel; @pa_sel ||= [0, 0]; end
    def $PokemonGlobal.regionMapSel=(v); @pa_sel = v; end
  end

  class Scene
    attr_accessor :data, :spots, :region
    def initialize(rows, spots, can_fly = true)
      @data = [nil, nil, rows]
      @spots = spots
      @region = 0
      @can_fly = can_fly
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

    eq "a square with no row at all is named by its coordinates",
       bm.square_text(scene, 9, 9), PokeAccess::I18n.t(:brm_square, :x => 9, :y => 9)

    fly = PokeAccess::I18n.t(:brm_fly)
    rows = vb_levels { bm.square_text(scene, 3, 4) }
    eq "brief: the place and whether one can fly there", rows[0], "Pueblo Paleta, #{fly}"
    eq "medium: its point of interest too", rows[1], "Pueblo Paleta, Laboratorio, #{fly}"
    PokeAccess::Config.verbosity = :brief
    bm.square_text(scene, 3, 4)
    PokeAccess::Config.verbosity = :full
    eq "the info key keeps the whole square", PokeAccess::Info.info_text, rows[2]
  ensure
    ($PokemonGlobal.regionMapSel = saved rescue nil)
  end
end

# The provider is picked by the scene's shape; the fly points are the screen's own @spots, not the generic
# pbGetHealingSpot rule (nil for every square here).
Suite.define("nav/better map: the cursor provider is picked by shape and the flyable set is the screen's own") do
  tm = PokeAccess::TownMap
  PaBetterRig.arm_global
  saved = ($PokemonGlobal.regionMapSel rescue nil)
  begin
    rows = [[3, 4, "Pueblo Paleta", nil], [5, 4, "Ruta 1", nil], [7, 4, "Ciudad Verde", nil]]
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

# A map opened with flying off (Infinite Fusion Hoenn's quest map) offers no fly points, whatever its @spots hold.
Suite.define("nav/better map: a map opened without flying marks no square as flyable") do
  rows = [[3, 4, "Pueblo Paleta", nil]]
  quests = PaBetterRig::Scene.new(rows, { [3, 4] => [:quest] }, false)
  eq "the quest's place is just its name", PokeAccess::BetterMap.square_text(quests, 3, 4), "Pueblo Paleta"
  eq "and the fly jump finds nowhere to go", PokeAccess::TownMap.fly_points(quests), []
  fly = PaBetterRig::Scene.new(rows, { [3, 4] => [:town] }, true)
  eq "while a map opened to fly jumps between its spots", PokeAccess::TownMap.fly_points(fly), [[3, 4]]
end

# The player's "you are here" icon: a sprite in the scrolled @window (Marin's SpriteHash, whose x and y are the
# scroll), centred on its square; that square says so, and a map drawn without the icon marks none.
Suite.define("nav/better map: the square under the player's icon says so, wherever the map has scrolled") do
  bm = PokeAccess::BetterMap
  sprite = Struct.new(:x, :y, :bitmap, :visible)
  hash = Struct.new(:x, :y, :player) do
    def [](key); key.to_s == "player" ? player : nil; end
  end
  rows = [[3, 4, "Pueblo Paleta", nil], [5, 4, "Ruta 1", nil]]
  scene = PaBetterRig::Scene.new(rows, {})
  scene.instance_variable_set(:@window, hash.new(-32, 0, sprite.new(16 * 3 + 8 - 32, 16 * 4 + 8, :icon, true)))
  you = PokeAccess::I18n.t(:rmap_you)
  eq "the icon's square, the map scrolled two squares left", bm.square_text(scene, 3, 4), "Pueblo Paleta, #{you}"
  eq "any other square is just itself", bm.square_text(scene, 5, 4), "Ruta 1"
  scene.instance_variable_set(:@window, hash.new(0, 0, sprite.new(0, 0, nil, true)))
  eq "a map opened without the player's icon marks no square", bm.square_text(scene, 0, 0),
     PokeAccess::I18n.t(:brm_square, :x => 0, :y => 0)
end
