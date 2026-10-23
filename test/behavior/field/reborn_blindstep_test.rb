# Reborn's Blindstep mode (games/reborn/blindstep.rb) plays footsteps, wall echoes and an event cue like the mod's
# own: while both sound, the mod names once per session, after a map's name, the options that mute either.
blindstep = File.join(Harness::ROOT, "games", "reborn", "blindstep.rb")
eval(Harness.source(blindstep), TOPLEVEL_BINDING, blindstep)

class RebornBlindstepTest < PokeAccessTest
  # Reborn's accessibility settings ($Settings): the master volume and its three sets.
  Settings = Struct.new(:accessibilityVolume, :footstepVolume, :wallVolume, :eventVolume)

  test "with Blindstep and the mod's sounds both playing, names the clash, queued" do
    with_blindstep(Settings.new(100, 100, 100, 75)) { PokeAccess::RebornBlindstep.warn_once }
    assert_equal [[notice, false]], SpeakCapture.log
  end

  test "names it only once per session" do
    with_blindstep(Settings.new(100, 100, 100, 75)) do
      PokeAccess::RebornBlindstep.warn_once
      SpeakCapture.clear
      PokeAccess::RebornBlindstep.warn_once
    end
    assert_nothing_spoken
  end

  test "Blindstep sounds while its master volume and any one of its three sets are above zero" do
    master_only = Struct.new(:accessibilityVolume)
    { Settings.new(1, 1, 0, 0) => true, Settings.new(1, 0, 1, 0) => true, Settings.new(1, 0, 0, 1) => true,
      Settings.new(1, 0, 0, 0) => false, Settings.new(0, 100, 100, 75) => false,
      Settings.new(:alto, 100, 100, 75) => false, master_only.new(100) => false,
      Struct.new(:footstepVolume, :wallVolume, :eventVolume).new(100, 100, 75) => false,
      nil => false }.each do |s, clash|
      SpeakCapture.clear
      with_blindstep(s) { PokeAccess::RebornBlindstep.warn_once }
      assert_equal(clash ? [[notice, false]] : [], SpeakCapture.log, "with the game's settings #{s.inspect}")
    end
  end

  test "with Blindstep on, a random walker stands still and is no mover, while one heading for the player still is" do
    ev = PokeAccess::World::Events
    World.clear_events
    random = World.event(:id => 6, :x => 2, :y => 2)
    random.instance_variable_set(:@active, TestPage.new(:move_type => 1))
    toward = World.event(:id => 7, :x => 4, :y => 2)
    toward.instance_variable_set(:@active, TestPage.new(:move_type => 2))
    ev.sync(true)
    got = [false, true].map do |on|
      $game_switches[:Blindstep] = on
      [ev.mover?(ev.record_of(random)), ev.mover?(ev.record_of(toward))]
    end
    assert_equal [[true, true], [false, true]], got, "Blindstep off, then on"
  ensure
    $game_switches[:Blindstep] = false
  end

  test "without the Blindstep switch on, there is nothing to clash with" do
    with_blindstep(Settings.new(100, 100, 100, 75), false) { PokeAccess::RebornBlindstep.warn_once }
    assert_nothing_spoken
  end

  test "with switches it cannot read by name, there is nothing to clash with" do
    switches = $game_switches
    with_blindstep(Settings.new(100, 100, 100, 75)) do
      $game_switches = Class.new { def [](_id); raise TypeError, "a switch is read by its number"; end }.new
      PokeAccess::RebornBlindstep.warn_once
    end
    assert_nothing_spoken
  ensure
    $game_switches = switches
  end

  test "the mod sounds while its positional audio is on and any one of its three sets is above zero" do
    playing = { :sound_nav => :full, :audio3d_volume => 80, :footstep_volume => 80, :wall_volume => 80,
                :event_volume => 70 }
    { {} => true, { :sound_nav => :off } => false, { :audio3d_volume => 0 } => false, { :audio3d_volume => 1 } => true,
      { :footstep_volume => 0, :wall_volume => 0, :event_volume => 0 } => false,
      { :footstep_volume => 1, :wall_volume => 0, :event_volume => 0 } => true,
      { :footstep_volume => 0, :wall_volume => 1, :event_volume => 0 } => true,
      { :footstep_volume => 0, :wall_volume => 0, :event_volume => 1 } => true }.each do |options, clash|
      playing.merge(options).each { |key, value| PokeAccess::Config.send("#{key}=", value) }
      SpeakCapture.clear
      with_blindstep(Settings.new(100, 100, 100, 75)) { PokeAccess::RebornBlindstep.warn_once }
      assert_equal(clash ? [[notice, false]] : [], SpeakCapture.log, "with the mod's options #{options.inspect}")
    end
  end

  test "a set of the mod's switched off in Sounds on does not sound, whatever its volume" do
    playing = { :sound_steps => true, :sound_wall => true, :footstep_volume => 80, :wall_volume => 80,
                :event_volume => 70 }
    { { :sound_steps => false, :sound_wall => false, :event_volume => 0 } => false,
      { :sound_steps => false, :wall_volume => 0, :event_volume => 0 } => false,
      { :sound_wall => false, :footstep_volume => 0, :event_volume => 0 } => false,
      { :sound_steps => false, :sound_wall => false } => true }.each do |options, clash|
      playing.dup.merge!(options).each { |key, value| PokeAccess::Config.send("#{key}=", value) }
      SpeakCapture.clear
      with_blindstep(Settings.new(100, 100, 100, 75)) { PokeAccess::RebornBlindstep.warn_once }
      assert_equal(clash ? [[notice, false]] : [], SpeakCapture.log, "with the mod's options #{options.inspect}")
    end
  end

  test "entering a map, the notice follows the map's name, and only on the first" do
    with_blindstep(Settings.new(100, 100, 100, 75)) do
      [40, 35].each do |map|
        $game_map.map_id = map
        PokeAccess::Locator.announce_map_change
      end
    end
    assert_equal [["Mapa 40", false], [notice, false], ["Mapa 35", false]], SpeakCapture.log
  end

  private

  # The notice that names the options muting either set.
  def notice
    PokeAccess::I18n.t(:reb_blindstep_overlap)
  end

  # Runs the block with Reborn's settings and its Blindstep switch as given and the notice not said yet this session;
  # the settings and the notice's state are put back after.
  def with_blindstep(settings, on = true)
    was = $Settings
    $Settings = settings
    $game_switches[:Blindstep] = on
    PokeAccess::RebornBlindstep.forget
    yield
  ensure
    $Settings = was
    PokeAccess::RebornBlindstep.forget
  end
end
