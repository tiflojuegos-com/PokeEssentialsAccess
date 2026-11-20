# Carleton Facility (maps 117, 119 and 121): floors of "Stepped on" tiles, each stepped on once (its self switch A);
# stepping on one again drops the player to the floor below (maps 118, 120 and 122) and every tile starts over as the map
# reloads. The whole floor brings out the ladder above its last tile, to the room of two of the six generators that the
# mine's superintendent waits for (variable 56, 1 after the scientist and 7 with all six). The floors hold no other
# ground, so a way across steps from tile to tile, enters by the first tile in event order and ends on the last, under
# the ladder: the only one on maps 117 and 121, one of many on 119. The assist follows whatever way the player walks.
module PokeAccess
  module SoulstonesCarleton
    FLOORS = { 117 => [(2..26).to_a], 119 => [(2..72).to_a], 121 => [(2..22).to_a, (25..41).to_a] }
    COUNTERS = { 117 => [51], 119 => [53], 121 => [54, 55] }
    # The tries a search for the way on may take before it gives up.
    SEARCH_CAP = 20000

    # True when the tile event id of this map has been stepped on.
    def self.stepped?(id)
      $game_self_switches[[$game_map.map_id, id, "A"]] ? true : false
    end

    # The tile of plan to step on next: the first of a way over every tile left from the one stood on, ending on the last
    # one; nil when there is none, :unknown when the search gave up. Worked out once a frame, and searched again only
    # once a tile is stepped on.
    def self.next_tile(plan)
      key = [PokeAccess::Frame.serial, $game_map.map_id, plan.first]
      return @next[1] if @next && @next[0] == key
      done = plan.select { |id| stepped?(id) }
      at = [$game_player.x, $game_player.y]
      walk_key = [$game_map.map_id, plan.first, done, at]
      @walk = [walk_key, next_now(plan, done, at)] unless @walk && @walk[0] == walk_key
      @next = [key, @walk[1]]
      @next[1]
    end

    # The next tile from the tiles done and where the player stands, as next_tile tells it: the way found last goes on
    # while the player keeps to it, and a new one is searched when they leave it.
    def self.next_now(plan, done, at)
      pos = {}
      plan.each { |id| ev = $game_map.events[id]; pos[id] = [ev.x, ev.y] if ev }
      return nil if done.length == plan.length || pos.length < plan.length
      cur = done.empty? ? nil : pos.keys.find { |id| pos[id] == at && done.include?(id) }
      return nil unless done.empty? || cur
      kept = kept_step(plan, done, cur)
      return kept if kept
      path = way(pos, plan.first, plan.last, done, cur)
      @route = path.is_a?(Array) ? [$game_map.map_id, plan.first, done, cur, path] : nil
      path.is_a?(Array) ? path.first : path
    end

    # The next tile of the way found last, when what was stepped on since is its start, or nil.
    def self.kept_step(plan, done, cur)
      return nil unless @route && @route[0] == $game_map.map_id && @route[1] == plan.first
      done0, cur0, path = @route[2], @route[3], @route[4]
      k = done.length - done0.length
      return nil if k < 0 || (done0 - done).length > 0
      return(cur == cur0 ? path.first : nil) if k == 0
      (done - done0).sort == path[0, k].sort && cur == path[k - 1] ? path[k] : nil
    end

    # A way over the tiles of pos not in done, from cur (nil: entering by first), ending on last, as the list of tiles
    # in order; nil when there is none, :unknown when the search gave up.
    def self.way(pos, first, last, done, cur)
      by = {}
      pos.each { |id, p| by[p] = id }
      nbr = {}
      pos.each { |id, (x, y)| nbr[id] = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]].map { |p| by[p] }.compact }
      rest = {}
      pos.each_key { |id| rest[id] = true unless done.include?(id) }
      budget = [SEARCH_CAP]
      if cur.nil?
        rest.delete(first)
        tail = rest.empty? ? [] : walk(first, rest, last, nbr, budget)
        return tail ? [first] + tail : (budget[0] < 0 ? :unknown : nil)
      end
      walk(cur, rest, last, nbr, budget) || (budget[0] < 0 ? :unknown : nil)
    end

    # Depth-first walk from cur over every tile of rest, ending on last: the tiles in order, or nil.
    def self.walk(cur, rest, last, nbr, budget)
      return(cur == last ? [] : nil) if rest.empty?
      return nil if (budget[0] -= 1) < 0
      options = nbr[cur].select { |n| rest[n] && (n != last || rest.length == 1) }
      options.sort_by { |n| nbr[n].count { |m| rest[m] } }.each do |n|
        rest.delete(n)
        tail = viable?(n, rest, last, nbr) ? walk(n, rest, last, nbr, budget) : nil
        rest[n] = true
        return [n] + tail if tail
        return nil if budget[0] < 0
      end
      nil
    end

    # Whether the tiles of rest can still be walked from cur: all joined to it, none but one beside it a dead end.
    def self.viable?(cur, rest, last, nbr)
      return true if rest.empty?
      seen = { cur => true }
      queue = [cur]
      until queue.empty?
        nbr[queue.shift].each { |n| next if seen[n] || !rest[n]; seen[n] = true; queue.push(n) }
      end
      return false unless rest.keys.all? { |id| seen[id] }
      ends = rest.keys.select { |id| id != last && nbr[id].count { |n| rest[n] || n == cur } < 2 }
      ends.length <= 1 && ends.all? { |id| nbr[cur].include?(id) }
    end

    # What the assist says of a floor: done, no way left, or to follow the right way.
    def self.hint(plan)
      return :ss1_carleton_done if plan.all? { |id| stepped?(id) }
      next_tile(plan) ? :ss1_carleton_hint : :ss1_carleton_off_plan
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  lab = PokeAccess::SoulstonesCarleton

  lab::FLOORS.each do |map, plans|
    plans.each_with_index do |plan, i|
      var = lab::COUNTERS[map][i]
      mechanic(:grid, map, :part => :"floor#{i}") do
        auto
        tiles plan.first..plan.last, :self => "A", :label => :ss1_carleton_tile, :count => :ss1_carleton_tiles,
                                     :words => { true => :ss1_carleton_stepped, false => :ss1_carleton_free }
        hint lambda { lab.hint(plan) }
        solved(nil, :quiet => true) { $game_variables[var].to_i >= plan.length }
      end
      mechanic(:state, map, :part => :"path#{i}") do
        auto
        plan.each do |id|
          spot(:event => id, :label => :puzzle_right_way, :assist => true, :onto => true,
               :when => lambda { lab.next_tile(plan) == id })
        end
        arrival_hint :ss1_carleton_rule, :once => true
        solved(nil, :quiet => true) { $game_variables[var].to_i >= plan.length }
      end
    end
  end

  [[118, [[12, 10, 117]]], [120, [[12, 14, 119]]], [122, [[10, 13, 121], [18, 13, 121]]]].each do |below, falls|
    mechanic(:state, below, :part => :fall) do
      auto
      falls.each { |x, y, from| sent_back :ss1_carleton_fell, :maps => [from], :to => [x, y] }
    end
  end

  mechanic(:state, [111, 117, 119, 121], :part => :generators) do
    auto
    count :ss1_carleton_generators, :value => lambda { [$game_variables[56].to_i - 1, 0].max }, :of => 6,
                                    :assist => true, :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[56].to_i >= 7 }
  end
end
