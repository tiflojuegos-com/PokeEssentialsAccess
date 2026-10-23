# Sound.earcon, the sounds always played flat: an id plays its catalog file at the volume given or its family's and
# the pitch given or the catalog's through its family's tone, up to 150; nothing at volume zero or with no :any file.
class EarconTest < PokeAccessTest
  Sound = PokeAccess::Sound
  SOUNDS = PokeAccess::Paths::SOUNDS

  test "plays a sound's file at the volume given and the catalog's pitch" do
    assert_equal [["#{SOUNDS}/pa_guide_c", 40, 88]], plays { Sound.earcon(:radar, 40) }
  end

  test "plays at the pitch given over the catalog's" do
    assert_equal [["#{SOUNDS}/pa_mg_tick", 60, 123]], plays { Sound.earcon(:minigame, 60, 123) }
  end

  test "plays at its family's volume when given none" do
    PokeAccess::Config.radar_volume = 44
    assert_equal [["#{SOUNDS}/pa_guide_c", 44, 88]], plays { Sound.earcon(:radar) }
  end

  test "pitches the radar by a tone of its own, the guide's leaving it alone" do
    PokeAccess::Config.guide_tone = 30
    assert_equal [["#{SOUNDS}/pa_guide_c", 40, 88]], plays { Sound.earcon(:radar, 40) }, "the guide's tone at 30"
    PokeAccess::Config.radar_tone = 30
    assert_equal [["#{SOUNDS}/pa_guide_c", 40, 67]], plays { Sound.earcon(:radar, 40) },
                 "its own at 30 plays the recording at 76 %, its 88 at 67"
  end

  test "ticks the radar below the guide's chime ahead and above its chime behind, whatever the guide's tone" do
    radar = plays { Sound.earcon(:radar, 40) }[0][2]
    chimes = (0..20).map do |i|
      PokeAccess::Config.guide_tone = i * 5
      [8, 2].map { |d| plays { Sound.cue(:guide, :dir => d, :vol => 40) }[0][2] }
    end
    assert_equal [], chimes.reject { |ahead, behind| behind < radar && radar < ahead }, "the radar at #{radar}"
  end

  test "never pitches past the flat channel's 150" do
    PokeAccess::Config.radar_tone = 100
    assert_equal [["#{SOUNDS}/pa_guide_c", 40, 150]], plays { Sound.earcon(:radar, 40) }
  end

  test "plays nothing at volume zero" do
    assert_equal [], plays { Sound.earcon(:radar, 0) }
  end

  test "plays nothing for an unknown sound, one never flat or one flat only toward a direction" do
    [:no_such_sound, :grid, :wall].each { |id| assert_equal [], plays { Sound.earcon(id, 50) }, id.inspect }
  end

  private

  # What the flat channel was asked to play while the block ran, as [file, volume, pitch].
  def plays
    with_cue_log do |log|
      yield
      log
    end
  end
end
