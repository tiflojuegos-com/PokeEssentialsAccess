# Sevii's Cycling Road (games/sevii/cycling_road.rb) over a stand-in shaped as its HUD (0253_Cycling Road HUD.rb): built
# as a run starts, it paints "Time:" over the seconds ridden, then repaints them as the run goes on. A run is timed
# while switch 270 is on, with its CyclingRoadState in variable 85. The stand-in holds CyclingRoadHUD's name only while
# the file is evaluated, so the hook binds to it and no other test sees the HUD.

# The HUD as far as its text goes: createText paints the label over the time, from initialize and on each repaint.
class SeviiCyclingHud
  def initialize
    @time = 0
    createText
  end

  def createText
    pbDrawTextPositions(nil, [[sprintf("Time:"), 60, 3, 0, nil, nil]])
    pbDrawTextPositions(nil, [[sprintf("%.2f seconds", @time), 60, 28, 0, nil, nil]])
    :painted
  end

  # The repaint after riding for the seconds given.
  def ride(seconds)
    @time = seconds
    createText
  end
end

hud_made = !Object.const_defined?(:CyclingRoadHUD)
Object.const_set(:CyclingRoadHUD, SeviiCyclingHud) if hud_made
begin
  road = File.join(Harness::ROOT, "games", "sevii", "cycling_road.rb")
  profiles = PokeAccess::Game.profiles.dup
  eval(Harness.source(road), TOPLEVEL_BINDING, road)
  PokeAccess::Game.instance_variable_set(:@profiles, profiles)
  PokeAccess::Game.instance_variable_set(:@profile_name, nil)
ensure
  Object.send(:remove_const, :CyclingRoadHUD) if hud_made
end

class SeviiCyclingRoadTest < PokeAccessTest
  # The run as variable 85 holds it, with its HUD.
  RoadState = Struct.new(:hud)
  # A Safari as pbSafariState answers it: running, with balls and steps left.
  Safari = Struct.new(:ballcount, :steps) do
    def inProgress?; true; end
  end

  test "a run's HUD says its first paint, queued, as the run starts, and nothing as it repaints" do
    hud = SeviiCyclingHud.new
    assert_equal :painted, hud.ride(1.5), "the HUD keeps its own answer"
    hud.ride(2.25)
    assert_equal [["Time: 0.00 seconds", false]], SpeakCapture.log
  end

  test "the field key says the time the HUD painted last while the run is timed, and leaves it out once it ends" do
    plain = field_key
    start_run.ride(12.5)
    assert_equal "#{plain}, Time: 12.50 seconds", field_key
    $game_switches[270] = false
    assert_equal plain, field_key
  end

  test "the field key says no time while variable 85 holds no HUD, and the time once one has painted" do
    $game_switches[270] = true
    plain = field_key
    $game_variables[85] = RoadState.new(nil)
    assert_equal plain, field_key
    start_run.ride(4)
    assert_equal "#{plain}, Time: 4.00 seconds", field_key
  end

  test "the run's time goes ahead of the field events core counts" do
    start_run.ride(3)
    safari = [PokeAccess::I18n.t(:safari_balls, :n => 12), PokeAccess::I18n.t(:safari_steps, :n => 300)].join(", ")
    GameFunctions.with(:pbSafariState => lambda { Safari.new(12, 300) }) do
      assert_equal "Time: 3.00 seconds, #{safari}", PokeAccess::Battle.field_event_text
    end
  end

  private

  # A run as the gate's event starts one: the switch on, the run in variable 85 and its HUD built.
  def start_run
    hud = SeviiCyclingHud.new
    $game_switches[270] = true
    $game_variables[85] = RoadState.new(hud)
    SpeakCapture.clear
    hud
  end

  # What the field key says off battle.
  def field_key
    PokeAccess::Battle.announce_overworld
    SpeakCapture.lines.last
  ensure
    SpeakCapture.clear
  end
end
