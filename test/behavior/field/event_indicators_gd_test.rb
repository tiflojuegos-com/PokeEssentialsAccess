# Event Indicators (plugins/event_indicators.rb) floats a marker over an event while its page carries an "Event
# Indicator" comment (a quest to take, in emerald); the locator says it after the event's name while it shows.
class EventIndicatorsGdTest < PokeAccessTest
  Marker = Struct.new(:type, :visible, :disposed) do
    def disposed?; disposed; end
  end

  # The map scene the markers live under: spriteset(map_id) answers the map's spriteset, which holds them by event id.
  class MapScene
    def initialize(markers); @set = Struct.new(:event_indicator_sprites).new(markers); end
    def spriteset(_map_id = -1); @set; end
  end

  test "every marker drawn with the quest graphics is a quest, any other is left to its picture" do
    npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc")
    { "quest" => true, "questsimple" => true, "questshortnpc" => true, "QuestNPC" => true, "question" => false,
      "Question" => false, "exclamation" => false, nil => false }.each do |type, named|
      want = named ? [quest] : []
      with_markers(3 => Marker.new(type, true, false)) do
        assert_equal want, PokeAccess::Locator.name_marks(npc), "a #{type.inspect} marker"
      end
    end
  end

  test "a marker hidden, disposed or that cannot say either is not said" do
    npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc")
    { "hidden while its event talks" => Marker.new("quest", false, false),
      "disposed as the page changed" => Marker.new("quest", true, true),
      "with no visible" => Struct.new(:type, :disposed?).new("quest", false),
      "with no disposed?" => Struct.new(:type, :visible).new("quest", true) }.each do |what, marker|
      with_markers(3 => marker) { assert_nil PokeAccess::EventIndicators.mark(npc), what }
    end
  end

  test "an event with no marker has no mark" do
    World.event(:id => 3, :name => "Grunt", :sprite => "npc")
    nurse = World.event(:id => 4, :name => "Nurse", :sprite => "nurse")
    with_markers(3 => Marker.new("quest", true, false)) { assert_equal [], PokeAccess::Locator.name_marks(nurse) }
  end

  test "a target that is not the map's own event carries no mark" do
    World.event(:id => 3, :name => "Grunt", :sprite => "npc", :x => 7, :y => 5)
    stray = TestGameEvent.new(:id => 3, :x => 7, :y => 5, :name => "Grunt", :pages => [TestPage.new(:sprite => "npc")])
    with_markers(3 => Marker.new("quest", true, false)) do
      assert_equal [], PokeAccess::Locator.name_marks(Struct.new(:x, :y, :id).new(7, 5, 3)), "a bare target at its tile"
      assert_equal [], PokeAccess::Locator.name_marks(stray), "another event under its id"
    end
  end

  test "outside the map scene, or with no markers kept, there is nothing to say" do
    npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc")
    assert_nil PokeAccess::EventIndicators.mark(npc), "a scene with no spriteset"
    with_markers(nil) { assert_nil PokeAccess::EventIndicators.mark(npc), "a spriteset with no marker list" }
  end

  test "the locator says the mark after the event's name while the marker shows, and leaves it out once it hides" do
    npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc", :x => 7, :y => 5)
    marker = Marker.new("quest", true, false)
    with_markers(3 => marker) do
      selecting(npc) do
        PokeAccess::Locator.announce_selected(true)
        marker.visible = false
        PokeAccess::Locator.announce_selected(true)
      end
    end
    rest = SpeakCapture.lines.last.to_s.sub(/\AGrunt, /, "")
    assert_equal ["Grunt, #{quest}, #{rest}", "Grunt, #{rest}"], SpeakCapture.lines,
                 "the name, the mark, then the rest of the line; the same line without the mark once hidden"
  end

  private

  def quest; PokeAccess::I18n.t(:evind_quest); end

  # Runs the block with npc as the locator's only target, selected; the locator's selection put back after.
  def selecting(npc)
    loc = PokeAccess::Locator
    saved = [loc.instance_variable_get(:@target), loc.instance_variable_get(:@targets)]
    loc.instance_variable_set(:@targets, [npc])
    loc.instance_variable_set(:@target, npc)
    yield
  ensure
    loc.instance_variable_set(:@target, saved[0])
    loc.instance_variable_set(:@targets, saved[1])
  end

  # Runs the block on the map scene, its spriteset keeping markers ({ event id => marker }, or nil for no list).
  def with_markers(markers)
    list = nil
    if markers
      list = []
      markers.each { |id, m| list[id] = m }
    end
    had = $scene
    $scene = MapScene.new(list)
    yield
  ensure
    $scene = had
  end
end
