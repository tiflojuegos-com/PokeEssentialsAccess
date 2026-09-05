# The tone menu: one 0-100 setting per sound family that pitches the family's cues on every path they
# take -- the positional engine (PA3D_Pitch), the flat SE fallback and the menu's own audition. What the
# suites pin is the contract the C side and the Ruby side share: 50 is the recording and each side of it
# is an octave; the engine is told once per change; the guide keeps ahead and behind on the flat pitched
# cue and moves its four directions by one factor; the flat fallback keeps a pitch-coded pair tellable
# apart inside mkxp's 50-150.
#
# Why the suites force engine state: the harness ships no PA3D dll. Win32API is a stub whose #call returns
# 0, so boot() never marks the engine ready and every play path refuses. The suites seed @ch with the handle
# table boot builds, mark the engine ready and replace the #call of the entry points they watch with a
# recorder, so the asserts read exactly the arguments the real dll receives. Everything is restored.
module A3DTone
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
    stop_recording
  end

  # A ready engine with every channel loaded and nothing sent yet, recording the native calls into log.
  def self.ready(log)
    a3d = PokeAccess::Audio3D
    a3d.instance_variable_set(:@ch, channels)
    a3d.instance_variable_set(:@tone_sent, {})
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@master_sent, nil)
    record(log)
  end

  def self.record(log)
    FNS.each do |c|
      fn = PokeAccess::Audio3D.const_get(c)
      fn.define_singleton_method(:call) { |*a| log.push([c, a]); 0 }
    end
  end

  def self.stop_recording
    FNS.each do |c|
      sc = (class << PokeAccess::Audio3D.const_get(c); self; end)
      sc.send(:remove_method, :call) if sc.instance_methods(false).map { |m| m.to_s }.include?("call")
    end
  end

  # The [channel, pitch] pairs PA3D_Pitch received, in order.
  def self.pitches(log)
    log.select { |c, _a| c == :PITCH }.map { |_c, a| a }
  end
end

Suite.define("tone: the 0-100 setting is an octave each way around the recording") do
  eq "0 plays at half the rate", PokeAccess.tone_to_pitch(0), 50
  eq "25 a tritone-and-a-bit below", PokeAccess.tone_to_pitch(25), 71
  eq "50 is the recording itself", PokeAccess.tone_to_pitch(50), 100
  eq "75 the mirror of 25", PokeAccess.tone_to_pitch(75), 141
  eq "100 plays at double the rate", PokeAccess.tone_to_pitch(100), 200
  steps = (0..20).map { |i| PokeAccess.tone_to_pitch(i * 5) }
  eq "every step of 5 goes up, none repeats", steps, steps.sort.uniq
  eq "the tone kind steps by 5 over 0-100 with no spoken unit", PokeAccess::Config::KIND_BOUNDS[:tone], [0, 100, 5, nil]
  keys = PokeAccess::Config.keys_of_kind(:tone)
  eq "ten families have a tone", keys.length, 10
  eq "and every one ships at the recording", keys.map { |k| PokeAccess::Config.schema_row(k)[1] }.uniq, [50]
  eq "all in the tone submenu", keys.map { |k| PokeAccess::Config.schema_row(k)[3] }.uniq, [:audio3d_tone]
  truthy "tones persist like any other numeric setting", PokeAccess::Settings::NUMERIC.include?(:tone)
end

Suite.define("tone: every channel has a family, and the glossary and the menu agree with the engine") do
  a3d = PokeAccess::Audio3D
  tones = PokeAccess::Config.keys_of_kind(:tone)
  missing = a3d::CHANNEL_FILES.map { |r| r[0] }.reject { |sym| a3d::TONE_KEYS[sym] }
  eq "every positional channel is pitched by some tone", missing, []
  eq "every tone named there is a setting of kind tone", a3d::TONE_KEYS.values.uniq.reject { |k| tones.include?(k) }, []
  eq "every family's tone pitches at least one channel", tones.reject { |k| a3d::TONE_KEYS.values.include?(k) }, []
  odd = PokeAccess::SoundGlossary.entries.select { |e| e[5] && !tones.include?(e[5]) }.map { |e| e[0] }
  eq "a glossary entry's tone column is a tone setting or nil", odd, []
  drift = PokeAccess::SoundGlossary.entries.select { |e| a3d::TONE_KEYS.has_key?(e[0]) && e[5] != a3d::TONE_KEYS[e[0]] }
  eq "and for a sound the engine plays it is the engine's own family", drift.map { |e| e[0] }, []
  previews = PokeAccess::ConfigMenu::PREVIEWS
  vols = PokeAccess::Config.schema_group(:audio3d_vol).map { |r| r[0] }
  vols.push(:audio3d_volume)
  silent = (vols + tones).reject { |k| PokeAccess::SoundGlossary.entry(previews[k]) }
  eq "every volume and tone row auditions a glossary sound", silent, []
  no_family = previews.values.uniq.reject { |id| PokeAccess::Config.keys_of_kind(:vol).include?(PokeAccess::ConfigMenu::FAMILY_VOLUME[id]) }
  eq "and every auditioned sound knows the volume its family plays at", no_family, []
  same = previews.select { |k, id| tones.include?(k) && PokeAccess::SoundGlossary.entry(id)[5] != k }
  eq "and a tone row auditions a sound of its own family", same.map { |k, _id| k }, []
end

Suite.define("tone: the engine hears a channel's pitch once per change, and the guide sets its own") do
  a3d = PokeAccess::Audio3D
  saved = A3DTone.snapshot
  log = []
  begin
    A3DTone.ready(log)
    a3d.sync_tones
    sent = A3DTone.pitches(log)
    eq "every channel but the guide got its pitch on the first pass", sent.length, a3d::CHANNEL_FILES.length - 1
    eq "all of them the recording, the default tone being 50", sent.map { |_ch, p| p }.uniq, [100]
    falsy "the guide channel was not among them", sent.any? { |ch, _p| ch == A3DTone.channels[:guide] }
    log.clear
    a3d.sync_tones
    eq "a second pass with nothing changed sends nothing", log.length, 0
    PokeAccess::Config.audio3d_tone_door = 100
    a3d.sync_tones
    eq "raising the door tone re-sends the door channel alone", A3DTone.pitches(log), [[A3DTone.channels[:door], 200]]
    log.clear
    PokeAccess::Config.audio3d_tone_wind = 0
    a3d.sync_tones
    winds = [:wind_w, :wind_e, :wind_n, :wind_s].map { |w| A3DTone.channels[w] }.sort
    eq "one wind tone moves the four wind channels", A3DTone.pitches(log).map { |ch, _p| ch }.sort, winds
    eq "an octave down, to half rate", A3DTone.pitches(log).map { |_ch, p| p }.uniq, [50]

    log.clear
    $game_player.x = 10; $game_player.y = 10
    PokeAccess::Config.guide_distance = 3
    guide = A3DTone.channels[:guide]
    truthy "the engine takes the chime to the left", a3d.guide(4, 60)
    eq "at the recording while the guide tone rests", A3DTone.pitches(log), [[guide, 100]]
    eq "placed three tiles west of the player at the asked volume", log.last, [:SET, [guide, 700, 1000, 60, 1]]
    log.clear
    falsy "ahead is refused: front and back stay on the flat pitched cue by design", a3d.guide(8, 60)
    falsy "and so is behind", a3d.guide(2, 60)
    eq "without a native call", log, []
    PokeAccess::Config.guide_tone = 100
    a3d.guide(6, 60)
    eq "the guide tone moves right by the flat pair's factor, not the free octave", A3DTone.pitches(log), [[guide, 107]]
    log.clear
    PokeAccess::Config.guide_tone = 0
    a3d.guide(6, 60)
    eq "and down as far as keeps behind over 50", A3DTone.pitches(log), [[guide, 71]]
  ensure
    A3DTone.restore(saved)
  end
end

Suite.define("tone: without PA3D_Pitch the engine plays unpitched and refuses nothing it used to take") do
  a3d = PokeAccess::Audio3D
  saved = A3DTone.snapshot
  log = []
  pitch_fn = a3d::PITCH
  begin
    A3DTone.ready(log)
    a3d.send(:remove_const, :PITCH); a3d.const_set(:PITCH, nil)
    falsy "ahead is refused, pitch export or not", a3d.guide(8, 60)
    truthy "left still goes through the engine", a3d.guide(4, 60)
    eq "with no pitch call at all", log.map { |c, _a| c }, [:SET]
    a3d.sync_tones
    eq "and the tone sync is a no-op", log.length, 1
    truthy "a preview still plays, unpitched", a3d.preview(:npc, 100, 200)
    eq "volume and place as asked", log.last, [:SET, [A3DTone.channels[:npc], 500, 500, 100, 1]]
  ensure
    a3d.send(:remove_const, :PITCH); a3d.const_set(:PITCH, pitch_fn)
    A3DTone.restore(saved)
  end
end

Suite.define("tone: the flat fallback keeps a pitch-coded pair apart inside mkxp's 50-150") do
  sp = PokeAccess::Spatial
  eq "at the recording the factor is one", sp.tone_factor(:guide_tone, 70, 140), 1.0
  PokeAccess::Config.guide_tone = 100
  truthy "an octave up is held to what keeps 140 under 150", (sp.tone_factor(:guide_tone, 70, 140) - 150.0 / 140).abs < 1e-9
  PokeAccess::Config.guide_tone = 0
  truthy "an octave down to what keeps 70 over 50", (sp.tone_factor(:guide_tone, 70, 140) - 50.0 / 70).abs < 1e-9
  PokeAccess::Config.footstep_tone = 100
  eq "a cue with headroom takes the full 1.5 the channel allows", sp.tone_factor(:footstep_tone, 90, 100), 1.5
  PokeAccess::Config.footstep_tone = 50
  eq "and at the recording it is untouched", sp.tone_factor(:footstep_tone, 90, 100), 1.0

  played = []
  orig = Audio.method(:se_play)
  begin
    Audio.define_singleton_method(:se_play) { |*a| played.push(a); nil }
    PokeAccess::Config.guide_tone = 100
    PokeAccess::Config.event_volume = 70
    PokeAccess::Locator.guide_cue(8, 0)
    PokeAccess::Locator.guide_cue(2, 0)
    match "ahead plays the centred guide file", played[0][0], /pa_guide_c/
    eq "at the ceiling instead of the 280 the engine would play", played[0][2], 150
    eq "and behind keeps the same ratio under it, still the low one", played[1][2], 75
    played.clear
    PokeAccess::Config.guide_tone = 0
    PokeAccess::Locator.guide_cue(8, 0)
    PokeAccess::Locator.guide_cue(2, 0)
    eq "an octave down: behind rests on the floor", played[1][2], 50
    eq "and ahead stays twice as high", played[0][2], 100
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end

  entry = PokeAccess::SoundGlossary.entry(:npc)
  PokeAccess::Config.audio3d_tone_npc = 100
  eq "a flat preview an octave up is capped", PokeAccess::SoundGlossary.flat_pitch(entry), 150
  eq "while the engine preview is not", PokeAccess::SoundGlossary.engine_pitch(entry), 200
  PokeAccess::Config.audio3d_tone_npc = 0
  eq "and an octave down is half on both", [PokeAccess::SoundGlossary.flat_pitch(entry), PokeAccess::SoundGlossary.engine_pitch(entry)], [50, 50]
  radar = PokeAccess::SoundGlossary.entry(:radar)
  PokeAccess::Config.guide_tone = 100
  eq "a sample recorded at the ceiling cannot go higher", PokeAccess::SoundGlossary.flat_pitch(radar), 150
  cane = PokeAccess::SoundGlossary.entry(:guide)
  eq "the guide entry follows the family's shared factor on both paths", [PokeAccess::SoundGlossary.flat_pitch(cane), PokeAccess::SoundGlossary.engine_pitch(cane)], [107, 107]
  tick = PokeAccess::SoundGlossary.entry(:minigame)
  eq "the minigame tick has no family and keeps its pitch", [PokeAccess::SoundGlossary.flat_pitch(tick), PokeAccess::SoundGlossary.engine_pitch(tick)], [100, 100]
end
