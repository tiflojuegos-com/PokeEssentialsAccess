# The sound catalog (Sound::Catalog): its settings rows are the audio menu's, key for key and in order; its sounds
# name the files that ship, fit the dll's channels, ping in rank order, stand in flat and play at settings that exist.
class CatalogTest < PokeAccessTest
  Catalog = PokeAccess::Sound::Catalog
  Config = PokeAccess::Config
  SOUNDS_DIR = File.join(Harness::ROOT, "assets", "sounds")
  # The settings groups the catalog's rows go to.
  GROUPS = [:audio3d_on, :audio3d_vol, :audio3d_freq, :audio3d_tone]
  # The audio menu's rows, as [key, default, kind, group, label, help, show_if, needs].
  ROWS = [
    [:sound_people, true, :flag, :audio3d_on, :lbl_on_people, :snd_npc_help, [:sound_nav, :full], [:positional]],
    [:sound_objects, true, :flag, :audio3d_on, :lbl_on_objects, :snd_object_help, [:sound_nav, :full], [:positional]],
    [:sound_hazards, true, :flag, :audio3d_on, :lbl_on_hazards, :snd_hazard_help, [:sound_nav, :full], [:positional]],
    [:sound_traps, true, :flag, :audio3d_on, :lbl_on_traps, :snd_trap_help, [:sound_nav, :full], [:positional]],
    [:sound_controls, true, :flag, :audio3d_on, :lbl_on_controls, :snd_control_help, [:sound_nav, :full],
     [:positional]],
    [:sound_pushes, true, :flag, :audio3d_on, :lbl_on_pushes, :snd_push_help, [:sound_nav, :full], [:positional]],
    [:sound_belts, true, :flag, :audio3d_on, :lbl_on_belts, :snd_belt_help, [:sound_nav, :full], [:positional]],
    [:sound_doors, true, :flag, :audio3d_on, :lbl_on_doors, :snd_door_help, [:sound_nav, :full], [:positional]],
    [:sound_exits, true, :flag, :audio3d_on, :lbl_on_exits, :snd_exit_help, [:sound_nav, :full], [:positional]],
    [:sound_teleporters, true, :flag, :audio3d_on, :lbl_on_teleporters, :snd_teleporter_help,
     [:sound_nav, :full], [:positional]],
    [:sound_marks, true, :flag, :audio3d_on, :lbl_on_marks, :snd_mark_help, [:sound_nav, :full], [:positional]],
    [:sound_water, true, :flag, :audio3d_on, :lbl_on_water, :snd_water_help, [:sound_nav, :full], [:positional]],
    [:sound_wind, true, :flag, :audio3d_on, :lbl_on_wind, :snd_wind_help, [:sound_nav, :full], [:positional]],
    [:sound_steps, true, :flag, :audio3d_on, :lbl_on_steps, :snd_step_help, [:sound_nav, [:basic, :full]], []],
    [:sound_wall, true, :flag, :audio3d_on, :lbl_on_wall, :snd_wall_help, [:sound_nav, [:basic, :full]], []],
    [:sound_jumps, true, :flag, :audio3d_on, :lbl_on_jumps, :snd_jump_help, nil, []],
    [:sound_ledges, true, :flag, :audio3d_on, :lbl_on_ledges, :snd_ledge_help, [:sound_nav, [:basic, :full]], []],
    [:proximity_radar, true, :flag, :audio3d_on, :lbl_on_radar, :snd_radar_help, [:sound_nav, :full], []],
    [:sound_grid, true, :flag, :audio3d_on, :lbl_on_grid, :snd_grid_help, nil, []],
    [:sound_minigame, true, :flag, :audio3d_on, :lbl_on_minigame, :snd_minigame_help, nil, []],
    [:audio3d_npc, 85, :vol, :audio3d_vol, :lbl_pos_people, :help_pos_people, [:sound_nav, :full], [:positional]],
    [:audio3d_object, 85, :vol, :audio3d_vol, :lbl_pos_objects, :help_pos_objects, [:sound_nav, :full], [:positional]],
    [:audio3d_hazard, 85, :vol, :audio3d_vol, :lbl_pos_hazards, :help_pos_hazards, [:sound_nav, :full], [:positional]],
    [:audio3d_trap, 85, :vol, :audio3d_vol, :lbl_pos_traps, :help_pos_traps, [:sound_nav, :full], [:positional]],
    [:audio3d_control, 85, :vol, :audio3d_vol, :lbl_pos_controls, :help_pos_controls, [:sound_nav, :full],
     [:positional]],
    [:audio3d_push, 85, :vol, :audio3d_vol, :lbl_pos_pushes, :help_pos_pushes, [:sound_nav, :full], [:positional]],
    [:audio3d_belt, 85, :vol, :audio3d_vol, :lbl_pos_belts, :help_pos_belts, [:sound_nav, :full], [:positional]],
    [:audio3d_door, 85, :vol, :audio3d_vol, :lbl_pos_doors, :help_pos_doors, [:sound_nav, :full], [:positional]],
    [:audio3d_exit, 85, :vol, :audio3d_vol, :lbl_pos_exits, :help_pos_exits, [:sound_nav, :full], [:positional]],
    [:audio3d_teleporter, 90, :vol, :audio3d_vol, :lbl_pos_teleporter, :help_pos_teleporter, [:sound_nav, :full],
     [:positional]],
    [:audio3d_mark, 85, :vol, :audio3d_vol, :lbl_pos_marks, :help_pos_marks, [:sound_nav, :full], [:positional]],
    [:audio3d_water, 70, :vol, :audio3d_vol, :lbl_pos_water, :help_pos_water, [:sound_nav, :full], [:positional]],
    [:audio3d_shore, 40, :vol, :audio3d_vol, :lbl_pos_shore, :help_pos_shore, [:sound_nav, :full], [:positional]],
    [:audio3d_wind, 55, :vol, :audio3d_vol, :lbl_pos_wind, :help_pos_wind, [:sound_nav, :full], [:positional]],
    [:footstep_volume, 80, :vol, :audio3d_vol, :lbl_footstep_vol, :help_footstep_vol, [:sound_nav, [:basic, :full]],
     []],
    [:wall_volume, 80, :vol, :audio3d_vol, :lbl_wall_vol, :help_wall_vol, [:sound_nav, [:basic, :full]], []],
    [:event_volume, 70, :vol, :audio3d_vol, :lbl_guide_vol, :help_guide_vol, nil, []],
    [:jump_volume, 70, :vol, :audio3d_vol, :lbl_jump_vol, :help_jump_vol, nil, []],
    [:radar_volume, 31, :vol, :audio3d_vol, :lbl_radar_vol, :help_radar_vol, [:sound_nav, :full], []],
    [:puzzle_volume, 70, :vol, :audio3d_vol, :lbl_puzzle_vol, :help_puzzle_vol, nil, []],
    [:minigame_volume, 60, :vol, :audio3d_vol, :lbl_minigame_vol, :help_minigame_vol, nil, []],
    [:audio3d_freq_npc, 90, :vol, :audio3d_freq, :lbl_freq_people, :help_freq_people, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_object, 10, :vol, :audio3d_freq, :lbl_freq_objects, :help_freq_objects, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_hazard, 10, :vol, :audio3d_freq, :lbl_freq_hazards, :help_freq_hazards, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_trap, 10, :vol, :audio3d_freq, :lbl_freq_traps, :help_freq_traps, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_control, 10, :vol, :audio3d_freq, :lbl_freq_controls, :help_freq_controls, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_push, 10, :vol, :audio3d_freq, :lbl_freq_pushes, :help_freq_pushes, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_belt, 10, :vol, :audio3d_freq, :lbl_freq_belts, :help_freq_belts, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_door, 70, :vol, :audio3d_freq, :lbl_freq_doors, :help_freq_doors, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_exit, 70, :vol, :audio3d_freq, :lbl_freq_exits, :help_freq_exits, [:sound_nav, :full],
     [:positional]],
    [:audio3d_freq_teleporter, 70, :vol, :audio3d_freq, :lbl_freq_teleporter, :help_freq_teleporter,
     [:sound_nav, :full], [:positional]],
    [:audio3d_freq_mark, 80, :vol, :audio3d_freq, :lbl_freq_marks, :help_freq_marks, [:sound_nav, :full],
     [:positional]],
    [:guide_freq, 75, :vol, :audio3d_freq, :lbl_guide_freq, :help_guide_freq, nil, []],
    [:guide_rhythm, :distance, :grhythm, :audio3d_freq, :lbl_guide_rhythm, :help_guide_rhythm, nil, []],
    [:audio3d_tone_npc, 50, :tone, :audio3d_tone, :lbl_tone_people, :help_tone_people, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_object, 50, :tone, :audio3d_tone, :lbl_tone_objects, :help_tone_objects, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_hazard, 50, :tone, :audio3d_tone, :lbl_tone_hazards, :help_tone_hazards, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_trap, 50, :tone, :audio3d_tone, :lbl_tone_traps, :help_tone_traps, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_control, 50, :tone, :audio3d_tone, :lbl_tone_controls, :help_tone_controls, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_push, 50, :tone, :audio3d_tone, :lbl_tone_pushes, :help_tone_pushes, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_belt, 50, :tone, :audio3d_tone, :lbl_tone_belts, :help_tone_belts, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_door, 50, :tone, :audio3d_tone, :lbl_tone_doors, :help_tone_doors, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_exit, 50, :tone, :audio3d_tone, :lbl_tone_exits, :help_tone_exits, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_teleporter, 50, :tone, :audio3d_tone, :lbl_tone_teleporter, :help_tone_teleporter,
     [:sound_nav, :full], [:positional]],
    [:audio3d_tone_mark, 50, :tone, :audio3d_tone, :lbl_tone_marks, :help_tone_marks, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_water, 50, :tone, :audio3d_tone, :lbl_tone_water, :help_tone_water, [:sound_nav, :full],
     [:positional]],
    [:audio3d_tone_wind, 50, :tone, :audio3d_tone, :lbl_tone_wind, :help_tone_wind, [:sound_nav, :full],
     [:positional]],
    [:footstep_tone, 50, :tone, :audio3d_tone, :lbl_footstep_tone, :help_footstep_tone, [:sound_nav, [:basic, :full]],
     []],
    [:wall_tone, 50, :tone, :audio3d_tone, :lbl_wall_tone, :help_wall_tone, [:sound_nav, [:basic, :full]], []],
    [:guide_tone, 50, :tone, :audio3d_tone, :lbl_guide_tone, :help_guide_tone, nil, []],
    [:jump_tone, 50, :tone, :audio3d_tone, :lbl_jump_tone, :help_jump_tone, nil, []],
    [:radar_tone, 50, :tone, :audio3d_tone, :lbl_radar_tone, :help_radar_tone, [:sound_nav, :full], []],
    [:grid_tone, 50, :tone, :audio3d_tone, :lbl_grid_tone, :help_grid_tone, nil, []]
  ]

  test "makes the audio menu's rows, key for key and in order" do
    got = Config.settings.select { |s| GROUPS.include?(s.group) }
    assert_equal ROWS, got.map { |s| [s.key, s.default, s.kind, s.group, s.label, s.help, s.show_if, s.needs] }
  end

  test "puts its rows right after the master volume, the occlusion right after them" do
    keys = Config.settings.map { |s| s.key }
    at = keys.index(:audio3d_volume)
    assert_equal ROWS.map { |r| r[0] } + [:audio3d_occlusion], keys[at + 1, ROWS.length + 1]
  end

  test "gives each of its rows a setting to read and to write" do
    keys = ROWS.map { |r| r[0] }
    assert_equal [], keys.reject { |k| Config.respond_to?(k) && Config.respond_to?("#{k}=") }
  end

  test "declares each sound and each family once" do
    ids = Catalog.entries.map { |e| e.id }
    families = Catalog.families.map { |f| f.id }
    assert_equal [[], []], [repeated(ids), repeated(families)]
  end

  test "gives every sound a family it declares" do
    assert_equal [], Catalog.entries.reject { |e| Catalog.family_of(e.family) }.map { |e| e.id }
  end

  test "knows no family by an id it never declared" do
    assert_nil Catalog.family_of(:no_such_family)
  end

  test "loads no more channels than the dll holds" do
    maxch = File.read(File.join(Harness::ROOT, "native", "pa3d_steam.c"))[/#define MAXCH (\d+)/, 1].to_i
    assert_operator maxch, :>, 0, "the dll's source declares MAXCH"
    assert_operator Catalog.channels.length, :<=, maxch
  end

  test "gives a file to every sound the sonar pings or the engine places" do
    placed = Catalog.entries.select { |e| e.role == :ping || e.place }
    assert_equal [], placed.reject { |e| e.file }.map { |e| e.id }
  end

  test "names only files that ship" do
    assert_equal [], missing_files(SOUNDS_DIR)
  end

  test "pings in rank order, which breaks a tie" do
    assert_equal [:npc, :object, :door, :hazard, :trap, :control, :belt, :teleporter, :mark, :push, :exit],
                 Catalog.pings.map { |e| e.id }
  end

  test "gives each ping a rank of its own, so a tie breaks the same way every time" do
    ranks = Catalog.pings.map { |e| e.rank }
    assert_equal ranks.uniq, ranks
  end

  test "gives each stand-in played toward a direction a file for all four" do
    assert_equal [], directional.reject { |e| e.flat.keys.sort == [2, 4, 6, 8] }.map { |e| e.id }
  end

  test "pitches the stand-ins to either side alike, the one ahead above them and the one behind below" do
    wrong = directional.reject do |e|
      side = e.flat[4][1]
      e.flat[6][1] == side && e.flat[8][1] > side && e.flat[2][1] < side
    end
    assert_equal [], wrong.map { |e| e.id }
  end

  test "keeps each sound's tone inside the pitches it plays flat" do
    clamped = Catalog.entries.select { |e| e.clamp }.map { |e| e.id }
    with_sound_engine(false) do
      assert_equal clamped.map { |id| [id, Catalog.entry(id).clamp] }, clamped.map { |id| [id, flat_pitch_range(id)] }
    end
  end

  test "auditions each sound in the glossary as it plays: an engine one's file as recorded, a flat one's as pitched" do
    played = Catalog.entries.select { |e| e.glossary && (e.file || (e.flat && e.flat[:any])) }
    wrong = played.reject { |e| e.glossary[2, 2] == (e.file ? [e.file, 100] : e.flat[:any]) }
    assert_equal [], wrong.map { |e| e.id }
    assert_equal [Catalog::GRID_COLUMNS[1], Catalog::GRID_ROWS[1]], Catalog.entry(:grid).glossary[2, 2],
                 "the grid's sample is its middle cell"
  end

  test "loops only the water, the four winds and the guide's held tone" do
    loops = Catalog.channels.select { |_id, _f, l| l == 1 }.map { |id, _f, _l| id }
    assert_equal [:water, :wind_n, :wind_e, :wind_s, :wind_w, :guide_hold], loops
  end

  test "blows one wind toward each side, offset as the player steps that way" do
    winds = Catalog.winds
    assert_equal [2, 4, 6, 8], winds.map { |e| e.side[0] }.sort, "four winds, one a side"
    assert_equal [], winds.reject { |e| PokeAccess::DIR_DELTA[e.side[0]] == e.side[1, 2] }.map { |e| e.id }
  end

  test "ships every positional file mono at 44.1 kHz" do
    assert_equal [], channel_files.reject { |f| wav_format(File.join(SOUNDS_DIR, f)) == [1, 44100] }
  end

  test "ships the mono copy at 48 kHz of every positional file" do
    copies = channel_files.map { |f| File.join(SOUNDS_DIR, "48000", f) }
    assert_equal [], copies.reject { |p| File.file?(p) && wav_format(p) == [1, 48000] }.map { |p| File.basename(p) }
  end

  test "ships no file that no sound names" do
    assert_equal [], unnamed_files(SOUNDS_DIR)
  end

  test "ships no 48 kHz copy of a sound that is not positional" do
    copies = Dir.glob(File.join(SOUNDS_DIR, "48000", "*.wav")).map { |p| File.basename(p) }
    assert_equal [], (copies - channel_files).sort
  end

  test "its file checks catch a stray file, a missing one and a stereo one" do
    Dir.mktmpdir("pa_catalog_files") do |dir|
      gone = catalog_files.first
      (catalog_files - [gone]).each { |f| write_wav(File.join(dir, f), 1, 44100) }
      stray = File.join(dir, "pa_stray.wav")
      write_wav(stray, 2, 48000)
      assert_equal ["pa_stray.wav"], unnamed_files(dir), "the one file no sound names"
      assert_equal [gone], missing_files(dir), "the one file a sound names that is not there"
      assert_equal [2, 48000], wav_format(stray), "a stereo file at 48 kHz"
    end
  end

  test "gives every sound a volume setting that exists" do
    assert_equal [], Catalog.entries.reject { |e| (k = Catalog.key(e.id, :vol)) && Config.setting(k) }.map { |e| e.id }
  end

  test "gives every ping a frequency setting that exists" do
    assert_equal [], Catalog.pings.reject { |e| Config.setting(Catalog.key(e.id, :freq)) }.map { |e| e.id }
  end

  test "gives the hazards, traps, controls, pushes, belts and edge exits settings of their own" do
    kinds = [:hazard, :trap, :control, :push, :belt, :exit]
    own = kinds.map { |id| [:vol, :freq, :tone].map { |k| Catalog.key(id, k) } }.flatten
    assert_equal 18, own.uniq.length, "a volume, a pace and a tone each"
  end

  test "plays a sound at its family's settings, or at those its family takes from another" do
    {
      [:teleporter, :freq] => :audio3d_freq_teleporter, [:radar, :vol] => :radar_volume, [:radar, :tone] => :radar_tone,
      [:ledge, :vol] => :jump_volume, [:ledge, :tone] => :jump_tone, [:ledge, :on] => :sound_ledges,
      [:grid, :vol] => :puzzle_volume, [:grid, :tone] => :grid_tone, [:minigame, :vol] => :minigame_volume
    }.each { |(id, kind), key| assert_equal key, Catalog.key(id, kind), "#{id}'s #{kind}" }
  end

  test "the help of a tone another family takes names that family's sounds too" do
    es = PokeAccess::I18n.table("es")
    unnamed = []
    Catalog.families.each do |f|
      lender = f.from[:tone] && Catalog.family_of(f.from[:tone])
      next unless lender && lender.tone
      help = es[lender.tone[3].to_s].to_s.downcase
      Catalog.entries.select { |e| e.family == f.id && e.glossary }.each do |e|
        name = es[e.glossary[0].to_s].to_s.downcase
        unnamed.push("#{lender.tone[3]} leaves out #{name}") unless help.include?(name)
      end
    end
    assert_equal [], unnamed
  end

  test "has no setting for what a family neither has nor takes" do
    [[:water, :freq], [:minigame, :tone], [:bump, :freq], [:guide, :on], [:no_such_sound, :vol]].each do |id, kind|
      assert_nil Catalog.key(id, kind), "#{id}'s #{kind}"
    end
    assert_nil Catalog.family_key(:no_such_family, :vol), "nor for a family it does not know"
  end

  private

  # The values seen more than once in a list.
  def repeated(list)
    list.select { |v| list.count(v) > 1 }.uniq
  end

  # The files the positional engine loads.
  def channel_files
    Catalog.channels.map { |_id, f, _l| f }
  end

  # The sounds whose stand-ins without the engine are a file per direction.
  def directional
    Catalog.entries.select { |e| e.flat && !e.flat[:any] }
  end

  # The lowest and highest pitch a sound plays at flat at the shipped tones: the grid's every row, any other sound
  # toward each direction.
  def flat_pitch_range(id)
    pitches = with_cue_log do |log|
      if id == :grid
        Catalog::GRID_ROWS.each_index { |row| PokeAccess::Sound.cell(1, row) }
      else
        [2, 4, 6, 8].each { |d| PokeAccess::Sound.cue(id, :dir => d, :vol => 50) }
      end
      log.map { |_file, _vol, pitch| pitch }
    end
    [pitches.min, pitches.max]
  end

  # Every file the catalog names: the channels', the flat stand-ins', the glossary's samples and the grid's.
  def catalog_files
    flat = Catalog::WALL_FLAT.values + Catalog::GUIDE_FLAT.values
    (channel_files +
     Catalog.entries.map { |e| e.glossary && "#{e.glossary[2]}.wav" }.compact +
     Catalog.entries.map { |e| (e.flat || {}).values.map { |f, _p| "#{f}.wav" } }.flatten +
     (Catalog::GRID_COLUMNS + flat.map { |f, _p| f }).map { |f| "#{f}.wav" }).uniq
  end

  # The files the catalog names that dir lacks.
  def missing_files(dir)
    catalog_files.reject { |f| File.file?(File.join(dir, f)) }
  end

  # The WAV files in dir that no sound names, sorted.
  def unnamed_files(dir)
    (Dir.glob(File.join(dir, "*.wav")).map { |p| File.basename(p) } - catalog_files).sort
  end

  # A WAV file's channels and rate, from its fmt chunk; nil when it has none.
  def wav_format(path)
    b = File.open(path, "rb") { |f| f.read }
    i = 12
    while i + 8 <= b.length
      size = b[i + 4, 4].unpack("V")[0]
      return [b[i + 10, 2].unpack("v")[0], b[i + 12, 4].unpack("V")[0]] if b[i, 4] == "fmt "
      i += 8 + size + (size & 1)
    end
    nil
  end

  # Writes a silent 16-bit PCM WAV header with these channels and rate.
  def write_wav(path, channels, rate)
    fmt = [1, channels, rate, rate * channels * 2, channels * 2, 16].pack("vvVVvv")
    body = "WAVE" + "fmt " + [fmt.length].pack("V") + fmt + "data" + [0].pack("V")
    File.open(path, "wb") { |f| f.write("RIFF" + [body.length].pack("V") + body) }
  end
end
