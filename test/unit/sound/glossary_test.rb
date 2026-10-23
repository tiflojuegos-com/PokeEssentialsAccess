# The sound glossary (Sound::Glossary) and the config menu's screen of it: the catalog's sounds that have a row, in
# order, auditioned flat with the file and pitch the game plays, the sound a setting row auditions, names and helps.
class GlossaryTest < PokeAccessTest
  Sound = PokeAccess::Sound
  # The config menu's state a test moves, put back after it.
  MENU_STATE = [:@mode, :@index, :@stack, :@armed, :@items, :@items_key]
  # Every sound of the catalog, in the order the glossary lists them.
  LISTED = [:npc, :object, :door, :teleporter, :mark, :control, :belt, :push, :exit, :trap, :hazard, :water, :shore,
            :wind_n, :wind_e, :wind_s, :wind_w, :wall, :interact, :bump, :step, :grass, :fstep_water, :guide,
            :guide_hold, :jump, :ledge, :radar, :minigame, :grid]

  test "lists every sound of the catalog that has a row, in the catalog's order" do
    assert_equal LISTED, Sound::Glossary.entries.map { |e| e.id }
  end

  test "finds a listed sound by its id, and none for an id no sound has" do
    assert_same Sound::Catalog.entry(:door), Sound::Glossary.entry(:door)
    assert_nil Sound::Glossary.entry(:no_such_sound)
  end

  test "leaves out a sound the catalog declares with no row" do
    with_sound(:pa_test_unlisted, :people) do |unlisted|
      assert_same unlisted, Sound::Catalog.entry(:pa_test_unlisted), "the catalog has it"
      assert_equal LISTED, Sound::Glossary.entries.map { |e| e.id }, "the list leaves it out"
      assert_nil Sound::Glossary.entry(:pa_test_unlisted), "and finding it by id gives nothing"
    end
  end

  test "has a row for every sound the positional engine loads and every one that only ever plays flat" do
    flat = Sound::Catalog.entries.select { |e| e.role == :earcon && e.flat && e.flat[:any] }.map { |e| e.id }
    assert_equal [:radar, :minigame], flat, "the radar's tick and the minigame's play flat only"
    heard = Sound::Catalog.channels.map { |id, _f, _l| id } + flat
    assert_equal [], heard - Sound::Glossary.entries.map { |e| e.id }
  end

  test "auditions on a volume, tone or switch row its family's first listed sound, the people's on the master" do
    rows = { :audio3d_volume => :npc, :audio3d_npc => :npc, :audio3d_wind => :wind_n, :audio3d_tone_wind => :wind_n,
             :sound_wind => :wind_n, :footstep_volume => :step, :jump_volume => :jump, :sound_ledges => :ledge,
             :guide_tone => :guide, :radar_volume => :radar, :radar_tone => :radar, :audio3d_shore => :shore,
             :audio3d_freq_door => nil }
    assert_equal rows.to_a, rows.keys.map { |key| [key, Sound::Glossary.preview_of(key)] }
  end

  test "keeps a low sound's flat audition at the flat channel's floor of 50, while the engine plays it lower" do
    with_sound(:pa_test_low, :people, :glossary => [:snd_npc, :snd_npc_help, "pa3d_npc", 80]) do |low|
      PokeAccess::Config.audio3d_tone_npc = 0
      assert_equal [50, 40], [Sound::Glossary.flat_pitch(low), Sound::Glossary.engine_pitch(low)]
    end
  end

  test "auditions a sound with a clamp flat at the pitch the game plays it, the grid's centre cell and the wall" do
    { :grid => [:grid_tone, 118], :wall => [:wall_tone, 125] }.each do |id, (key, want)|
      PokeAccess::Config.send("#{key}=", 100)
      assert_equal want, Sound::Glossary.flat_pitch(Sound::Glossary.entry(id)), "#{id} at its highest tone"
    end
  end

  test "plays a listed sound flat at the volume asked, after cutting the last one, and reports true" do
    result = :unset
    log = flat_log { result = Sound::Glossary.play(Sound::Glossary.entry(:door), 40) }
    assert_equal [true, [[:stop], ["pa3d_door", 40, 100]]], [result, log]
  end

  test "for no sound plays nothing, cuts nothing and reports false" do
    result = :unset
    log = flat_log { result = Sound::Glossary.play(nil) }
    assert_equal [false, []], [result, log]
  end

  test "survives a sound with no sample, playing nothing and reporting false" do
    result = :unset
    log = flat_log { result = Sound::Glossary.play(Sound::Catalog::Entry.new(:pa_test_mute, :people)) }
    assert_equal [false, [[:stop]]], [result, log]
  end

  test "opening it from the top screen says its title and its first sound" do
    on_menu_screen(:top) do |cm|
      point_at(cm) { |row| row[:group] == :sounds }
      cm.activate(1)
      assert_equal [["#{t(:cat_sounds)}. #{t(:snd_npc)}", true]], SpeakCapture.log
    end
  end

  test "its screen names each sound in the glossary's order, then back" do
    on_menu_screen(:sounds) do |cm|
      want = Sound::Glossary.entries.map { |e| t(e.glossary[0]) } + [t(:back)]
      assert_equal want, cm.items.map { |row| cm.describe(row) }
    end
  end

  test "the info key on a sound's row says where that sound fires" do
    on_menu_screen(:sounds) do |cm|
      point_at(cm) { |row| row[:entry] && row[:entry].id == :door }
      cm.speak_help
      assert_equal [[t(:snd_door_help), true]], SpeakCapture.log
    end
  end

  test "confirm on a sound's row auditions that sound alone, flat at full volume and its own pitch" do
    on_menu_screen(:sounds) do |cm|
      { :door => ["pa3d_door", 100, 100], :radar => ["pa_guide_c", 100, 88] }.each do |id, sample|
        point_at(cm) { |row| row[:entry] && row[:entry].id == id }
        assert_equal [[:stop], sample], flat_log { cm.activate(1) }, "on the row of #{id}"
      end
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # Runs the block with the config menu on a screen, its cursor on the first row and nothing said yet; the menu's
  # state is put back after.
  def on_menu_screen(mode)
    cm = PokeAccess::ConfigMenu
    saved = MENU_STATE.map { |ivar| cm.instance_variable_get(ivar) }
    cm.instance_variable_set(:@stack, mode == :top ? [] : [[:top, 0]])
    cm.instance_variable_set(:@mode, mode)
    cm.instance_variable_set(:@index, 0)
    cm.instance_variable_set(:@armed, nil)
    SpeakCapture.clear
    yield cm
  ensure
    MENU_STATE.each_with_index { |ivar, i| cm.instance_variable_set(ivar, saved[i]) }
  end

  # Puts the menu's cursor on the first row of its screen the block accepts.
  def point_at(cm, &pick)
    i = cm.items.index(&pick)
    flunk "no such row on #{cm.instance_variable_get(:@mode)}" unless i
    cm.instance_variable_set(:@index, i)
  end

  # What the flat channel did while the block ran: [file, volume, pitch] for each sample played, [:stop] for a stop.
  def flat_log
    log = []
    real = [Audio.method(:se_play), Audio.method(:se_stop)]
    Audio.define_singleton_method(:se_play) { |file, vol, pitch| log.push([File.basename(file.to_s), vol, pitch]) }
    Audio.define_singleton_method(:se_stop) { |*_a| log.push([:stop]) }
    yield
    log
  ensure
    Audio.define_singleton_method(:se_play, real[0])
    Audio.define_singleton_method(:se_stop, real[1])
  end

  # Runs the block with a sound of a family declared in the catalog (yielded), as Catalog.sound takes opts; the
  # catalog is put back after.
  def with_sound(id, family, opts = {})
    cat = Sound::Catalog
    cat.sound(id, family, opts)
    yield cat.entries.last
  ensure
    cat.entries.delete_if { |e| e.id == id }
    cat.instance_variable_set(:@memo, {})
  end
end
