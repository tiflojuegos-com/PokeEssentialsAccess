# The per-tile emitter scan (Audio3D.rescan, refresh_movers). No dll involved: the suites assert the @emitters
# table the ping loop plays from.

# Bucketing, the range cut, the NEAR_MAX cap (the nearest three of four adjacent people with distinct sprites) and
# clustering, in one scan.
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

# Line of sight drops emitters only in hide mode; hear and occlude keep them.
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

# Hide mode keeps a service-desk clerk behind her counter (within the desk range) and cuts an ordinary person
# behind the same counter.
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

# @near[:water], where the water loop plays: the nearest water tile within the sonar range (a waterfall counts),
# read from real terrain tags.
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

# refresh_movers retracks the puzzle movers between tile changes and leaves every other bucket alone.
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

# A map change (Caches.reset_all) drops the scan state and keeps the booted engine with its loaded channels.
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

# The engine's player passable?, counted: every (x, y, d) it is asked, in order.
def with_asked_steps
  asked = []
  class << $game_player; alias_method :asked_spec_passable?, :passable?; end
  $game_player.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); asked_spec_passable?(x, y, d) }
  yield asked
ensure
  class << $game_player; remove_method :passable?, :asked_spec_passable?; end
end

# Five people east of the player in a two-row corridor: their rays share their first steps.
def sonar_corridor
  $game_map.load_grid(["############",
                       "#@.........#",
                       "#..........#",
                       "############"])
  World.clear_events
  [[4, 1, "ana"], [6, 1, "bea"], [8, 1, "cid"], [5, 2, "dan"], [9, 2, "eva"]].each_with_index do |(x, y, s), i|
    World.event(:kind => :trainer, :id => i + 1, :x => x, :y => y).character_name = s
  end
end

# Inside one_answer_per_step the rays of a scan ask the engine once per step and keep what they kept without it.
Suite.define("audio3d: with the step memo a scan asks each step once and finds the same") do
  a3d = PokeAccess::Audio3D
  prev_range = PokeAccess::Config.audio3d_range
  prev_occ = PokeAccess::Config.audio3d_occlusion
  begin
    PokeAccess::Config.audio3d_range = 12
    PokeAccess::Config.audio3d_occlusion = :hide
    sonar_corridor
    with_asked_steps do |asked|
      a3d.rescan(1, 1)
      a3d.update_walls(1, 1)
      plain = [a3d.instance_variable_get(:@emitters), a3d.instance_variable_get(:@wall)]
      plain_asks = asked.length
      asked.clear
      a3d.one_answer_per_step do
        a3d.rescan(1, 1)
        a3d.update_walls(1, 1)
      end
      eq "the same emitters and walls as without the memo",
         [a3d.instance_variable_get(:@emitters), a3d.instance_variable_get(:@wall)], plain
      eq "each step was asked once", asked.length, asked.uniq.length
      truthy "fewer questions than the rays make on their own (#{asked.length} against #{plain_asks})",
             asked.length < plain_asks
      falsy "and the memo is closed afterwards", a3d.instance_variable_get(:@step_memo)
    end
  ensure
    PokeAccess::Config.audio3d_range = prev_range
    PokeAccess::Config.audio3d_occlusion = prev_occ
    World.clear_events
    $game_map.clear_grid
  end
end

# A whole tick scans under the memo, and the next tick asks the engine afresh: a rock pushed onto the rays between
# two ticks hides the people behind it.
Suite.define("audio3d: a tick asks each step once, and the next tick asks again") do
  a3d = PokeAccess::Audio3D
  ivars = [:@ready, :@ch, :@active, :@emitters, :@near, :@wall, :@scan_pos, :@ptime, :@ping_idx, :@last_ping_any,
           :@last_ping_pos, :@mover_time, :@gates, :@bgm_restored, :@master_sent, :@air_sent, :@basic_silenced]
  saved = ivars.inject({}) { |h, k| h[k] = a3d.instance_variable_get(k); h }
  prev_trainer = $Trainer
  prev_range = PokeAccess::Config.audio3d_range
  prev_occ = PokeAccess::Config.audio3d_occlusion
  begin
    $Trainer = Object.new
    chans = {}
    a3d::CHANNEL_FILES.each_with_index { |row, i| chans[row[0]] = i }
    a3d.instance_variable_set(:@ready, true)
    a3d.instance_variable_set(:@ch, chans)
    a3d.instance_variable_set(:@scan_pos, nil)
    PokeAccess::Config.sound_nav = :full
    PokeAccess::Config.audio3d_range = 12
    PokeAccess::Config.audio3d_occlusion = :hide
    sonar_corridor
    rock = World.event(:id => 9, :x => 3, :y => 1)
    rock.character_name = ""
    with_asked_steps do |asked|
      a3d.tick
      truthy "the tick scanned the corridor", asked.length > 0
      eq "and asked the engine once per step", asked.length, asked.uniq.length
      eq "the nearest people ping", a3d.instance_variable_get(:@emitters)[:npc].first, [4, 1]
      rock.blocking = true
      a3d.instance_variable_set(:@scan_pos, nil)
      a3d.tick
      falsy "the next tick sees the rock across the rays", (a3d.instance_variable_get(:@emitters)[:npc] || []).include?([4, 1])
      falsy "and holds no memo between ticks", a3d.instance_variable_get(:@step_memo)
    end
  ensure
    PokeAccess::Config.audio3d_range = prev_range
    PokeAccess::Config.audio3d_occlusion = prev_occ
    $Trainer = prev_trainer
    saved.each { |k, v| a3d.instance_variable_set(k, v) }
    World.clear_events
    $game_map.clear_grid
  end
end
