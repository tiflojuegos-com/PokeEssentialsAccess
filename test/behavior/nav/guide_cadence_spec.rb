# The guide cane's per-frame loop (Locator.guide_tick) as heard: the chime interval, which grows with distance; the
# direction cue, up and down told apart by pitch alone; "no route" said once; arrival; a target that vanishes.

# Points the cane at target with no cached route, cadence or latches, so the next guide_tick recomputes and chimes.
def guide_aim(loc, target)
  [:@guide_time, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh, :@guide_surf,
   :@noroute_key, :@noroute_cue_at, :@guide_noroute, :@jump_at, :@blocked_recheck_at].each do |s|
    loc.instance_variable_set(s, nil)
  end
  loc.instance_variable_set(:@target, target)
  loc.instance_variable_set(:@guide, true)
end

# Backdates the last chime to secs ago, standing in for frames passing without sleeping.
def guide_rewind(loc, secs)
  loc.instance_variable_set(:@guide_time, PokeAccess.clock - secs)
end

# Runs the block with the guide ivars saved and restored and the test grid dropped after (Reset does not cover them),
# and with a $Trainer, since guide_tick is silent while Spatial.busy? (no trainer reads as character selection).
def with_guide_state
  loc = PokeAccess::Locator
  ivars = [:@guide, :@guide_time, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh, :@guide_surf,
           :@guide_noroute, :@noroute_key, :@noroute_cue_at, :@jump_at, :@blocked_recheck_at, :@target]
  prev = ivars.map { |s| loc.instance_variable_get(s) }
  had_trainer = $Trainer
  $Trainer = Object.new
  def $Trainer.name; "Rojo"; end
  falsy "the player is not stuck on the character-selection screen", PokeAccess::Spatial.busy?
  yield loc
ensure
  $Trainer = had_trainer
  ivars.each_index { |i| loc.instance_variable_set(ivars[i], prev[i]) }
  $game_map.clear_ledges
  $game_map.clear_grid
end

# Yields a log of [file, volume, pitch] for every Audio.se_play, where each cue lands under test (no 3D engine).
def with_cue_log
  log = []
  orig = Audio.method(:se_play)
  Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
  yield log
ensure
  Audio.define_singleton_method(:se_play, orig)
end

# The basename of a logged cue (the path is prefixed with the sounds folder).
def cue_name(entry)
  entry[0].to_s.split("/").last
end

Suite.define("guide: the chime holds its interval, and the interval follows distance and the setting") do
  hpa_fresh_grid(["##########",
                  "#@...T...#",
                  "##########"])
  with_guide_state do |loc|
    base = PokeAccess.freq_to_seconds(PokeAccess::Config.guide_freq)
    eq "with no distance the interval is the plain configured one", loc.guide_interval(nil), base
    eq "at the target the interval is the configured one", loc.guide_interval(0), base
    eq "at the falloff distance it has doubled", loc.guide_interval(24), base * 2
    eq "and beyond the falloff it stops growing", loc.guide_interval(200), base * 2
    truthy "so a far target chimes less often than a near one", loc.guide_interval(24) > loc.guide_interval(1)

    begin
      PokeAccess::Config.guide_freq = 100
      fast = loc.guide_interval(0)
      PokeAccess::Config.guide_freq = 0
      slow = loc.guide_interval(0)
      truthy "a higher guide_freq means a shorter gap between chimes", fast < slow
    ensure
      PokeAccess::Config.guide_freq = 55
    end

    eq "the fixture put the target four tiles to the player's right",
       [[$game_player.x, $game_player.y], [$game_map.events[1].x, $game_map.events[1].y]],
       [[1, 1], [5, 1]]
    guide_aim(loc, $game_map.events[1])
    with_cue_log do |log|
      loc.guide_tick
      eq "the first tick chimes", log.length, 1
      loc.guide_tick
      eq "a tick in the very next frame adds nothing", log.length, 1
      guide_rewind(loc, 0.5)
      loc.guide_tick
      eq "half a second later (still inside the interval) it is silent", log.length, 1
      guide_rewind(loc, 2.0)
      loc.guide_tick
      eq "past the interval it chimes again", log.length, 2

      begin
        $game_temp.message_window_showing = true
        guide_rewind(loc, 2.0)
        loc.guide_tick
        eq "and it never chimes over an open message box", log.length, 2
      ensure
        $game_temp.message_window_showing = nil
      end
      guide_rewind(loc, 2.0)
      loc.guide_tick
      eq "once the box closes the chime resumes", log.length, 3
    end
  end
end

Suite.define("guide: the chime says which way, and gets louder as the target nears") do
  hpa_fresh_grid(["#######",
                  "###U###",
                  "###.###",
                  "#L.@.R#",
                  "###.###",
                  "###D###",
                  "#######"])
  with_guide_state do |loc|
    up = $game_map.events[1]; left = $game_map.events[2]
    right = $game_map.events[3]; down = $game_map.events[4]
    eq "the fixture put the four targets around the player",
       [[up.x, up.y], [left.x, left.y], [right.x, right.y], [down.x, down.y]],
       [[3, 1], [1, 3], [5, 3], [3, 5]]

    with_cue_log do |log|
      guide_aim(loc, right); loc.guide_tick
      eq "a target to the right plays the right-panned cue", cue_name(log.last), "pa_guide_r"
      guide_aim(loc, left); loc.guide_tick
      eq "a target to the left plays the left-panned one", cue_name(log.last), "pa_guide_l"

      guide_aim(loc, up); loc.guide_tick
      eq "up uses the flat (unpannable) cue", cue_name(log.last), "pa_guide_c"
      up_pitch = log.last[2]
      guide_aim(loc, down); loc.guide_tick
      eq "down uses the same file", cue_name(log.last), "pa_guide_c"
      down_pitch = log.last[2]
      truthy "and up is told from down by a HIGHER pitch", up_pitch > down_pitch
      eq "up is the high pitch", up_pitch, 140
      eq "down is the low one", down_pitch, 70
    end

    with_cue_log do |log|
      loc.guide_cue(6, 1)
      loc.guide_cue(6, 30)
      truthy "a target one tile away chimes louder than one thirty away", log[0][1] > log[1][1]
      eq "beyond the falloff the volume rests on the 35% floor",
         log[1][1], (PokeAccess::Config.event_volume * 0.35).to_i
      loc.guide_cue(0, 1)
      eq "no direction plays nothing", log.length, 2
      begin
        PokeAccess::Config.event_volume = 0
        loc.guide_cue(6, 1)
        eq "and a muted cue volume plays nothing either", log.length, 2
      ensure
        PokeAccess::Config.event_volume = 70
      end
    end
  end
end

Suite.define("guide: an unreachable target is announced once, and its cue does not gallop in place") do
  hpa_fresh_grid(["################",
                  "#@.............#",
                  "#..............#",
                  "#....######....#",
                  "#....#....#....#",
                  "#....#.T..#....#",
                  "#....#....#....#",
                  "#....######....#",
                  "#.....B........#",
                  "################"])
  with_guide_state do |loc|
    sealed = $game_map.events[1]; open_ev = $game_map.events[2]
    noroute = Regexp.new(Regexp.escape(PokeAccess::I18n.t(:loc_no_route)))
    truthy "the fixture really has no route into the sealed room",
           PokeAccess::Pathfinder.find_path(sealed.x, sealed.y).nil?
    truthy "while the other target IS reachable",
           !PokeAccess::Pathfinder.find_path(open_ev.x, open_ev.y).nil?

    guide_aim(loc, sealed)
    loc.guide_tick
    spoke_once "the first tick says there is no route", noroute
    truthy "but the cane stays on, so it keeps nudging the player closer",
           loc.instance_variable_get(:@guide)
    guide_rewind(loc, 5.0); loc.guide_tick
    guide_rewind(loc, 5.0); loc.guide_tick
    spoke_once "two more ticks later it has still only been said once", noroute

    with_cue_log do |log|
      guide_rewind(loc, 5.0); loc.guide_tick
      eq "standing on the same tile does not re-chime the straight-line cue", log.length, 0
      $game_player.x = 2
      guide_rewind(loc, 5.0); loc.guide_tick
      eq "stepping to a new tile chimes toward it again", log.length, 1
    end

    SpeakCapture.clear
    loc.instance_variable_set(:@target, open_ev)
    guide_rewind(loc, 5.0); loc.guide_tick
    not_spoke "a routable target says nothing about routes", noroute
    falsy "and it clears the no-route latch", loc.instance_variable_get(:@guide_noroute)

    SpeakCapture.clear
    loc.instance_variable_set(:@target, sealed)
    guide_rewind(loc, 5.0); loc.guide_tick
    spoke_once "so a LATER unreachable target is announced again", noroute
  end
end

# The player stands one tile off the wall on purpose: "#@A" in a double-quoted row would interpolate @A.
Suite.define("guide: reaching the target announces it and switches the cane off") do
  hpa_fresh_grid(["##########",
                  "#.@A..B..#",
                  "##########"])
  with_guide_state do |loc|
    here = $game_map.events[1]; far = $game_map.events[2]
    arrived = Regexp.new(Regexp.escape(PokeAccess::I18n.t(:loc_arrived)))
    eq "the fixture put one target next to the player and one further off",
       [[$game_player.x, $game_player.y], [here.x, here.y], [far.x, far.y]],
       [[2, 1], [3, 1], [6, 1]]

    guide_aim(loc, far)
    loc.guide_tick
    not_spoke "a target still five tiles away does not announce arrival", arrived
    truthy "and the cane is still on", loc.instance_variable_get(:@guide)

    SpeakCapture.clear
    guide_aim(loc, here)
    loc.guide_tick
    spoke_once "standing next to the target announces the arrival", arrived
    falsy "and the cane switches itself off", loc.instance_variable_get(:@guide)

    SpeakCapture.clear
    with_cue_log do |log|
      guide_rewind(loc, 5.0)
      loc.guide_tick
      silent "a further tick with the cane off says nothing"
      eq "and chimes nothing", log.length, 0
    end
  end
end

Suite.define("guide: a target that disappears stops the cane instead of chiming at a ghost") do
  hpa_fresh_grid(["##########",
                  "#@...T...#",
                  "##########"])
  with_guide_state do |loc|
    ev = $game_map.events[1]
    lost = Regexp.new(Regexp.escape(PokeAccess::I18n.t(:loc_target_lost)))
    eq "the fixture put a reachable target on the map", [ev.x, ev.y], [5, 1]

    guide_aim(loc, ev)
    loc.guide_tick
    not_spoke "a target still on the map is not reported lost", lost

    SpeakCapture.clear
    $game_map.events.delete(ev.id)
    guide_aim(loc, ev)
    loc.guide_tick
    spoke_once "an event that left the map is announced as lost", lost
    falsy "and the cane stops", loc.instance_variable_get(:@guide)
  end
end
