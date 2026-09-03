# Hearing a setting as it moves: a volume or tone row of the audio menus auditions its family's sound on
# every press. Through the positional engine when it is up (centred on the player, so the whole octave is
# audible), through the flat glossary sample when it is not; a looping sample is stopped again after a
# moment and when the menu closes. The tone submenu itself is asserted here too, next to the volumes and
# frequencies it sits with.
#
# The engine state is forced the way the audio suites do it: the harness ships no PA3D dll, so the suite
# seeds the channel table, marks the engine ready and records the entry points it watches.
module MenuAudition
  IVARS = [:@ch, :@tone_sent, :@ready, :@master_sent]
  FNS = [:SET, :PITCH, :MAST]

  def self.channels
    h = {}
    PokeAccess::Audio3D::CHANNEL_FILES.each_with_index { |row, i| h[row[0]] = i }
    h
  end

  def self.snapshot
    IVARS.inject({}) { |h, k| h[k] = PokeAccess::Audio3D.instance_variable_get(k); h }
  end

  def self.restore(saved)
    saved.each { |k, v| PokeAccess::Audio3D.instance_variable_set(k, v) }
    FNS.each do |c|
      sc = (class << PokeAccess::Audio3D.const_get(c); self; end)
      sc.send(:remove_method, :call) if sc.instance_methods(false).map { |m| m.to_s }.include?("call")
    end
    PokeAccess::ConfigMenu.instance_variable_set(:@preview, nil)
  end

  def self.ready(log)
    a3d = PokeAccess::Audio3D
    a3d.instance_variable_set(:@ch, channels)
    a3d.instance_variable_set(:@tone_sent, {})
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@master_sent, nil)
    FNS.each do |c|
      fn = a3d.const_get(c)
      fn.define_singleton_method(:call) { |*a| log.push([c, a]); 0 }
    end
  end

  def self.pitches(log)
    log.select { |c, _a| c == :PITCH }.map { |_c, a| a }
  end

  # Runs the block with the engine down and Audio.se_play / se_stop recorded as [name, args].
  def self.flat(log)
    a3d = PokeAccess::Audio3D
    a3d.instance_variable_set(:@ready, false)
    play = Audio.method(:se_play)
    stop = Audio.method(:se_stop)
    Audio.define_singleton_method(:se_play) { |*a| log.push([:se_play, a]); nil }
    Audio.define_singleton_method(:se_stop) { |*a| log.push([:se_stop, a]); nil }
    yield
  ensure
    Audio.define_singleton_method(:se_play, play)
    Audio.define_singleton_method(:se_stop, stop)
  end
end

Suite.define("config menu: the audio category offers a tones submenu with the nine families") do
  menu = PokeAccess::ConfigMenu
  saved = [menu.instance_variable_get(:@mode), menu.instance_variable_get(:@index)]
  begin
    menu.instance_variable_set(:@mode, :audio)
    groups = menu.items.select { |i| i[:kind] == :enter }.map { |i| i[:group] }
    eq "tones sits after volumes and frequencies", groups, [:audio3d_vol, :audio3d_freq, :audio3d_tone, :audio3d_walls, :audio3d_adv]
    menu.instance_variable_set(:@mode, :audio3d_tone)
    rows = menu.items.select { |i| i[:kind] == :setting }.map { |i| i[:row][0] }
    eq "the submenu lists the nine tones in schema order", rows, PokeAccess::Config.keys_of_kind(:tone)
    eq "each spoken as its label and a bare number", menu.describe(menu.items[0]), "#{PokeAccess::I18n.t(:lbl_tone_people)}, 50"
    eq "and closed by the back row", menu.items.last[:kind], :back
  ensure
    menu.instance_variable_set(:@mode, saved[0]); menu.instance_variable_set(:@index, saved[1])
  end
end

Suite.define("config menu: a tone or volume row auditions through the engine when it is up") do
  menu = PokeAccess::ConfigMenu
  saved = MenuAudition.snapshot
  log = []
  begin
    MenuAudition.ready(log)
    $game_player.x = 4; $game_player.y = 6
    door = MenuAudition.channels[:door]

    SpeakCapture.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_door), 1)
    eq "the tone moved one step of 5", PokeAccess::Config.audio3d_tone_door, 55
    spoke "and was spoken with its label", /#{Regexp.escape(PokeAccess::I18n.t(:lbl_tone_doors))}, 55/
    eq "the master volume went out first, the dll having heard none yet", log[0], [:MAST, [80]]
    eq "the door channel was pitched to the new tone", MenuAudition.pitches(log), [[door, PokeAccess.tone_to_pitch(55)]]
    eq "then played centred on the player at the door family's own volume", log.last, [:SET, [door, 400, 600, 85, 1]]

    log.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_door), 1)
    eq "a volume row moves by 10", PokeAccess::Config.audio3d_door, 95
    eq "and auditions at the value just set, through the family's tone", log.last, [:SET, [door, 400, 600, 95, 1]]
    eq "the pitch being the door tone set a moment ago", MenuAudition.pitches(log), [[door, PokeAccess.tone_to_pitch(55)]]
    falsy "the master was not re-sent, it had not changed", log.any? { |c, _a| c == :MAST }

    log.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_volume), 1)
    eq "the master row pushes the new master before its sample", log[0], [:MAST, [90]]
    eq "and demonstrates it with the people cue at the people volume, the master doing the change", log.last, [:SET, [MenuAudition.channels[:npc], 400, 600, 85, 1]]

    log.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_water), -1)
    water = MenuAudition.channels[:water]
    eq "a loop starts like any other sample, at its family's volume", log.last, [:SET, [water, 400, 600, 70, 1]]
    eq "but is remembered so it can be stopped", (menu.instance_variable_get(:@preview) || [])[0], :water
    log.clear
    menu.expire_preview
    eq "before its time it keeps playing", log, []
    menu.instance_variable_set(:@preview, [:water, PokeAccess.clock - 1])
    menu.expire_preview
    eq "when its time is up the menu silences it", log.last, [:SET, [water, 0, 0, 0, 0]]
    falsy "and forgets it", menu.instance_variable_get(:@preview)

    log.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_wind), 1)
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_npc), 1)
    wind = MenuAudition.channels[:wind_n]
    truthy "moving to another row stops the loop that was auditioning", log.include?([:SET, [wind, 0, 0, 0, 0]])
    eq "a one-shot sample is not remembered", menu.instance_variable_get(:@preview), nil

    PokeAccess::Config.audio3d_tone_door = 100
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_door), 1)
    eq "a tone stops at 100", PokeAccess::Config.audio3d_tone_door, 100
    PokeAccess::Config.audio3d_tone_door = 0
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_door), -1)
    eq "and at 0", PokeAccess::Config.audio3d_tone_door, 0
    eq "the audition at 0 is an octave down", MenuAudition.pitches(log).last, [door, 50]

    log.clear
    menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_freq_door), 1)
    eq "a frequency row has nothing to audition in one press", log, []
  ensure
    MenuAudition.restore(saved)
  end
end

Suite.define("config menu: with the engine down the audition falls back to the flat glossary sample") do
  menu = PokeAccess::ConfigMenu
  saved = MenuAudition.snapshot
  log = []
  begin
    MenuAudition.flat(log) do
      menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_tone_npc), 1)
      eq "the previous preview is cut first", log[0], [:se_stop, []]
      match "then the family's file plays flat", log[1][1][0], /pa3d_npc$/
      eq "at the people volume, pitched to the new tone", log[1][1][1, 2], [85, PokeAccess.tone_to_pitch(55)]
      log.clear
      menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_npc), -1)
      eq "a volume row plays at the value just set", log[1][1][1], 75
      log.clear
      PokeAccess::Config.audio3d_tone_npc = 100
      menu.adjust_setting(PokeAccess::Config.schema_row(:audio3d_npc), 1)
      eq "and the flat channel's ceiling holds the pitch at 150", log[1][1][2], 150
      falsy "no loop is remembered on the flat path", menu.instance_variable_get(:@preview)
    end
  ensure
    MenuAudition.restore(saved)
  end
end
