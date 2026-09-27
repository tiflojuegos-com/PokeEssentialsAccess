# Load order for the engine Reborn, Rejuvenation and Desolation share (no .rb): imported by the three, loaded after
# core and the plugins and before each game's own modules. A gen-6 lineage on Ruby 3.1 that keeps its data in a
# $cache, whose data provider (data_rv) comes first.
{
  :modules => %w[
    data_rv
    inspect_rv
    battle_marks_rv
    randomizer_rv
    storage_rv
    summary_rv
    own_voice_rv
    field_notes_rv
    time_weather_rv
    dex_forms_rv
    jukebox_rv
    move_restorer_rv
    region_map_rv
    move_tutor_rv
    passwords_rv
  ]
}
