# The marker ping. A mark is a tile the player named, not an event, so the event scan never meets one:
# rescan adds the map's marks as an emitter type of their own, within the same reach and under the same
# line-of-sight rule as everything else, and a mark set or removed re-scans on the next frame instead of
# waiting for the player to step. Pinned because the whole family -- channel, tone, cadence, glossary --
# hangs off the scan finding them: with that one call missing every table entry is right and the player
# hears nothing.

# Deletes the marks files and forgets the store.
def marks_audio_wipe
  [PokeAccess::Marks::FILE, PokeAccess::Marks::IMPORT, PokeAccess::Marks::EXPORT].each { |f| (File.delete(f) rescue nil) }
  PokeAccess::Marks.reload!
end

Suite.define("audio3d: the player's marks ping as an emitter type of their own, within reach") do
  a3d = PokeAccess::Audio3D
  marks_audio_wipe
  World.clear_events
  saved_range = PokeAccess::Config.audio3d_range
  begin
    $game_map.map_id = 1
    PokeAccess::Config.audio3d_range = 6
    PokeAccess::Marks.set(1, 7, 5, "Tienda")
    PokeAccess::Marks.set(1, 5, 9, "Salida")
    PokeAccess::Marks.set(1, 20, 20, "Lejos")
    PokeAccess::Marks.set(2, 6, 5, "Otro mapa")
    a3d.rescan(5, 5)
    eq "the marks of this map within reach are the :mark emitters, nearest first",
       a3d.instance_variable_get(:@emitters)[:mark], [[7, 5], [5, 9]]

    truthy "the family has a channel of its own", a3d::CHANNEL_FILES.any? { |r| r[0] == :mark && r[1] == "pa3d_mark.wav" }
    eq "pitched by its own tone", a3d::TONE_KEYS[:mark], :audio3d_tone_mark
    eq "and paced by its own cadence, not the objects'", a3d::PING_DEFS[:mark], :audio3d_freq_mark
    eq "at its own volume", a3d.type_vol(:mark), PokeAccess::Config.audio3d_mark

    a3d.instance_variable_set(:@scan_pos, [5, 5, 1])
    PokeAccess::Marks.delete(1, 7, 5)
    PokeAccess::Events.emit(:tags_changed)
    eq "a change to the player's overrides drops the scan cursor, so the next tick rescans",
       a3d.instance_variable_get(:@scan_pos), nil
    a3d.rescan(5, 5)
    eq "and the removed mark no longer pings", a3d.instance_variable_get(:@emitters)[:mark], [[5, 9]]

    PokeAccess::Marks.delete(1, 5, 9)
    a3d.rescan(5, 5)
    eq "with no marks left the type has no emitters at all", a3d.instance_variable_get(:@emitters)[:mark], nil
  ensure
    PokeAccess::Config.audio3d_range = saved_range
    marks_audio_wipe
    World.clear_events
  end
end
