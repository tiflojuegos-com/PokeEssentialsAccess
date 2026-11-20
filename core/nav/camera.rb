module PokeAccess
  # The free camera (Alt+K): a tile of the map the mod listens and reads from, moved by the game's walk keys while the
  # game's input reads as released, from which a destination or a trail is fixed for the guides. It never moves the
  # player and writes nothing of the game's.
  module Camera
    # Map frames the camera stands still before the soundscape reads the scene from it again.
    STILL_FRAMES = 8
    # The most tiles a long move (Shift with a direction) goes.
    LONG_MAX = 10
    # The most steps a trail holds.
    TRAIL_MAX = 300
    # The keys the camera answers besides the walk keys: Backspace, Enter, Escape and Space.
    VK_BACK = 0x08
    VK_RETURN = 0x0D
    VK_ESCAPE = 0x1B
    VK_SPACE = 0x20
    # The game's direction buttons, by direction code, in the order they are asked.
    DIR_BUTTONS = [[2, :DOWN], [4, :LEFT], [6, :RIGHT], [8, :UP]]
    # What says why a trail stretch is not taken, by its kind (Routes::Trail).
    WHY_KEYS = { :blocked => :cam_why_blocked, :exit => :cam_why_exit, :warp => :cam_why_warp, :carried => :cam_why_carried,
                 :company => :loc_surf_company, :cut => :loc_route_gave_up }

    @active = false
    @lent = 0
    @guard = false
    @serial = 0
    @readers = []

    # True while the camera is open.
    def self.active?; @active; end

    # The tile the mod listens and reads from, [x, y]: the camera's while it is open, else the player's; nil with no
    # player.
    def self.focus
      return [@x, @y] if @active
      $game_player ? [$game_player.x, $game_player.y] : nil
    end

    # The camera's bridge level while it is open (0 or 1, as Guide.player_state), else the player's.
    def self.level
      return flat(@level) if @active
      $game_player ? PokeAccess::Guide.player_state[2] : 0
    end

    # True unless the camera moved within the last STILL_FRAMES map frames: only then does the soundscape read the scene
    # from it again.
    def self.still?
      !@active || PokeAccess::Frame.serial - @moved.to_i >= STILL_FRAMES
    end

    # True while the game's input reads as released: the camera open, or just shut with the key it was shut by or a
    # direction still down (pulse), the mod on, its menu shut and nothing lent (lend).
    def self.blocking?
      return false unless (@active || @guard) && @lent == 0
      (PokeAccess::Keys.enabled rescue true) && !PokeAccess::ConfigMenu.active?
    end

    # Runs the block with the game's input answering as if the camera were shut, the camera kept open if control is lost
    # meanwhile (a text field over the map); the mod's own menu keeps it open too, its input free while it is open.
    def self.lend
      @lent += 1
      yield
    ensure
      @lent -= 1
    end

    # True while lend runs.
    def self.lent?; @lent > 0; end

    # Each pulse: lifts the hold on the game's input once Enter, Escape and every direction are let go after shutting.
    def self.pulse
      return unless @guard
      kb = PokeAccess::Keyboard
      held = kb.down?(VK_RETURN) || kb.down?(VK_ESCAPE) || lend { (Input.dir4 rescue 0) != 0 }
      @guard = false unless held
    end

    # The map frame's :camera step: the fixed trail's progress follows the player (track); Alt+K opens or shuts the
    # camera; open, its keys move and fix it.
    def self.tick
      track
      return unless PokeAccess::Keys.focused?
      return toggle if PokeAccess::Keys.key(:camera)
      keys if @active
    end

    # Alt+K: opens the camera on the player's tile, or shuts it.
    def self.toggle
      @active ? close(shut_line) : open
    end

    # Opens the camera on the player's tile, only on the map with control free and nothing carrying the player.
    def self.open
      c = PokeAccess::Control
      return say(PokeAccess::I18n.t(:cam_map_only)) unless $game_player && c.on_map? && c.free? && c.keys? && !c.carried?
      st = PokeAccess::Guide.player_state
      @active = true
      @trail = nil
      @hop = nil
      @fx_end = nil
      place(st[0], st[1], st[2], false)
      say(PokeAccess::I18n.t(:cam_on))
    end

    # Shuts the camera, dropping a trail being drawn: the game's input stays held until the keys are let go (pulse), the
    # listener goes back to the player and line is said, cutting in with cut; nothing with nil.
    def self.close(line = nil, cut = true)
      return unless @active
      @active = false
      @trail = nil
      @guard = true
      PokeAccess::Sound.follow_focus
      PokeAccess.speak(line, cut) if line && !line.empty?
    end

    # What shutting says: the trail being drawn dropped, then the camera shut.
    def self.shut_line
      t = PokeAccess::I18n
      PokeAccess.sentences([@trail ? t.t(:cam_trail_discarded) : nil, t.t(:cam_off)].compact)
    end

    # The keys while open: Escape shuts; Enter fixes, with Shift starts or drops a trail; Backspace takes a trail step
    # back; Space goes to the player, with Shift to the selected target; a walk key moves, with Ctrl through, with Shift
    # far (long).
    def self.keys
      k = PokeAccess::Keys
      shift = k.shift_down?
      if hit?(VK_ESCAPE)
        close(shut_line)
      elsif hit?(VK_RETURN)
        shift ? trail_toggle : fix
      elsif hit?(VK_BACK)
        undo
      elsif hit?(VK_SPACE)
        shift ? to_target : home
      else
        d = direction
        move(d, k.ctrl_down? ? :through : (shift ? :long : :step)) if d
      end
    end

    # True on the frame a key goes down.
    def self.hit?(vk)
      PokeAccess::Remap.code_pressed?(vk)
    end

    # The walk key the game reads this frame, pressed or repeating on the game's own schedule, as a direction code, or
    # nil: the engine's keys, mkxp-z's bindings, the mod's and a game's own Ruby input alike.
    def self.direction
      lend do
        hit = DIR_BUTTONS.detect { |_d, b| Input.const_defined?(b) && (Input.repeat?(Input.const_get(b)) rescue false) }
        hit ? hit[0] : nil
      end
    end

    # The tile one step from (x, y) toward d.
    def self.ahead(x, y, d)
      dd = PokeAccess::DIR_DELTA[d] || [0, 0]
      [x + dd[0], y + dd[1]]
    end

    # One move toward d: :step and :through one tile, the first only where the player could press that way, the second
    # whatever stands there; :long on to the next change (long).
    def self.move(d, how)
      return long(d) if how == :long
      from = [@x, @y]
      prev = @label
      r = advance(d, how == :through)
      return blocked(d) unless r
      footstep
      say(PokeAccess.sentences([r[0], step_line(from, prev, r[1], d, r[2])].compact))
    end

    # A long move (Shift): tile by tile while the way is open, up to the first tile that changes (what is said of it,
    # another ground, a move that jumps or slides, a side opening or closing past the first tile) or LONG_MAX; says how
    # far, then the line of the tile it stops on.
    def self.long(d)
      n = 0
      cut = nil
      sides = nil
      last = nil
      said = PokeAccess::CameraText.parts(@x, @y)
      while n < LONG_MAX
        from = [@x, @y]
        prev = @label
        r = advance(d, false)
        break unless r
        n += 1
        cut = r[0] || cut
        last = [from, prev, r[1], r[2]]
        now = sides_of(@x, @y, d)
        told = PokeAccess::CameraText.parts(@x, @y)
        break if changed?(prev, r[1], [said, told], now, sides)
        said = told
        sides = now
      end
      return blocked(d) if n == 0
      footstep
      line = step_line(last[0], last[1], last[2], d, last[3])
      say(PokeAccess.sentences([cut, PokeAccess::I18n.t(:cam_jump, :n => n), line].compact))
    end

    # Whether a long move stops on the camera's tile, reached by st from ground prev: what is said of it other than of
    # the tile before (talk, [before, now]; the first tile falling silent goes on, one thing left behind), another
    # ground, a move that is no plain step, or its sides opening or closing against the tile before (sides; nil on the
    # first).
    def self.changed?(prev, st, talk, now, sides)
      return true if talk[0] != talk[1] && (!talk[1].empty? || !sides.nil?)
      return true if @label != prev
      return true if st && st.kind != :walk
      !sides.nil? && now != sides
    end

    # Whether the player could step off (x, y) to each side of d, as [one side, the other].
    def self.sides_of(x, y, d)
      ways = d == 2 || d == 8 ? [4, 6] : [2, 8]
      ways.map { |w| PokeAccess::World::Probe.step?(x, y, w) }
    end

    # Takes the camera one tile toward d, through what stands there with through: [the trail's cut line or nil, the
    # player's move that way or nil, whether the tile was crossed]; nil when it cannot go (off the map, a full trail, the
    # player's way shut without through).
    def self.advance(d, through)
      nx, ny = ahead(@x, @y, d)
      return nil if PokeAccess::World::Terrain.outside?(nx, ny)
      st = opening(d)
      return nil if (st.nil? && !through) || full?(nx, ny, st ? st.level : @level)
      @hop = st && st.kind == :jump && (st.x != nx || st.y != ny) ? [st.x, st.y, st] : nil
      [place(nx, ny, st ? st.level : @level), st, st.nil?]
    end

    # The move the player would make pressing d from the camera's tile, or nil: the second half of a ledge hop taken
    # from its ledge, else the replay's moves, pushing off onto water where the player may surf (Pathfinder.may_surf?:
    # afloat, from ground the camera has come ashore on), and off water on foot.
    def self.opening(d)
      nx, ny = ahead(@x, @y, d)
      return @hop[2] if @hop && @hop[0] == nx && @hop[1] == ny
      moves = PokeAccess::Routes::Moves
      plain = PokeAccess::Pathfinder.replay_mode
      st = PokeAccess::Pathfinder.may_surf?(@x, @y) ? moves.try(@x, @y, @level, d, plain | moves::SURF_PLAN) : nil
      st || moves.try(@x, @y, @level, d, plain)
    end

    # Puts the camera on (x, y) at bridge level lvl, the listener with it before anything sounds there; with rec, the
    # trail takes the tile and level: its cut line, or nil.
    def self.place(x, y, lvl, rec = true)
      @x = x
      @y = y
      @level = lvl
      @moved = PokeAccess::Frame.serial
      @label = PokeAccess::CameraText.surface(x, y)
      @bump = nil
      PokeAccess::Sound.follow_focus
      rec ? record(x, y, flat(lvl)) : nil
    end

    # A bridge level as the guide keeps the player's: 1 on a bridge, whatever ramp step set it, else 0.
    def self.flat(lvl); lvl.to_i > 0 ? 1 : 0; end

    # The line of a step onto the camera's tile from the tile from, whose ground was prev, by the player's move st that
    # way (nil when crossed): what it does said once per landing.
    def self.step_line(from, prev, st, d, crossed)
      fresh = st && (st.x != @x || st.y != @y) && [st.x, st.y] != @fx_end
      @fx_end = fresh ? [st.x, st.y] : (st && st.x == @x && st.y == @y ? nil : @fx_end)
      PokeAccess::CameraText.step_line(@x, @y, from, prev, fresh ? st : nil, d, crossed)
    end

    # The ground's step on the camera's tile, where it stands: water, grass or the ground.
    def self.footstep
      t = PokeAccess::World::Terrain
      id = t.water?(@x, @y) ? :fstep_water : (t.grass?(@x, @y) ? :grass : :step)
      PokeAccess::Sound.cue(id, :at => [@x, @y])
    end

    # Why a move toward d did not go: the map's edge, a full trail, or what stands in the way.
    def self.blocked(d)
      nx, ny = ahead(@x, @y, d)
      return bump(d, PokeAccess::CameraText.edge_line(@x, @y, d)) if PokeAccess::World::Terrain.outside?(nx, ny)
      st = opening(d)
      return say(PokeAccess::I18n.t(:cam_trail_full, :n => TRAIL_MAX)) if full?(nx, ny, st ? st.level : @level)
      text = PokeAccess::CameraText
      bump(d, [text.blocked_line(nx, ny), text.act_line(@x, @y, d)].compact.join(", "))
    end

    # What stops a move toward d: the wall's sound that way (the interact sound before something to use), again once per
    # cooldown while the key is held, and line once per push.
    def self.bump(d, line)
      key = [@x, @y, d]
      now = PokeAccess.clock
      fresh = @bump.nil? || @bump[0] != key
      return if !fresh && now - @bump[1] < PokeAccess::Sound::Feedback.cooldown
      @bump = [key, now]
      nx, ny = ahead(@x, @y, d)
      ev = PokeAccess::Control.event_at(nx, ny)
      usable = ev && (PokeAccess::Locator.interactable?(ev) rescue false)
      PokeAccess::Sound.cue(usable ? :interact : :wall, :dir => d, :at => [@x, @y])
      say(line) if fresh
    end

    # Space: the camera back on the player's tile; not while a trail is drawn.
    def self.home
      return say(PokeAccess::I18n.t(:cam_trail_busy)) if @trail
      st = PokeAccess::Guide.player_state
      @hop = nil
      place(st[0], st[1], st[2], false)
      say(PokeAccess::I18n.t(:cam_home))
    end

    # Shift+Space: the camera on the locator's selected target; not while a trail is drawn.
    def self.to_target
      t = PokeAccess::I18n
      return say(t.t(:cam_trail_busy)) if @trail
      loc = PokeAccess::Locator
      loc.ensure_target
      tg = loc.target
      return say(t.t(:loc_nothing_selected)) if tg.nil? || PokeAccess::World::Terrain.outside?(tg.x, tg.y)
      @hop = nil
      place(tg.x, tg.y, level_on(tg), false)
      footstep
      say(t.t(:cam_to_target, :name => loc.target_name(tg)))
    end

    # The bridge level the camera takes on the tile of the locator's target tg: 0 off every bridge; on one, the level
    # the player's walk there ends at (Locator.route_plan; theirs with nothing to walk), else the camera's own.
    def self.level_on(tg)
      return 0 unless PokeAccess::World::Terrain.bridge_at?(tg.x, tg.y)
      plan = PokeAccess::Locator.route_plan(tg)
      return @level unless plan.kind == :walk && plan.route
      st = PokeAccess::Guide.player_state
      ends = PokeAccess::Routes::Moves.trace(st[0], st[1], st[2], plan.route, PokeAccess::Pathfinder.replay_mode).last
      ends ? flat(ends.level) : st[2]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      @level
    end

    # Shift+Enter: starts a trail on the camera's tile, or drops the one being drawn.
    def self.trail_toggle
      t = PokeAccess::I18n
      if @trail
        @trail = nil
        return say(t.t(:cam_trail_discarded))
      end
      @trail = [[@x, @y, flat(@level)]]
      st = PokeAccess::Guide.player_state
      x = @x
      y = @y
      dx = x - st[0]
      dy = y - st[1]
      return say(t.t(:cam_trail_start)) if dx == 0 && dy == 0
      say(t.t(:cam_trail_start_far, :dirs => PokeAccess::Locator.dir_phrase(dx, dy)))
    end

    # Adds a tile at bridge level lvl to the trail being drawn, cutting it back to that tile when it already passes there
    # at that level: the line saying so, or nil.
    def self.record(x, y, lvl)
      return nil unless @trail
      i = @trail.index([x, y, lvl])
      unless i
        @trail.push([x, y, lvl])
        return nil
      end
      @trail = @trail[0..i]
      PokeAccess::I18n.t(:cam_trail_cut, :n => @trail.length - 1)
    end

    # True when a trail being drawn holds TRAIL_MAX steps and (x, y) at bridge level lvl is not on it, as record keeps
    # its tiles.
    def self.full?(x, y, lvl)
      !@trail.nil? && @trail.length > TRAIL_MAX && !@trail.include?([x, y, flat(lvl)])
    end

    # Backspace: takes the trail's last step back, the camera with it.
    def self.undo
      t = PokeAccess::I18n
      return say(t.t(:cam_trail_empty)) if @trail.nil? || @trail.length < 2
      from = [@x, @y]
      prev = @label
      @trail.pop
      @hop = nil
      last = @trail[-1]
      place(last[0], last[1], last[2], false)
      footstep
      say(PokeAccess.sentences([t.t(:cam_trail_undo, :n => @trail.length - 1), step_line(from, prev, nil, nil, false)]))
    end

    # Enter: the camera's tile as the destination (a trail being drawn, the trail), selected for the guides, the route
    # said and the camera shut; one with no way on foot is fixed too and says so.
    def self.fix
      return fix_trail if @trail
      t = PokeAccess::I18n
      st = PokeAccess::Guide.player_state
      return say(t.t(:cam_dest_here)) if st[0] == @x && st[1] == @y
      @serial += 1
      dest = PokeAccess::Locator::SurfaceTarget.new(@x, @y, t.t(:cam_dest_name), :camera, @serial)
      @dest_onto = PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(@x, @y))[0] != :no
      @dest = dest
      close(nil)
      PokeAccess::Locator.pick(dest)
      plan = PokeAccess::Locator.route_plan(dest)
      say(PokeAccess.sentences([t.t(:cam_dest_set, :steps => PokeAccess::Routes::Text.listing(plan)), t.t(:cam_off)]))
    end

    # Enter on a trail: fixes it as the trail target on its last tile, selected for the guides; says the camera's legs,
    # the presses the player makes, what is gone round or where it is cut, and the camera shut.
    def self.fix_trail
      t = PokeAccess::I18n
      tiles = @trail
      return say(t.t(:cam_trail_empty)) if tiles.length < 2
      dirs = (1...tiles.length).map { |i| PokeAccess::Routes::Trail.dir_between(tiles[i - 1], tiles[i]) }
      @serial += 1
      last = tiles[-1]
      target = PokeAccess::Locator::SurfaceTarget.new(last[0], last[1], t.t(:cam_trail_name), :trail, @serial)
      @trail_target = target
      @trail_tiles = tiles
      @tracked = nil
      @progress = PokeAccess::Routes::Trail.index_of(tiles, PokeAccess::Guide.player_state) == 0 ? 0 : nil
      @trail_stats = nil
      close(nil)
      PokeAccess::Locator.pick(target)
      plan = PokeAccess::Locator.route_plan(target)
      say(PokeAccess.sentences([PokeAccess::CameraText.trail_line(dirs, plan), t.t(:cam_off)]))
    end

    # The camera's targets on this map: the destination and the trail, while fixed.
    def self.targets
      [@dest, @trail_target].compact
    end

    # True for a destination or a trail target of the camera's.
    def self.target?(t)
      t.is_a?(PokeAccess::Locator::SurfaceTarget) && (t.key == :camera || t.key == :trail)
    end

    # True while the camera's target t is still the one fixed on this map.
    def self.holds?(t)
      own = t.key == :camera ? @dest : @trail_target
      !own.nil? && own.ref == t.ref
    end

    # True for a camera target the guides end on: a trail always, a destination the player can stand on.
    def self.onto?(t)
      t.key == :trail || @dest_onto ? true : false
    end

    # Each map frame with a trail fixed and the player's state changed since the last: its progress moves on to the
    # farthest trail tile the player has stood on, once they stood on its first.
    def self.track
      return unless @trail_tiles && $game_player
      st = PokeAccess::Guide.player_state
      return if st == @tracked
      @tracked = st
      i = PokeAccess::Routes::Trail.index_of(@trail_tiles, st)
      return if i.nil? || (@progress.nil? && i != 0)
      @progress = i if @progress.nil? || i > @progress
    end

    # The way along the fixed trail for its target (Routes::Trail.plan), its progress kept; nil for any other target.
    def self.plan(t)
      return nil unless target?(t) && t.key == :trail && holds?(t)
      made, @progress = PokeAccess::Routes::Trail.plan(@trail_tiles, @progress, t.ref)
      @trail_stats = made.stats
      made
    end

    # What the guides say arriving along the trail: its end, or where and why it is cut; nil for any other target.
    def self.arrived_line(t)
      return nil unless target?(t) && t.key == :trail && @trail_tiles
      i = PokeAccess::I18n
      st = PokeAccess::Guide.player_state
      why = (@trail_stats || {})[:trail_cut]
      last = @trail_tiles[-1]
      return i.t(:cam_trail_end) if why.nil? || (st[0] == last[0] && st[1] == last[1])
      i.t(:cam_trail_stop_here, :why => i.t(WHY_KEYS[why]))
    end

    # Registers what the camera says of the tiles of owner (as a terrain rule's, Routes::Moves.owns?): the block gets x
    # and y and answers a line, a list of them, or nil; said as the camera steps there and with the info key.
    def self.tile_reader(owner = nil, &blk)
      @readers.push([PokeAccess::Routes::Moves.owner_of(owner), blk])
    end

    # What the tile readers say of (x, y), each a line; a reader that fails is logged once and left out.
    def self.tile_lines(x, y)
      out = []
      @readers.each do |own, blk|
        next unless PokeAccess::Routes::Moves.owns?(own, x, y)
        begin
          [blk.call(x, y)].flatten.each { |v| out.push(v.to_s) if v && !v.to_s.empty? }
        rescue StandardError => e
          PokeAccess.log_once("camera_reader", e)
        end
      end
      out
    end

    # Says a line, cutting in; nothing for an empty one.
    def self.say(line)
      PokeAccess.speak(line, true) if line && !line.to_s.empty?
      nil
    end

    # Forgets the camera and its targets: run on a map change. A camera still open (a transfer no loss of control came
    # before, as a parallel event's) shuts as close does, its line queued after what the game says, the game's input
    # held until the keys are let go.
    def self.reset
      if @active
        close(shut_line, false)
      else
        @guard = false
      end
      @trail = nil
      @hop = nil
      @dest = nil
      @trail_target = nil
      @trail_tiles = nil
      @trail_stats = nil
      @tracked = nil
    end
  end
end

PokeAccess::Frame.each_pulse { PokeAccess::Camera.pulse }
PokeAccess::Events.on(:control_lost) do |reason|
  unless PokeAccess::Camera.lent? || reason == :mod_menu
    PokeAccess::Camera.close(PokeAccess::Camera.shut_line, false)
  end
end
PokeAccess::Caches.register(:camera) { PokeAccess::Camera.reset }
PokeAccess::Camera.tile_reader { |x, y| PokeAccess::Puzzles.names_at(x, y) }
PokeAccess::Info.map_owner(:camera, true) do
  at = PokeAccess::Camera.active? ? PokeAccess::Camera.focus : nil
  at ? PokeAccess::CameraText.tile_line(at[0], at[1]) : nil
end
