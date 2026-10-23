# The cane (Guide.tick) as heard: a chime toward the next step on guide_rhythm's interval, louder as the target nears,
# up and down told by pitch; no route said once with chimes straight at the target; arrival or a lost target ends it.
class GuideCadenceTest < PokeAccessTest
  G = PokeAccess::Guide
  T = PokeAccess::I18n
  # A corridor with the player at its left end and a target four tiles to the right (route: three presses).
  CORRIDOR = ['##########',
              '#@...T...#',
              '##########']
  # A walled room the player cannot get into holds the first target; the second stands in the open.
  SEALED = ['################',
            '#@.............#',
            '#..............#',
            '#....######....#',
            '#....#....#....#',
            '#....#.T..#....#',
            '#....#....#....#',
            '#....######....#',
            '#.....B........#',
            '################']
  # A corridor with a door at (4,1) between the player at its left end and a target at (6,1).
  DOOR = ['#########',
          '#@..D.T.#',
          '#########']

  test "its interval is guide_freq's gap at the target, growing with the distance to twice that from 24 tiles on" do
    base = PokeAccess.freq_to_seconds(PokeAccess::Config.guide_freq)
    { 0 => base, 6 => base * 1.25, 12 => base * 1.5, 24 => base * 2, 200 => base * 2 }.each do |dist, want|
      assert_in_delta want, G.interval(dist), 1e-9, "#{dist} tiles away"
    end
  end

  test "its interval is the same at any distance with a constant rhythm" do
    PokeAccess::Config.guide_rhythm = :constant
    base = PokeAccess.freq_to_seconds(PokeAccess::Config.guide_freq)
    assert_equal [base, base, base], [0, 1, 24].map { |d| G.interval(d) }
  end

  test "a higher guide_freq makes the gap between chimes shorter" do
    gaps = [0, 75, 100].map do |f|
      PokeAccess::Config.guide_freq = f
      G.interval(0)
    end
    assert_equal [0, 75, 100].map { |f| PokeAccess.freq_to_seconds(f) }, gaps, "each the gap of its guide_freq"
    assert_operator gaps[0], :>, gaps[2], "0 is slower than 100"
  end

  test "its volume falls from the guide volume beside the target to a 35 % floor, and is none with the sound off" do
    { [70, 0] => 70, [70, 1] => 67, [70, 12] => 35, [70, 24] => 24, [70, 100] => 24, [1, 0] => 1,
      [0, 1] => nil }.each do |(vol, dist), want|
      PokeAccess::Config.event_volume = vol
      got = G.volume(dist)
      want.nil? ? assert_nil(got, "volume #{vol}") : assert_equal(want, got, "volume #{vol}, #{dist} tiles away")
    end
  end

  test "chimes toward the next step at a volume that falls with the target's distance" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        guide_frame
        assert_equal [["pa_guide_r", 58, 100]], heard(log)
      end
    end
  end

  test "chimes on its first frame, and again only once its interval has passed" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, pass|
      gap = G.interval(4)
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        guide_frame
        guide_frame
        at_once = log.length
        pass.call(gap - 0.01)
        guide_frame
        inside = log.length
        pass.call(0.02)
        guide_frame
        assert_equal [1, 1, 2], [at_once, inside, log.length], "a frame at once, one just inside the gap, one past it"
      end
    end
  end

  test "keeps silent over an open message box, and chimes once it closes" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        held = nil
        begin
          $game_temp.message_window_showing = true
          guide_frame
          held = log.length
        ensure
          $game_temp.message_window_showing = nil
        end
        guide_frame
        assert_equal [0, 1], [held, log.length]
      end
    end
  end

  test "plays no chime with the guide's volume at zero" do
    hpa_fresh_grid(CORRIDOR)
    PokeAccess::Config.event_volume = 0
    guided do |loc, _pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        guide_frame
        assert_equal [], log
      end
    end
  end

  test "tells the way by its cue: right and left by their side, up high and down low on the middle one" do
    hpa_fresh_grid(['#######',
                    '###U###',
                    '###.###',
                    '#L.@.R#',
                    '###.###',
                    '###D###',
                    '#######'])
    guided do |loc, _pass|
      ev = $game_map.events
      { "up" => [ev[1], ["pa_guide_c", 64, 140]], "left" => [ev[2], ["pa_guide_l", 64, 100]],
        "right" => [ev[3], ["pa_guide_r", 64, 100]], "down" => [ev[4], ["pa_guide_c", 64, 70]] }.each do |way, (to, want)|
        with_cue_log do |log|
          guide_aim(loc, to)
          guide_frame
          assert_equal [want], heard(log), way
        end
      end
    end
  end

  test "says again for a new target that its next step lands where the key is to be held" do
    hpa_fresh_grid(CORRIDOR)
    with_held_ground([2, 1]) do
      guided do |loc, _pass|
        guide_aim(loc, $game_map.events[1])
        SpeakCapture.clear
        guide_frame
        first = SpeakCapture.log.dup
        loc.instance_variable_set(:@target, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
        SpeakCapture.clear
        guide_frame
        hold = [[T.t(:loc_hold_key), false]]
        assert_equal [hold, hold], [first, SpeakCapture.log], "for the first target, then for the new one"
      end
    end
  end

  test "says once, without cutting in, that there is no route, and keeps the cane on" do
    hpa_fresh_grid(SEALED)
    guided do |loc, pass|
      guide_aim(loc, $game_map.events[1])
      SpeakCapture.clear
      3.times do
        guide_frame
        pass.call(5.0)
      end
      assert_equal [[[T.t(:loc_no_route), false]], true], [SpeakCapture.log, G.on?(:cane)]
    end
  end

  test "chimes straight toward a target with no route once per tile it is heard from" do
    hpa_fresh_grid(SEALED)
    guided do |loc, pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        guide_frame
        pass.call(5.0)
        guide_frame
        still = heard(log)
        $game_player.x = 2
        pass.call(5.0)
        guide_frame
        assert_equal [[["pa_guide_r", 40, 100]], 2], [still, log.length], "standing still, then a tile on"
      end
    end
  end

  test "a target with no route is announced again after a routable one" do
    hpa_fresh_grid(SEALED)
    assert_nil walk_route(7, 5), "no walk gets into the sealed room"
    assert_equal 11, walk_route(6, 8).length, "the open target is eleven presses away"
    guided do |loc, pass|
      sealed = $game_map.events[1]
      guide_aim(loc, sealed)
      guide_frame
      loc.instance_variable_set(:@target, $game_map.events[2])
      pass.call(5.0)
      SpeakCapture.clear
      guide_frame
      open = SpeakCapture.lines.dup
      loc.instance_variable_set(:@target, sealed)
      pass.call(5.0)
      SpeakCapture.clear
      guide_frame
      assert_equal [[], [T.t(:loc_no_route)]], [open, SpeakCapture.lines], "the open one, then the sealed one again"
    end
  end

  test "turning the other guide on says the no route again" do
    hpa_fresh_grid(SEALED)
    guided do |loc, _pass|
      guide_aim(loc, $game_map.events[1])
      guide_frame
      G.switch(:steps, true)
      SpeakCapture.clear
      guide_frame
      assert_equal [T.t(:loc_no_route)], SpeakCapture.lines
    end
  end

  test "once a way that opened shuts again, the no route is said again and chimed straight again from the same tile" do
    hpa_fresh_grid(DOOR)
    door = $game_map.events[1]
    door.blocking = true
    guided do |loc, _pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[2])
        shut = frame_heard(log)
        door.through = true
        G.event_ended
        open = frame_heard(log)
        door.through = false
        chime = ["pa_guide_r", 55, 100]
        assert_equal [[[T.t(:loc_no_route)], [chime]], [[], [chime]], [[T.t(:loc_no_route)], [chime]]],
                     [shut, open, frame_heard(log)], "shut, open, then shut again"
      end
    end
  end

  test "with no route, chimes the longer way toward the target if it can be stepped, else the other, else toward water" do
    {
      "the longer way open" => [['#########',
                                 '#@....#T#',
                                 '#.....###',
                                 '#########'], ["pa_guide_r", 100]],
      "the longer way walled" => [['#########',
                                   '#@#....##',
                                   '#.....#T#',
                                   '#.....###',
                                   '#########'], ["pa_guide_c", 70]],
      "the longer way down" => [['#####',
                                 '#@..#',
                                 '#...#',
                                 '#...#',
                                 '#####',
                                 '##T##',
                                 '#####'], ["pa_guide_c", 70]],
      "as far across as down" => [['#######',
                                   '#@...##',
                                   '#....##',
                                   '#....##',
                                   '#....##',
                                   '#####T#',
                                   '#######'], ["pa_guide_r", 100]],
      "water the longer way" => [['##########',
                                  '#@~~~~#T##',
                                  '##.....###',
                                  '##########'], ["pa_guide_r", 100]],
      "water the other way" => [['#########',
                                 '#@#....##',
                                 '#~....#T#',
                                 '#~....###',
                                 '#########'], ["pa_guide_c", 70]],
      "walls on both ways" => [['#########',
                                '#@#....##',
                                '##....#T#',
                                '#.....###',
                                '#########'], nil]
    }.each do |what, (rows, want)|
      hpa_fresh_grid(rows)
      guided do |loc, _pass|
        with_cue_log do |log|
          guide_aim(loc, $game_map.events[1])
          SpeakCapture.clear
          guide_frame
          cues = log.map { |e| [cue_name(e), e[2]] }
          assert_equal [[T.t(:loc_no_route)], want ? [want] : []], [SpeakCapture.lines, cues], what
        end
      end
    end
  end

  test "beside the target it announces the arrival, cutting in, and goes quiet with the cane off" do
    hpa_fresh_grid(['##########',
                    '#.@A..B..#',
                    '##########'])
    guided do |loc, pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[1])
        SpeakCapture.clear
        guide_frame
        arrived = SpeakCapture.log.dup
        pass.call(5.0)
        SpeakCapture.clear
        guide_frame
        assert_equal [[[T.t(:loc_arrived), true]], [], [], false], [arrived, SpeakCapture.log, log, G.on?(:cane)]
      end
    end
  end

  test "a target still steps away is not arrived at: nothing is said and the cane chimes on" do
    hpa_fresh_grid(['##########',
                    '#.@A..B..#',
                    '##########'])
    guided do |loc, _pass|
      with_cue_log do |log|
        guide_aim(loc, $game_map.events[2])
        SpeakCapture.clear
        guide_frame
        assert_equal [[], 1, true], [SpeakCapture.lines, log.length, G.on?(:cane)]
      end
    end
  end

  test "on a spot to dive or to come up it ends saying what the action button does there" do
    hpa_fresh_grid(['#####',
                    '#.@.#',
                    '#####'])
    guided do |loc, _pass|
      { :surf_dive => :loc_dive_here, :surf_surface => :loc_surface_here }.each do |kind, key|
        guide_aim(loc, loc::SurfaceTarget.new(2, 1, "spot", kind))
        SpeakCapture.clear
        guide_frame
        assert_equal [[[T.t(key), true]], false], [SpeakCapture.log, G.on?(:cane)], kind.to_s
      end
    end
  end

  test "a target gone from the map is announced lost, cutting in, and the cane stops" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      ev = $game_map.events[1]
      guide_aim(loc, ev)
      guide_frame
      $game_map.events.delete(ev.id)
      SpeakCapture.clear
      guide_frame
      assert_equal [[[T.t(:loc_target_lost), true]], false], [SpeakCapture.log, G.on?(:cane)]
    end
  end

  private

  # Runs the block in with_guide_state with the clock stopped (with_clock), yielding the locator and the clock's lambda.
  def guided
    with_guide_state { |loc| with_clock { |pass| yield loc, pass } }
  end

  # Runs the block with PokeAccess.clock standing still, yielding a lambda that moves it on by the seconds given.
  def with_clock
    now = [1000.0]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    yield lambda { |secs| now[0] += secs }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # The cues logged by with_cue_log as [file, volume, pitch].
  def heard(log)
    log.map { |e| [cue_name(e), e[1], e[2]] }
  end

  # Runs one frame of the guides and returns what it said and the cues it played (heard), the log emptied after.
  def frame_heard(log)
    SpeakCapture.clear
    guide_frame
    out = [SpeakCapture.lines.dup, heard(log)]
    log.clear
    out
  end

  # Runs the block with the tiles given as ground where the direction key is to be held (Moves.held_key_rule), the
  # rules put back as they were after.
  def with_held_ground(*tiles)
    mv = PokeAccess::Routes::Moves
    saved = mv.instance_variable_get(:@held_rules).dup
    mv.held_key_rule { |x, y| tiles.include?([x, y]) }
    yield
  ensure
    mv.instance_variable_set(:@held_rules, saved)
    mv.forget_map
  end
end
