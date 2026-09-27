# Rejuvenation's region map (games/rejuvenation/region_map.rb), a rework of PokemonRegionMapScene with a @selection
# cursor over $cache.town_map and no pbGetMapLocation: the opening line, each square with its point of interest, fly
# and the player's head, the fly jump through its own provider, and the Pokedex nest page it becomes in mode 2. The
# scene's methods stand in below as the rework defines them; each build is handed to the stub's pbStartScene.
module RejuvMapSpec
  Place = Struct.new(:name, :poi, :flyData, :region)

  class Viewport
    attr_accessor :ox, :oy
    def initialize; @ox = 0; @oy = 0; end
  end

  class Sprite
    attr_accessor :x, :y, :visible
    def initialize(x = 0, y = 0, visible = true); @x = x; @y = y; @visible = visible; end
  end

  def self.town
    { 0 => { :name => "Aevium Region" },
      [5, 5] => Place.new("Gearen City", "Gearen Laboratory", [], 0),
      [9, 5] => Place.new("Route 1", "", [12, 3, 4], 0),
      [40, 5] => Place.new("Oceana Pier", "", [20, 1, 1], 0),
      [2, 9] => Place.new("Far Away", "", [30, 1, 1], 4) }
  end

  # The build of mode 0 or 1: the town map, the cursor on the player's square with the player's head there, and the
  # bottom bar written as the rework writes it.
  def self.map_build
    lambda do |s, _a|
      s.instance_variable_set(:@mapdata, town)
      s.instance_variable_set(:@region, [0])
      s.instance_variable_set(:@selection, [5, 5])
      s.instance_variable_set(:@mapX, 5)
      s.instance_variable_set(:@mapY, 5)
      s.instance_variable_set(:@viewport, Viewport.new)
      bar = MapBottomSprite.new
      s.instance_variable_set(:@sprites, { "cursor" => Sprite.new(80, 80), "player" => Sprite.new, "mapbottom" => bar })
      bar.mapname = s.getRegionName
      bar.maplocation = s.getMapName
      bar.mapdetails = s.getPOI
    end
  end

  # The build of the nest page: the map's first writes, then the nest's squares and encounters, the bar blanked and
  # the nest named, the cursor hidden.
  def self.nest_build(squares, encounters)
    lambda do |s, a|
      map_build.call(s, a)
      s.instance_variable_get(:@sprites).delete("player")
      squares.each_with_index do |(x, y), i|
        s.instance_variable_get(:@sprites)["point#{i}"] = Sprite.new(x * 16 + 8, y * 16 + 8)
      end
      s.instance_variable_set(:@numpoints, squares.length)
      s.instance_variable_set(:@encounters, encounters)
      bar = s.instance_variable_get(:@sprites)["mapbottom"]
      bar.mapname = ""
      bar.maplocation = ""
      bar.mapdetails = "Pikachu's nest"
      bar.alttext = "No Known Nests" if squares.empty?
      s.instance_variable_get(:@sprites)["cursor"].visible = false
    end
  end

  def self.scene(build)
    s = PokemonRegionMapScene.new
    s.instance_variable_set(:@build, build)
    s
  end

  # A move the arrows make: the cursor lands, the next frame's pbUpdate runs, then the bar is written, its point of
  # interest and region save on the nest page.
  def self.step(s, xy, nest = false)
    s.instance_variable_set(:@selection, xy)
    s.pbUpdate
    bar = s.instance_variable_get(:@sprites)["mapbottom"]
    bar.maplocation = s.getMapName
    return if nest
    bar.mapdetails = s.getPOI
    bar.mapname = s.getRegionName
  end

  def self.load_profile
    return if @loaded
    %w[region_map encounters].each do |f|
      load File.expand_path("../../../games/rejuvenation/#{f}.rb", File.dirname(__FILE__))
    end
    @loaded = true
  end
end

class Window_EncounterDetails < Window_AdvancedCommandPokemon; end

class MapBottomSprite
  def mapdetails=(value); @mapdetails = value; end
  def alttext=(value); @alttext = value; end
end

class PokemonRegionMapScene
  LEFT = 0 unless const_defined?(:LEFT)
  TOP = 0 unless const_defined?(:TOP)
  SCREENRIGHT = 28 unless const_defined?(:SCREENRIGHT)
  SCREENBOTTOM = 18 unless const_defined?(:SCREENBOTTOM)

  def getMapName; d = @mapdata[@selection]; (d && @region.include?(d.region)) ? d.name : ""; end
  def getPOI; d = @mapdata[@selection]; (d && @region.include?(d.region)) ? d.poi : ""; end
  def getRegionName; @mapdata[0][:name]; end
  def getFlySpot(pos); d = @mapdata[pos]; (d && !d.flyData.empty? && @region.include?(d.region)) ? d.flyData : nil; end
  def pbUpdate; nil; end
  def endNestScene; nil; end

  def pbChangeMapFocus(focus)
    @sprites["cursor"].visible = focus
    @sprites["mapbottom"].maplocation = focus ? getMapName : ""
  end
end

Suite.define("rejuvenation map: the opening and each square with its point of interest, fly and the player") do
  RejuvMapSpec.load_profile
  t = PokeAccess::I18n
  s = RejuvMapSpec.scene(RejuvMapSpec.map_build)
  SpeakCapture.clear
  s.pbStartScene(false, 0)
  here = "Gearen City, Gearen Laboratory, #{t.t(:rmap_you)}"
  eq "the region and the square it opens on, with its point of interest and the player's head, queued once",
     SpeakCapture.log, [["Aevium Region. #{here}", false]]
  SpeakCapture.clear
  s.pbUpdate
  silent "the next frame says nothing again"

  RejuvMapSpec.step(s, [6, 5])
  eq "a square with no place is said by where it is", SpeakCapture.lines, [t.t(:brm_square, :x => 6, :y => 5)]
  SpeakCapture.clear
  RejuvMapSpec.step(s, [5, 5])
  eq "coming back over the blank square says the place again, and the bar does not repeat it", SpeakCapture.lines, [here]

  SpeakCapture.clear
  fly = RejuvMapSpec.scene(RejuvMapSpec.map_build)
  fly.pbStartScene(false, 1)
  SpeakCapture.clear
  RejuvMapSpec.step(fly, [9, 5])
  eq "on the fly map a square with a fly spot says so", SpeakCapture.lines, ["Route 1, #{t.t(:brm_fly)}"]
  SpeakCapture.clear
  RejuvMapSpec.step(s, [9, 5])
  eq "on the plain map it does not", SpeakCapture.lines, ["Route 1"]
end

Suite.define("rejuvenation map: J/K/L/I jump between fly spots through the rework's own cursor") do
  RejuvMapSpec.load_profile
  t = PokeAccess::I18n
  s = RejuvMapSpec.scene(RejuvMapSpec.map_build)
  s.pbStartScene(false, 1)
  eq "the map in use is the one the jump works on", PokeAccess::TownMap.open_scene, s
  eq "its flyable squares are the fly spots of the regions on show", PokeAccess::RejuvMap.flyable(s).sort, [[9, 5], [40, 5]]
  SpeakCapture.clear
  truthy "a jump to the right lands", PokeAccess::TownMap.jump(s, :right)
  eq "on the nearest fly spot that way", s.instance_variable_get(:@selection), [9, 5]
  eq "the cursor sprite with it", s.instance_variable_get(:@sprites)["cursor"].x, 144
  silent "the bar is rewritten unsaid"
  s.pbUpdate
  eq "and the next frame says the square", SpeakCapture.lines, ["Route 1, #{t.t(:brm_fly)}"]

  PokeAccess::TownMap.jump(s, :right)
  eq "a spot past the window's edge scrolls the view", [s.instance_variable_get(:@mapX), s.instance_variable_get(:@viewport).ox],
     [28, (40 - 28) * 16]
  eq "and keeps the cursor on its square", s.instance_variable_get(:@selection), [40, 5]
  SpeakCapture.clear
  falsy "with nothing further, no jump", PokeAccess::TownMap.jump(s, :right)
  eq "and it says so", SpeakCapture.lines, [t.t(:tm_no_fly)]
end

Suite.define("rejuvenation map: the nest page says the nest and its places, never where the player is") do
  RejuvMapSpec.load_profile
  t = PokeAccess::I18n
  enc = [[12, "Route 1", :Land, 25], [13, "Route 1", :OldRod, 10], [14, "Oceana Pier", :Water, 30]]
  s = RejuvMapSpec.scene(RejuvMapSpec.nest_build([[9, 5]], enc))
  SpeakCapture.clear
  s.pbStartScene(false, 2, :PIKACHU, false)
  eq "the nest and the places, once, and neither the region nor the player's place", SpeakCapture.lines,
     ["Pikachu's nest. #{t.t(:pdx_places, :list => "Route 1, Oceana Pier")}"]
  SpeakCapture.clear
  s.pbUpdate
  silent "the hidden cursor says nothing"
  s.pbChangeMapFocus(true)
  silent "giving it the map is not said by the bar"
  s.pbUpdate
  eq "the next frame says the square under it", SpeakCapture.lines, ["Gearen City"]
  SpeakCapture.clear
  RejuvMapSpec.step(s, [9, 5], true)
  eq "a nest square says so", SpeakCapture.lines, ["Route 1, #{t.t(:rj_map_nest)}"]
  s.endNestScene
  eq "closing the page frees the jump keys", PokeAccess::TownMap.open_scene, nil

  none = RejuvMapSpec.scene(RejuvMapSpec.nest_build([], []))
  SpeakCapture.clear
  none.pbStartScene(false, 2, :PIKACHU, false)
  eq "with no nests, what the page paints in the middle", SpeakCapture.lines, ["Pikachu's nest. No Known Nests"]
end

Suite.define("rejuvenation map: the nest page's encounter list says how each species is met") do
  RejuvMapSpec.load_profile
  t = PokeAccess::I18n
  fig = [0x2007].pack("U")
  rows = ["<icon=Encounters/OldRod> #{fig}25% #{fig}Route 1", "<icon=Encounters/LandNightUnderwater> #{fig} 5% #{fig}Sea Floor",
          "<icon=Encounters/Mystery> #{fig} 1% #{fig}Nowhere"]
  win = Window_EncounterDetails.new(rows)
  eq "the icon as its method, then the chance and the map", PokeAccess::Menus.focused_text(win),
     "#{t.t(:rj_enc_oldrod)}, 25%, Route 1"
  win.index = 1
  eq "an underwater map's icon says so", PokeAccess::Menus.focused_text(win),
     "#{t.t(:rj_enc_landnight)} #{t.t(:rj_enc_underwater)}, 5%, Sea Floor"
  win.index = 2
  eq "an icon with no word leaves the rest", PokeAccess::Menus.focused_text(win), "1%, Nowhere"
end
