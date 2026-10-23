# Rejuvenation's region map (games/rejuvenation/region_map.rb and encounters.rb), a rework of PokemonRegionMapScene
# with a @selection cursor over $cache.town_map and no pbGetMapLocation: the opening line, each square with its point
# of interest, fly and the player's head, the fly jump through its own provider, the Pokedex nest page it becomes in
# mode 2 and that page's encounter list.

# The nest page's encounter list (X on the page): one row per way the species is met.
class Window_EncounterDetails < Window_AdvancedCommandPokemon; end

# The bar's writers the rework adds: the point of interest beside the place, and the line the nest page paints in the
# middle when it has no nest.
class MapBottomSprite
  def mapdetails=(value); @mapdetails = value; end
  def alttext=(value); @alttext = value; end
end

# The rework's methods, as Rejuv/RegionMap.rb defines them: a square's place, point of interest, region and fly spot
# come from its town map entry while its region is on show; pbStartScene ends with a frame (pbUpdate).
class PokemonRegionMapScene
  LEFT = 0 unless const_defined?(:LEFT)
  TOP = 0 unless const_defined?(:TOP)
  SCREENRIGHT = 28 unless const_defined?(:SCREENRIGHT)
  SCREENBOTTOM = 18 unless const_defined?(:SCREENBOTTOM)

  def getMapName; d = @mapdata[@selection]; (d && @region.include?(d.region)) ? d.name : ""; end
  def getPOI; d = @mapdata[@selection]; (d && @region.include?(d.region)) ? d.poi : ""; end
  def getRegionName; d = @mapdata[@selection]; (d && @region.include?(d.region)) ? @mapdata[d.region][:name] : @mapdata[0][:name]; end
  def getFlySpot(pos); d = @mapdata[pos]; (d && !d.flyData.empty? && @region.include?(d.region)) ? d.flyData : nil; end
  def pbUpdate; nil; end
  def endNestScene; nil; end

  def pbChangeMapFocus(focus)
    @sprites["cursor"].visible = focus
    @sprites["mapbottom"].maplocation = focus ? getMapName : ""
  end
end

class RejuvenationMapTest < PokeAccessTest
  PATHS = %w[region_map encounters].map { |f| File.join(Harness::ROOT, "games", "rejuvenation", "#{f}.rb") }
  Place = Struct.new(:name, :poi, :flyData, :region)
  # A town map entry whose place the game fails to read.
  Unreadable = Struct.new(:poi, :flyData, :region) do
    def name; raise IOError, "the entry cannot be read"; end
  end
  Viewport = Struct.new(:ox, :oy)
  # The town map: two regions' names, then the squares, the cursor opening on Gearen City's.
  TOWN = { 0 => { :name => "Aevium Region" }, 4 => { :name => "Grand Dream City" },
           [4, 5] => Place.new("Gearen City", "Gearen Laboratory", [], 0),
           [9, 5] => Place.new("Route 1", "", [12, 3, 4], 0),
           [40, 5] => Place.new("Oceana Pier", "", [20, 1, 1], 0),
           [9, 30] => Place.new("Route 9", "", [21, 1, 1], 0),
           [2, 9] => Place.new("Far Away", "", [30, 1, 1], 4) }
  GEAREN = "Gearen City, Gearen Laboratory"
  ENCOUNTERS = [[12, "Route 1", :Land, 25], [13, "Route 1", :OldRod, 10], [14, "Oceana Pier", :Water, 30]]
  FIGURE = [0x2007].pack("U")

  # A sprite of the scene: where it is drawn and whether it shows.
  class Sprite
    attr_accessor :x, :y, :visible
    def initialize(x = 0, y = 0, visible = true); @x = x; @y = y; @visible = visible; end
  end

  class << self
    # Whether the profile was loaded: it loads once per process, its hooks binding once by name.
    attr_accessor :loaded
  end

  test "opens with the region and the square under the cursor, its point of interest and the player's head, queued" do
    start(map_build)
    assert_equal [["Aevium Region. #{GEAREN}, #{t(:rmap_you)}", false]], SpeakCapture.log
  end

  test "the frame after the opening says nothing" do
    s = start(map_build)
    SpeakCapture.clear
    s.pbUpdate
    assert_nothing_spoken
  end

  test "the bar rewritten on the opening square says nothing" do
    s = start(map_build)
    SpeakCapture.clear
    step(s, [4, 5])
    assert_nothing_spoken
  end

  test "opens with no player's mark where the map draws no head" do
    start(map_build(head: false))
    assert_equal ["Aevium Region. #{GEAREN}"], SpeakCapture.lines
  end

  test "a map that opens with its cursor hidden says only its region" do
    start(map_build(strip: lambda { |s| ivar(s, :@sprites)["cursor"].visible = false }))
    assert_equal [["Aevium Region", false]], SpeakCapture.log
  end

  test "the map's start returns what the game's own start returns" do
    load_profile
    s = PokemonRegionMapScene.new
    s.instance_variable_set(:@build, map_build)
    assert_equal true, s.pbStartScene(false, 0)
  end

  test "a move to a square with no place says its coordinates, interrupting" do
    s = start(map_build)
    SpeakCapture.clear
    step(s, [3, 5])
    assert_equal [[t(:brm_square, :x => 3, :y => 5), true]], SpeakCapture.log
  end

  test "coming back over a blank square says the place once, the bar's write not repeating it" do
    s = start(map_build)
    step(s, [3, 5])
    SpeakCapture.clear
    step(s, [4, 5])
    assert_equal ["#{GEAREN}, #{t(:rmap_you)}"], SpeakCapture.lines
  end

  test "a square the game fails to read is left unsaid, and the next one is read" do
    s = start(map_build(town: TOWN.merge([5, 5] => Unreadable.new("", [], 0))))
    SpeakCapture.clear
    [[5, 5], [9, 5]].each do |xy|
      s.instance_variable_set(:@selection, xy)
      s.pbUpdate
    end
    assert_equal [["Route 1", true]], SpeakCapture.log
  end

  test "a move into another region on show says the region first" do
    s = start(map_build(regions: [0, 4]))
    SpeakCapture.clear
    step(s, [2, 9])
    assert_equal ["Grand Dream City. Far Away"], SpeakCapture.lines
  end

  test "on the fly map, a square with a visited fly spot says fly is available" do
    s = start(map_build, 1)
    SpeakCapture.clear
    step(s, [9, 5])
    assert_equal ["Route 1, #{t(:brm_fly)}"], SpeakCapture.lines
  end

  test "on the fly map, a square with no fly spot says nothing of fly" do
    start(map_build, 1)
    assert_equal ["Aevium Region. #{GEAREN}, #{t(:rmap_you)}"], SpeakCapture.lines
  end

  test "on the fly map, the fly spot of a map never visited says nothing of fly" do
    with_visited(20 => true) do
      s = start(map_build, 1)
      SpeakCapture.clear
      step(s, [9, 5])
      assert_equal ["Route 1"], SpeakCapture.lines
    end
  end

  test "on the plain map, a fly spot says nothing of fly" do
    s = start(map_build)
    SpeakCapture.clear
    step(s, [9, 5])
    assert_equal ["Route 1"], SpeakCapture.lines
  end

  test "leaves a region map that is not the rework to the core" do
    load_profile
    { "neither a cursor nor a town table" => {}, "a cursor over a town list" => { :@selection => [4, 5], :@mapdata => [] },
      "a town table with no cursor" => { :@mapdata => TOWN, :@region => [0] } }.each do |what, ivars|
      s = PokemonRegionMapScene.new
      s.instance_variable_set(:@build, lambda do |scene, _args|
        ivars.each { |name, value| scene.instance_variable_set(name, value) }
        scene.instance_variable_set(:@sprites, {})
        scene.pbUpdate
      end)
      SpeakCapture.clear
      s.pbStartScene(false, 0)
      s.pbUpdate
      assert_nothing_spoken what
    end
  end

  test "the nest page opens with the nest and the places the species is found in, never the region nor the player" do
    start(nest_build([[9, 5]], ENCOUNTERS), 2)
    assert_equal [["Pikachu's nest. #{t(:pdx_places, :list => "Route 1, Oceana Pier")}", false]], SpeakCapture.log
  end

  test "the nest page names each place once and leaves out a blank one" do
    start(nest_build([[9, 5]], [[12, "Route 1", :Land, 25], [13, "", :Water, 5], [14, "Route 1", :OldRod, 10]]), 2)
    assert_equal ["Pikachu's nest. #{t(:pdx_places, :list => "Route 1")}"], SpeakCapture.lines
  end

  test "a nest page with no nests says what it paints in the middle" do
    start(nest_build([], []), 2)
    assert_equal ["Pikachu's nest. No Known Nests"], SpeakCapture.lines
  end

  test "the nest page's hidden cursor says nothing" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    SpeakCapture.clear
    s.pbUpdate
    assert_nothing_spoken
  end

  test "given the map, the nest page's cursor is said on the next frame, not by the bar" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    SpeakCapture.clear
    s.pbChangeMapFocus(true)
    held = SpeakCapture.lines.dup
    s.pbUpdate
    assert_equal [[], ["Gearen City"]], [held, SpeakCapture.lines], "nothing on the focus, then the square"
  end

  test "the nest page's cursor given the map again says its square again" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    [true, false, true].each do |focus|
      s.pbChangeMapFocus(focus)
      SpeakCapture.clear
      s.pbUpdate
    end
    assert_equal [["Gearen City", true]], SpeakCapture.log
  end

  test "a nest square says so" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    s.pbChangeMapFocus(true)
    s.pbUpdate
    SpeakCapture.clear
    step(s, [9, 5], true)
    assert_equal ["Route 1, #{t(:rj_map_nest)}"], SpeakCapture.lines
  end

  test "the nest page holds the jump keys until it closes" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    open = PokeAccess::TownMap.open_scene
    s.endNestScene
    assert_equal [s, nil], [open, PokeAccess::TownMap.open_scene]
  end

  test "a jump lands on the nearest fly spot that way, the cursor sprite with it, unsaid" do
    s = start(map_build, 1)
    SpeakCapture.clear
    moved = PokeAccess::TownMap.jump(s, :right)
    assert_equal [true, [9, 5], [144, 80]], [moved, selection(s), sprite_xy(s, "cursor")]
    assert_nothing_spoken "the bar is rewritten unsaid"
  end

  test "the frame after a jump says the square it landed on" do
    s = start(map_build, 1)
    PokeAccess::TownMap.jump(s, :right)
    SpeakCapture.clear
    s.pbUpdate
    assert_equal [["Route 1, #{t(:brm_fly)}", true]], SpeakCapture.log
  end

  test "a jump rewrites the bar's place, point of interest and region, as the scene's own move does" do
    s = start(map_build(regions: [0, 4]), 1)
    PokeAccess::TownMap.jump(s, :down)
    assert_equal [[2, 9], ["Far Away", "", "Grand Dream City"]], [selection(s), painted(s)]
  end

  test "on the nest page, a jump rewrites only the bar's place" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    s.pbChangeMapFocus(true)
    PokeAccess::TownMap.jump(s, :right)
    assert_equal ["Route 1", "Pikachu's nest", ""], painted(s)
  end

  test "a jump within the window moves the cursor in it, the view kept" do
    s = start(map_build, 1)
    PokeAccess::TownMap.jump(s, :right)
    assert_equal [[9, 5], 9, 5, [0, 0]], [selection(s), ivar(s, :@mapX), ivar(s, :@mapY), view(s)]
  end

  test "a jump past the window's right edge scrolls the view, keeping the cursor on its square" do
    s = start(map_build, 1)
    2.times { PokeAccess::TownMap.jump(s, :right) }
    assert_equal [[40, 5], 28, [(40 - 28) * 16, 0], 640], [selection(s), ivar(s, :@mapX), view(s), sprite_xy(s, "cursor")[0]]
  end

  test "a jump one square past the window's right edge scrolls the view one square" do
    s = start(map_build(town: TOWN.merge([29, 5] => Place.new("Route 2", "", [22, 1, 1], 0))), 1)
    2.times { PokeAccess::TownMap.jump(s, :right) }
    assert_equal [[29, 5], 28, [16, 0]], [selection(s), ivar(s, :@mapX), view(s)]
  end

  test "a jump back past the window's left edge scrolls the view back" do
    s = start(map_build, 1)
    2.times { PokeAccess::TownMap.jump(s, :right) }
    PokeAccess::TownMap.jump(s, :left)
    assert_equal [[9, 5], 0, [(40 - 28 - 3) * 16, 0]], [selection(s), ivar(s, :@mapX), view(s)]
  end

  test "a jump past the window's bottom scrolls the view down" do
    s = start(map_build, 1)
    PokeAccess::TownMap.jump(s, :down)
    assert_equal [[9, 30], 18, [0, (30 - 18) * 16], [144, 480]],
                 [selection(s), ivar(s, :@mapY), view(s), sprite_xy(s, "cursor")]
  end

  test "a map missing its viewport, its bottom bar or its cursor sprite still takes a jump past the window's edge" do
    { "no viewport" => lambda { |s| s.instance_variable_set(:@viewport, nil) },
      "no bottom bar" => lambda { |s| ivar(s, :@sprites).delete("mapbottom") },
      "no cursor sprite" => lambda { |s| ivar(s, :@sprites).delete("cursor") } }.each do |what, strip|
      s = start(map_build(strip: strip), 1)
      moved = (1..2).map { PokeAccess::TownMap.jump(s, :right) }
      assert_equal [[true, true], [40, 5], 28], [moved, selection(s), ivar(s, :@mapX)], what
    end
  end

  test "with no fly spot further that way, a jump says so and leaves the cursor" do
    s = start(map_build, 1)
    2.times { PokeAccess::TownMap.jump(s, :right) }
    SpeakCapture.clear
    moved = PokeAccess::TownMap.jump(s, :right)
    assert_equal [false, [40, 5], [t(:tm_no_fly)]], [moved, selection(s), SpeakCapture.lines]
  end

  test "the fly spot of a region not on show is no jump target" do
    s = start(map_build, 1)
    SpeakCapture.clear
    moved = PokeAccess::TownMap.jump(s, :left)
    assert_equal [false, [t(:tm_no_fly)]], [moved, SpeakCapture.lines]
  end

  test "while the nest page's cursor is hidden, a jump does nothing" do
    s = start(nest_build([[9, 5]], ENCOUNTERS), 2)
    SpeakCapture.clear
    moved = PokeAccess::TownMap.jump(s, :right)
    assert_equal [false, [4, 5]], [moved, selection(s)]
    assert_nothing_spoken
  end

  test "an encounter row says how the species is met, its chance and its map" do
    { "<icon=Encounters/OldRod> #{FIGURE}25% #{FIGURE}Route 1" => "#{t(:rj_enc_oldrod)}, 25%, Route 1",
      "<icon=Encounters/Land> #{FIGURE}40% #{FIGURE}Route 2" => "#{t(:rj_enc_land)}, 40%, Route 2",
      "<icon=Encounters/LandNightUnderwater> #{FIGURE} 5% #{FIGURE}Sea Floor" =>
        "#{t(:rj_enc_landnight)} #{t(:rj_enc_underwater)}, 5%, Sea Floor" }.each do |row, said|
      assert_equal said, encounter(row), "for #{row.inspect}"
    end
  end

  test "an encounter row with no icon, or an icon with no word, says its chance and its map" do
    { "<icon=Encounters/Mystery> #{FIGURE} 1% #{FIGURE}Nowhere" => "1%, Nowhere",
      "#{FIGURE}30% #{FIGURE}Route 3" => "30%, Route 3" }.each do |row, said|
      assert_equal said, encounter(row), "for #{row.inspect}"
    end
  end

  test "an encounter row with no chance before its map is said as painted after its method" do
    assert_equal "#{t(:rj_enc_headbutt)}, Special", encounter("<icon=Encounters/Headbutt> Special")
  end

  test "an index past the encounter list reads nothing" do
    load_profile
    win = Window_EncounterDetails.new(["<icon=Encounters/Land> 40% Route 2"])
    win.index = 1
    assert_nil PokeAccess::Menus.focused_text(win)
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def ivar(s, name)
    s.instance_variable_get(name)
  end

  def selection(s)
    ivar(s, :@selection)
  end

  def sprite_xy(s, key)
    sp = ivar(s, :@sprites)[key]
    [sp.x, sp.y]
  end

  # How far the scene's viewport is scrolled: [ox, oy].
  def view(s)
    vp = ivar(s, :@viewport)
    [vp.ox, vp.oy]
  end

  # What the bottom bar paints: [place, point of interest, region].
  def painted(s)
    bar = ivar(s, :@sprites)["mapbottom"]
    [ivar(bar, :@maplocation), ivar(bar, :@mapdetails), ivar(bar, :@mapname)]
  end

  # Evaluates the profile's two files once per process, as the harness loads a file, leaving the suite's profiles
  # as they were.
  def load_profile
    return if self.class.loaded
    self.class.loaded = true
    game = PokeAccess::Game
    kept = [game.profiles.dup, game.instance_variable_get(:@profile_name)]
    PATHS.each { |path| eval(Harness.source(path), TOPLEVEL_BINDING, path) }
    game.profiles.replace(kept[0])
    game.instance_variable_set(:@profile_name, kept[1])
  end

  # A rework scene started in mode (0 the map, 1 to fly, 2 the nest page) with build standing in for the game's own.
  def start(build, mode = 0)
    load_profile
    s = PokemonRegionMapScene.new
    s.instance_variable_set(:@build, build)
    mode == 2 ? s.pbStartScene(false, 2, :PIKACHU, false) : s.pbStartScene(false, mode)
    s
  end

  # Lays what both builds start with: the town map with regions on show, the cursor on (4, 5) of the map and of its
  # window, the view unscrolled, and the bottom bar written for it; returns the bar.
  def lay_map(s, regions, sprites, town = TOWN)
    s.instance_variable_set(:@mapdata, town)
    s.instance_variable_set(:@region, regions)
    s.instance_variable_set(:@selection, [4, 5])
    s.instance_variable_set(:@mapX, 4)
    s.instance_variable_set(:@mapY, 5)
    s.instance_variable_set(:@viewport, Viewport.new(0, 0))
    bar = MapBottomSprite.new
    s.instance_variable_set(:@sprites, sprites.merge("cursor" => Sprite.new(64, 80), "mapbottom" => bar))
    bar.mapname = s.getRegionName
    bar.maplocation = s.getMapName
    bar.mapdetails = s.getPOI
    bar
  end

  # The build of the map (mode 0) and of the fly map (mode 1): the town map with regions on show, the player's head on
  # the cursor's square unless head is false, what strip takes off the scene, then the frame the game's start ends
  # with; it returns true, as the game's start does.
  def map_build(regions: [0], head: true, town: TOWN, strip: nil)
    lambda do |s, _args|
      lay_map(s, regions, head ? { "player" => Sprite.new(64, 80) } : {}, town)
      strip.call(s) if strip
      s.pbUpdate
      true
    end
  end

  # The build of the nest page: the town map, a red point over each nest square, the encounters the X list shows, the
  # bar blanked and the nest named (with "No Known Nests" where it has none), the cursor hidden, then a frame.
  def nest_build(squares, encounters)
    lambda do |s, _args|
      points = {}
      squares.each_with_index { |(x, y), i| points["point#{i}"] = Sprite.new(x * 16 + 8, y * 16 + 8) }
      bar = lay_map(s, [0], points)
      s.instance_variable_set(:@numpoints, squares.length)
      s.instance_variable_set(:@encounters, encounters)
      bar.mapname = ""
      bar.maplocation = ""
      bar.mapdetails = "Pikachu's nest"
      bar.alttext = "No Known Nests" if squares.empty?
      ivar(s, :@sprites)["cursor"].visible = false
      s.pbUpdate
      true
    end
  end

  # A move the arrows make: the cursor lands on xy, the next frame runs, then the bar is rewritten as the scene's loop
  # does, its point of interest and region save on the nest page.
  def step(s, xy, nest = false)
    s.instance_variable_set(:@selection, xy)
    s.pbUpdate
    bar = ivar(s, :@sprites)["mapbottom"]
    bar.maplocation = s.getMapName
    return if nest
    bar.mapdetails = s.getPOI
    bar.mapname = s.getRegionName
  end

  # The encounter list's line for a row, as its window reads it focused.
  def encounter(row)
    load_profile
    PokeAccess::Menus.focused_text(Window_EncounterDetails.new([row]))
  end

  # Runs the block with the game's record of visited maps answering visited, taken back after.
  def with_visited(visited)
    $PokemonGlobal.define_singleton_method(:visitedMaps) { visited }
    yield
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :visitedMaps)
  end
end
