# The free camera (Camera): opening on the player, the game's input held while it is open, its moves (a wall, a
# crossing, the map's edge, a long move), what it says and where it sounds, the soundscape and the locator from it,
# the destination it fixes, the readers a profile adds and what shuts it.
class CameraTest < PokeAccessTest
  Camera = PokeAccess::Camera
  Text = PokeAccess::CameraText
  T = PokeAccess::I18n
  # A room with the player at its left, a wall row above.
  ROOM = ['############',
          '#@.........#',
          '#..........#',
          '############']
  # A corridor from the player that opens to a side at (6,2).
  CORRIDOR = ['##########',
              '#@.......#',
              '######.###',
              '##########']
  # A row of 14 open tiles.
  LONG = ['#################',
          '#@...............',
          '#################']

  test "opens on the player's tile and says so; shut, the focus and the listener are the player's again" do
    with_camera(ROOM) do
      with_sound_engine do |dll|
        Camera.open
        open_focus = Camera.focus
        Camera.move(6, :step)
        moved = [Camera.focus, dll.args(:listener).last]
        Camera.close(T.t(:cam_off))
        u = PokeAccess::Sound::Pa3d::TILE_UNITS
        assert_equal [[1, 1], [[2, 1], [2 * u, 1 * u]], [1, 1], [1 * u, 1 * u]],
                     [open_focus, moved, Camera.focus, dll.args(:listener).last]
        assert_equal T.t(:cam_on), SpeakCapture.lines.first
        assert_equal T.t(:cam_off), SpeakCapture.lines.last
      end
    end
  end

  test "the game's input reads as released while open and until the keys that shut it are let go; lend gives it back" do
    with_camera(ROOM) do
      dir = [6]
      swapping(Input, :trigger__access_orig, proc { |*_a| true }) do
        swapping(Input, :dir4__access_orig, proc { |*_a| dir[0] }) do
          before = [Input.trigger?(Input::C), Input.dir4]
          Camera.open
          held = [Input.trigger?(Input::C), Input.dir4, Input.press?(Input::B), Input.repeat?(Input::DOWN)]
          lent = Camera.lend { [Input.trigger?(Input::C), Input.dir4] }
          Camera.close(nil)
          Camera.pulse
          guarded = [Input.trigger?(Input::C), Input.dir4]
          dir[0] = 0
          Camera.pulse
          after = Input.trigger?(Input::C)
          assert_equal [[true, 6], [false, 0, false, false], [true, 6], [false, 0], true], [before, held, lent, guarded, after]
        end
      end
    end
  end

  test "steps where the player could, bumps a wall saying it once per push, and crosses it with Ctrl" do
    with_camera(ROOM) do
      Camera.open
      SpeakCapture.clear
      Camera.move(8, :step)
      Camera.move(8, :step)
      blocked = [Camera.focus, SpeakCapture.lines]
      SpeakCapture.clear
      Camera.move(8, :through)
      assert_equal [[[1, 1], [T.t(:cam_wall)]], [1, 0]], [blocked, Camera.focus]
      assert_includes SpeakCapture.lines.last, T.t(:cam_unstandable)
    end
  end

  test "a wall whose tag names a surface is a wall, bumped or crossed, and water stopping the way is water" do
    with_camera(ROOM) do
      $game_map.set_terrain(1, 0, 3)
      $game_map.set_terrain(2, 0, 7)
      PokeAccess::World.reset!
      Camera.open
      SpeakCapture.clear
      Camera.move(8, :step)
      wall = SpeakCapture.lines
      Camera.move(8, :through)
      crossed = SpeakCapture.lines.last
      refute_includes crossed, T.t(:surf_sand)
      assert_equal [T.t(:cam_wall)], wall
      refute_includes Text.tile_line(1, 0), T.t(:surf_sand)
      assert_equal T.t(:surf_water), Text.blocked_line(2, 0)
    end
  end

  test "stops at the map's edge and names the map past it where a step off is open" do
    with_camera(LONG) do
      Camera.open
      2.times { Camera.move(6, :long) }
      SpeakCapture.clear
      swapping(PokeAccess::Locator, :connection_edges, proc { { 7 => [[16, 1, 6]] } }) do
        swapping(PokeAccess::Locator, :map_name, proc { |_id| "Ruta 2" }) do
          Camera.move(6, :step)
        end
      end
      assert_equal [[16, 1], [T.t(:cam_edge_to, :map => "Ruta 2")]], [Camera.focus, SpeakCapture.lines]
    end
  end

  test "a long move goes on to a side opening, or ten tiles, and says how far" do
    with_camera(CORRIDOR) do
      Camera.open
      SpeakCapture.clear
      Camera.move(6, :long)
      assert_equal [6, 1], Camera.focus, "the corridor opens downward at x 6"
      assert_match(/\A#{Regexp.escape(T.t(:cam_jump, :n => 5))}/, SpeakCapture.lines.last)
    end
    with_camera(LONG) do
      Camera.open
      Camera.move(6, :long)
      assert_equal [11, 1], Camera.focus, "ten tiles at most"
    end
  end

  test "says the name of what stands on the tile, and a profile's tile reader with it" do
    with_camera(ROOM) do
      ev = TestEvent.new(1, "Cartel", 3, 1)
      $game_map.events[1] = ev
      PokeAccess::World.reset!
      with_rules(:readers, [nil, proc { |x, y| x == 3 && y == 1 ? "baldosa rara" : nil }]) do
        Camera.open
        Camera.move(6, :step)
        SpeakCapture.clear
        Camera.move(6, :step)
        line = SpeakCapture.lines.last
        assert_includes line, PokeAccess::Locator.target_name(ev)
        assert_includes line, "baldosa rara"
      end
    end
  end

  test "the step sounds on the camera's tile, and the soundscape reads the scene from it once it stands still" do
    with_camera(ROOM) do
      with_sound_engine do |dll|
        Camera.open
        dll.log.clear
        Camera.move(6, :step)
        step = dll.played.map { |id, x, y, _v| [id, x, y] }
        scans = []
        sch = PokeAccess::Sound::Scheduler
        swapping(PokeAccess::Sound::Scene, :scan, proc { |x, y| scans.push([x, y]) }) do
          sch.instance_variable_set(:@scan_pos, nil)
          sch.scan_and_ping(*Camera.focus)
          moving = scans.dup
          Camera.instance_variable_set(:@moved, PokeAccess::Frame.serial - Camera::STILL_FRAMES)
          sch.scan_and_ping(*Camera.focus)
          assert_equal [[[:step, 2, 1]], [], [[2, 1]]], [step, moving, scans]
        end
      end
    end
  end

  test "J and K count from the camera: the nearest target to it first, its direction from it, no steps on foot" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      near = TestEvent.new(1, "Cerca", 2, 2)
      far = TestEvent.new(2, "Lejos", 9, 2)
      $game_map.events[1] = near
      $game_map.events[2] = far
      PokeAccess::World.reset!
      Camera.open
      8.times { Camera.move(6, :step) }
      loc.clear_targets
      SpeakCapture.clear
      loc.step(1)
      said = SpeakCapture.lines.last
      assert_equal far, loc.target
      assert_includes said, loc.dir_phrase(0, 1)
      refute_includes said, T.t(:loc_steps, :n => 1)
    end
  end

  test "I says the way on foot from the camera" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      Camera.open
      5.times { Camera.move(6, :step) }
      t = loc::SurfaceTarget.new(9, 1, "cofre", :spot)
      loc.instance_variable_set(:@target, t)
      SpeakCapture.clear
      loc.announce_route
      route = PokeAccess::Pathfinder::Route.new
      route.concat([6, 6])
      want = PokeAccess::Routes::Text.line(PokeAccess::Routes::Plan.new(:walk, route), [6, 1], [nil, nil])
      assert_equal want, SpeakCapture.lines.last, "two right, to beside the chest, from the camera's tile"
    end
  end

  test "Ctrl+G marks the camera's tile, M says where the camera is and the info key describes its tile" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      Camera.open
      3.times { Camera.move(6, :step) }
      marked = nil
      swapping(loc, :edit_mark, proc { |x, y| marked = [x, y] }) { loc.mark_here }
      SpeakCapture.clear
      loc.announce_coords
      where = SpeakCapture.lines.last
      info = PokeAccess::Info.map_text
      assert_equal [4, 1], marked
      assert_equal Text.where_line(4, 1), where
      assert_includes where, loc.dir_phrase(3, 0)
      assert_equal Text.tile_line(4, 1), info
      assert_includes info, loc.coords_text(4, 1)
    end
  end

  test "Enter fixes the destination: selected, listed among the markers, said with the player's route, the camera shut" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      Camera.open
      4.times { Camera.move(6, :step) }
      SpeakCapture.clear
      Camera.fix
      t = loc.target
      steps = PokeAccess::Routes::Text.listing(loc.route_plan(t))
      assert_equal [false, :camera, [5, 1], true, true], [Camera.active?, t.key, [t.x, t.y], loc.target_valid?, loc.onto?(t)]
      assert_includes loc.mark_targets, t
      assert_equal PokeAccess.sentences([T.t(:cam_dest_set, :steps => steps), T.t(:cam_off)]), SpeakCapture.lines.last
      Camera.reset
      refute loc.target_valid?, "a map change drops it"
    end
  end

  test "the guides and the sounds of the player's own moves wait silent while the camera is open, and run once shut" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      plans = 0
      steps = 0
      guide_aim(loc, loc::SurfaceTarget.new(9, 1, "cofre", :spot))
      Camera.open
      swapping(PokeAccess::Sound::Feedback, :footstep, proc { steps += 1 }) do
        swapping(loc, :route_plan, proc { |_t| plans += 1; PokeAccess::Routes::Plan.new(:none) }) do
          guide_frame
          PokeAccess::Sound::Feedback.tick
          open = [plans, steps]
          Camera.close(nil)
          guide_frame
          PokeAccess::Sound::Feedback.tick
          assert_equal [[0, 0], [1, 1]], [open, [plans, steps]], "planned and stepped once the camera is shut"
        end
      end
    end
  end

  test "control lost shuts the camera, said queued, unless lent or for the mod's menu; the mod switched off shuts it" do
    with_camera(ROOM) do
      Camera.open
      Camera.lend { PokeAccess::Events.emit(:control_lost, :stalled) }
      PokeAccess::Events.emit(:control_lost, :mod_menu)
      lent = Camera.active?
      SpeakCapture.clear
      PokeAccess::Events.emit(:control_lost, :message)
      assert_equal [true, false], [lent, Camera.active?]
      assert_equal [[T.t(:cam_off), false]], SpeakCapture.log
      Camera.open
      PokeAccess::Keys.instance_variable_set(:@enabled, true)
      swapping(PokeAccess::Keys, :hotkey?, proc { |_k| true }) { PokeAccess::Keys.toggle_poll }
      off = Camera.active?
      PokeAccess::Keys.instance_variable_set(:@enabled, true)
      refute off
    end
  end

  test "enters a ledge only the way it is hopped, says the jump once and lands past it, its tile shut to a walk" do
    with_camera(ROOM) do
      $game_map.place_ledge(3, 1, 6)
      $game_map.block_step(3, 1, 6)
      PokeAccess::World.reset!
      Camera.open
      Camera.move(6, :step)
      SpeakCapture.clear
      Camera.move(6, :step)
      onto = [Camera.focus, SpeakCapture.lines.last]
      SpeakCapture.clear
      Camera.move(6, :step)
      landed = [Camera.focus, SpeakCapture.lines]
      Camera.move(4, :step)
      assert_equal [[[3, 1], PokeAccess::Routes::Text.jump(6)], [[4, 1], []], [4, 1]], [onto, landed, Camera.focus]
    end
  ensure
    $game_map.clear_ledges
  end

  test "names the declared puzzle point of the tile through the core's tile reader" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      ev = TestEvent.new(1, "palanca norte", 3, 1)
      $game_map.events[1] = ev
      PokeAccess::World.reset!
      named = "palanca norte"
      spots = [loc::SurfaceTarget.new(3, 1, named, :puzzle_spot), loc::SurfaceTarget.new(3, 1, "rejilla", :puzzle_spot)]
      plain = proc { |t| t.is_a?(loc::SurfaceTarget) ? t.name : t.name.to_s }
      swapping(loc, :target_name, plain) do
      swapping(PokeAccess::World::Mechanics, :instances, proc { [:spec_puzzle] }) do
        swapping(PokeAccess::Puzzles, :targets_of, proc { |_inst| spots }) do
        swapping(PokeAccess::Puzzles, :shown_names, proc { |_inst| [] }) do
          Camera.open
          Camera.move(6, :step)
          SpeakCapture.clear
          Camera.move(6, :step)
          line = SpeakCapture.lines.last
          assert_includes line, "rejilla"
          assert_equal 1, line.scan(named).length, "a name the tile's event and its puzzle point share is said once"
          assert_includes Text.tile_line(3, 1), "rejilla"
        end
        end
      end
      end
    end
  end

  test "every read of the game's input answers nothing while the camera is open, and the engine's once shut and let go" do
    with_camera(ROOM) do
      added = []
      reads = { :trigger? => [:trigger__access_orig, false], :press? => [:press__access_orig, false],
                :repeat? => [:repeat__access_orig, false], :triggerex? => [:triggerex__access_orig, false],
                :pressex? => [:pressex__access_orig, false], :dir4 => [:dir4__access_orig, 0], :dir8 => [:dir8__access_orig, 0] }
      PokeAccess::Remap::HELD_READS.each { |m, idle| reads[m] = [:"#{m.to_s.delete('?')}__access_orig", idle] }
      want = [:release?, :time?, :count, :repeatcount, :repeatex?, :releaseex?, :timeex?, :countex, :repeatcountex,
              :axis_triggerex?, :scroll_v, :trigger?, :press?, :repeat?, :triggerex?, :pressex?, :dir4, :dir8]
      assert_equal want.map { |m| m.to_s }.sort, reads.keys.map { |m| m.to_s }.sort, "every read mkxp-z and the dumps have"
      sc = Input.singleton_class
      begin
        PokeAccess::Remap::HELD_READS.each_key do |m|
          next if sc.method_defined?(m)
          added.push(m)
          Input.define_singleton_method(m) { |*_a| :engine }
        end
        src = Harness.source(File.join(Harness::ROOT, "core", "input", "remap.rb"))
        eval(src[src.index("\nbegin\n")..-1], TOPLEVEL_BINDING, "remap.rb loaded again")
        saved = reads.map { |_m, (orig, _idle)| [orig, Input.method(orig)] }
        reads.each_value { |orig, _idle| Input.define_singleton_method(orig) { |*_a| :engine } }
        Camera.open
        held = reads.map { |m, (_orig, idle)| [m, Input.send(m, 1) == idle && Input.send(m, 1) != :engine] }
        Camera.reset
        Camera.instance_variable_set(:@guard, false)
        free = reads.keys.reject { |m| [:dir4, :dir8].include?(m) }.map { |m| [m, Input.send(m, 1) == :engine] }
        assert_equal reads.keys.map { |m| [m, true] }, held
        assert_equal free.map { |m, _v| [m, true] }, free
      ensure
        (saved || []).each { |orig, meth| Input.define_singleton_method(orig, meth) }
        added.each do |m|
          ali = :"#{m.to_s.delete('?')}__access_orig"
          sc.send(:remove_method, m) if sc.method_defined?(m)
          sc.send(:remove_method, ali) if sc.method_defined?(ali)
        end
      end
    end
  end

  test "the hold on the game's input after shutting lasts while Enter or Escape is down, and goes once let go" do
    with_camera(ROOM) do
      kb = PokeAccess::Keyboard
      [Camera::VK_RETURN, Camera::VK_ESCAPE].each do |vk|
        down = [true]
        swapping(Input, :trigger__access_orig, proc { |*_a| true }) do
          swapping(kb, :down?, proc { |k| k == vk && down[0] }) do
            Camera.open
            Camera.close(nil)
            Camera.pulse
            guarded = Input.trigger?(Input::C)
            down[0] = false
            Camera.pulse
            assert_equal [false, true], [guarded, Input.trigger?(Input::C)], "held while #{vk} is down"
          end
        end
      end
    end
  end

  test "Alt+K opens and shuts it; inside, Escape, Enter, Shift+Enter, Backspace, Space, Shift+Space and the walk keys" do
    with_camera(ROOM) do
      keys = PokeAccess::Keys
      pressed = [nil]
      mods = [false, false]
      moves = []
      swapping(Camera, :hit?, proc { |vk| vk == pressed[0] }) do
        swapping(keys, :shift_down?, proc { mods[0] }) do
          swapping(keys, :ctrl_down?, proc { mods[1] }) do
            swapping(keys, :key, proc { |name| name == :camera && pressed[0] == :alt_k }) do
              pressed[0] = :alt_k
              Camera.tick
              opened = Camera.active?
              pressed[0] = Camera::VK_SPACE
              mods[0] = true
              Camera.tick
              said = SpeakCapture.lines.last
              pressed[0] = Camera::VK_RETURN
              Camera.tick
              started = !Camera.instance_variable_get(:@trail).nil?
              mods[0] = false
              pressed[0] = Camera::VK_BACK
              Camera.tick
              undo = SpeakCapture.lines.last
              pressed[0] = Camera::VK_SPACE
              Camera.tick
              home = SpeakCapture.lines.last
              pressed[0] = nil
              swapping(Camera, :move, proc { |d, how| moves.push([d, how]) }) do
                swapping(Camera, :direction, proc { 6 }) do
                  [[false, false], [true, false], [false, true]].each do |m|
                    mods[0], mods[1] = m
                    Camera.tick
                  end
                end
              end
              mods[0] = false
              mods[1] = false
              pressed[0] = Camera::VK_ESCAPE
              Camera.tick
              shut = Camera.active?
              assert_equal [true, true, false], [opened, started, shut]
              assert_equal T.t(:loc_nothing_selected), said, "Shift+Space with nothing selected"
              assert_equal [T.t(:cam_trail_empty), T.t(:cam_trail_busy)], [undo, home]
              assert_equal [[6, :step], [6, :long], [6, :through]], moves
              pressed[0] = :alt_k
              Camera.tick
              pressed[0] = Camera::VK_RETURN
              Camera.move(6, :step)
              Camera.tick
              assert_equal [false, :camera], [Camera.active?, PokeAccess::Locator.target.key], "Enter fixes the destination"
            end
          end
        end
      end
    end
  end

  test "the walk key read is the game's, pressed or repeating, whatever holds the input" do
    with_camera(ROOM) do
      Camera.open
      swapping(Input, :repeat__access_orig, proc { |b, *_r| b == Input::RIGHT }) do
        assert_equal 6, Camera.direction
      end
      swapping(Input, :repeat__access_orig, proc { |*_a| false }) { assert_nil Camera.direction }
    end
  end

  test "T and M with the camera open: the tile, over a puzzle's line, and where the camera is" do
    with_camera(ROOM) do
      swapping(PokeAccess::Puzzles, :info_line, proc { "linea del puzle" }) do
        closed = PokeAccess::Info.map_text
        Camera.open
        2.times { Camera.move(6, :step) }
        PokeAccess::Locator.refresh_info
        SpeakCapture.clear
        PokeAccess::Keys.info_key
        PokeAccess::Keys.coords_key
        assert_equal "linea del puzle", closed
        assert_equal [Text.tile_line(3, 1), Text.where_line(3, 1)], SpeakCapture.lines
      end
    end
  end

  test "each level of the camera's steps says its own: what stands there, the ground, the reach on foot" do
    with_camera(['#######',
                 '#@.#..#',
                 '#######']) do
      ev = TestEvent.new(1, "Estatua", 4, 1)
      $game_map.events[1] = ev
      $game_map.set_terrain(4, 1, 10)
      PokeAccess::World.reset!
      PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(4, 1), true)
      name = PokeAccess::Locator.target_name(ev)
      ground = T.t(PokeAccess::World::Terrain.label(4, 1))
      said = [:brief, :medium, :full].map do |level|
        swapping(PokeAccess::Verbosity, :level, proc { |_r| level }) do
          Camera.reset
          Camera.open
          Camera.move(6, :step)
          Camera.move(6, :through)
          SpeakCapture.clear
          Camera.move(6, :step)
          SpeakCapture.lines.last
        end
      end
      assert_equal [name, [name, ground].join(", "), [name, ground, T.t(:cam_unreachable)].join(", ")], said
    end
  end

  test "a destination with no way on foot is fixed too and says so, the guides ending beside it" do
    with_camera(['#######',
                 '#@.#..#',
                 '#######']) do
      loc = PokeAccess::Locator
      Camera.open
      Camera.move(6, :step)
      Camera.move(6, :through)
      Camera.move(6, :step)
      SpeakCapture.clear
      Camera.fix
      t = loc.target
      plan = loc.route_plan(t)
      assert_equal [:camera, [4, 1], false, :none], [t.key, [t.x, t.y], loc.onto?(t), plan.kind]
      assert_includes SpeakCapture.lines.last, PokeAccess::Routes::Text.listing(plan).sub(/\A, /, "")
    end
  end

  test "I from the camera searches from the camera's bridge level, and lends the walkers in the way" do
    with_camera(['##########',
                 '#@.......#',
                 '##########']) do
      loc = PokeAccess::Locator
      planner = PokeAccess::Routes::Planner
      npc = TestEvent.new(1, "Paseante", 5, 1)
      npc.blocking = true
      $game_map.events[1] = npc
      PokeAccess::World.reset!
      Camera.open
      2.times { Camera.move(6, :step) }
      Camera.instance_variable_set(:@level, 1)
      loc.instance_variable_set(:@target, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
      asked = nil
      real = planner.method(:plan_from)
      swapping(planner, :plan_from, proc { |*a| asked = a[2]; real.call(*a) }) { loc.announce_route }
      Camera.instance_variable_set(:@level, 0)
      plan = swapping(PokeAccess::Routes::Regions, :lendable_walkers, proc { [npc] }) do
        swapping(planner, :reach, proc { |*_a| [:yes, 0] }) { planner.plan_from(3, 1, 0, 8, 1, true) }
      end
      assert_equal [1, :walk, [6, 6, 6, 6, 6]], [asked, plan.kind, plan.route.to_a]
    end
  end

  test "a long move stops where what is said changes: into a zone, out of it, and past what its first tile leaves" do
    with_camera(LONG) do
      zone = proc { |x, y| y == 1 && x >= 3 && x <= 6 ? "a la vista" : (y == 1 && x == 9 ? "marca" : nil) }
      with_rules(:readers, [nil, zone]) do
        Camera.open
        stops = (1..4).map { Camera.move(6, :long); Camera.focus[0] }
        assert_equal [3, 7, 9, 16], stops
      end
    end
  end

  test "control lost while a trail is drawn says it is dropped as the camera shuts" do
    with_camera(ROOM) do
      Camera.open
      Camera.trail_toggle
      Camera.move(6, :step)
      SpeakCapture.clear
      PokeAccess::Events.emit(:control_lost, :message)
      assert_equal [[PokeAccess.sentences([T.t(:cam_trail_discarded), T.t(:cam_off)]), false]], SpeakCapture.log
    end
  end

  test "a map change with the camera open shuts it saying so, queued, the game's input held until the keys are let go" do
    with_camera(ROOM) do
      Camera.open
      SpeakCapture.clear
      PokeAccess::Events.emit(:map_changed, 7)
      held = Camera.blocking?
      Camera.pulse
      assert_equal [false, true, false], [Camera.active?, held, Camera.blocking?]
      assert_includes SpeakCapture.log, [T.t(:cam_off), false]
    end
  end

  test "Ctrl across a tile shut from this side alone says so, with its ground and reach, as the info key tells it" do
    with_camera(ROOM) do
      $game_map.set_terrain(3, 1, 3)
      $game_map.block_step(2, 1, 6)
      PokeAccess::World.reset!
      swapping(PokeAccess::Verbosity, :level, proc { |_r| :full }) do
        Camera.open
        Camera.move(6, :step)
        SpeakCapture.clear
        Camera.move(6, :through)
        line = SpeakCapture.lines.last
        assert_equal [3, 1], Camera.focus
        assert_includes line, T.t(:cam_shut_side)
        assert_includes line, T.t(:surf_sand)
        refute_includes line, T.t(:cam_unstandable)
        refute_includes Text.tile_line(3, 1), T.t(:cam_unstandable)
      end
    end
  end

  test "Shift+Space takes the level of the target's tile: none off every bridge, on one the player's walk there" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      $game_map.place_bridge(5, 1)
      PokeAccess::World.reset!
      levels = [[8, 1], [5, 1]].map do |x, y|
        tg = loc::SurfaceTarget.new(x, y, "sitio", :spot)
        swapping(loc, :ensure_target, proc { nil }) do
          swapping(loc, :target, proc { tg }) do
            Camera.reset
            Camera.open
            Camera.instance_variable_set(:@level, 1)
            Camera.to_target
            [Camera.focus, Camera.level]
          end
        end
      end
      assert_equal [[[8, 1], 0], [[5, 1], 0]], levels
    end
  end

  test "the fixed trail's progress is read again only when the player's state changes" do
    with_camera(ROOM) do
      Camera.open
      Camera.trail_toggle
      3.times { Camera.move(6, :step) }
      Camera.fix
      reads = 0
      trail = PokeAccess::Routes::Trail
      real = trail.method(:index_of)
      swapping(trail, :index_of, proc { |tiles, st| reads += 1; real.call(tiles, st) }) do
        3.times { Camera.track }
        $game_player.x = 2
        3.times { Camera.track }
      end
      assert_equal [2, 1], [reads, Camera.instance_variable_get(:@progress)]
    end
  end

  test "a full trail takes no tile it passes at another bridge level" do
    with_camera(ROOM) do
      Camera.open
      Camera.trail_toggle
      Camera.instance_variable_set(:@trail, [[2, 1, 0]] + (1..Camera::TRAIL_MAX).map { |i| [100 + i, 50, 0] })
      Camera.instance_variable_set(:@level, 1)
      SpeakCapture.clear
      Camera.move(6, :step)
      trail = Camera.instance_variable_get(:@trail)
      assert_equal [[1, 1], Camera::TRAIL_MAX + 1], [Camera.focus, trail.length]
      assert_equal [T.t(:cam_trail_full, :n => Camera::TRAIL_MAX)], SpeakCapture.lines
    end
  end

  test "afloat, the camera comes ashore and pushes off onto water again from there, as the player could" do
    with_camera(['#########',
                 '#@~..~~.#',
                 '#########']) do
      $game_player.x = 2
      $PokemonGlobal.surfing = true
      PokeAccess::World.reset!
      swapping(PokeAccess::FieldMoves, :can?, proc { |_m| true }) do
        Camera.open
        4.times { Camera.move(6, :step) }
        assert_equal [6, 1], Camera.focus
      end
    end
  ensure
    $PokemonGlobal.surfing = false
  end

  test "a tile reader whose owner names other maps is not asked here, and one naming this map is" do
    with_camera(ROOM) do
      moves = PokeAccess::Routes::Moves
      asked = []
      here = $game_map.map_id
      away = [moves.owner_of(:maps => [here + 1], :tiles => lambda { |_x, _y| asked.push(:tiles); true }),
              proc { |_x, _y| asked.push(:away); "lejos" }]
      near = [moves.owner_of(:maps => here), proc { |_x, _y| asked.push(:here); "cerca" }]
      with_rules(:readers, away) do
        with_rules(:readers, near) do
          assert_equal ["cerca"], Camera.tile_lines(2, 1)
        end
      end
      assert_equal [:here], asked
    end
  end

  test "opens only with control free on the map" do
    with_camera(ROOM) do
      PokeAccess::Control.hold(:spec_screen) { Camera.open }
      assert_equal [false, T.t(:cam_map_only)], [Camera.active?, SpeakCapture.lines.last]
    end
  end

  test "a slide, a carry or a run says where it ends from the tile left; a plain step says nothing" do
    move = Struct.new(:kind, :x, :y)
    loc = PokeAccess::Locator
    assert_equal T.t(:cam_slide, :where => loc.dir_phrase(4, 0)), Text.effect([2, 1], move.new(:slide, 6, 1), 6)
    assert_includes Text.effect([5, 5], move.new(:carry, 3, 2), 8), T.t(:dir_up), "a carry turning names both ways"
    assert_includes Text.effect([5, 5], move.new(:carry, 3, 2), 8), T.t(:dir_left)
    assert_nil Text.effect([2, 1], move.new(:step, 3, 1), 6)
  end

  test "a bump where the action button carries the player past, as a climb on a mount, says so after the wall" do
    with_camera(['#####',
                 '#@.##',
                 '#####']) do
      climb = proc { |x, y, d, on| x == 3 && y == 1 && d == 6 && !on ? [:carry, 2, 0, false, nil] : nil }
      swapping(PokeAccess::Routes::Effects, :act_at, climb) do
        Camera.open
        Camera.move(6, :step)
        SpeakCapture.clear
        Camera.move(6, :step)
        assert_equal [T.t(:cam_wall), T.t(:loc_act_route)].join(", "), SpeakCapture.lines.last
        assert_equal [2, 1], Camera.focus, "the camera stays: only the player's press climbs"
      end
      swapping(PokeAccess::Routes::Effects, :act_at, proc { |_x, _y, _d, _on| nil }) do
        Camera.home
        Camera.move(6, :step)
        SpeakCapture.clear
        Camera.move(8, :step)
        assert_equal T.t(:cam_wall), SpeakCapture.lines.last, "a plain wall"
      end
    end
  end

  test "names a silent control the puzzles category lists by itself on the camera's tile" do
    with_camera(ROOM) do
      loc = PokeAccess::Locator
      drawn = [loc::SurfaceTarget.new(4, 1, "baldosa pisada", :puzzle_control, 7)]
      swapping(PokeAccess::World::Mechanics, :instances, proc { [] }) do
        swapping(PokeAccess::Puzzles::Auto, :targets, proc { drawn }) do
          assert_equal ["baldosa pisada"], PokeAccess::Puzzles.names_at(4, 1)
          assert_equal [], PokeAccess::Puzzles.names_at(3, 1)
          assert_includes Text.tile_line(4, 1), "baldosa pisada"
        end
      end
    end
  end

  private

  # Runs the block on a grid map with the guides' state, the camera forgotten before and after.
  def with_camera(rows)
    with_guide_state do |loc|
      hpa_fresh_grid(rows)
      Camera.reset
      SpeakCapture.clear
      yield loc
    end
  ensure
    Camera.reset
  end

  # Runs the block with a rule added to the camera's list (:readers), taken off after.
  def with_rules(list, rule)
    rules = Camera.instance_variable_get(:"@#{list}")
    rules.push(rule)
    yield
  ensure
    rules.delete(rule)
  end

  # The block's value with mod's own method meth answering as body does, the method put back after.
  def swapping(mod, meth, body)
    sc = mod.singleton_class
    saved = :"camera_test_saved_#{meth.to_s.delete('?!')}"
    sc.send(:alias_method, saved, meth)
    mod.define_singleton_method(meth, &body)
    yield
  ensure
    if sc && sc.method_defined?(saved)
      sc.send(:alias_method, meth, saved)
      sc.send(:remove_method, saved)
    end
  end
end
