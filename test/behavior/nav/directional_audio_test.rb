require "tmpdir"

class DirectionalAudioTest < PokeAccessTest
  Cfg = PokeAccess::Config
  Sound = PokeAccess::Sound
  SIDES = [:front, :back, :left, :right]

  test "four direction defaults and labels are complete in every supported language" do
    assert_equal [120, 80, 100, 100], Sound::Mixer.direction_pitches
    [:en, :pl, :es, :fr, :de, :pt].each do |language|
      Cfg.language = language
      (SIDES.map { |s| "lbl_direction_#{s}".to_sym } +
        [:help_direction_pitch, :percent_unit, :lbl_interact_vol, :lbl_interact_tone, :help_interact_vol, :help_interact_tone]).each do |key|
        refute_equal key.to_s, PokeAccess::I18n.t(key)
        refute_equal "", PokeAccess::I18n.t(key)
      end
    end
  end

  test "boot and later updates send all four pitches together without replaying sources" do
    set_directions([140, 60, 75, 125])
    Cfg.audio3d_output = :stereo
    with_sound_engine(false) do |dll|
      assert_equal true, Sound::Pa3d.boot
      assert_equal [[140, 60, 75, 125]], dll.args(:directional_pitch)
      Sound::Pa3d.directional_pitch(*Sound::Mixer.direction_pitches)
      assert_equal 1, dll.args(:directional_pitch).length
      Cfg.direction_pitch_left = 90
      Sound::Pa3d.directional_pitch(*Sound::Mixer.direction_pitches)
      assert_equal [[140, 60, 75, 125], [140, 60, 90, 125]], dll.args(:directional_pitch)
      assert_equal [], dll.played
    end
  end

  test "direction rows require stereo or mono and their actual native capability" do
    with_sound_engine do
      row = Cfg.setting(:direction_pitch_front)
      Cfg.audio3d_output = :binaural
      assert_equal false, Cfg.visible?(row)
      [:stereo, :mono].each { |mode| Cfg.audio3d_output = mode; assert_equal true, Cfg.visible?(row) }
    end
    with_sound_engine(true, 44100, [:directional_pitch]) do |dll|
      Cfg.audio3d_output = :stereo
      assert_equal false, Cfg.visible?(Cfg.setting(:direction_pitch_front))
      Sound::Pa3d.directional_pitch(140, 60, 75, 125)
      assert_equal [], dll.args(:directional_pitch)
      assert_equal true, Sound::Pa3d.start(:npc, 6, 5, 70)
    end
  end

  test "flat bumps keep one pitch and preserve independent volumes" do
    Cfg.audio3d_output = :stereo
    set_directions([150, 50, 75, 125])
    Cfg.wall_volume = 30
    Cfg.interact_volume = 70
    {8 => 150, 2 => 50, 4 => 75, 6 => 125}.each do |direction, pitch|
      wall = flat_plays { Sound.flat(Sound::Catalog.entry(:wall), direction, Sound::Mixer.volume(:wall)) }.first
      object = flat_plays { Sound.flat(Sound::Catalog.entry(:interact), direction, Sound::Mixer.volume(:interact)) }.first
      assert_equal [30, 100], wall[1..2]
      assert_equal [70, 100], object[1..2]
    end
  end

  test "object bump volume tone and enable state are independent from plain walls" do
    with_sound_engine do
      Cfg.sound_nav = :full
      Cfg.wall_volume = 0
      Cfg.interact_volume = 70
      assert_equal false, Sound.bump_audible?(false)
      assert_equal true, Sound.bump_audible?(true)
      Cfg.wall_volume = 80
      Cfg.sound_interact = false
      assert_equal true, Sound.bump_audible?(false)
      assert_equal false, Sound.bump_audible?(true)
      Cfg.sound_interact = true
      Cfg.wall_tone = 25
      Cfg.interact_tone = 75
      assert_equal 71, Sound::Mixer.pitch3d(:wall)
      assert_equal 141, Sound::Mixer.pitch3d(:interact)
    end
  end

  test "old shared bump settings migrate but explicit independent choices win" do
    with_settings do |path|
      File.binwrite(path, "wall_volume=30\nwall_tone=25\nsound_wall=false\n")
      PokeAccess::Settings.apply
      assert_equal [30, 25, false], [Cfg.interact_volume, Cfg.interact_tone, Cfg.sound_interact]
      File.binwrite(path, "wall_volume=30\nwall_tone=25\nsound_wall=false\ninteract_volume=70\ninteract_tone=75\nsound_interact=true\n")
      PokeAccess::Settings.apply
      assert_equal [30, 25, false], [Cfg.wall_volume, Cfg.wall_tone, Cfg.sound_wall]
      assert_equal [70, 75, true], [Cfg.interact_volume, Cfg.interact_tone, Cfg.sound_interact]
    end
  end

  test "custom direction rates persist and malformed numeric input is bounded" do
    with_settings do |path|
      set_directions([140, 60, 75, 125])
      Cfg.audio3d_output = :stereo
      PokeAccess::Settings.write
      set_directions([100, 100, 100, 100])
      PokeAccess::Settings.apply
      assert_equal [140, 60, 75, 125], Sound::Mixer.direction_pitches
      File.binwrite(path, "direction_pitch_front=-10\ndirection_pitch_back=1000\n")
      PokeAccess::Settings.apply
      assert_equal [50, 150], Sound::Mixer.direction_pitches[0..1]
    end
  end

  test "native contact cues opt out of direction pitch without moving their stereo position" do
    Cfg.audio3d_output = :stereo
    set_directions([150, 50, 75, 125])
    Cfg.wall_volume = 30
    Cfg.interact_volume = 70
    with_sound_engine(false) do |dll|
      assert_equal true, Sound::Pa3d.boot
      assert_equal [[:wall, 1], [:interact, 1]], dll.by_sound(:fixed_pitch)
      [[8, 5, 4], [2, 5, 6], [4, 4, 5], [6, 6, 5]].each do |dir, x, y|
        dll.log.clear
        assert_equal :engine, Sound.cue(:wall, :dir => dir)
        assert_equal [[:wall, x, y, 30]], dll.played
      end
    end
  end

  test "flat contact pitch stays constant while wall and object tones remain independent" do
    Cfg.audio3d_output = :stereo
    set_directions([150, 50, 75, 125])
    Cfg.wall_tone = 50
    Cfg.interact_tone = 75
    [8, 2, 4, 6].each do |direction|
      wall = flat_plays { Sound.flat(Sound::Catalog.entry(:wall), direction, 30) }.first
      object = flat_plays { Sound.flat(Sound::Catalog.entry(:interact), direction, 70) }.first
      assert_equal [30, 100], wall[1..2]
      assert_equal [70, 141], object[1..2]
    end
  end

  test "contact cues fall back safely with their stereo samples on an older native engine" do
    Cfg.audio3d_output = :stereo
    set_directions([150, 50, 75, 125])
    with_sound_engine(true, 44100, [:fixed_pitch]) do |dll|
      heard = flat_plays { assert_equal :flat, Sound.cue(:wall, :dir => 4, :vol => 40) }
      assert_equal [], dll.played
      assert_equal [["#{PokeAccess::Paths::SOUNDS}/pa3d_wall_l", 40, 100]], heard
      assert_equal true, Sound::Pa3d.start(:npc, 6, 5, 70)
    end
  end

  test "southern wall wind stays in an audible register in speaker modes and retains the shared tone" do
    [:stereo, :mono].each do |output|
      Cfg.audio3d_output = output
      Cfg.audio3d_tone_wind = 50
      with_sound_engine do
        assert_equal 200, Sound::Mixer.pitch3d(:wind_s)
        assert_equal 100, Sound::Mixer.pitch3d(:wind_n)
        assert_equal 100, Sound::Mixer.pitch3d(:wind_e)
        assert_equal 100, Sound::Mixer.pitch3d(:npc)
        Cfg.audio3d_tone_wind = 75
        assert_equal 282, Sound::Mixer.pitch3d(:wind_s)
      end
    end
    Cfg.audio3d_output = :binaural
    Cfg.audio3d_tone_wind = 50
    with_sound_engine { assert_equal 100, Sound::Mixer.pitch3d(:wind_s) }
  end

  test "category direction screens offer pitch and only applicable repetition controls" do
    Cfg.audio3d_output = :stereo
    with_sound_engine do
      Sound::Catalog.directional_families.each do |family|
        group = ("audio_directions_" + family.id.to_s).to_sym
        rows = Cfg.settings_in(group)
        assert_equal 4, rows.count { |row| row.key.to_s.end_with?("_pitch") }, family.id.to_s
        assert_equal(family.freq ? 4 : 0, rows.count { |row| row.key.to_s.end_with?("_rate") }, family.id.to_s)
        assert rows.all? { |row| Cfg.send(row.key) == 100 }, family.id.to_s
      end
      assert_nil Cfg.setting(:audio_dir_wind_north_rate)
      assert_nil Cfg.setting(:audio_dir_wall_north_rate)
      assert_nil Cfg.setting(:audio_dir_steps_north_pitch)
      assert_nil Cfg.setting(:audio_dir_grid_north_pitch)
      [:en, :pl, :es, :fr, :de, :pt].each do |language|
        Cfg.language = language
        [:cat_directional_sounds, :cat_directional_sounds_help, :help_dir_category_pitch, :help_dir_category_rate].each do |key|
          refute_equal key.to_s, PokeAccess::I18n.t(key)
        end
      end
    end
  end

  test "every directional setting names its sound family and direction in all supported languages" do
    Cfg.audio3d_output = :stereo
    with_sound_engine do
      [:en, :pl, :es, :fr, :de, :pt].each do |language|
        Cfg.language = language
        groups = Cfg.groups_in(:audio_directions)
        refute_empty groups
        groups.each do |group|
          family = PokeAccess::I18n.t(group.label)
          Cfg.settings_in(group.id).each do |row|
            name = PokeAccess::ConfigMenu.label_of(:kind => :setting, :row => row)
            assert_includes name, family, row.key.to_s
            assert_includes name, PokeAccess::I18n.t(row.label), row.key.to_s
            refute_includes name, "%{", row.key.to_s
          end
        end
      end
    end
  end

  test "shared directional pitch labels clearly identify their shared scope" do
    Cfg.language = :en
    expected = { :front => "Shared north pitch", :back => "Shared south pitch",
                 :left => "Shared west pitch", :right => "Shared east pitch" }
    expected.each do |side, label|
      row = Cfg.setting(("direction_pitch_" + side.to_s).to_sym)
      assert_equal label, PokeAccess::ConfigMenu.label_of(:kind => :setting, :row => row)
    end
  end

  test "family names are essential labels while ordinary settings and group names retain their labels" do
    Cfg.language = :en
    Cfg.read_help = false
    row = Cfg.setting(:audio_dir_wind_north_pitch)
    group = Cfg.groups_in(:audio_directions).find { |entry| entry.id == row.group }
    label = PokeAccess::ConfigMenu.label_of(:kind => :setting, :row => row)
    assert_includes label, PokeAccess::I18n.t(group.label)
    assert_equal 100, Cfg.send(row.key)
    assert_equal [:setting, row.key], PokeAccess::ConfigMenu.row_id(:kind => :setting, :row => row)
    assert_equal PokeAccess::I18n.t(group.label), PokeAccess::ConfigMenu.label_of(:kind => :enter, :label => group.label)
    ordinary = Cfg.setting(:read_help)
    assert_equal PokeAccess::I18n.t(ordinary.label), PokeAccess::ConfigMenu.label_of(:kind => :setting, :row => ordinary)
    unknown = Cfg::Setting.new(:label_fixture, false, :flag, :unregistered_fixture, ordinary.label)
    assert_equal PokeAccess::I18n.t(ordinary.label), PokeAccess::ConfigMenu.label_of(:kind => :setting, :row => unknown)
  end

  test "category pitch packets remain independent and update without replaying a source" do
    Cfg.audio3d_output = :stereo
    Cfg.audio_dir_people_north_pitch = 125
    Cfg.audio_dir_people_south_pitch = 75
    with_sound_engine(false) do |dll|
      assert_equal true, Sound::Pa3d.boot
      npc = Sound::Pa3d.channel(:npc)
      object = Sound::Pa3d.channel(:object)
      assert_includes dll.args(:channel_directions), [npc, 125, 75, 100, 100]
      assert_includes dll.args(:channel_directions), [object, 100, 100, 100, 100]
      dll.log.clear
      Cfg.audio_dir_people_east_pitch = 150
      Sound::Scheduler.tones
      assert_equal [[npc, 125, 75, 100, 150]], dll.args(:channel_directions)
      assert_equal [], dll.played
    end
  end

  test "directional repetition follows each category and the guide while neutral settings preserve the old gap" do
    base = Sound::Mixer.ping_seconds(:npc)
    Cfg.audio_dir_people_north_rate = 200
    Cfg.audio_dir_people_south_rate = 50
    assert_in_delta base / 2, Sound::Mixer.ping_seconds(:npc, 0, -1), 0.000001
    assert_in_delta base * 2, Sound::Mixer.ping_seconds(:npc, 0, 1), 0.000001
    assert_in_delta base, Sound::Mixer.ping_seconds(:npc, 1, 0), 0.000001
    object = Sound::Mixer.ping_seconds(:object)
    assert_in_delta object, Sound::Mixer.ping_seconds(:object, 0, -1), 0.000001
    diagonal = Sound::Mixer.ping_seconds(:npc, 1, -1)
    Cfg.audio_dir_people_south_rate = 200
    Cfg.audio_dir_people_west_rate = 50
    assert_in_delta diagonal, Sound::Mixer.ping_seconds(:npc, 1, -1), 0.000001
    Cfg.guide_rhythm = :constant
    original = PokeAccess::Guide.interval(4)
    Cfg.audio_dir_guide_north_rate = 200
    Cfg.audio_dir_guide_south_rate = 50
    assert_in_delta original / 2, PokeAccess::Guide.interval(4, 8), 0.000001
    assert_in_delta original * 2, PokeAccess::Guide.interval(4, 2), 0.000001
  end

  test "category settings persist beside common choices and numeric values stay bounded" do
    with_settings do |path|
      Cfg.direction_pitch_front = 130
      Cfg.audio_dir_people_north_pitch = 125
      Cfg.audio_dir_wall_south_pitch = 90
      Cfg.audio_dir_people_east_rate = 175
      PokeAccess::Settings.write
      Cfg.audio_dir_people_north_pitch = 100
      Cfg.audio_dir_wall_south_pitch = 100
      Cfg.audio_dir_people_east_rate = 100
      PokeAccess::Settings.apply
      assert_equal [130, 125, 90, 175], [Cfg.direction_pitch_front, Cfg.audio_dir_people_north_pitch, Cfg.audio_dir_wall_south_pitch, Cfg.audio_dir_people_east_rate]
      File.binwrite(path, "audio_dir_people_north_pitch=0\naudio_dir_people_east_rate=999\n")
      PokeAccess::Settings.apply
      assert_equal [50, 200], [Cfg.audio_dir_people_north_pitch, Cfg.audio_dir_people_east_rate]
    end
  end

  test "older engines hide unavailable category pitch but preserve applicable cadence and playback" do
    Cfg.audio3d_output = :stereo
    with_sound_engine(true, 44100, [:channel_directions]) do |dll|
      assert_equal false, Cfg.visible?(Cfg.setting(:audio_dir_people_north_pitch))
      assert_equal true, Cfg.visible?(Cfg.setting(:audio_dir_people_north_rate))
      assert_equal true, Sound::Pa3d.start(:npc, 6, 5, 70)
      assert_equal [], dll.args(:channel_directions)
    end
  end

  test "direction previews use the selected side and cadence preview stops when dismissed" do
    Cfg.audio3d_output = :stereo
    now = 10.0
    original = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now }
    with_sound_engine do |dll|
      PokeAccess::ConfigMenu.preview(:audio_dir_people_north_pitch, :direction_factor, 100)
      assert_equal [:npc, 5, 4], dll.played.last[0..2]
      PokeAccess::ConfigMenu.preview(:audio_dir_wind_south_pitch, :direction_factor, 100)
      assert_equal [:wind_s, 5, 6], dll.played.last[0..2]
      PokeAccess::ConfigMenu.stop_preview
      Cfg.audio_dir_people_north_rate = 200
      PokeAccess::ConfigMenu.preview(:audio_dir_people_north_rate, :direction_factor, 200)
      count = dll.played.length
      now += Sound::Mixer.ping_seconds(:npc, 0, -1) + 0.001
      PokeAccess::ConfigMenu.expire_preview
      assert_equal count + 1, dll.played.length
      PokeAccess::ConfigMenu.stop_preview
      count = dll.played.length
      now += 5
      PokeAccess::ConfigMenu.expire_preview
      assert_equal count, dll.played.length
    end
  ensure
    PokeAccess::ConfigMenu.stop_preview
    PokeAccess.define_singleton_method(:clock, original) if original
  end

  test "requested binaural hides category pitch before the paused menu resumes audio" do
    Cfg.audio3d_output = :stereo
    with_sound_engine do
      assert_equal 2, Sound::Pa3d.output_playing
      Cfg.set(:audio3d_output, :binaural)
      assert_equal 2, Sound::Pa3d.output_playing, "the soundscape is still paused under the menu"
      assert_equal false, Cfg.visible?(Cfg.setting(:audio_dir_people_north_pitch))
      assert_equal true, Cfg.visible?(Cfg.setting(:audio_dir_people_north_rate))
    end
  end

  test "requested stereo shows category pitch before the paused menu resumes audio" do
    Cfg.audio3d_output = :binaural
    with_sound_engine do
      assert_equal 0, Sound::Pa3d.output_playing
      Cfg.set(:audio3d_output, :stereo)
      assert_equal 0, Sound::Pa3d.output_playing, "the soundscape is still paused under the menu"
      assert_equal true, Cfg.visible?(Cfg.setting(:audio_dir_people_north_pitch))
    end
  end

  def set_directions(values)
    SIDES.each_with_index { |side, index| Cfg.send("direction_pitch_#{side}=", values[index]) }
  end

  def with_settings
    previous = PokeAccess::Settings::FILE
    Dir.mktmpdir do |dir|
      PokeAccess::Settings.send(:remove_const, :FILE)
      PokeAccess::Settings.const_set(:FILE, File.join(dir, "settings.ini"))
      begin
        yield PokeAccess::Settings::FILE
      ensure
        PokeAccess::Settings.send(:remove_const, :FILE)
        PokeAccess::Settings.const_set(:FILE, previous)
      end
    end
  end

  def flat_plays
    played = []
    original = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*args| played.push([args[0], args[1], args[2]]); nil }
    yield
    played
  ensure
    Audio.define_singleton_method(:se_play, original)
  end
end
