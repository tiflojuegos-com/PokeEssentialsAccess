# The cache registry, and the failure it is meant to prevent: a module that caches per-map state and never
# registers its reset. Nothing complains -- the module simply answers with the previous map's data, which
# for a screen reader means a terrain label, a target list or a "no route" verdict from where the player no
# longer is. The registry is printed by the diagnostic, which is the only place such a module shows up.
Suite.define("caches: every module that remembers the map is registered to forget it") do
  names = PokeAccess::Caches.names

  # Named one by one on purpose. A list derived from the code would pass whatever the code happens to do,
  # which is the property under test.
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

# The two modules R4 caught. Their memos are keyed on coordinates or on a terrain label, neither of which
# survives a door, so the reset is the only thing standing between the player and a stale announcement.
Suite.define("caches: Spatial and the module-wide cursor table really do forget") do
  sp = PokeAccess::Spatial
  sp.instance_variable_set(:@surf_here, :terrain_water)
  sp.instance_variable_set(:@radar_key, [3, 4])
  sp.instance_variable_set(:@lens_key, [5, 6])
  sp.reset_map_state
  eq "the terrain label the player was standing on", sp.instance_variable_get(:@surf_here), nil
  eq "the radar's remembered tile", sp.instance_variable_get(:@radar_key), nil
  eq "and the lens tile", sp.instance_variable_get(:@lens_key), nil

  # Readers with no scene to hang on (the HUD line, Awakening's cards) dedup here, and this table used to
  # outlive everything: only the test harness ever emptied it.
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

# The guide's "there is no route" answer is memoised on [px, py, tx, ty] with no map in it, and the memo
# short-circuits A* entirely -- so carried across a map it does not go stale, it goes WRONG.
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
