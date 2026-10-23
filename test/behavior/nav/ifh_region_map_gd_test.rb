# Infinite Fusion Hoenn's BetterRegionMap screens (games/infinitefusion_hoenn/region_map.rb), gamedata pass: the weather
# map says each square's HUD weather after its place, in one line; the secret base's square says the point of interest
# painted over town_map.dat's; and the quest map says its title, its own line and its side panel of quests, once each.
# The stand-ins paint as the Hoenn copy does and come before the plugin is loaded again (the harness booted with no
# BetterRegionMap for its hooks to bind to) and then the profile, as the game loads them; the quest log's reader, whose
# quest kinds the side panel shares, is loaded here only when no other test has.
unless Kernel.respond_to?(:pbDisplayText)
  def Kernel.pbDisplayText(_message, _x, _y, _z = nil, _base = nil, _shadow = nil, _align = 2); nil; end
end
def Kernel.pbClearText; nil; end unless Kernel.respond_to?(:pbClearText)

# The addon's screen as the Hoenn copy paints it: the region's name on top, the place and its point of interest on the
# bottom line ("Secret Base" over the player's base, map 99), and on the weather map each square's weather as HUD text,
# which the core's HUD reader hears as it is written (the stub engine boots without that writer, so the core's own wrap
# of it is not bound here). main is its loop, which the opening read runs before; dispose closes it.
class BetterRegionMap
  def initialize(rows, weather = {})
    @data = [nil, nil, rows]
    @region = 0
    @weather = weather
    @show_weather = true
    @region_name = "Hoenn"
  end
  def main; end
  def dispose; end
  def find_location_at_position(x, y); @data[2].find { |e| e[0] == x && e[1] == y }; end
  def move_cursor_to(x, y); $PokemonGlobal.regionMapSel = [x, y]; end
  def pbGetHealingSpot(_x, _y); nil; end
  def update_text
    update_text_at_location(find_location_at_position($PokemonGlobal.regionMapSel[0], $PokemonGlobal.regionMapSel[1]))
  end
  def update_text_at_location(location)
    poi = location && location[3] ? location[3] : ""
    poi = "Secret Base" if location && location[4] == 99
    update_weather_text(location) if @show_weather
    pbDrawTextPositions(nil, [[@region_name, 16, 0], [location ? location[2] : "", 16, 354], [poi, 496, 354]])
  end
  def update_weather_text(location)
    w = location ? @weather[location[4]] : nil
    Kernel.pbClearText
    return unless w
    w.each_with_index do |line, i|
      Kernel.pbDisplayText(line, 400, 25 * (i + 1))
      PokeAccess::HudText.say(line)
    end
  end
end

# The quest map's side panel of a square's quests (QuestMapPopup), as the reader inspects it.
class IfhQuestPanel
  def initialize(quests, place); @quests = quests; @location_name = place; end
end

# The quest map: a BetterRegionMap that paints its own line (its title, the key for the list, the place and how many
# quests are in progress there) without calling up, and opens a passive side panel of a square's quests.
class QuestMap < BetterRegionMap
  def initialize(rows, quests)
    super(rows)
    @show_weather = false
    @quests = quests
    @popup = nil
  end
  def update_text_at_location(location)
    n = (@quests[$PokemonGlobal.regionMapSel] || []).length
    count = n > 1 ? "#{n} quests in progress" : (n > 0 ? "#{n} quest in progress" : "")
    pbDrawTextPositions(nil, [["Quest Log", 24, -8], ["L/R : LIST", 360, -8], [location ? location[2] : "", 16, 344],
                              [count, 496, 344]])
  end
  def show_popup(quests, place = "Petalburg City"); @popup = IfhQuestPanel.new(quests, place); end
  def hide_popup; @popup = nil; end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  ifh_brm = File.join(Harness::ROOT, "plugins", "better_region_map.rb")
  eval(Harness.source(ifh_brm), TOPLEVEL_BINDING, ifh_brm)
ensure
  $VERBOSE = verbose
end
unless defined?(PokeAccess::IF2Quests)
  ifh_quests = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "quests.rb")
  eval(Harness.source(ifh_quests), TOPLEVEL_BINDING, ifh_quests)
end
ifh_rmap = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "region_map.rb")
eval(Harness.source(ifh_rmap), TOPLEVEL_BINDING, ifh_rmap)

class IfhRegionMapGdTest < PokeAccessTest
  Map = PokeAccess::BetterMap
  # Rows of town_map.dat: [x, y, place, point of interest, map id]; map 99 holds the player's secret base.
  ROWS = [[3, 4, "Petalburg City", "Gym", 5], [6, 4, "Route 102", nil, 6], [9, 2, "Route 104", "Hut", 99]]
  # The weather the weather map paints for map 5: its name, then its figure.
  WEATHER = { 5 => ["Heavy sunshine", "30 C"] }
  Quest = Struct.new(:name, :type)
  QUESTS = [Quest.new("Busca el gato", :MAIN_QUEST), Quest.new("Lleva la carta", :SIDE_QUEST),
            Quest.new("Grafiti", :MAGMA_QUEST)]
  PETALBURG = "Petalburg City, Gym, Heavy sunshine, 30 C"

  test "says a square's weather after its place, its figure and point of interest from medium" do
    scene = weather_map
    with_map(scene, 3, 4) do
      scene.update_text
      assert_equal ["Petalburg City, Heavy sunshine", PETALBURG, PETALBURG], vb_levels { Map.square_text(scene, 3, 4) }
    end
  end

  test "says a square with no weather by its place alone" do
    scene = weather_map
    with_map(scene, 3, 4) do
      move_to(scene, 6, 4)
      assert_equal "Route 102", Map.square_text(scene, 6, 4)
    end
  end

  test "adds what a repaint painted to its own square only" do
    scene = weather_map
    with_map(scene, 3, 4) do
      scene.update_text
      move_to(scene, 6, 4)
      assert_equal "Petalburg City, Gym", Map.square_text(scene, 3, 4)
    end
  end

  test "says a move as one line, the weather the HUD paints not said on its own" do
    scene = weather_map
    with_map(scene, 6, 4) do
      assert_equal [[PETALBURG, true]], said { move_to(scene, 3, 4) }
    end
  end

  test "says a move onto open sea by the square's coordinates" do
    scene = weather_map
    with_map(scene, 6, 4) do
      assert_equal [[t(:brm_square, :x => 5, :y => 5), true]], said { move_to(scene, 5, 5) }
    end
  end

  test "says the point of interest the secret base paints over town_map.dat's, whatever the region's name" do
    ["Hoenn", ""].each do |region|
      scene = BetterRegionMap.new(ROWS)
      scene.instance_variable_set(:@region_name, region)
      with_map(scene, 9, 2) do
        scene.update_text
        assert_equal "Route 104, Secret Base", Map.square_text(scene, 9, 2), "region #{region.inspect}"
      end
    end
  end

  test "the weather map opens with its region's name, then its square" do
    scene = weather_map
    with_region_names do
      SpeakCapture.clear
      with_map(scene, 6, 4) { assert_equal [["msg0", false], ["Route 102", false]], SpeakCapture.log }
    end
  end

  test "the quest map's title is its own, with the key for its list while key hints are said" do
    hint = "Quest Log. L/R : LIST"
    assert_equal ["Quest Log", hint, hint], vb_levels { Map.region_name(quest_map) }
  end

  test "the quest map opens with its title, its square, then a panel built before it was up" do
    scene = quest_map
    SpeakCapture.clear
    with_selection(3, 4) { scene.show_popup(QUESTS) }
    with_map(scene, 3, 4) do
      assert_equal [["Quest Log. L/R : LIST", false], ["Petalburg City, 3 quests in progress", false], [panel, false]],
                   SpeakCapture.log
    end
  end

  test "says a move on the quest map with the place and the quests in progress it paints" do
    scene = quest_map
    with_map(scene, 6, 4) do
      assert_equal [["Petalburg City, 3 quests in progress", true]], said { move_to(scene, 3, 4) }
    end
  end

  test "says one quest in progress in the singular" do
    scene = quest_map([6, 4] => [QUESTS[0]])
    with_map(scene, 3, 4) do
      assert_equal [["Route 102, 1 quest in progress", true]], said { move_to(scene, 6, 4) }
    end
  end

  test "says a move on the quest map onto a square with no place by its coordinates" do
    scene = quest_map
    with_map(scene, 3, 4) do
      assert_equal [[t(:brm_square, :x => 5, :y => 5), true]], said { move_to(scene, 5, 5) }
    end
  end

  test "says a full repaint of the quest map once, with the quest map's own line" do
    scene = quest_map
    with_map(scene, 6, 4) do
      $PokemonGlobal.regionMapSel = [3, 4]
      assert_equal [["Petalburg City, 3 quests in progress", true]], said { scene.update_text }
    end
  end

  test "reads a square's panel queued, its header and each quest with the kind its colour marks" do
    scene = quest_map
    with_map(scene, 3, 4) do
      assert_equal [[panel, false]], said { scene.show_popup(QUESTS) }
    end
  end

  test "reads the panel's quests without their kinds at brief" do
    scene = quest_map
    with_map(scene, 3, 4) do
      PokeAccess::Config.verbosity = :brief
      assert_equal [["Petalburg City Quests. Busca el gato. Lleva la carta. Grafiti", false]],
                   said { scene.show_popup(QUESTS) }
    end
  end

  test "does not read the same panel again, nor one rebuilt for the same quests in another order" do
    scene = quest_map
    with_map(scene, 3, 4) do
      scene.show_popup(QUESTS)
      assert_equal [], said { Map.read(scene); scene.show_popup(QUESTS.reverse) }
    end
  end

  test "reads a panel of other quests at the same place" do
    other = [Quest.new("Busca el perro", :AQUA_QUEST), Quest.new("Lleva el paquete", :SIDE_QUEST),
             Quest.new("Pinta", :SIDE_QUEST)]
    scene = quest_map
    with_map(scene, 3, 4) do
      scene.show_popup(QUESTS)
      want = "Petalburg City Quests. Busca el perro, #{t(:if2_qt_aqua)}. Lleva el paquete. Pinta"
      assert_equal [[want, false]], said { scene.show_popup(other) }
    end
  end

  test "says nothing for a panel with no quests" do
    scene = quest_map
    with_map(scene, 3, 4) do
      assert_equal [], said { scene.show_popup([]) }
    end
  end

  test "forgets the panel on a square without quests, so the panel built on coming back is read again" do
    scene = quest_map
    with_map(scene, 3, 4) do
      scene.show_popup(QUESTS)
      scene.hide_popup
      move_to(scene, 5, 5)
      move_to(scene, 3, 4)
      assert_equal [[panel, false]], said { scene.show_popup(QUESTS) }
    end
  end

  test "reads a panel left up after the square's line, on coming back from a square without quests" do
    scene = quest_map
    with_map(scene, 3, 4) do
      scene.show_popup(QUESTS)
      move_to(scene, 5, 5)
      assert_equal [["Petalburg City, 3 quests in progress", true], [panel, false]], said { move_to(scene, 3, 4) }
    end
  end

  private

  def t(key, opts = {}); PokeAccess::I18n.t(key, opts); end

  # The weather map over ROWS.
  def weather_map
    BetterRegionMap.new(ROWS, WEATHER)
  end

  # The quest map over ROWS, its quests filed by square ([3, 4] has QUESTS).
  def quest_map(quests = { [3, 4] => QUESTS })
    QuestMap.new(ROWS, quests)
  end

  # The side panel of QUESTS at Petalburg City as it is read: its header, then each quest with its kind from medium.
  def panel
    "Petalburg City Quests. Busca el gato, #{t(:qmp_main)}. Lleva la carta. Grafiti, #{t(:if2_qt_magma)}"
  end

  # Runs the block with the screen's cursor global on $PokemonGlobal holding [x, y], the global put back after.
  def with_selection(x, y)
    g = $PokemonGlobal
    added = !g.respond_to?(:regionMapSel)
    if added
      def g.regionMapSel; @pa_spec_sel; end
      def g.regionMapSel=(v); @pa_spec_sel = v; end
    else
      was = g.regionMapSel
    end
    g.regionMapSel = [x, y]
    yield
  ensure
    if added
      g.singleton_class.send(:remove_method, :regionMapSel, :regionMapSel=)
      g.send(:remove_instance_variable, :@pa_spec_sel) if g.instance_variable_defined?(:@pa_spec_sel)
    else
      g.regionMapSel = was
    end
  end

  # Runs the block with the screen opened as the game opens it, its cursor on (x, y), and closed after.
  def with_map(scene, x, y)
    with_selection(x, y) do
      begin
        scene.main
        yield
      ensure
        scene.dispose
      end
    end
  end

  # Moves the cursor to (x, y) and repaints the line there, as the screen's cursor animation does.
  def move_to(scene, x, y)
    $PokemonGlobal.regionMapSel = [x, y]
    scene.update_text_at_location(scene.find_location_at_position(x, y))
  end

  # What the block made the mod say, as [text, interrupt] pairs.
  def said
    SpeakCapture.clear
    yield
    SpeakCapture.log.dup
  end

  # Runs the block with the game's region names in MessageTypes, which the gamedata stub lacks, taken out after only
  # when it was put in here.
  def with_region_names
    added = !MessageTypes.const_defined?(:RegionNames, false)
    MessageTypes.const_set(:RegionNames, 1) if added
    yield
  ensure
    MessageTypes.send(:remove_const, :RegionNames) if added
  end
end
