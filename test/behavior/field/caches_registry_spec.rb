# Every module that caches per-map state registers its reset (the list is literal on purpose, not derived from the
# code), and one reset raising does not stop the others.
Suite.define("caches: every module that remembers the map is registered to forget it") do
  names = PokeAccess::Caches.names

  [:puzzles, :audio3d, :pathfinder, :spatial, :cursor_global].each do |mod|
    truthy "#{mod} registers a reset", names.include?(mod)
  end

  ran = []
  PokeAccess::Caches.register(:spec_probe_a) { ran.push(:a) }
  PokeAccess::Caches.register(:spec_probe_b) { raise "este reset revienta" }
  PokeAccess::Caches.register(:spec_probe_c) { ran.push(:c) }
  begin
    PokeAccess::Caches.reset_all
    eq "one reset blowing up does not stop the others", ran, [:a, :c]
  ensure
    [:spec_probe_a, :spec_probe_b, :spec_probe_c].each { |n| PokeAccess::Caches.register(n) { } }
  end
end

# Spatial's map reset forgets its terrain, radar and lens tiles; Cursor.reset_global empties the module-wide dedup
# table that readers with no holder share.
Suite.define("caches: Spatial and the module-wide cursor table really do forget") do
  sp = PokeAccess::Spatial
  sp.instance_variable_set(:@surf_here, :terrain_water)
  sp.instance_variable_set(:@radar_key, [3, 4])
  sp.instance_variable_set(:@lens_pos, [5, 6])
  sp.reset_map_state
  eq "the terrain label the player was standing on", sp.instance_variable_get(:@surf_here), nil
  eq "the radar's remembered tile", sp.instance_variable_get(:@radar_key), nil
  eq "and the lens tile", sp.instance_variable_get(:@lens_pos), nil

  holderless = PokeAccess::Cursor
  SpeakCapture.clear
  holderless.announce(nil, :spec_slot, 1, true) { "primero" }
  spoke "a holderless reader speaks", /primero/
  SpeakCapture.clear
  holderless.announce(nil, :spec_slot, 1, true) { "primero" }
  silent "and dedups like any other"
  holderless.reset_global
  SpeakCapture.clear
  holderless.announce(nil, :spec_slot, 1, true) { "primero" }
  spoke "until the map changes, when it starts over", /primero/
end

# clear_targets drops the guide's memos: the no-route verdict (keyed on [px, py, tx, ty], with no map in it), the
# route and its target.
Suite.define("caches: clearing targets also drops the guide's route memo") do
  loc = PokeAccess::Locator
  loc.instance_variable_set(:@noroute_key, [1, 2, 3, 4])
  loc.instance_variable_set(:@guide_path, [[1, 2]])
  loc.instance_variable_set(:@guide_target, [3, 4])
  loc.clear_targets
  eq "the no-route verdict", loc.instance_variable_get(:@noroute_key), nil
  eq "the cached route", loc.instance_variable_get(:@guide_path), nil
  eq "and where it was headed", loc.instance_variable_get(:@guide_target), nil
end
