# With defer_target_rebuild on, an event's end only marks the locator's list stale, to be rebuilt where it is next
# read with the selected target kept; off, it is rebuilt at once.
Suite.define("locator: a list an event leaves stale is rebuilt where it is next read") do
  loc = PokeAccess::Locator
  had_interp = loc.instance_variable_get(:@interp_running)
  prev_defer = PokeAccess::Config.defer_target_rebuild
  World.clear_events
  begin
    a = World.event(:kind => :npc, :id => 1, :x => 3, :y => 1)
    b = World.event(:kind => :npc, :id => 2, :x => 6, :y => 1)
    loc.rebuild_targets
    loc.instance_variable_set(:@target, b)
    loc.instance_variable_set(:@ti, loc.instance_variable_get(:@targets).index(b))
    listed = loc.instance_variable_get(:@targets)

    PokeAccess::Config.defer_target_rebuild = true
    loc.instance_variable_set(:@interp_running, true)
    loc.refresh_on_event_end
    truthy "the event's end leaves the list as it was, only marked stale",
           loc.instance_variable_get(:@targets).equal?(listed) && loc.instance_variable_get(:@targets_stale)

    had_xy = [$game_player.x, $game_player.y]
    $game_player.x = 3; $game_player.y = 2
    was_ti = loc.instance_variable_get(:@ti)
    loc.ensure_target
    falsy "the where key rebuilds a stale list", loc.instance_variable_get(:@targets).equal?(listed)
    falsy "and it is fresh again", loc.instance_variable_get(:@targets_stale)
    eq "keeping the selected target selected", loc.instance_variable_get(:@target), b
    eq "at its place in the new list", loc.instance_variable_get(:@ti), loc.instance_variable_get(:@targets).index(b)
    falsy "which is not the place it held in the old one", loc.instance_variable_get(:@ti) == was_ti
    $game_player.x = had_xy[0]; $game_player.y = had_xy[1]

    listed = loc.instance_variable_get(:@targets)
    PokeAccess::Config.defer_target_rebuild = false
    loc.instance_variable_set(:@interp_running, true)
    loc.refresh_on_event_end
    falsy "with the setting off, the event's end rebuilds it at once", loc.instance_variable_get(:@targets).equal?(listed)
    falsy "and leaves nothing stale", loc.instance_variable_get(:@targets_stale)
    truthy "the list holds the events either way", loc.instance_variable_get(:@targets).include?(a)
  ensure
    PokeAccess::Config.defer_target_rebuild = prev_defer
    loc.instance_variable_set(:@interp_running, had_interp)
    loc.instance_variable_set(:@targets_stale, false)
    World.clear_events
  end
end
