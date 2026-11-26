# Citae Prisma (map 896), the mirror room of Necrozma's errand (x 17 to 28, y 60 to 68): in the dark (switch 1900) the
# prism (events 70 and 71) fires four lights (66 to 69) that RebornScripts.rb turns at the mirrors and Serra (72) and
# that die off the box, on a rock, a mirror's back or a crystal; four lit as they die open the door (1895).
module PokeAccess
  module RebornPrisma
    MAP = 896
    FIRING = 1882
    DARK = 1900
    LUNA_MET = 1902
    DOOR = 1895
    STORY = 725
    LIGHTS = { 69 => 8, 67 => 4, 66 => 2, 68 => 6 }
    MIRRORS = { 75 => :rbrf_face_sw, 74 => :rbrf_face_ne, 73 => :rbrf_face_nw }
    FIXED = { [17, 61] => :rbrf_face_se, [17, 67] => :rbrf_face_ne, [28, 67] => :rbrf_face_nw }
    # The crystals: [switch, colour, event, tile]. Used, blue opens the north and east bridge (1891), green lets rocks
    # break (1892), red swaps the red rocks (1893), purple sends each mirror back where Luna last saw it (variables 731
    # to 738); each firing puts out all but the purple.
    CRYSTALS = [[1887, :blue, 76, [18, 60]], [1888, :green, 78, [18, 68]], [1889, :red, 77, [27, 60]],
                [1890, :purple, 79, [27, 68]]]
    BOX_ROCKS = [80, 107, 108, 109]
    EAST_ROCKS = [96, 97]
    WEST_ROCK = 98
    ALL_ROCKS = [80, 107, 108, 109, 96, 97, 98]
    RED_ROCKS = [110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 130, 131, 146]
    OUTLINES = [142, 143, 144, 145]
    ORBS = [138, 139, 140]
    OUTLINE_SPOTS = { 75 => [18, 66], 74 => [17, 66] }
    STEPS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # Per goal, its legs: where the mirrors stand as the leg starts, and each push as [event, x, y, way, stand x, stand y].
    LEGS = {
      :a_blue => [
        [{ 75 => [20, 61] },
         [[75, 20, 61, 6, 19, 61], [75, 21, 61, 6, 20, 61], [75, 22, 61, 8, 22, 62]]]
      ],
      :b_purple => [
        [{ 74 => [25, 61], 75 => [20, 61] },
         [[75, 20, 61, 2, 20, 60], [75, 20, 62, 2, 20, 61], [75, 20, 63, 6, 19, 63], [75, 21, 63, 6, 20, 63],
          [75, 22, 63, 6, 21, 63], [75, 23, 63, 6, 22, 63], [75, 24, 63, 6, 23, 63], [75, 25, 63, 2, 25, 62],
          [75, 25, 64, 6, 24, 64], [75, 26, 64, 6, 25, 64]]],
        [{ 74 => [25, 61], 75 => [22, 60] },
         [[75, 22, 60, 2, 22, 59], [75, 22, 61, 2, 22, 60], [75, 22, 62, 2, 22, 61], [75, 22, 63, 6, 21, 63],
          [75, 23, 63, 6, 22, 63], [75, 24, 63, 6, 23, 63], [75, 25, 63, 2, 25, 62], [75, 25, 64, 6, 24, 64],
          [75, 26, 64, 6, 25, 64]]],
        [{ 74 => [17, 66], 75 => [18, 66] },
         [[75, 18, 66, 8, 18, 67], [75, 18, 65, 8, 18, 66], [75, 18, 64, 6, 17, 64], [75, 19, 64, 6, 18, 64],
          [75, 20, 64, 8, 20, 65], [75, 20, 63, 6, 19, 63], [75, 21, 63, 6, 20, 63], [75, 22, 63, 6, 21, 63],
          [75, 23, 63, 6, 22, 63], [75, 24, 63, 6, 23, 63], [75, 25, 63, 2, 25, 62], [75, 25, 64, 6, 24, 64],
          [75, 26, 64, 6, 25, 64]]]
      ],
      :b_save => [
        [{ 74 => [25, 61], 75 => [20, 61] },
         [[75, 20, 61, 2, 20, 60], [75, 20, 62, 2, 20, 61], [75, 20, 63, 2, 20, 62], [75, 20, 64, 2, 20, 63],
          [75, 20, 65, 2, 20, 64], [75, 20, 66, 4, 21, 66], [75, 19, 66, 4, 20, 66], [74, 25, 61, 2, 25, 60],
          [74, 25, 62, 2, 25, 61], [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63], [74, 23, 63, 4, 24, 63],
          [74, 22, 63, 4, 23, 63], [74, 21, 63, 4, 22, 63], [74, 20, 63, 4, 21, 63], [74, 19, 63, 2, 19, 62],
          [74, 19, 64, 4, 20, 64], [74, 18, 64, 4, 19, 64], [74, 17, 64, 2, 17, 63], [74, 17, 65, 2, 17, 64]]],
        [{ 74 => [25, 61], 75 => [22, 60] },
         [[75, 22, 60, 2, 22, 59], [75, 22, 61, 2, 22, 60], [75, 22, 62, 2, 22, 61], [75, 22, 63, 4, 23, 63],
          [75, 21, 63, 4, 22, 63], [75, 20, 63, 2, 20, 62], [75, 20, 64, 2, 20, 63], [75, 20, 65, 2, 20, 64],
          [75, 20, 66, 4, 21, 66], [75, 19, 66, 4, 20, 66], [74, 25, 61, 2, 25, 60], [74, 25, 62, 2, 25, 61],
          [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63], [74, 23, 63, 4, 24, 63], [74, 22, 63, 4, 23, 63],
          [74, 21, 63, 4, 22, 63], [74, 20, 63, 4, 21, 63], [74, 19, 63, 2, 19, 62], [74, 19, 64, 4, 20, 64],
          [74, 18, 64, 4, 19, 64], [74, 17, 64, 2, 17, 63], [74, 17, 65, 2, 17, 64]]],
        [{ 74 => [25, 61], 75 => [27, 64] },
         [[75, 27, 64, 2, 27, 63], [75, 27, 65, 2, 27, 64], [75, 27, 66, 4, 28, 66], [75, 26, 66, 4, 27, 66],
          [75, 25, 66, 4, 26, 66], [75, 24, 66, 4, 25, 66], [75, 23, 66, 4, 24, 66], [75, 22, 66, 4, 23, 66],
          [75, 21, 66, 4, 22, 66], [75, 20, 66, 4, 21, 66], [75, 19, 66, 4, 20, 66], [74, 25, 61, 2, 25, 60],
          [74, 25, 62, 2, 25, 61], [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63], [74, 23, 63, 4, 24, 63],
          [74, 22, 63, 4, 23, 63], [74, 21, 63, 4, 22, 63], [74, 20, 63, 4, 21, 63], [74, 19, 63, 2, 19, 62],
          [74, 19, 64, 4, 20, 64], [74, 18, 64, 4, 19, 64], [74, 17, 64, 2, 17, 63], [74, 17, 65, 2, 17, 64]]]
      ],
      :b_fire => [
        [{ 74 => [17, 66], 75 => [18, 66] },
         [[75, 18, 66, 8, 18, 67], [75, 18, 65, 8, 18, 66], [75, 18, 64, 6, 17, 64], [75, 19, 64, 6, 18, 64],
          [75, 20, 64, 8, 20, 65], [75, 20, 63, 8, 20, 64], [75, 20, 62, 6, 19, 62], [75, 21, 62, 6, 20, 62],
          [75, 22, 62, 8, 22, 63], [74, 17, 66, 6, 16, 66], [74, 18, 66, 6, 17, 66]]],
        [{ 74 => [17, 66], 75 => [27, 64] },
         [[75, 27, 64, 4, 28, 64], [75, 26, 64, 4, 27, 64], [75, 25, 64, 4, 26, 64], [75, 24, 64, 8, 24, 65],
          [75, 24, 63, 8, 24, 64], [75, 24, 62, 4, 25, 62], [75, 23, 62, 4, 24, 62], [75, 22, 62, 8, 22, 63],
          [74, 17, 66, 6, 16, 66], [74, 18, 66, 6, 17, 66]]]
      ],
      :b_fire2 => [
        [{ 74 => [17, 66], 75 => [27, 64] },
         [[75, 27, 64, 4, 28, 64], [75, 26, 64, 4, 27, 64], [75, 25, 64, 4, 26, 64], [75, 24, 64, 8, 24, 65],
          [75, 24, 63, 8, 24, 64], [75, 24, 62, 4, 25, 62], [75, 23, 62, 4, 24, 62], [75, 22, 62, 8, 22, 63],
          [74, 17, 66, 6, 16, 66], [74, 18, 66, 8, 18, 67], [74, 18, 65, 8, 18, 66]]],
        [{ 74 => [25, 61], 75 => [27, 64] },
         [[75, 27, 64, 4, 28, 64], [75, 26, 64, 4, 27, 64], [75, 25, 64, 4, 26, 64], [75, 24, 64, 8, 24, 65],
          [75, 24, 63, 8, 24, 64], [75, 24, 62, 4, 25, 62], [75, 23, 62, 4, 24, 62], [75, 22, 62, 8, 22, 63],
          [74, 25, 61, 2, 25, 60], [74, 25, 62, 2, 25, 61], [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63],
          [74, 23, 63, 4, 24, 63], [74, 22, 63, 4, 23, 63], [74, 21, 63, 4, 22, 63], [74, 20, 63, 2, 20, 62],
          [74, 20, 64, 4, 21, 64], [74, 19, 64, 4, 20, 64]]],
        [{ 74 => [25, 61], 75 => [20, 61] },
         [[75, 20, 61, 6, 19, 61], [75, 21, 61, 6, 20, 61], [74, 25, 61, 2, 25, 60], [74, 25, 62, 2, 25, 61],
          [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63], [74, 23, 63, 4, 24, 63], [74, 22, 63, 4, 23, 63],
          [74, 21, 63, 4, 22, 63], [74, 20, 63, 2, 20, 62], [74, 20, 64, 4, 21, 64], [74, 19, 64, 4, 20, 64]]]
      ],
      :c_red => [
        [{ 73 => [26, 66], 74 => [17, 66], 75 => [18, 66] },
         [[73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67], [73, 27, 65, 8, 27, 66]]],
        [{ 73 => [26, 66], 74 => [25, 61], 75 => [20, 61] },
         [[73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67], [73, 27, 65, 8, 27, 66]]]
      ],
      :c_red_green => [
        [{ 73 => [26, 66], 74 => [17, 66], 75 => [18, 66] },
         [[75, 18, 66, 8, 18, 67], [75, 18, 65, 8, 18, 66], [75, 18, 64, 8, 18, 65], [75, 18, 63, 8, 18, 64],
          [75, 18, 62, 8, 18, 63], [74, 17, 66, 6, 16, 66], [74, 18, 66, 8, 18, 67], [74, 18, 65, 8, 18, 66],
          [74, 18, 64, 4, 19, 64], [73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67], [73, 27, 65, 8, 27, 66]]],
        [{ 73 => [26, 66], 74 => [25, 61], 75 => [20, 61] },
         [[74, 25, 61, 2, 25, 60], [74, 25, 62, 2, 25, 61], [74, 25, 63, 4, 26, 63], [74, 24, 63, 4, 25, 63],
          [74, 23, 63, 4, 24, 63], [74, 22, 63, 4, 23, 63], [74, 21, 63, 4, 22, 63], [74, 20, 63, 2, 20, 62],
          [74, 20, 64, 4, 21, 64], [74, 19, 64, 4, 20, 64], [74, 18, 64, 4, 19, 64], [75, 20, 61, 4, 21, 61],
          [75, 19, 61, 4, 20, 61], [73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67], [73, 27, 65, 8, 27, 66]]]
      ],
      :d_purple => [
        [{ 72 => [19, 64], 73 => [26, 66], 74 => [25, 61], 75 => [20, 61], 95 => [19, 63] },
         [[75, 20, 61, 2, 20, 60], [75, 20, 62, 6, 19, 62], [75, 21, 62, 2, 21, 61], [75, 21, 63, 6, 20, 63],
          [75, 22, 63, 6, 21, 63], [75, 23, 63, 6, 22, 63], [75, 24, 63, 6, 23, 63], [75, 25, 63, 2, 25, 62],
          [75, 25, 64, 6, 24, 64], [75, 26, 64, 6, 25, 64]]]
      ],
      :d_final => [
        [{ 72 => [19, 64], 73 => [26, 66], 74 => [25, 61], 75 => [20, 61], 95 => [19, 63] },
         [[75, 20, 61, 6, 19, 61], [75, 21, 61, 6, 20, 61], [75, 22, 61, 8, 22, 62], [72, 19, 64, 4, 20, 64],
          [72, 18, 64, 8, 18, 65], [72, 18, 63, 2, 18, 62], [73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67],
          [73, 27, 65, 8, 27, 66]]],
        [{ 72 => [19, 64], 73 => [26, 66], 74 => [25, 61], 75 => [27, 64], 95 => [19, 63] },
         [[75, 27, 64, 4, 28, 64], [75, 26, 64, 4, 27, 64], [75, 25, 64, 4, 26, 64], [75, 24, 64, 8, 24, 65],
          [75, 24, 63, 8, 24, 64], [75, 24, 62, 4, 25, 62], [75, 23, 62, 4, 24, 62], [75, 22, 62, 8, 22, 63],
          [75, 22, 61, 8, 22, 62], [72, 19, 64, 4, 20, 64], [72, 18, 64, 8, 18, 65], [72, 18, 63, 2, 18, 62],
          [73, 26, 66, 6, 25, 66], [73, 27, 66, 8, 27, 67], [73, 27, 65, 8, 27, 66]]]
      ]
    }
    WAYS = { 2 => :rbrf_way_down, 4 => :rbrf_way_left, 6 => :rbrf_way_right, 8 => :rbrf_way_up }
    FIRE_SPOT = [24, 64]
    JUMP_SPOT = [27, 67]
    # Stage B's purple jumps, by where EV74 stands as the prism fires (EV75 at 22, 61). The second works only from the
    # left light's turn at 18, 64 to its blue crystal, frames 34 to 77 after firing, so it is cued (:cue) by that light.
    JUMPS = {
      :b_fire => { :at => [19, 66], :fire => :rbrf_hint_fire_jump, :now => :rbrf_hint_jump_now },
      :b_fire2 => { :at => [18, 64], :fire => :rbrf_hint_fire_jump_cue, :now => :rbrf_hint_jump_wait_cue, :cue => 67 }
    }

    @beams = nil
    @last_sig = nil
    @last_text = nil
    @cued = false

    def self.on?(s); $game_switches[s] ? true : false; end

    def self.event(id); ($game_map.events || {})[id]; end

    def self.in_room?(x, y); x >= 17 && x <= 28 && y >= 60 && y <= 68; end

    def self.t(key, vars = {}); PokeAccess::I18n.t(key, vars); end

    # The mirrors and Serra standing in the room now, by event id, as [x, y].
    def self.objects
      ids = [75]
      ids.push(74) if on?(1897)
      ids.push(73) if on?(1898)
      ids.push(95, 72) if on?(1899)
      out = {}
      ids.each { |id| ev = event(id); out[id] = [ev.x, ev.y] if ev }
      out
    end

    def self.smashed?(id); $game_self_switches[[MAP, id, "A"]] ? true : false; end

    def self.standing?(id)
      ev = event(id)
      ev ? ev.x != 49 : false
    end

    def self.box_rocks_done?; BOX_ROCKS.all? { |id| smashed?(id) }; end

    def self.east_open?; EAST_ROCKS.any? { |id| !standing?(id) }; end

    def self.saved?
      v = $game_variables
      [v[731], v[732]] == OUTLINE_SPOTS[75] && [v[737], v[738]] == OUTLINE_SPOTS[74]
    end

    def self.lit?(color); c = CRYSTALS.find { |e| e[1] == color }; on?(c[0]); end

    # The positions after each push of a leg, from its start; Serra's facing is kept once she is pushed.
    def self.replay(start, pushes)
      states = [start.dup]
      cur = start.dup
      facing = nil
      pushes.each do |id, x, y, way, _sx, _sy|
        dx, dy = STEPS[way]
        cur = cur.dup.merge!(id => [x + dx, y + dy])
        facing = way if id == 72
        states.push(cur.dup.merge!(:facing => facing))
      end
      states
    end

    def self.matches?(state, objs)
      return false unless state.keys.reject { |k| k == :facing }.sort == objs.keys.sort
      return false unless objs.all? { |id, p| state[id] == p }
      state[:facing].nil? || (event(72) && event(72).direction == state[:facing])
    end

    # The leg of a goal the room stands on, as [pushes left, the next push], [0, nil] once placed, or nil off every leg.
    def self.leg_step(goal)
      objs = objects
      (LEGS[goal] || []).each do |start, pushes|
        states = replay(start, pushes)
        (states.length - 1).downto(0) do |k|
          next unless matches?(states[k], objs)
          return [pushes.length - k, pushes[k]]
        end
      end
      nil
    end

    # What to do next, as [kind, detail]: a goal of LEGS to place and then fire, or an action.
    def self.goal
      return [:done] if on?(DOOR)
      return [:wait] if on?(FIRING)
      story = $game_variables[STORY].to_i
      return [:story, on?(LUNA_MET) ? :rbrf_hint_story_serra : :rbrf_hint_story_luna] if story < 5
      return stage_d(story) if on?(1899)
      return stage_c if on?(1898)
      return stage_b if on?(1897)
      return [:act, :blue] if lit?(:blue) && !on?(1891)
      return [:go, :rbrf_hint_orb_north] if on?(1891)
      [:place, :a_blue]
    end

    # Green first, through the purple jump, to break the room's rocks; then blue and green from one firing, through a
    # second jump, as the east rock is faced only from the blue's bridge.
    def self.stage_b
      unless box_rocks_done?
        return [:smash] if on?(1892)
        return [:act, :green] if lit?(:green)
        return [:place, :b_purple] unless lit?(:purple)
        return [:place, saved? && leg_step(:b_fire) ? :b_fire : :b_save]
      end
      return [:go, :rbrf_hint_orb_east] if on?(1891) && east_open?
      return [:smash] if on?(1891) && on?(1892)
      return [:act, :blue] if lit?(:blue) && (lit?(:green) || on?(1892))
      return [:act, :green] if lit?(:green) && on?(1891)
      return [:place, :b_purple] unless lit?(:purple)
      [:place, saved? ? :b_fire2 : :b_save]
    end

    # Red for the west's red rock, then green again if the west rock stands: it is faced only past a red rock.
    def self.stage_c
      west = standing?(WEST_ROCK)
      return [:go, :rbrf_hint_orb_west] if on?(1893) && !west
      return [:act, :red] if !on?(1893) && lit?(:red)
      return [:smash] if on?(1892) && on?(1893) && west
      return [:act, :green] if west && on?(1893) && lit?(:green)
      return [:leave] if on?(1893)
      [:place, west ? :c_red_green : :c_red]
    end

    # Serra as the fourth mirror, the red rocks back in place and the purple kept lit.
    def self.stage_d(story)
      return [:leave] if on?(1893)
      return [:serra] if story < 6
      return [:wait] if story == 7
      return [:place, :d_purple] unless lit?(:purple)
      return [:fire] if story == 6
      [:place, :d_final]
    end

    # The next push of a goal, or what follows once its mirrors stand placed.
    def self.place_step(name)
      step = leg_step(name)
      return [:off_plan] unless step
      left, push = step
      return [:push, left, push] if push
      return [:save] if name == :b_save
      JUMPS[name] ? [:jump, name] : [:fire]
    end

    # The assist's step as one line.
    def self.hint
      g = goal
      g = place_step(g[1]) if g[0] == :place
      case g[0]
      when :done then t(:rbrf_hint_door)
      when :wait then on?(FIRING) && jump_leg ? t(JUMPS[jump_leg][:now]) : t(:rbrf_hint_wait)
      when :story, :go then t(g[1])
      when :act then act_line(g[1])
      when :smash then smash_line
      when :leave then t(:rbrf_hint_leave)
      when :serra then t(:rbrf_hint_serra)
      when :off_plan then t(:rbrf_hint_off_plan)
      when :save then t(:rbrf_hint_save)
      when :push then push_line(g[1], g[2])
      when :jump then on?(DARK) ? t(JUMPS[g[1]][:fire]) : t(:rbrf_hint_dark)
      else fire_line
      end
    end

    # The jump of JUMPS the mirrors stand placed for while the purple is lit, or nil.
    def self.jump_leg
      return nil unless on?(1897) && !on?(1898) && lit?(:purple)
      o = objects
      return nil unless o[75] == [22, 61]
      JUMPS.keys.find { |k| JUMPS[k][:at] == o[74] }
    end

    # Says the moment to use the purple once a firing, as the light that opens its jump's window turns.
    def self.cue
      leg = jump_leg
      light = leg && JUMPS[leg][:cue]
      return if @cued || light.nil? || !PokeAccess::Puzzles.assist?
      ev = event(light)
      return unless ev && ev.direction != LIGHTS[light]
      @cued = true
      PokeAccess.speak(t(:rbrf_hint_jump_cue), true)
    end

    def self.fire_line
      return t(:rbrf_hint_dark) unless on?(DARK)
      parts = [t(:rbrf_hint_fire)]
      parts.push(t(:rbrf_hint_keep_purple)) if lit?(:purple)
      PokeAccess.sentences(parts)
    end

    def self.act_line(color)
      parts = [t(:"rbrf_hint_use_#{color}")]
      parts.push(t(:rbrf_hint_keep_purple)) if lit?(:purple)
      PokeAccess.sentences(parts)
    end

    def self.push_line(left, push)
      id, x, y, way, sx, sy = push
      return t(:rbrf_hint_dark) if id == 72 && !on?(DARK)
      key = id == 72 ? :rbrf_push_serra : :rbrf_push_mirror
      t(key, :x => x, :y => y, :dir => t(WAYS[way]), :sx => sx, :sy => sy, :left => left)
    end

    # The rocks the green crystal lets break now, each where it can be faced: what is left of the room's, then in stage
    # B the east one from the blue's bridge, and in stage C the west one past the red rocks the red swaps.
    def self.smash_line
      ids = BOX_ROCKS.reject { |id| smashed?(id) }
      return t(:rbrf_hint_smash_east) if ids.empty? && !on?(1898)
      ids.push(WEST_ROCK) if on?(1898) && on?(1893) && standing?(WEST_ROCK)
      cells = ids.map { |id| ev = event(id); ev ? "#{ev.x}, #{ev.y}" : nil }.compact
      t(:rbrf_hint_smash, :list => cells.join("; "))
    end

    # Where the next step is taken: the push's tile, the prism's or the purple crystal's for the jump.
    def self.stand
      return nil unless PokeAccess::Puzzles.assist?
      g = goal
      return (jump_leg ? JUMP_SPOT : nil) if g[0] == :wait
      return nil unless g[0] == :place
      s = place_step(g[1])
      return [s[2][4], s[2][5]] if s[0] == :push
      s[0] == :jump ? FIRE_SPOT : nil
    end

    def self.mirror_label(ev)
      return nil unless in_room?(ev.x, ev.y)
      [:rbrf_mirror, { :face => t(MIRRORS[ev.id]) }]
    end

    def self.crystal_label(ev)
      c = CRYSTALS.find { |e| e[2] == ev.id }
      [:rbrf_crystal, { :color => t(:"rbrf_color_#{c[1]}"), :state => t(on?(c[0]) ? :rbrf_lit : :rbrf_unlit) }]
    end

    def self.serra_label(ev)
      return nil unless on?(1899) && $game_variables[STORY].to_i >= 8 && in_room?(ev.x, ev.y)
      [:rbrf_serra, { :dir => t(WAYS[ev.direction] || :rbrf_way_up) }]
    end

    def self.solid?(ev); !ev.through && (ev.tile_id.to_i > 0 || ev.character_name.to_s != ""); end

    # The info key's line: the dark, the lights in flight, the crystals lit and what the used ones keep open.
    def self.info_line
      parts = [t(on?(DARK) ? :rbrf_dark : :rbrf_bright)]
      parts.push(t(:rbrf_firing)) if on?(FIRING)
      parts.push(lit_line)
      parts.push(t(:rbrf_bridge_on)) if on?(1891)
      parts.push(t(:rbrf_rocks_on)) if on?(1892)
      parts.push(t(:rbrf_red_on)) if on?(1893)
      PokeAccess.sentences(parts)
    end

    def self.lit_line
      colors = CRYSTALS.select { |s, _c, _e, _p| on?(s) }.map { |_s, c, _e, _p| t(:"rbrf_color_#{c}") }
      colors.empty? ? t(:rbrf_none_lit) : t(:rbrf_lit_list, :list => colors.join(", "))
    end

    # Follows each light while they fly: where it turns and where it dies out.
    def self.track
      unless @beams
        @beams = {}
        @cued = false
        LIGHTS.each { |id, way| @beams[id] = { :way => way, :turns => [], :end => nil } }
      end
      LIGHTS.each_key do |id|
        b = @beams[id]
        ev = event(id)
        next if b[:end] || ev.nil?
        if on?(id + 1817)
          b[:end] = ending(ev)
        elsif ev.direction != b[:way] && STEPS[ev.direction]
          b[:way] = ev.direction
          b[:turns].push(turn_of(ev))
        end
      end
    end

    def self.turn_of(ev)
      serra = event(72)
      return [:serra, ev.direction] if on?(1899) && serra && serra.x == ev.x && serra.y == ev.y
      dx, dy = STEPS[ev.direction]
      [:mirror, ev.direction, ev.x - dx, ev.y - dy]
    end

    def self.ending(ev)
      c = CRYSTALS.find { |_s, _c, _e, p| p == [ev.x, ev.y] }
      return [:lit, c[1]] if c
      return [:out, ev.x, ev.y] unless in_room?(ev.x, ev.y)
      mirrors = objects.reject { |id, _p| id == 72 || id == 95 }.values
      return [:back, ev.x, ev.y] if FIXED[[ev.x, ev.y]] || mirrors.include?([ev.x, ev.y])
      [:hit, ev.x, ev.y]
    end

    # What a light did, as one sentence.
    def self.beam_line(id)
      b = @beams[id]
      turns = b[:turns].map do |tr|
        if tr[0] == :serra
          t(:rbrf_turn_serra, :dir => t(WAYS[tr[1]]))
        else
          t(:rbrf_turn, :dir => t(WAYS[tr[1]]), :x => tr[2], :y => tr[3])
        end
      end
      e = b[:end] || [:hit, event(id).x, event(id).y]
      last = case e[0]
             when :lit then t(:rbrf_end_lit, :color => t(:"rbrf_color_#{e[1]}"))
             when :out then t(:rbrf_end_out, :x => e[1], :y => e[2])
             when :back then t(:rbrf_end_back, :x => e[1], :y => e[2])
             else t(:rbrf_end_hit, :x => e[1], :y => e[2])
             end
      path = turns.empty? ? last : t(:rbrf_path, :turns => turns.join(", "), :end => last)
      t(:rbrf_beam, :light => t(:"rbrf_light_#{LIGHTS[id]}"), :path => path)
    end

    # What a sighted player saw of the firing just over, and with the assist the next step.
    def self.summary
      parts = [69, 67, 66, 68].map { |id| beam_line(id) }
      parts.push(lit_line)
      text = parts.join(" ")
      if PokeAccess::Puzzles.assist?
        @last_text = hint
        text = "#{text} #{@last_text}"
      end
      text
    end

    # The state the assist's step hangs on.
    def self.signature
      serra = event(72)
      [objects.sort, serra ? serra.direction : 0, [1882, 1887, 1888, 1889, 1890, 1891, 1892, 1893, 1895, 1897, 1898,
       1899, 1900].map { |s| on?(s) }, $game_variables[STORY].to_i, saved?,
       ALL_ROCKS.map { |id| smashed?(id) || !standing?(id) }]
    end

    def self.busy?; ($game_system.map_interpreter.running? rescue false); end

    # Follows the lights each frame, says each firing as it ends and, with the assist, each new step and the jump's cue.
    def self.poll
      return unless $game_map && $game_map.map_id == MAP
      if on?(FIRING)
        track
        cue
      end
      if @beams && !on?(FIRING)
        return if busy?
        PokeAccess.speak(summary, false)
        @beams = nil
        @last_sig = signature
        return
      end
      return if busy? || !PokeAccess::Puzzles.assist?
      sig = signature
      return if sig == @last_sig
      first = @last_sig.nil?
      @last_sig = sig
      return if first
      text = hint
      return if text == @last_text
      @last_text = text
      PokeAccess.speak(text, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # Drops what was kept of the last map.
    def self.forget
      @beams = nil
      @last_sig = nil
      @last_text = nil
      @cued = false
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornPrisma.forget }

PokeAccess::Game.define("reborn") do
  pr = PokeAccess::RebornPrisma
  poll_each_frame { pr.poll }
  mechanic(:state, pr::MAP) do
    name [70, 71], :rbrf_prism, :grouped => true
    name pr::MIRRORS.keys, lambda { |ev| pr.mirror_label(ev) }, :when => lambda { |ev| pr.in_room?(ev.x, ev.y) }
    name 95, :rbrf_broken_mirror, :when => lambda { |ev| pr.in_room?(ev.x, ev.y) }
    name [76, 77, 78, 79], lambda { |ev| pr.crystal_label(ev) }
    name 72, lambda { |ev| pr.serra_label(ev) }
    name pr::OUTLINES, :rbrf_outline, :when => lambda { |ev| pr.in_room?(ev.x, ev.y) }
    name pr::ORBS, :rbrf_orb
    name pr::RED_ROCKS, :rbrf_red_rock, :when => lambda { |ev| pr.solid?(ev) }
    hide pr::LIGHTS.keys
    pr::FIXED.each { |at, face| spot :at => at, :label => lambda { [:rbrf_fixed_mirror, { :face => pr.t(face) }] } }
    spot :at => lambda { pr.stand }, :label => :rbrf_spot_step, :assist => true, :onto => true,
         :when => lambda { !pr.stand.nil? }
    arrival_hint :rbrf_rule, :once => true
    info { pr.info_line }
    hint lambda { pr.hint }
    active { !$game_switches[pr::DOOR] }
    solved(nil, :quiet => true) { $game_switches[pr::DOOR] }
  end
end
