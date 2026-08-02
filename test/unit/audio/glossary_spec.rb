# SoundGlossary: the browsable catalogue of the mod's non-verbal signals. The assert that matters most is
# the first one -- an entry naming a file the mod does not ship would be a menu item that teaches the
# player a sound they will never hear, and nothing else in the suite would notice. The rest pins the
# preview contract (flat, full volume, the entry's pitch) and the config-menu wiring that lists it.
Suite.define("glossary: every listed sound ships, and previews play flat at its pitch") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  missing = PokeAccess::SoundGlossary::ENTRIES.reject do |e|
    File.file?(File.join(root, "assets", "sounds", "#{e[1]}.wav"))
  end
  eq "every glossary entry names a sound file the mod ships", missing.map { |e| e[0] }, []

  ids = PokeAccess::SoundGlossary::ENTRIES.map { |e| e[0] }
  eq "no duplicated entry id", ids.length, ids.uniq.length
  truthy "the catalogue covers the whole vocabulary", ids.length >= 15

  # The anti-drift assert: for every entry named after a positional channel, the preview must be the
  # SAME file that channel loads -- renaming a wav in the engine would otherwise leave the glossary
  # teaching a sound the game no longer plays, and only a player would ever notice.
  chan = {}
  PokeAccess::Audio3D::CHANNEL_FILES.each { |sym, file, _lp| chan[sym] = file }
  drifted = PokeAccess::SoundGlossary::ENTRIES.select do |e|
    chan[e[0]] && chan[e[0]] != "#{e[1]}.wav"
  end
  eq "each entry previews the very file its engine channel loads", drifted.map { |e| e[0] }, []
  covered = ids.select { |i| chan[i] }
  eq "and every positional channel is in the glossary", (chan.keys - covered).sort_by { |s| s.to_s }, []

  # The same anti-drift assert for the NON-positional signals: two entries take their file and pitch from
  # Spatial::EARCONS, not from a 3D channel, so the cross above never looked at them -- renaming that wav
  # (or repitching it) would leave the glossary teaching a sound the mod no longer plays, the exact gap the
  # channel cross exists to close. The pairing is spelled out because the two vocabularies name the same
  # sound differently (a glossary id is what the sound is called TO THE PLAYER), and it is asserted complete
  # in both directions: a new or renamed earcon fails here instead of quietly escaping the catalogue.
  ear = PokeAccess::Spatial::EARCONS
  earcon_of = { :radar => :radar_blip, :minigame => :minigame_tick }
  eq "every earcon the mod plays is paired with a glossary entry",
     (ear.keys - earcon_of.values).sort_by { |s| s.to_s }, []
  eq "and the pairing names no earcon that vanished",
     (earcon_of.values - ear.keys).sort_by { |s| s.to_s }, []
  eq "and every paired glossary id is really in the catalogue",
     earcon_of.keys.reject { |i| ids.include?(i) }.sort_by { |s| s.to_s }, []
  ear_drift = PokeAccess::SoundGlossary::ENTRIES.select do |e|
    row = ear[earcon_of[e[0]]]
    row && (row[0] != e[1] || row[1] != e[4])
  end
  eq "each earcon entry previews the very file and pitch the mod plays", ear_drift.map { |e| e[0] }, []

  played = []
  Audio.instance_eval do
    (class << self; self; end).send(:define_method, :se_play) { |*a| played << a }
  end
  begin
    npc = PokeAccess::SoundGlossary::ENTRIES.detect { |e| e[0] == :npc }
    truthy "play reports it played", PokeAccess::SoundGlossary.play(npc)
    eq "one preview played", played.length, 1
    truthy "the entry's file is the one played", played[0][0].include?("pa3d_npc")
    eq "previews are full volume, not the configured one", played[0][1], 100

    played.clear
    radar = PokeAccess::SoundGlossary::ENTRIES.detect { |e| e[0] == :radar }
    PokeAccess::SoundGlossary.play(radar)
    eq "an entry with its own pitch keeps it", played[0][2], 150

    played.clear
    falsy "a nil entry is a safe no-op", PokeAccess::SoundGlossary.play(nil)
    eq "and plays nothing", played.length, 0
  ensure
    Audio.instance_eval do
      (class << self; self; end).send(:define_method, :se_play) { |*a| }
    end
  end
end

# The config menu must LIST the catalogue: one row per sound (labelled by its name key, so the generic
# label_of speaks it) plus the back row, and the help key must be the entry's own -- the whole point of
# the section is that the help key explains where each sound fires.
Suite.define("glossary: the config menu lists every sound with its own label and help") do
  cm = PokeAccess::ConfigMenu
  prev_mode = cm.instance_variable_get(:@mode)
  prev_index = cm.instance_variable_get(:@index)
  begin
    cm.instance_variable_set(:@mode, :sounds)
    cm.instance_variable_set(:@index, 0)
    rows = cm.items
    eq "one row per sound plus back", rows.length, PokeAccess::SoundGlossary::ENTRIES.length + 1
    eq "the last row goes back", rows.last[:kind], :back
    eq "the first row is a sound", rows[0][:kind], :sound
    eq "labelled by the entry's name key", rows[0][:label], PokeAccess::SoundGlossary::ENTRIES[0][2]
    eq "and carries its entry for the preview", rows[0][:entry][0], PokeAccess::SoundGlossary::ENTRIES[0][0]

    SpeakCapture.clear
    cm.speak_help
    spoke "the help key speaks where the focused sound fires",
          /#{Regexp.escape(PokeAccess::I18n.t(PokeAccess::SoundGlossary::ENTRIES[0][3])[0, 24])}/
  ensure
    cm.instance_variable_set(:@mode, prev_mode)
    cm.instance_variable_set(:@index, prev_index)
  end
end
