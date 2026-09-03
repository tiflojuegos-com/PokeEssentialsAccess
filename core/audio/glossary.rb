module PokeAccess
  # Sound glossary: half of what the mod tells the player is not words but SIGNALS -- the sonar pings, the
  # bump feedback, the footsteps, the guide cane. Learning them by meeting them in the field is slow and
  # ambiguous (two pings a second apart, which was the door?), so the config menu browses this catalogue:
  # move to hear a sound's name, press the help key for where it fires, press confirm to play it.
  # Previews are flat -- centred, full volume, through the plain SE channel -- because the goal is to
  # memorise the TIMBRE; panning and the configured per-category volumes are the field's job, not this
  # list's. The files are exactly the ones the audio engine loads, so the glossary cannot drift from what
  # the game actually plays.
  module SoundGlossary
    # [id, sound file (no extension), spoken-name key, help key, playback pitch, tone setting or nil]. The
    # tone column is the family's setting from the tone menu, so a preview plays the sound the player has
    # configured and not the recording (a spec keeps it equal to the engine's own channel => tone table).
    # The four winds get an
    # entry EACH because they are four different recordings (one per wall side, so two walls at once stay
    # tellable apart), not one sound panned: hearing only one would teach a quarter of the vocabulary.
    # The bump and cane cues do the opposite -- their _l/_c/_r files are the SAME sound pre-panned, so one
    # entry with the centred file is the whole sound, and its help says the side comes from the panning.
    ENTRIES = [
      [:npc,         "pa3d_npc",         :snd_npc,         :snd_npc_help,         100, :audio3d_tone_npc],
      [:object,      "pa3d_object",      :snd_object,      :snd_object_help,      100, :audio3d_tone_object],
      [:door,        "pa3d_door",        :snd_door,        :snd_door_help,        100, :audio3d_tone_door],
      [:teleporter,  "pa3d_teleporter",  :snd_teleporter,  :snd_teleporter_help,  100, :audio3d_tone_teleporter],
      [:control,     "pa3d_control",     :snd_control,     :snd_control_help,     100, :audio3d_tone_object],
      [:push,        "pa3d_boing",       :snd_push,        :snd_push_help,        100, :audio3d_tone_object],
      [:trap,        "pa3d_boop",        :snd_trap,        :snd_trap_help,        100, :audio3d_tone_object],
      [:hazard,      "pa3d_hazard",      :snd_hazard,      :snd_hazard_help,      100, :audio3d_tone_object],
      [:water,       "pa3d_water",       :snd_water,       :snd_water_help,       100, :audio3d_tone_water],
      [:wind_n,      "pa3d_wind_n",      :snd_wind_n,      :snd_wind_help,        100, :audio3d_tone_wind],
      [:wind_e,      "pa3d_wind_e",      :snd_wind_e,      :snd_wind_help,        100, :audio3d_tone_wind],
      [:wind_s,      "pa3d_wind_s",      :snd_wind_s,      :snd_wind_help,        100, :audio3d_tone_wind],
      [:wind_w,      "pa3d_wind_w",      :snd_wind_w,      :snd_wind_help,        100, :audio3d_tone_wind],
      [:wall,        "pa3d_wall",        :snd_wall,        :snd_wall_help,        100, :wall_tone],
      [:interact,    "pa3d_interact",    :snd_interact,    :snd_interact_help,    100, :wall_tone],
      [:bump,        "pa3d_wall_c",      :snd_bump,        :snd_bump_help,        100, :wall_tone],
      [:step,        "pa_step",          :snd_step,        :snd_step_help,        100, :footstep_tone],
      [:grass,       "pa_grass",         :snd_grass,       :snd_grass_help,       100, :footstep_tone],
      [:fstep_water, "pa_water",         :snd_swim,        :snd_swim_help,        100, :footstep_tone],
      [:guide,       "pa_guide_c",       :snd_guide,       :snd_guide_help,       100, :guide_tone],
      [:radar,       "pa_guide_c",       :snd_radar,       :snd_radar_help,       150, :guide_tone],
      [:minigame,    "pa_mg_tick",       :snd_minigame,    :snd_minigame_help,    100, nil]
    ]

    # The catalogue, for the menu that lists it.
    def self.entries; ENTRIES; end

    # The entry with an id, or nil.
    def self.entry(id); ENTRIES.find { |e| e[0] == id }; end

    # Plays an entry's sample at a 0-100 volume through the flat SE channel, pitched by its family's tone.
    # Stops the previous preview first: the water and wind entries are multi-second loops, so arrowing
    # quickly through the list would otherwise pile them on top of each other. Returns true when a sound
    # was requested.
    def self.play(entry, volume = 100)
      return false unless entry
      (Audio.se_stop rescue nil)
      PokeAccess::Spatial.cue(entry[1], volume, flat_pitch(entry))
      true
    rescue StandardError
      false
    end

    # An entry's pitch through its family's tone as the flat SE channel can play it (50 to 150).
    def self.flat_pitch(entry)
      [(entry[4] * factor_of(entry, true)).round, 150].min
    end

    # An entry's pitch through its family's tone as the positional engine plays it (no ceiling).
    def self.engine_pitch(entry)
      (entry[4] * factor_of(entry, false)).round
    end

    # An entry's tone factor: none without a family, the guide family's shared one, else the family's tone
    # as the engine plays it or, on the flat path, held inside 50-150 for this entry's own pitch.
    def self.factor_of(entry, flat)
      key = entry[5]
      return 1.0 unless key
      return PokeAccess::Spatial.guide_tone_factor if key == :guide_tone
      return PokeAccess::Spatial.tone_factor(key, entry[4], entry[4]) if flat
      PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) / 100.0
    end
  end
end
