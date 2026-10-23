# The BetterRegionMap addon, both Infinite Fusion games' region map: each square read with its place, point of interest,
# fly and player icons; the fly jump's provider, picked by shape; and the screen's opening, moving and closing reads.

# The addon's screen as the game defines it, for the plugin's hooks to bind to by its name: point rows in @data[2],
# main its loop (the opening read runs before it), update_text and update_text_at_location its painters of the line
# under the cursor, dispose its close.
class BetterRegionMap
  def initialize(rows)
    @data = [nil, nil, rows]
    @spots = {}
    @region = 0
    @can_fly = true
  end
  def main; end
  def move_cursor_to(x, y); $PokemonGlobal.regionMapSel = [x, y]; end
  def update_text; end
  def update_text_at_location(_location); end
  def pbGetHealingSpot(_x, _y); nil; end
  def dispose; end
end

# The harness booted with no BetterRegionMap, so the plugin's hook registrations (its top-level statements that call
# PokeAccess::Hooks) are evaluated again at their own lines for the hooks to bind; the rest of it stays as loaded.
require "prism"
brm = File.join(Harness::ROOT, "plugins", "better_region_map.rb")
Prism.parse(Harness.source(brm)).value.statements.body.each do |st|
  eval(st.slice, TOPLEVEL_BINDING, brm, st.location.start_line) if st.slice.include?("PokeAccess::Hooks.")
end

class BetterRegionMapTest < PokeAccessTest
  Map = PokeAccess::BetterMap
  Jump = PokeAccess::TownMap
  ROWS = [[3, 4, "Pueblo Paleta", "Laboratorio"], [5, 4, "Ruta 1", nil], [7, 4, "Ciudad Verde", nil]]
  SPOTS = { [3, 4] => [1, 2, 3], [7, 4] => [1, 2, 3] }

  # A scene shaped like the addon's screen, of a class no hook binds to: point rows [x, y, place, point of interest] in
  # @data[2], the fly icons it drew in @spots, whether it was opened to fly, its region, and the calls made on it.
  class Screen
    attr_reader :calls
    def initialize(rows, spots = {}, can_fly = true)
      @data = [nil, nil, rows]
      @spots = spots
      @region = 0
      @can_fly = can_fly
      @calls = []
    end
    def move_cursor_to(x, y); @calls.push([:move_cursor_to, x, y]); $PokemonGlobal.regionMapSel = [x, y]; end
    def update_text; @calls.push([:update_text]); end
    def pbGetHealingSpot(_x, _y); nil; end
  end

  # A copy of the screen with its own row lookup.
  class LookupScreen < Screen
    def find_location_at_position(x, y); [x, y, "Torre Celeste", nil]; end
  end

  # The player's icon, one with no visible reader, and the scrolled window holding it (Marin's SpriteHash, whose x and
  # y are the scroll).
  Sprite = Struct.new(:x, :y, :bitmap, :visible)
  BareSprite = Struct.new(:x, :y, :bitmap)
  SpriteHash = Struct.new(:x, :y, :player) do
    def [](key); key.to_s == "player" ? player : nil; end
  end

  test "reads a square as its place, its point of interest and the fly icon the screen drew" do
    assert_equal "Pueblo Paleta, Laboratorio, #{fly}", Map.square_text(Screen.new(ROWS, SPOTS), 3, 4)
  end

  test "reads a square with no point of interest or fly icon as its place alone" do
    assert_equal "Ruta 1", Map.square_text(Screen.new(ROWS, SPOTS), 5, 4)
  end

  test "names a square with no row by its coordinates" do
    assert_equal PokeAccess::I18n.t(:brm_square, :x => 9, :y => 2), Map.square_text(Screen.new(ROWS, SPOTS), 9, 2)
  end

  test "names a row with a blank place by its coordinates, with its point of interest after" do
    screen = Screen.new([[2, 6, " ", "Cueva"]])
    assert_equal "#{PokeAccess::I18n.t(:brm_square, :x => 2, :y => 6)}, Cueva", Map.square_text(screen, 2, 6)
  end

  test "drops the point of interest at brief and says it from medium" do
    screen = Screen.new(ROWS, SPOTS)
    assert_equal ["Pueblo Paleta, #{fly}", "Pueblo Paleta, Laboratorio, #{fly}", "Pueblo Paleta, Laboratorio, #{fly}"],
                 vb_levels { Map.square_text(screen, 3, 4) }
  end

  test "keeps the whole square on the info key whatever the level says" do
    PokeAccess::Config.verbosity = :brief
    Map.square_text(Screen.new(ROWS, SPOTS), 3, 4)
    assert_equal "Pueblo Paleta, Laboratorio, #{fly}", PokeAccess::Info.info_text
  end

  test "reads the square through the screen's own lookup where its copy has one" do
    assert_equal "Torre Celeste", Map.square_text(LookupScreen.new(ROWS), 5, 4)
  end

  test "names every square by its coordinates and offers no fly candidate when the screen holds no map data" do
    coordinates = PokeAccess::I18n.t(:brm_square, :x => 3, :y => 4)
    { "no data at all" => nil, "data with no rows" => [nil, nil, nil] }.each do |what, data|
      screen = Screen.new(ROWS)
      screen.instance_variable_set(:@data, data)
      assert_equal [coordinates, []], [Map.square_text(screen, 3, 4), Jump.points(screen)], what
    end
  end

  test "names even a square with a row by its coordinates and offers no fly candidate when another row is broken" do
    screen = Screen.new([nil] + ROWS)
    assert_equal [PokeAccess::I18n.t(:brm_square, :x => 3, :y => 4), []],
                 [Map.square_text(screen, 3, 4), Jump.points(screen)]
  end

  test "says the player's icon on its square, wherever the map has scrolled" do
    screen = Screen.new(ROWS)
    screen.instance_variable_set(:@window, icon_window(-32, -16, 16 * 3 + 8 - 32, 16 * 4 + 8 - 16))
    assert_equal ["Pueblo Paleta, Laboratorio, #{you}", "Ruta 1"],
                 [Map.square_text(screen, 3, 4), Map.square_text(screen, 5, 4)]
  end

  test "marks the square an icon drawn off its centre lies on" do
    screen = Screen.new(ROWS)
    screen.instance_variable_set(:@window, icon_window(0, 0, 16 * 3 + 8 + 7, 16 * 4 + 8 + 7))
    assert_equal "Pueblo Paleta, Laboratorio, #{you}", Map.square_text(screen, 3, 4)
  end

  test "reads the icon's square from its own place in a window that does not scroll" do
    screen = Screen.new(ROWS)
    screen.instance_variable_set(:@window, { "player" => Sprite.new(16 * 5 + 8, 16 * 4 + 8, :icon, true) })
    assert_equal "Ruta 1, #{you}", Map.square_text(screen, 5, 4)
  end

  test "takes an icon that does not tell whether it shows for one shown" do
    screen = Screen.new(ROWS)
    screen.instance_variable_set(:@window, SpriteHash.new(0, 0, BareSprite.new(16 * 5 + 8, 16 * 4 + 8, :icon)))
    assert_equal "Ruta 1, #{you}", Map.square_text(screen, 5, 4)
  end

  test "marks no square while the screen draws no player icon, hides it or gives it no place" do
    { "no bitmap" => icon_window(0, 0, 8, 8, nil), "hidden" => icon_window(0, 0, 8, 8, :icon, false),
      "no icon at all" => SpriteHash.new(0, 0, nil),
      "an icon with no place" => icon_window(0, 0, nil, nil) }.each do |what, window|
      screen = Screen.new([[0, 0, "Isla", nil]])
      screen.instance_variable_set(:@window, window)
      assert_equal "Isla", Map.square_text(screen, 0, 0), what
    end
  end

  test "is the fly jump's provider for a scene shaped like the addon's screen" do
    assert_equal "better_region_map", Jump.provider_for(Screen.new(ROWS))[0]
  end

  test "is no provider for a scene missing one of the screen's methods" do
    [:move_cursor_to, :update_text, :pbGetHealingSpot].each do |gone|
      scene = Screen.new(ROWS)
      scene.singleton_class.send(:undef_method, gone)
      assert_nil Jump.provider_for(scene), "without #{gone}"
    end
  end

  test "reads the cursor from the global the screen keeps it in" do
    { [5, 4] => [5, 4], ["7", "2"] => [7, 2], [5] => nil, nil => nil, "5,4" => nil }.each do |held, cursor|
      with_cursor_at(held) do
        if cursor
          assert_equal cursor, Jump.cursor(Screen.new(ROWS)), "for #{held.inspect}"
        else
          assert_nil Jump.cursor(Screen.new(ROWS)), "for #{held.inspect}"
        end
      end
    end
  end

  test "offers every row of the map as a fly jump candidate" do
    assert_equal [[3, 4], [5, 4], [7, 4]], Jump.points(Screen.new(ROWS, SPOTS))
  end

  test "offers only the squares the screen marked as fly destinations" do
    assert_equal [[3, 4], [7, 4]], Jump.fly_points(Screen.new(ROWS, SPOTS)).sort
  end

  test "offers no fly destination and marks none on a map opened without flying, whatever its spots hold" do
    quests = Screen.new(ROWS, { [3, 4] => [:quest] }, false)
    assert_equal [], Jump.fly_points(quests), "the fly jump finds nowhere to go"
    assert_equal "Pueblo Paleta, Laboratorio", Map.square_text(quests, 3, 4), "and the square has no fly mark"
  end

  test "moves the cursor through the screen, which then repaints its line" do
    with_cursor_at([5, 4]) do
      screen = Screen.new(ROWS, SPOTS)
      assert_equal true, Jump.move(screen, 7, 4), "the move is reported done"
      assert_equal [[:move_cursor_to, 7, 4], [:update_text]], screen.calls, "placed, then repainted"
      assert_equal [7, 4], Jump.cursor(screen), "the cursor stands where it was told"
    end
  end

  test "says the square under the cursor, and the next one it moves to" do
    with_cursor_at([3, 4]) do
      screen = opened(Screen.new(ROWS, SPOTS))
      Map.read(screen)
      $PokemonGlobal.regionMapSel = [5, 4]
      Map.read(screen)
      assert_equal [["Pueblo Paleta, Laboratorio, #{fly}", true], ["Ruta 1", true]], SpeakCapture.log
    end
  end

  test "says a square once while the cursor stays on it" do
    with_cursor_at([5, 4]) do
      screen = opened(Screen.new(ROWS))
      Map.read(screen)
      Map.read(screen)
      assert_equal ["Ruta 1"], SpeakCapture.lines
    end
  end

  test "reads the opening square without interrupting" do
    with_cursor_at([5, 4]) do
      Map.read(opened(Screen.new(ROWS)), false)
      assert_equal [["Ruta 1", false]], SpeakCapture.log
    end
  end

  test "says nothing for a screen other than the open map" do
    with_cursor_at([5, 4]) do
      opened(Screen.new(ROWS))
      Map.read(Screen.new(ROWS))
      assert_nothing_spoken
    end
  end

  test "says nothing while the screen's global holds no square" do
    with_cursor_at(nil) do
      Map.read(opened(Screen.new(ROWS)))
      assert_nothing_spoken
    end
  end

  test "says the region and then the square under the cursor as the screen opens, neither interrupting" do
    with_cursor_at([5, 4]) do
      with_region_names(0 => "Kanto") do
        BetterRegionMap.new(ROWS).main
        assert_equal [["Kanto", false], ["Ruta 1", false]], SpeakCapture.log
      end
    end
  end

  test "says only the square as the screen opens on a region with no name" do
    with_cursor_at([5, 4]) do
      with_region_names(0 => "") do
        BetterRegionMap.new(ROWS).main
        assert_equal [["Ruta 1", false]], SpeakCapture.log
      end
    end
  end

  test "says the square the cursor moves to as the screen repaints its line, by either painter" do
    [:update_text, :update_text_at_location].each do |painter|
      with_cursor_at([5, 4]) do
        screen = BetterRegionMap.new(ROWS)
        screen.main
        SpeakCapture.clear
        $PokemonGlobal.regionMapSel = [3, 4]
        painter == :update_text ? screen.update_text : screen.update_text_at_location(ROWS[0])
        assert_equal [["Pueblo Paleta, Laboratorio", true]], SpeakCapture.log, "painted by #{painter}"
      end
    end
  end

  test "lets go of the map and its square on the info key as the screen closes" do
    with_cursor_at([5, 4]) do
      screen = BetterRegionMap.new(ROWS)
      screen.main
      held = [Jump.open_scene, PokeAccess::Info.info_text]
      screen.dispose
      assert_equal [[screen, "Ruta 1"], [nil, nil]], [held, [Jump.open_scene, PokeAccess::Info.info_text]]
    end
  end

  test "names the region from the game's region names, cleaned" do
    with_region_names(0 => "<c=1>Kanto</c>", 2 => "Hoenn") do
      screen = Screen.new(ROWS)
      assert_equal "Kanto", Map.region_name(screen), "region 0"
      screen.instance_variable_set(:@region, 2)
      assert_equal "Hoenn", Map.region_name(screen), "region 2"
    end
  end

  test "names no region for a screen with none, or one the game leaves blank" do
    with_region_names(0 => "  ") do
      assert_nil Map.region_name(Screen.new(ROWS)), "a blank name"
      screen = Screen.new(ROWS)
      screen.instance_variable_set(:@region, nil)
      assert_nil Map.region_name(screen), "no region"
    end
  end

  private

  # The fly icon's word.
  def fly
    PokeAccess::I18n.t(:brm_fly)
  end

  # The player's icon's word.
  def you
    PokeAccess::I18n.t(:rmap_you)
  end

  # A window scrolled to (sx, sy) holding the player's icon at (x, y).
  def icon_window(sx, sy, x, y, bitmap = :icon, visible = true)
    SpriteHash.new(sx, sy, Sprite.new(x, y, bitmap, visible))
  end

  # The screen, opened as the map on screen.
  def opened(screen)
    Jump.opened(screen)
    screen
  end

  # Runs the block with the screen's cursor global on $PokemonGlobal holding sel, the global put back after.
  def with_cursor_at(sel)
    g = $PokemonGlobal
    added = !g.respond_to?(:regionMapSel)
    if added
      def g.regionMapSel; @pa_spec_sel; end
      def g.regionMapSel=(v); @pa_spec_sel = v; end
    else
      was = g.regionMapSel
    end
    g.regionMapSel = sel
    yield
  ensure
    if added
      g.singleton_class.send(:remove_method, :regionMapSel, :regionMapSel=)
      g.send(:remove_instance_variable, :@pa_spec_sel) if g.instance_variable_defined?(:@pa_spec_sel)
    else
      g.regionMapSel = was
    end
  end

  # Runs the block with the game's region names answering names (region => name), the message type and the
  # message lookup put back after.
  def with_region_names(names)
    added = !MessageTypes.const_defined?(:RegionNames, false)
    MessageTypes.const_set(:RegionNames, :region_names) if added
    kind = MessageTypes::RegionNames
    GameFunctions.with(:pbGetMessage => lambda { |type, id| type == kind ? names[id].to_s : "msg#{id}" }) { yield }
  ensure
    MessageTypes.send(:remove_const, :RegionNames) if added
  end
end
