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
    # [id, sound file (no extension), spoken-name key, help key, playback pitch]. The four winds get an
    # entry EACH because they are four different recordings (one per wall side, so two walls at once stay
    # tellable apart), not one sound panned: hearing only one would teach a quarter of the vocabulary.
    # The bump and cane cues do the opposite -- their _l/_c/_r files are the SAME sound pre-panned, so one
    # entry with the centred file is the whole sound, and its help says the side comes from the panning.
    ENTRIES = [
      [:npc,         "pa3d_npc",         :snd_npc,         :snd_npc_help,         100],
      [:object,      "pa3d_object",      :snd_object,      :snd_object_help,      100],
      [:door,        "pa3d_door",        :snd_door,        :snd_door_help,        100],
      [:teleporter,  "pa3d_teleporter",  :snd_teleporter,  :snd_teleporter_help,  100],
      [:control,     "pa3d_control",     :snd_control,     :snd_control_help,     100],
      [:push,        "pa3d_boing",       :snd_push,        :snd_push_help,        100],
      [:trap,        "pa3d_boop",        :snd_trap,        :snd_trap_help,        100],
      [:hazard,      "pa3d_hazard",      :snd_hazard,      :snd_hazard_help,      100],
      [:water,       "pa3d_water",       :snd_water,       :snd_water_help,       100],
      [:wind_n,      "pa3d_wind_n",      :snd_wind_n,      :snd_wind_help,        100],
      [:wind_e,      "pa3d_wind_e",      :snd_wind_e,      :snd_wind_help,        100],
      [:wind_s,      "pa3d_wind_s",      :snd_wind_s,      :snd_wind_help,        100],
      [:wind_w,      "pa3d_wind_w",      :snd_wind_w,      :snd_wind_help,        100],
      [:wall,        "pa3d_wall",        :snd_wall,        :snd_wall_help,        100],
      [:interact,    "pa3d_interact",    :snd_interact,    :snd_interact_help,    100],
      [:bump,        "pa_bump_c",        :snd_bump,        :snd_bump_help,        100],
      [:step,        "pa_step",          :snd_step,        :snd_step_help,        100],
      [:grass,       "pa_grass",         :snd_grass,       :snd_grass_help,       100],
      [:fstep_water, "pa_water",         :snd_swim,        :snd_swim_help,        100],
      [:guide,       "pa_guide_c",       :snd_guide,       :snd_guide_help,       100],
      [:radar,       "pa_guide_c",       :snd_radar,       :snd_radar_help,       150],
      [:minigame,    "pa_mg_tick",       :snd_minigame,    :snd_minigame_help,    100]
    ]

    # The catalogue, for the menu that lists it.
    def self.entries; ENTRIES; end

    # Plays an entry's sample. Stops the previous preview first: the water and wind entries are
    # multi-second loops, so arrowing quickly through the list would otherwise pile them on top of
    # each other. Returns true when a sound was requested.
    def self.play(entry)
      return false unless entry
      (Audio.se_stop rescue nil)
      PokeAccess::Spatial.cue(entry[1], 100, entry[4])
      true
    rescue StandardError
      false
    end
  end
end
