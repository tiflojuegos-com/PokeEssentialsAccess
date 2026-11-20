# The pitch the player sets for each side (audio3d_pitch_north, south, west and east) in mono and stereo, where the dll
# already pitches a source by how far ahead or behind it lies: the engine is sent the rate that, over its own tilt,
# sounds at the player's pitch, so the defaults change nothing.
class DirectionPitchTest < PokeAccessTest
  Pa3d = PokeAccess::Sound::Pa3d
  Cfg = PokeAccess::Config

  test "at the default pitches a source plays at its own rate on every side, the engine's tilt alone pitching it" do
    stereo do |dll|
      [[5, 4], [5, 6], [4, 5], [6, 5], [6, 4], [3, 8]].each { |x, y| Pa3d.start(:wall, x, y, 80) }
      assert_equal [[:wall, 100]], dll.by_sound(:pitch)
    end
  end

  test "a source on a side plays at the pitch set for it, over the engine's tilt" do
    set_pitches(130, 70, 90, 110)
    stereo do |dll|
      sent = [[5, 4], [5, 6], [4, 5], [6, 5]].map { |x, y| Pa3d.start(:wall, x, y, 80); dll.by_sound(:pitch).last[1] }
      assert_equal [108, 88, 90, 110], sent, "north 130 over 120, south 70 over 80, west and east as set"
    end
  end

  test "a source on a diagonal mixes the pitches of its two sides" do
    set_pitches(130, 70, 90, 110)
    stereo do |dll|
      Pa3d.start(:wall, 6, 4, 80)
      assert_equal 112, dll.by_sound(:pitch).last[1], "north-east: 1.2828 over the engine's 1.1414"
    end
  end

  test "the pitch for a side is on top of the sound's own tone" do
    set_pitches(130, 80, 100, 100)
    stereo do |dll|
      Pa3d.tone(:wall, 120)
      Pa3d.start(:wall, 5, 4, 80)
      assert_equal [[:wall, 100], [:wall, 120], [:wall, 130]], dll.by_sound(:pitch)
    end
  end

  test "with speakers behind, or binaural, and for a source on the listener, the rate is the sound's own" do
    set_pitches(130, 70, 90, 110)
    [:binaural, :quad, :surround51, :surround71].each do |mode|
      with_sound_engine do |dll|
        Pa3d.output(mode)
        Pa3d.listener(5, 5)
        Pa3d.tone(:wall, 100)
        Pa3d.start(:wall, 5, 4, 80)
        assert_equal [[:wall, 100]], dll.by_sound(:pitch), mode.to_s
      end
    end
    stereo do |dll|
      Pa3d.start(:wall, 5, 5, 80)
      assert_equal [[:wall, 100]], dll.by_sound(:pitch), "on the listener"
    end
  end

  test "a loop that plays is pitched again as the listener moves to its other side" do
    set_pitches(130, 70, 100, 100)
    stereo do |dll|
      Pa3d.tone(:water, 100)
      Pa3d.hold(:water, 5, 3, 70)
      Pa3d.listener(5, 2)
      assert_equal [100, 108, 88], dll.by_sound(:pitch).select { |id, _pct| id == :water }.map { |_id, pct| pct }
    end
  end

  test "the menu shows the four pitches with stereo or mono output only" do
    rows = [:audio3d_pitch_north, :audio3d_pitch_south, :audio3d_pitch_west, :audio3d_pitch_east].map { |k| Cfg.setting(k) }
    Reset.with_capability(:positional, true) do
      shown = [:binaural, :stereo, :mono, :quad, :surround71].map do |mode|
        Cfg.audio3d_output = mode
        rows.map { |r| Cfg.visible?(r) }.uniq
      end
      assert_equal [[false], [true], [true], [false], [false]], shown
    end
  end

  private

  # Sets the pitches for the north, the south, the west and the east.
  def set_pitches(north, south, west, east)
    Cfg.audio3d_pitch_north = north
    Cfg.audio3d_pitch_south = south
    Cfg.audio3d_pitch_west = west
    Cfg.audio3d_pitch_east = east
  end

  # Runs the block with the engine in stereo, the listener on (5, 5) and the wall's tone at 100, yielding the dll.
  def stereo
    with_sound_engine do |dll|
      Pa3d.output(:stereo)
      Pa3d.listener(5, 5)
      Pa3d.tone(:wall, 100)
      yield dll
    end
  end
end
