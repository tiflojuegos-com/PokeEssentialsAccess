# The per-tile emitter scan (Audio3D.rescan / refresh_movers): what the soundscape decides to sound at all.
# It runs on every tile change, so its three cuts -- the range, the nearest-few cap and the line-of-sight
# drop -- are what stands between a readable soundscape and a wall of noise. None of it touches the dll:
# rescan only reads $game_map.events, the classifier and the raycast, and writes the @emitters table the
# ping loop later plays from, so these suites assert that table directly.

# Bucketing, the range cut, the NEAR_MAX cap and clustering, all in one scan. The cap is asserted through
# four adjacent people with four different sprites: they must stay four emitters (so the cap has something
# to cut) and the scan must keep the three NEAREST, not the first three the event hash happens to yield.
Suite.define("audio3d: rescan buckets by type, keeps the nearest few and merges one structure") do
  a3d = PokeAccess::Audio3D
  prev_range = PokeAccess::Config.audio3d_range
  begin
    World.clear_events
    PokeAccess::Config.audio3d_range = 6
    [[6, 5, "ana"], [7, 5, "bea"], [8, 5, "cid"], [9, 5, "dan"]].each_with_index do |(x, y, sprite), i|
      ev = World.event(:kind => :trainer, :id => i + 1, :x => x, :y => y)
      ev.character_name = sprite
    end
    World.event(:kind => :door, :id => 10, :x => 5, :y => 3)
    World.event(:kind => :door, :id => 11, :x => 2, :y => 5)
    World.event(:kind => :door, :id => 12, :x => 2, :y => 6)
    World.event(:kind => :door, :id => 13, :x => 5, :y => 12)

    a3d.rescan(5, 5)
    emit = a3d.instance_variable_get(:@emitters)
    eq "only the three nearest people survive the cap, nearest first", emit[:npc], [[6, 5], [7, 5], [8, 5]]
    eq "the two touching warp tiles ping once, the lone door apart", emit[:door], [[5, 3], [2, 5]]
    falsy "and nothing outside the sonar range is scanned", emit[:door].include?([5, 12])

    PokeAccess::Config.audio3d_range = 12
    a3d.rescan(5, 5)
    eq "widening the range brings the far door back", a3d.instance_variable_get(:@emitters)[:door],
       [[5, 3], [2, 5], [5, 12]]
  ensure
    PokeAccess::Config.audio3d_range = prev_range
    World.clear_events
  end
end

# Line of sight is only applied in HIDE mode; hear and occlude keep the emitter and let the dll muffle it.
# Getting this backwards either deletes half the map's cues or lets the player hear through every wall, and
# the same grid with the same events proves which mode did what.
Suite.define("audio3d: only hide mode drops the emitters behind a wall") do
  a3d = PokeAccess::Audio3D
  prev_occ = PokeAccess::Config.audio3d_occlusion
  prev_range = PokeAccess::Config.audio3d_range
  begin
    PokeAccess::Config.audio3d_range = 12
    $game_map.load_grid(["#########", "#@..#...#", "#########"])
    World.clear_events
    near = World.event(:kind => :trainer, :id => 1, :x => 3, :y => 1)
    near.character_name = "ana"
    far = World.event(:kind => :trainer, :id => 2, :x => 6, :y => 1)
    far.character_name = "bea"

    PokeAccess::Config.audio3d_occlusion = :occlude
    a3d.rescan(1, 1)
    eq "in occlude mode the walled-off person is kept (the dll muffles her)",
       a3d.instance_variable_get(:@emitters)[:npc], [[3, 1], [6, 1]]

    PokeAccess::Config.audio3d_occlusion = :hear
    a3d.rescan(1, 1)
    eq "in hear mode too", a3d.instance_variable_get(:@emitters)[:npc], [[3, 1], [6, 1]]

    PokeAccess::Config.audio3d_occlusion = :hide
    a3d.rescan(1, 1)
    eq "in hide mode only the one in the open is left", a3d.instance_variable_get(:@emitters)[:npc], [[3, 1]]
  ensure
    PokeAccess::Config.audio3d_occlusion = prev_occ
    PokeAccess::Config.audio3d_range = prev_range
    World.clear_events
    $game_map.clear_grid
  end
end

# The Pokemon Center case: the nurse is behind an impassable counter, so hide mode would delete the most
# important emitter on the map. The bypass must save HER and nobody else -- the ordinary shopper one tile
# further behind the same counter must still be cut, or the exception has swallowed the rule.
Suite.define("audio3d: hide mode keeps the counter clerk but not the person behind her") do
  a3d = PokeAccess::Audio3D
  prev_occ = PokeAccess::Config.audio3d_occlusion
  prev_desk = PokeAccess::Config.audio3d_desk_range
  begin
    PokeAccess::Config.audio3d_occlusion = :hide
    PokeAccess::Config.audio3d_desk_range = 2
    $game_map.load_grid(["######", "#@C..#", "######"])
    World.clear_events
    nurse = World.event(:kind => :trainer, :id => 1, :x => 3, :y => 1)
    nurse.character_name = "nurse"
    shopper = World.event(:kind => :trainer, :id => 2, :x => 4, :y => 1)
    shopper.character_name = "boy"

    falsy "the counter really does occlude them both", a3d.line_clear?(1, 1, 3, 1)
    a3d.rescan(1, 1)
    eq "the clerk survives the line-of-sight cut, the shopper does not",
       a3d.instance_variable_get(:@emitters)[:npc], [[3, 1]]

    PokeAccess::Config.audio3d_desk_range = 0
    a3d.rescan(1, 1)
    eq "with the bypass switched off even the clerk goes quiet",
       a3d.instance_variable_get(:@emitters)[:npc], nil
  ensure
    PokeAccess::Config.audio3d_occlusion = prev_occ
    PokeAccess::Config.audio3d_desk_range = prev_desk
    World.clear_events
    $game_map.clear_grid
  end
end

# The water loop follows the nearest WATER tile within the sonar range: a map's grass must not start it,
# and a shore further out than the range must stop it. @near[:water] is the one value set_loop reads, so a
# wrong nil here is a loop that never stops (or never starts).
#
# The sonar looks for its own water rather than reusing the locator's surface list, which would scan a
# 61-tile box for eleven surface kinds to throw ten away and then re-filter by the range that should have
# bounded the scan. That is why this drives real terrain tags instead of stubbing the locator out.
Suite.define("audio3d: the water loop follows the nearest water surface only") do
  a3d = PokeAccess::Audio3D
  prev_range = PokeAccess::Config.audio3d_range
  begin
    World.clear_events
    $game_map.clear_grid
    PokeAccess::Config.audio3d_range = 6

    $game_map.set_terrain(8, 5, 7)
    a3d.rescan(5, 5)
    eq "a shore in range positions the loop", a3d.instance_variable_get(:@near)[:water], [8, 5]

    # Nearer water wins, and it is the manhattan distance that decides -- the rings must not report a tile
    # simply because it was reached first in some scan order.
    $game_map.set_terrain(5, 3, 7)
    a3d.rescan(5, 5)
    eq "and the nearest of two shores wins", a3d.instance_variable_get(:@near)[:water], [5, 3]

    $game_map.clear_grid
    $game_map.set_terrain(15, 5, 7)
    a3d.rescan(5, 5)
    eq "a shore out of range stops it", a3d.instance_variable_get(:@near)[:water], nil

    PokeAccess::Config.audio3d_range = 12
    a3d.rescan(5, 5)
    eq "widening the sonar range reaches it", a3d.instance_variable_get(:@near)[:water], [15, 5]

    $game_map.clear_grid
    $game_map.set_terrain(6, 5, 10)
    a3d.rescan(5, 5)
    eq "and a surface that is not water never starts it", a3d.instance_variable_get(:@near)[:water], nil

    # A waterfall has always counted as water for this cue, and the tile beyond the map edge has never
    # been asked about: both are behaviour the rewrite had to carry over rather than decide afresh.
    $game_map.set_terrain(4, 5, 8)
    a3d.rescan(5, 5)
    eq "a waterfall still counts as water", a3d.instance_variable_get(:@near)[:water], [4, 5]

    $game_map.clear_grid
    $game_map.set_terrain(0, 5, 7)
    a3d.rescan(0, 5)
    eq "water underfoot is found without leaving the map", a3d.instance_variable_get(:@near)[:water], [0, 5]
  ensure
    PokeAccess::Config.audio3d_range = prev_range
    $game_map.clear_grid
    World.clear_events
  end
end

# Movers (the ship sharpedos) drift while the player stands still, so their tiles go stale between tile
# changes. refresh_movers is the cheap partial rescan that retracks them -- and it must leave every other
# bucket ALONE: rebuilding them all on a timer is what the tile-change scan exists to avoid.
Suite.define("audio3d: refresh_movers retracks the movers and touches nothing else") do
  a3d = PokeAccess::Audio3D
  prev_range = PokeAccess::Config.audio3d_range
  begin
    World.clear_events
    PokeAccess::Config.audio3d_range = 6
    mover = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    mover.character_name = "sharpedo"
    person = World.event(:kind => :trainer, :id => 2, :x => 7, :y => 5)
    person.character_name = "ana"
    PokeAccess::Puzzles.register($game_map.map_id, :kind => :state,
      :obstacles => [{ :match => /sharpedo/i, :kind => :mover }])
    PokeAccess::Puzzles.reset_state

    a3d.rescan(5, 5)
    eq "the first scan finds the mover", a3d.instance_variable_get(:@emitters)[:trap], [[6, 5]]
    eq "and the person beside it", a3d.instance_variable_get(:@emitters)[:npc], [[7, 5]]

    mover.x = 5; mover.y = 8
    a3d.refresh_movers(5, 5)
    eq "the mover is retracked without a full rescan", a3d.instance_variable_get(:@emitters)[:trap], [[5, 8]]
    eq "and the person's cached tile is left as it was", a3d.instance_variable_get(:@emitters)[:npc], [[7, 5]]

    mover.x = 5; mover.y = 19
    a3d.refresh_movers(5, 5)
    eq "a mover that drifts out of range goes quiet", a3d.instance_variable_get(:@emitters)[:trap], []
  ensure
    PokeAccess::Puzzles.instance_variable_set(:@defs, {})
    PokeAccess::Puzzles.reset_state
    PokeAccess::Config.audio3d_range = prev_range
    World.clear_events
  end
end

# On a map change the scan state MUST die (otherwise the previous map's people keep pinging from tiles that
# no longer exist, so a blind player walks toward nothing), while the engine and its loaded channels MUST
# survive (re-opening the audio device on every door would stutter the game and mute the music).
Suite.define("audio3d: a map change drops the scan state but never the loaded engine") do
  a3d = PokeAccess::Audio3D
  keep = [:@emitters, :@wall, :@near, :@scan_pos, :@ready, :@ch]
  saved = {}
  begin
    keep.each { |k| saved[k] = a3d.instance_variable_get(k) }
    a3d.instance_variable_set(:@emitters, { :npc => [[3, 3]] })
    a3d.instance_variable_set(:@wall, { :w => 2 })
    a3d.instance_variable_set(:@near, { :water => [4, 4] })
    a3d.instance_variable_set(:@scan_pos, [3, 3, 1])
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, { :npc => 0 })

    PokeAccess::Caches.reset_all
    eq "the previous map's emitters are gone", a3d.instance_variable_get(:@emitters), {}
    eq "so is its wall cache", a3d.instance_variable_get(:@wall), {}
    eq "and its water surface", a3d.instance_variable_get(:@near), {}
    eq "the scan cursor is armed to rescan on the first frame", a3d.instance_variable_get(:@scan_pos), nil
    truthy "but the engine stays booted", a3d.instance_variable_get(:@ready)
    eq "with its channels still loaded", a3d.instance_variable_get(:@ch), { :npc => 0 }
  ensure
    saved.each { |k, v| a3d.instance_variable_set(k, v) }
  end
end
