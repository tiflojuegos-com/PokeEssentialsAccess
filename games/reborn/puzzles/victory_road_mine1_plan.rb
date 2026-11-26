# Victory Road's first mine with the puzzle assist: one plan across the atrium (784, 812 once the pillar has blown), B1F
# (786, then 811) and 2F (788), kept in victory_road_mine1_data.rb. The step taken is the one whose map, switches,
# variables and moved boulders stand now; off the plan, a lever, leaving the room or the stairs bring it back.
module PokeAccess
  module RebornVrMineRoute
    AHEAD = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    DIRS = { 2 => :rbrh_dir_down, 4 => :rbrh_dir_left, 6 => :rbrh_dir_right, 8 => :rbrh_dir_up }
    LABELS = { :lever => :rbg_plan_lever, :use => :rbg_plan_use, :climb => :rbrh_climb, :smash => :rbrh_smash,
               :exit => :rbrh_exit, :touch => :rbrh_touch }

    def self.plan; PokeAccess::RebornVrMineData::PLAN; end

    def self.map_id; $game_map ? $game_map.map_id : nil; end

    # True on one of the plan's maps before the way out is reached.
    def self.live?
      plan[:maps].include?(map_id) && !done?
    end

    def self.done?
      $game_variables[plan[:done]].to_i >= plan[:done_at]
    end

    # The switches on and the variables not at 0, in the plan's order; a variable with a floor counts as that floor
    # below it (the story's variable before the atrium).
    def self.signature
      floor = plan[:floor] || {}
      on = plan[:switches].select { |s| $game_switches[s] }.map { |s| "S#{s}" }
      vals = plan[:vars].map do |v|
        n = [$game_variables[v].to_i, floor[v] || 0].max
        n == 0 ? nil : "V#{v}=#{n}"
      end.compact
      (on + vals).join(",")
    end

    # The boulders of this map that stand off their own tile, as the plan writes them, the one skipped left out.
    def self.moved(skip = nil)
      home = plan[:homes][map_id] || {}
      out = []
      home.keys.sort.each do |id|
        next if id == skip
        ev = $game_map.events[id]
        next unless ev && [ev.x, ev.y] != home[id]
        out << "#{id}:#{ev.x},#{ev.y}"
      end
      out.join(";")
    end

    # How many pushes of a push step are done, or nil when the boulder is not on its line.
    def self.pushed(s)
      ev = $game_map.events[s[1]]
      bx, by, d, n = s[4]
      return nil unless ev
      dx, dy = AHEAD[d]
      (0...n).find { |k| ev.x == bx + dx * k && ev.y == by + dy * k }
    end

    # True when the step stands as things are now (its map, state and boulders).
    def self.fits?(s, sig)
      return false unless s[0] == map_id && s[3] == sig
      return (s[5] || "") == moved(s[1]) && !pushed(s).nil? if s[2] == :push
      (s[5] || "") == moved
    end

    # True when the player stands in a step's zone (row spans "y:x0-x1,x2;..."), or the step has none.
    def self.in_zone?(s)
      return true unless s[6]
      @spans ||= {}
      rows = (@spans[s[6]] ||= parse_spans(s[6]))
      (rows[$game_player.y] || []).any? { |a, b| $game_player.x >= a && $game_player.x <= b }
    end

    def self.parse_spans(text)
      rows = {}
      text.split(";").each do |row|
        y, runs = row.split(":")
        rows[y.to_i] = runs.split(",").map { |r| a, b = r.split("-"); [a.to_i, (b || a).to_i] }
      end
      rows
    end

    # The step to take now as [index, step], or nil off the plan.
    def self.step
      return nil unless live?
      sig = signature
      cands = []
      plan[:steps].each_with_index { |s, i| cands << i if fits?(s, sig) }
      return nil if cands.empty?
      i = cands.find { |c| in_zone?(plan[:steps][c]) } || cands[0]
      [i, plan[:steps][i]]
    end

    # Off the plan: the lever of this map whose flip brings the state back onto one of its steps, or nil.
    def self.lever_back
      levers = plan[:levers][map_id]
      return nil unless levers
      cur = signature.split(",")
      mine = plan[:steps].select { |s| s[0] == map_id }.map { |s| s[3].split(",").sort }
      levers.each do |sw, id|
        flag = "S#{sw}"
        flipped = (cur.include?(flag) ? cur - [flag] : cur + [flag]).sort
        return id if mine.include?(flipped)
      end
      nil
    end

    # True when a step of this map has the state as it stands, but the boulders stand elsewhere.
    def self.boulders_off?
      sig = signature
      plan[:steps].any? { |s| s[0] == map_id && s[3] == sig }
    end

    # What to do next, as [kind, event, step index]; [:back, lever] off the plan; nil when nothing is known.
    def self.target
      s = step
      return [s[1][2], s[1][1], s[0]] if s
      id = lever_back
      id && [:back, id, nil]
    end

    # Where the next thing to do is: the tile to push from for a push, else the event as it stands.
    def self.next_at
      t = target
      return nil unless t
      ev = $game_map.events[t[1]]
      return nil unless ev
      return [ev.x, ev.y] unless t[0] == :push
      d = plan[:steps][t[2]][4][2]
      [ev.x - AHEAD[d][0], ev.y - AHEAD[d][1]]
    end

    # True while the next thing to do is a push, stood on rather than faced.
    def self.pushing?
      t = target
      !t.nil? && t[0] == :push
    end

    # The next thing to do, in words.
    def self.next_label
      t = target
      return nil unless t
      i18n = PokeAccess::I18n
      case t[0]
      when :cart
        ev = $game_map.events[t[1]]
        name = ev && PokeAccess::RebornVrMines.cart_label(ev)
        i18n.t(:rbg_plan_cart, :name => name || i18n.t(:rbc2_cart))
      when :push then push_label(plan[:steps][t[2]])
      when :back then i18n.t(:rbg_plan_back)
      else i18n.t(LABELS[t[0]] || :rbg_plan_use)
      end
    end

    # A push step: the way, and how many pushes are left of the run.
    def self.push_label(s)
      i18n = PokeAccess::I18n
      left = s[4][3] - (pushed(s) || 0)
      dir = i18n.t(DIRS[s[4][2]])
      left > 1 ? i18n.t(:rbrh_push_n, :dir => dir, :n => left) : i18n.t(:rbrh_push, :dir => dir)
    end

    # The info key's line with the assist: the step's number and what it is, and where from the player; off the plan,
    # what brings it back.
    def self.info_line
      return nil unless PokeAccess::Puzzles.assist? && live?
      t = target
      at = next_at
      if t && at
        where = PokeAccess::Locator.dir_phrase(at[0] - $game_player.x, at[1] - $game_player.y)
        what = next_label
        return PokeAccess::I18n.t(:rbg_plan_off, :what => what, :where => where) unless t[2]
        return PokeAccess::I18n.t(:rbg_plan_step, :n => t[2] + 1, :total => plan[:steps].length, :what => what,
                                  :where => where)
      end
      PokeAccess::I18n.t(boulders_off? ? :rbrh_reset : :rbrh_lost)
    end
  end
end

PokeAccess::Game.define("reborn") do
  route = PokeAccess::RebornVrMineRoute
  PokeAccess::RebornVrMineData::PLAN[:maps].each do |map|
    mechanic(:state, map, :part => :mine_route) do
      auto
      spot :at => lambda { route.next_at }, :label => lambda { route.next_label }, :assist => true, :onto => true,
           :when => lambda { route.pushing? }
      spot :at => lambda { route.next_at }, :label => lambda { route.next_label }, :assist => true,
           :when => lambda { !route.pushing? }
      info { route.info_line }
      active { PokeAccess::Puzzles.assist? && route.live? }
      hint :rbrh_hint
      solved(nil, :quiet => true) { route.done? }
    end
  end
end
