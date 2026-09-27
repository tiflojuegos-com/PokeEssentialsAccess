# Infinite Fusion Hoenn's region map screens, gamedata pass: the weather map's HUD weather joins the square's line
# instead of being cut by it, the secret base's painted point of interest wins over town_map.dat's, and the quest map
# reads its own line, title and side panel. The stand-ins keep the Hoenn copy's paint (region name on top, place and
# point of interest on the bottom line, weather as HUD text) and come before the plugin loads again (the harness had
# no BetterRegionMap for its hooks) and then the profile, as the game loads them; the quest log's reader, whose quest
# kinds the side panel shares, is loaded here only when no earlier spec has.
unless Kernel.respond_to?(:pbDisplayText)
  def Kernel.pbDisplayText(_message, _x, _y, _z = nil, _base = nil, _shadow = nil, _align = 2); nil; end
end
def Kernel.pbClearText; nil; end unless Kernel.respond_to?(:pbClearText)

class BetterRegionMap
  def initialize(rows, weather = {})
    @data = [nil, nil, rows]
    @region = 0
    @weather = weather
    @show_weather = true
    @region_name = "Hoenn"
  end
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
    Kernel.pbDisplayText(w[0], 400, 25)
    Kernel.pbDisplayText(w[1], 400, 50)
  end
end

class IfhQuestPanel
  def initialize(quests, place); @quests = quests; @location_name = place; end
end

class QuestMap < BetterRegionMap
  def initialize(rows, quests)
    super(rows)
    @show_weather = false
    @quests = quests
    @popup = nil
  end
  def update_text_at_location(location)
    n = (@quests[$PokemonGlobal.regionMapSel] || []).length
    pbDrawTextPositions(nil, [["Quest Log", 24, -8], ["L/R : LIST", 360, -8], [location ? location[2] : "", 16, 344],
                              [n > 0 ? "#{n} quests in progress" : "", 496, 344]])
  end
  def show_popup(quests); @popup = IfhQuestPanel.new(quests, "Petalburg City"); end
  def hide_popup; @popup = nil; end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.expand_path("../../../plugins/better_region_map.rb", File.dirname(__FILE__))
ensure
  $VERBOSE = verbose
end
unless defined?(PokeAccess::IF2Quests)
  load File.expand_path("../../../games/infinitefusion_hoenn/quests.rb", File.dirname(__FILE__))
end
load File.expand_path("../../../games/infinitefusion_hoenn/region_map.rb", File.dirname(__FILE__))

module IfhRegionRig
  def self.arm_global
    return if $PokemonGlobal.respond_to?(:regionMapSel)
    def $PokemonGlobal.regionMapSel; @pa_sel ||= [0, 0]; end
    def $PokemonGlobal.regionMapSel=(v); @pa_sel = v; end
  end

  ROWS = [[3, 4, "Petalburg City", "Gym", 5], [6, 4, "Route 102", nil, 6], [9, 2, "Route 104", "Hut", 99]]
end

Suite.define("ifh region map: the weather map says each square's weather after its place, in one line") do
  IfhRegionRig.arm_global
  saved = $PokemonGlobal.regionMapSel
  begin
    scene = BetterRegionMap.new(IfhRegionRig::ROWS, 5 => ["Heavy sunshine", "30 C"])
    $PokemonGlobal.regionMapSel = [3, 4]
    scene.update_text
    rows = vb_levels { PokeAccess::BetterMap.square_text(scene, 3, 4) }
    eq "brief: the place and its weather", rows[0], "Petalburg City, Heavy sunshine"
    eq "full: its point of interest and the weather's figure too", rows[2], "Petalburg City, Gym, Heavy sunshine, 30 C"
    $PokemonGlobal.regionMapSel = [6, 4]
    scene.update_text_at_location(scene.find_location_at_position(6, 4))
    eq "a square with no weather says just its place", PokeAccess::BetterMap.square_text(scene, 6, 4), "Route 102"
    eq "and what was kept for another square is not added to this one",
       PokeAccess::BetterMap.square_text(scene, 3, 4), "Petalburg City, Gym"
  ensure
    $PokemonGlobal.regionMapSel = saved
  end
end

Suite.define("ifh region map: a move on the weather map is one line, the weather after the place, nothing cut") do
  IfhRegionRig.arm_global
  saved = $PokemonGlobal.regionMapSel
  scene = BetterRegionMap.new(IfhRegionRig::ROWS, 5 => ["Heavy sunshine", "30 C"])
  begin
    PokeAccess::TownMap.opened(scene)
    $PokemonGlobal.regionMapSel = [3, 4]
    SpeakCapture.clear
    scene.update_text_at_location(scene.find_location_at_position(3, 4))
    line = PokeAccess::BetterMap.square_text(scene, 3, 4)
    truthy "the line said carries the weather", line.include?("Heavy sunshine")
    eq "the plugin's read of the move, after the repaint was kept, is the only speech", SpeakCapture.log,
       [[line, true]]
  ensure
    PokeAccess::TownMap.closed(scene)
    $PokemonGlobal.regionMapSel = saved
  end
end

Suite.define("ifh region map: the secret base's square says the point of interest the screen paints over it") do
  IfhRegionRig.arm_global
  saved = $PokemonGlobal.regionMapSel
  begin
    scene = BetterRegionMap.new(IfhRegionRig::ROWS)
    $PokemonGlobal.regionMapSel = [9, 2]
    scene.update_text
    eq "the painted Secret Base, not town_map.dat's", PokeAccess::BetterMap.square_text(scene, 9, 2),
       "Route 104, Secret Base"
    scene.instance_variable_set(:@region_name, "")
    scene.update_text
    eq "also on a map whose region paints no name", PokeAccess::BetterMap.square_text(scene, 9, 2),
       "Route 104, Secret Base"
  ensure
    $PokemonGlobal.regionMapSel = saved
  end
end

Suite.define("ifh region map: the quest map reads its title, each square's quests and the side panel once") do
  t = PokeAccess::I18n
  IfhRegionRig.arm_global
  saved = $PokemonGlobal.regionMapSel
  q = Struct.new(:name, :type)
  quests = [q.new("Busca el gato", :MAIN_QUEST), q.new("Lleva la carta", :SIDE_QUEST), q.new("Grafiti", :MAGMA_QUEST)]
  scene = QuestMap.new(IfhRegionRig::ROWS, { [3, 4] => quests })
  begin
    eq "its title and, while hints are said, the key for the list", PokeAccess::BetterMap.region_name(scene),
       "Quest Log. L/R : LIST"
    PokeAccess::TownMap.opened(scene)
    $PokemonGlobal.regionMapSel = [3, 4]
    SpeakCapture.clear
    scene.update_text_at_location(scene.find_location_at_position(3, 4))
    eq "a move reads the place and the quests in progress it paints, never town_map.dat's point of interest",
       SpeakCapture.last, "Petalburg City, 3 quests in progress"
    SpeakCapture.clear
    scene.show_popup(quests)
    eq "the passive panel, queued: its header and each quest with the kind its colour marks",
       SpeakCapture.log,
       [["Petalburg City Quests. Busca el gato, #{t.t(:qmp_main)}. Lleva la carta. Grafiti, #{t.t(:if2_qt_magma)}", false]]
    SpeakCapture.clear
    PokeAccess::BetterMap.read(scene)
    silent "the same panel is not read again"
    scene.show_popup(quests.reverse)
    silent "nor the one the map rebuilds for the same quests in another order as the cursor settles"
    scene.hide_popup
    $PokemonGlobal.regionMapSel = [5, 5]
    scene.update_text_at_location(scene.find_location_at_position(5, 5))
    $PokemonGlobal.regionMapSel = [3, 4]
    scene.update_text_at_location(scene.find_location_at_position(3, 4))
    SpeakCapture.clear
    scene.show_popup(quests)
    truthy "a square without quests forgets the panel, so coming back reads it again",
           SpeakCapture.lines.any? { |l| l.start_with?("Petalburg City Quests") }
  ensure
    PokeAccess::TownMap.closed(scene)
    $PokemonGlobal.regionMapSel = saved
  end
end
