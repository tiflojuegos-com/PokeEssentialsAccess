# Route 109's beach ball quest (map 39): the kids' quest giver (event 57, at 40,16) sets switch 2139 and draws the
# Krabby. Kicking the ball (event 4, kick_ball) sends it the way the player faces, floor(move speed * 0.8) tiles (2
# walking, 3 running), one tile back off what stops it, three times at most; a visible wild Pokemon on its way pops it
# (its page 2 takes it back to 26,5), and landing within 2 steps of the quest giver sets switch 2140.
module PokeAccess
  module HoennBeachBall
    MAP = 39
    BALL = 4
    GOAL = [40, 16]
    QUEST = 2139
    DONE = 2140
    WILD = "OverworldPokemon"
    DIRS = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    SPEEDS = [3, 4]
    KICKS = { 2 => :if_ho_ball_kick_down, 4 => :if_ho_ball_kick_left, 6 => :if_ho_ball_kick_right, 8 => :if_ho_ball_kick_up }

    # True while the quest is taken and the ball not yet brought.
    def self.quest?
      $game_switches[QUEST] && !$game_switches[DONE] ? true : false
    end

    # Where a kick along d ([dir, dx, dy]) at a move speed, from (x, y) with the player on kicker, leaves the ball, as
    # [x, y, won], or nil when it pops, step by step as kick_ball takes it. env answers :open (x, y, dir) as
    # $game_map.passable?, :lands (x, y, kicker) for the ball's jump onto a tile and :pops (x, y) for a wild Pokemon there.
    def self.kick(x, y, d, speed, kicker, env)
      dir, dx, dy = d
      left = [speed * 0.8, 1].max.floor
      bounces = 0
      while left > 0 && bounces < 3
        travel = 0
        popped = false
        while travel < left
          tx = x + dx * (travel + 1)
          ty = y + dy * (travel + 1)
          if env[:pops].call(tx, ty)
            popped = true
          elsif !env[:open].call(tx - dx, ty - dy, dir) || !env[:open].call(tx, ty, dir)
            break
          end
          travel += 1
        end
        if travel > 0 && (popped || env[:lands].call(x + dx * travel, y + dy * travel, kicker))
          x += dx * travel
          y += dy * travel
        end
        if travel < left
          bounces += 1
          left = [left / 2.0, 1].max.floor
          dx = -dx
          dy = -dy
          dir = 10 - dir
          back = [left / 2.0, 1].max.floor
          if popped || env[:lands].call(x + dx * back, y + dy * back, kicker)
            x += dx * back
            y += dy * back
          end
        else
          left = 0
        end
        return nil if popped
        return [x, y, true] if (x - GOAL[0]).abs + (y - GOAL[1]).abs <= 2
      end
      [x, y, false]
    end

    # The fewest kicks that take the ball from (x, y) to the kids, as [the first's d, its speed, how many], or nil: a
    # breadth-first search over where the ball lands, each kick made from a tile env's :stand (x, y) lets the player on.
    def self.plan(x, y, env)
      seen = { [x, y] => nil }
      queue = [[x, y]]
      until queue.empty?
        cur = queue.shift
        DIRS.each do |d|
          kicker = [cur[0] - d[1], cur[1] - d[2]]
          next unless env[:stand].call(kicker[0], kicker[1])
          SPEEDS.each do |speed|
            r = kick(cur[0], cur[1], d, speed, kicker, env)
            next unless r
            step = [cur, d, speed]
            return opening(seen, step) if r[2]
            nxt = [r[0], r[1]]
            next if seen.key?(nxt)
            seen[nxt] = step
            queue.push(nxt)
          end
        end
      end
      nil
    end

    # The first kick of the plan ending with step, walked back through seen, and how many kicks it takes.
    def self.opening(seen, step)
      n = 1
      while seen[step[0]]
        step = seen[step[0]]
        n += 1
      end
      [step[1], step[2], n]
    end

    # The game's own answers for one plan from where ball lies now, each kept for that search.
    def self.live_env(ball)
      map = $game_map
      open = {}
      free = {}
      wild = {}
      stand = {}
      {
        :open => lambda { |x, y, dir| kept(open, [x, y, dir]) { map.passable?(x, y, dir) ? true : false } },
        :lands => lambda { |x, y, kicker| [x, y] != kicker && kept(free, [x, y]) { lands?(map, ball, x, y) } },
        :pops => lambda { |x, y| kept(wild, [x, y]) { wild?(map, x, y) } },
        :stand => lambda { |x, y| kept(stand, [x, y]) { stand?(map, x, y) } }
      }
    end

    # The value table holds for key, else the block's, kept.
    def self.kept(table, key)
      table.key?(key) ? table[key] : (table[key] = yield)
    end

    # True when the ball's jump can end on (x, y), as Game_Character#passable? with direction 0 answers for it, the
    # player aside.
    def self.lands?(map, ball, x, y)
      return false unless map.valid?(x, y) && map.passable?(x, y, 0)
      map.events.values.none? { |e| !e.equal?(ball) && !e.through && at?(e, x, y) }
    end

    # True when kick_ball would pop the ball on (x, y): the first event there, as get_event_at_position finds it, is a
    # wild Pokemon with a page (Game_Event#active?).
    def self.wild?(map, x, y)
      e = map.events.values.find { |ev| at?(ev, x, y) }
      e && e.name == WILD && PokeAccess.ivar(e, :@page) && !PokeAccess.ivar(e, :@erased) ? true : false
    end

    # True when the player can get to (x, y), as the core's regions on foot tell it; while their walk does not tell
    # yet, when it can be stepped onto from a free tile beside it.
    def self.stand?(map, x, y)
      return false unless map.valid?(x, y)
      case PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(x, y))[0]
      when :yes then true
      when :no then false
      else DIRS.any? { |dir, dx, dy| !solid?(map, x - dx, y - dy) && $game_player.passable?(x - dx, y - dy, dir) }
      end
    end

    # True when a drawn character that is not walked through stands on (x, y).
    def self.solid?(map, x, y)
      map.events.values.any? { |e| !e.through && !e.character_name.to_s.empty? && at?(e, x, y) }
    end

    # True when event e covers (x, y).
    def self.at?(e, x, y)
      e.respond_to?(:at_coordinate?) ? e.at_coordinate?(x, y) : (e.x == x && e.y == y)
    end

    # Where the ball lies from the kids, for the info key.
    def self.from_kids
      ev = $game_map.events[BALL]
      return "" unless ev
      [:if_ho_ball_from_kids, { :dist => PokeAccess::Puzzles.offset_phrase(ev.x - GOAL[0], ev.y - GOAL[1]) }]
    end

    # The next kick and how many are left, with the puzzle assist; that none gets there past the Pokemon now.
    def self.hint
      ev = $game_map.events[BALL]
      return "" unless ev
      found = plan(ev.x, ev.y, live_env(ev))
      return :if_ho_ball_hint_none unless found
      d, speed, n = found
      gait = PokeAccess::I18n.t(speed == SPEEDS[0] ? :if_ho_ball_walk : :if_ho_ball_run)
      [:if_ho_ball_hint, { :kick => PokeAccess::I18n.t(KICKS[d[0]]), :gait => gait, :n => n }]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  ball = PokeAccess::HoennBeachBall

  mechanic(:state, ball::MAP) do
    auto
    name [ball::BALL, 73], :if_ho_ball
    name 57, :if_ho_ball_burst
    watch :self => [ball::BALL, "A"], :say => :if_ho_ball_popped
    arrival_hint lambda { ball.quest? ? :if_ho_ball_rule : nil }, :once => true
    solved { $game_switches[ball::DONE] }
    phase lambda { ball.quest? }, :title => lambda { ball.from_kids }, :quiet => true, :hint => lambda { ball.hint },
                                  :track => { :event => ball::BALL, :label => :if_ho_ball }
  end
end
