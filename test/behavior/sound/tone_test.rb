# The tone settings, 0-100 with 50 the recording and an octave each side: the pitch they give each family of sounds on
# the positional engine (PA3D_Pitch), on the flat SE channel within its 50-150 and in the menu's audition.
class ToneTest < PokeAccessTest
  Sound = PokeAccess::Sound
  Config = PokeAccess::Config
  # Flat pitch pairs [low, high], from a chime's wide pair to single sounds ([p, p]), each narrow enough for 50-150.
  PAIRS = [[50, 50], [70, 140], [80, 120], [85, 140], [90, 100], [100, 100], [101, 101], [110, 110], [150, 150]]

  test "turns the 0-100 setting into an octave either way of the recording" do
    { 0 => 50, 25 => 71, 50 => 100, 75 => 141, 100 => 200 }.each do |tone, pitch|
      assert_equal pitch, PokeAccess.tone_to_pitch(tone), "tone #{tone}"
    end
  end

  test "raises the pitch at every step of five" do
    steps = (0..20).map { |i| PokeAccess.tone_to_pitch(i * 5) }
    assert_equal steps.sort.uniq, steps
  end

  test "steps a tone by five within 0-100 in the menu, said with no unit" do
    s = Config.setting(:audio3d_tone_npc)
    got = [[50, 1], [100, 1], [0, -1]].map do |tone, dir|
      Config.audio3d_tone_npc = tone
      Config.next_value(s, dir)
    end
    assert_equal [[55, 100, 0], "55"], [got, Config.value_name(s, 55)]
  end

  test "reads a stored tone back as a number held inside 0-100, and no tone from a word" do
    s = Config.setting(:audio3d_tone_npc)
    assert_equal [100, 0, 55, nil], ["120", "-5", " 55 ", "loud"].map { |text| Config.parse(s, text) }
  end

  test "keeps every tone setting in the tone submenu" do
    assert_equal [:audio3d_tone], tone_keys.map { |k| Config.setting(k).group }.uniq
  end

  test "pitches every positional channel by a tone setting" do
    cat = Sound::Catalog
    assert_equal [], cat.channels.map { |id, _f, _l| id }.reject { |id| tone_keys.include?(cat.key(id, :tone)) }
  end

  test "gives every tone setting a channel or a flat sound of its own to pitch" do
    cat = Sound::Catalog
    used = cat.channels.map { |id, _f, _l| cat.key(id, :tone) } +
           cat.entries.select { |e| e.role == :earcon }.map { |e| cat.key(e.id, :tone) }
    assert_equal [], tone_keys - used
  end

  test "names only tone settings as the tone of a listed sound" do
    gl = Sound::Glossary
    wrong = gl.entries.select { |e| (k = Sound::Catalog.key(e.id, :tone)) && !tone_keys.include?(k) }
    assert_equal [], wrong.map { |e| e.id }
  end

  test "auditions on every switch, volume and tone row a listed sound that knows its volume" do
    gl = Sound::Glossary
    rows = Config.settings_in(:audio3d_on).map { |r| r.key } + Config.settings_in(:audio3d_vol).map { |r| r.key } +
           [:audio3d_volume] + tone_keys
    assert_equal [], rows.reject { |k| gl.entry(gl.preview_of(k)) && Sound::Mixer.volume(gl.preview_of(k)) }
  end

  test "auditions on a tone row a sound of the row's own family" do
    gl = Sound::Glossary
    assert_equal [], tone_keys.reject { |k| Sound::Catalog.key(gl.preview_of(k), :tone) == k }
  end

  test "auditions nothing on a row that is no sound's" do
    gl = Sound::Glossary
    assert_nil gl.entry(gl.preview_of(:language))
  end

  test "gives each channel its family's pitch on the first tone pass, save the guide's and the jump's" do
    with_sound_engine do |dll|
      Sound::Scheduler.tones
      own = [:guide, :guide_hold, :jump]
      want = Sound::Catalog.channels.map { |id, _f, _l| [id, 100] }.reject { |id, _p| own.include?(id) }
      assert_equal want, dll.by_sound(:pitch)
    end
  end

  test "sends no pitch again on a tone pass with nothing changed" do
    with_sound_engine do |dll|
      Sound::Scheduler.tones
      dll.log.clear
      Sound::Scheduler.tones
      assert_equal [], dll.log
    end
  end

  test "sends a changed tone to its family's channels alone" do
    { [:audio3d_tone_door, 100] => [[:door, 200]],
      [:audio3d_tone_wind, 0] => [[:wind_n, 50], [:wind_e, 50], [:wind_s, 50], [:wind_w, 50]],
      [:footstep_tone, 100] => [[:shore, 200], [:step, 200], [:grass, 200], [:fstep_water, 200]],
      [:jump_tone, 100] => [[:ledge, 200]] }.each do |(key, tone), want|
      with_sound_engine do |dll|
        Sound::Scheduler.tones
        dll.log.clear
        Config.send("#{key}=", tone)
        Sound::Scheduler.tones
        Config.send("#{key}=", 50)
        assert_equal want, dll.by_sound(:pitch), "#{key} at #{tone}"
      end
    end
  end

  test "plays the guide's chime to the side through the engine at its tone's pitch" do
    { 50 => 100, 100 => 107, 0 => 71 }.each do |tone, pitch|
      with_sound_engine do |dll|
        Config.guide_tone = tone
        cue = Sound.cue(:guide, :dir => 4, :vol => 60)
        assert_equal [:engine, [[:guide, pitch]], [[:guide, 2, 5, 60]]], [cue, dll.by_sound(:pitch), dll.played],
                     "the guide's tone at #{tone}, three tiles west of the player"
      end
    end
  end

  test "plays the guide's chime ahead and behind flat, without the engine" do
    with_sound_engine do |dll|
      assert_equal [:flat, :flat, []],
                   [Sound.cue(:guide, :dir => 8, :vol => 60), Sound.cue(:guide, :dir => 2, :vol => 60), dll.log]
    end
  end

  test "holds the guide's tone to the side, and ahead and behind on the player told apart by pitch" do
    toward = { 4 => [100, 200, 500], 6 => [100, 800, 500], 8 => [140, 500, 500], 2 => [70, 500, 500] }
    toward.each do |dir, (pitch, x, y)|
      with_sound_engine do |dll|
        held = Sound.hold(:guide_hold, :dir => dir, :vol => 60)
        n = Sound::Pa3d.channels[:guide_hold]
        assert_equal [true, [[:pitch, [n, pitch]], [:set, [n, x, y, 60, 1]]]], [held, dll.log], "toward #{dir}"
      end
    end
  end

  test "pitches the held tone by the guide's tone, as its chime" do
    Config.guide_tone = 100
    with_sound_engine do |dll|
      Sound.hold(:guide_hold, :dir => 4, :vol => 60)
      Sound.hold(:guide_hold, :dir => 8, :vol => 60)
      assert_equal [[:guide_hold, 107], [:guide_hold, 150]], dll.by_sound(:pitch)
    end
  end

  test "stops the held tone when asked with no direction" do
    with_sound_engine do |dll|
      Sound.hold(:guide_hold, :dir => 4, :vol => 60)
      dll.log.clear
      assert_equal [true, [:guide_hold]], [Sound.hold(:guide_hold), dll.stopped]
    end
  end

  test "never asks a dll without the pitch entry point to pitch, the chime still playing" do
    with_sound_engine(true, 44100, [:pitch]) do |dll|
      asked = asked_of(dll)
      cue = Sound.cue(:guide, :dir => 4, :vol => 60)
      Sound::Scheduler.tones
      assert_equal [:engine, [:set]], [cue, asked]
    end
  end

  test "auditions a sound with the listener on the player and no muffle left by a ping behind a wall" do
    with_sound_engine do |dll|
      Sound::Pa3d.listener(1, 1)
      Sound::Pa3d.occlude(:npc, 80)
      dll.log.clear
      Sound.preview(:npc, 100, 200)
      assert_equal [[[500, 500]], [[:npc, 0]]], [dll.args(:listener), dll.by_sound(:occl)]
    end
  end

  test "auditions a sound without the pitch entry point, unpitched, at the volume and place asked" do
    with_sound_engine(true, 44100, [:pitch]) do |dll|
      assert_equal [true, [[:npc, 5, 5, 100]]], [Sound.preview(:npc, 100, 200), dll.played]
    end
  end

  test "keeps a flat pair's ratio, its high note held at 150 and its low one at 50" do
    { [100, 70, 140] => [75, 150], [0, 70, 140] => [50, 100], [50, 70, 140] => [70, 140],
      [100, 90, 100] => [135, 150] }.each do |(tone, lo, hi), want|
      Config.guide_tone = tone
      f = Sound::Mixer.tone_factor(:guide_tone, lo, hi)
      assert_equal want, [(lo * f).round, (hi * f).round], "tone #{tone} on the pair #{lo}-#{hi}"
    end
  end

  test "puts every tone of a flat pair inside 50-150, and leaves as the tone gives it a pair that fits" do
    bad = []
    (0..100).each do |tone|
      Config.guide_tone = tone
      raw = PokeAccess.tone_to_pitch(tone) / 100.0
      PAIRS.each do |lo, hi|
        f = Sound::Mixer.tone_factor(:guide_tone, lo, hi)
        fits = lo * raw >= 50 && hi * raw <= 150
        pinned = (hi * f - 150).abs < 1e-9 || (lo * f - 50).abs < 1e-9
        inside = lo * f >= 50 - 1e-9 && hi * f <= 150 + 1e-9
        bad.push([tone, lo, hi, f]) unless inside && (fits ? f == raw : pinned)
      end
    end
    assert_equal [], bad.first(5)
  end

  test "gives the recording's factor to a key that is no tone setting" do
    assert_equal 1.0, Sound::Mixer.tone_factor(:no_such_tone, 70, 140)
  end

  test "plays the guide's flat chime ahead and behind as a pair held inside 50-150" do
    { 50 => [140, 70], 100 => [150, 75], 0 => [100, 50] }.each do |tone, (ahead, behind)|
      Config.guide_tone = tone
      played = flat_plays do
        PokeAccess::Guide.cue(8, 0)
        PokeAccess::Guide.cue(2, 0)
      end
      assert_equal [["pa_guide_c", 70, ahead], ["pa_guide_c", 70, behind]], played, "the guide's tone at #{tone}"
    end
  end

  test "auditions a listed sound flat at full volume and its family's tone, the last audition stopped first" do
    Config.audio3d_tone_npc = 100
    result = nil
    played = flat_plays { result = Sound::Glossary.play(Sound::Glossary.entry(:npc)) }
    assert_equal [true, [[:stop], ["pa3d_npc", 100, 150]]], [result, played]
  end

  test "auditions a sound flat no higher than 150, while the engine plays its full tone" do
    gl = Sound::Glossary
    npc = gl.entry(:npc)
    { 100 => [150, 200], 50 => [100, 100], 0 => [50, 50] }.each do |tone, want|
      Config.audio3d_tone_npc = tone
      assert_equal want, [gl.flat_pitch(npc), gl.engine_pitch(npc)], "the people's tone at #{tone}"
    end
  end

  test "auditions the guide's sounds at their chime's shared pitch on both paths, the radar at its own tone" do
    gl = Sound::Glossary
    { 100 => [[:guide, 107, 107], [:guide_hold, 107, 107], [:radar, 88, 88]],
      0 => [[:guide, 71, 71], [:guide_hold, 71, 71], [:radar, 88, 88]] }.each do |tone, want|
      Config.guide_tone = tone
      got = [:guide, :guide_hold, :radar].map { |id| e = gl.entry(id); [id, gl.flat_pitch(e), gl.engine_pitch(e)] }
      assert_equal want, got, "the guide's tone at #{tone}"
    end
  end

  test "auditions the jump inside its own flat range on both paths" do
    gl = Sound::Glossary
    Config.jump_tone = 100
    jump = gl.entry(:jump)
    assert_equal [107, 107], [gl.flat_pitch(jump), gl.engine_pitch(jump)]
  end

  test "plays and auditions a sound with no tone at its recording" do
    gl = Sound::Glossary
    tick = gl.entry(:minigame)
    mx = Sound::Mixer
    assert_equal [100, 1.0, 100, 100],
                 [mx.pitch3d(:minigame), mx.flat_factor(:minigame), gl.flat_pitch(tick), gl.engine_pitch(tick)]
  end

  test "pitches the jump as it plays inside the flat channel, and the frame's tone pass leaves that pitch" do
    Config.jump_tone = 100
    with_sound_engine do |dll|
      cue = Sound.cue(:jump, :dir => 6, :vol => 60)
      Sound::Scheduler.tones
      assert_equal [:engine, [[:jump, 107]]], [cue, dll.by_sound(:pitch).select { |id, _p| id == :jump }]
    end
  end

  private

  # The keys of every tone setting.
  def tone_keys
    Config.settings.select { |s| s.kind == :tone }.map { |s| s.key }
  end

  # Records every entry point the mod asks the shadow for, those it lacks included.
  def asked_of(dll)
    asked = []
    dll.define_singleton_method(:call) { |name, *args| asked.push(name); super(name, *args) }
    asked
  end

  # What the flat channel did while the block ran: [file, volume, pitch] for each sound played, [:stop] for a stop.
  def flat_plays
    played = []
    real = [Audio.method(:se_play), Audio.method(:se_stop)]
    Audio.define_singleton_method(:se_play) { |file, vol, pitch| played.push([File.basename(file.to_s), vol, pitch]) }
    Audio.define_singleton_method(:se_stop) { |*_a| played.push([:stop]) }
    yield
    played
  ensure
    Audio.define_singleton_method(:se_play, real[0])
    Audio.define_singleton_method(:se_stop, real[1])
  end
end
