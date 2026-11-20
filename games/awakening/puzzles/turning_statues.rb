# The shrine rooms of statues that turn themselves and their neighbours with each use: a quarter to the left in Fire's
# west and south-west rooms (336, 339), Earth's two (374, 376) and the Empyrean's floor 561 (515), a half turn in Fire's
# south-east room (343, two groups). A parallel event opens the way once all face the room's way. Each use says where
# the statues it turns face; with the puzzle assist, the uses still needed. Turning commutes, so the plan is the
# fewest uses of each statue that bring every facing to the goal, read off the facings at the time.
module PokeAccess
  module AwakeningTurns
    CROSS = { 2 => [2, 3], 3 => [3, 5, 4], 4 => [4, 2, 5], 5 => [5, 2, 3] }
    # map => [quarters a use turns, {statue => the statues its use turns}, the facing the check asks of all, win test]
    ROOMS = {
      336 => [1, CROSS, 2, lambda { $game_switches[209] }],
      339 => [1, CROSS, 4, lambda { $game_switches[212] }],
      515 => [1, CROSS, 2, lambda { $game_switches[432] }],
      374 => [1, { 3 => [3, 4, 6], 4 => [4, 5], 5 => [5, 4, 3], 6 => [6, 5, 3] }, 8,
              lambda { $game_self_switches[[374, 7, "A"]] }],
      376 => [1, { 4 => [4, 6], 5 => [5, 6, 4], 6 => [6, 7, 4], 7 => [7, 5] }, 2,
              lambda { $game_self_switches[[376, 8, "A"]] }],
      343 => [2, { 1 => [1, 2, 3], 2 => [2, 1], 3 => [3, 1], 6 => [6, 9, 7], 7 => [7, 10, 6], 8 => [8, 9],
                   9 => [9, 8, 6], 10 => [10, 7] }, 2, lambda { $game_self_switches[[343, 12, "A"]] }]
    }
    # The facings in the order a quarter turn to the left goes through them.
    ORDER = [2, 6, 8, 4]
    @plans = {}

    # True once the room's check has opened the way.
    def self.won?(map); ROOMS[map][3].call ? true : false; end

    # The room's statue ids in reading order, the order their numbers follow.
    def self.ids(map)
      ROOMS[map][1].keys.select { |id| $game_map.events[id] }.sort_by { |id| ev = $game_map.events[id]; [ev.y, ev.x] }
    end

    # A statue's spoken name: its number in reading order.
    def self.label(map, id); [:awk_statue_n, { :n => ids(map).index(id).to_i + 1 }]; end

    # The facing after turning d by q quarters to the left.
    def self.turn(d, q); ORDER[(ORDER.index(d).to_i + q) % 4]; end

    # Every statue's facing now.
    def self.facings(map)
      out = {}
      ids(map).each { |id| out[id] = ($game_map.events[id].direction rescue 2) }
      out
    end

    # The fewest uses of each statue that bring all to the goal from these facings, as [[id, uses], ...] with the
    # uses above 0; nil when no count does. Kept per facings: at most 4^4 or 2^8 counts are tried, once each.
    def self.plan(map, faces)
      key = [map, faces.keys.sort.map { |id| faces[id] }]
      return @plans[key] if @plans.key?(key)
      q, links, goal, = ROOMS[map]
      ids = faces.keys.sort
      span = 4 / q
      best = nil
      (0...(span**ids.size)).each do |code|
        uses = []
        ids.size.times { uses.push(code % span); code /= span }
        next if best && uses.inject(0) { |a, b| a + b } >= best.inject(0) { |a, b| a + b }
        now = faces.dup
        ids.each_with_index { |id, k| (links[id] || []).each { |t| now[t] = turn(now[t], q * uses[k]) if now[t] } }
        best = uses if now.values.all? { |d| d == goal }
      end
      @plans[key] = best && ids.zip(best).select { |_id, n| n > 0 }
    end

    # The assist's line for these facings: the uses still needed, or that all face the goal.
    def self.plan_line(map, faces)
      steps = plan(map, faces)
      return nil if steps.nil?
      return PokeAccess::I18n.t(:awk_turn_ready) if steps.empty?
      list = steps.sort_by { |id, _n| ids(map).index(id).to_i }.map do |id, n|
        PokeAccess::I18n.t(:awk_turn_times, :name => PokeAccess::Puzzles.label_of(label(map, id)), :n => n)
      end
      PokeAccess::I18n.t(:awk_turn_plan, :list => list.join(", "))
    end

    # What a use of statue id turns, as the page starts and before the statues move: each one's facing after the
    # turn and, with the assist, the uses left from there; nil once the room is solved or the page turns nothing.
    def self.after_use(map, id)
      ev = $game_map.events[id]
      list = ev && PokeAccess.ivar(ev, :@list)
      return nil if won?(map) || list.nil? || list.size <= 1
      q, links, = ROOMS[map]
      faces = facings(map)
      turned = (links[id] || []).select { |t| faces[t] }.sort_by { |t| ids(map).index(t).to_i }
      turned.each { |t| faces[t] = turn(faces[t], q) }
      parts = turned.map { |t| "#{PokeAccess::Puzzles.label_of(label(map, t))}: #{PokeAccess::Puzzles.face_name(faces[t])}" }
      parts.push(plan_line(map, faces)) if PokeAccess::Puzzles.assist?
      PokeAccess.sentences(parts.compact)
    end

    # The info key's line: each statue's facing, in reading order.
    def self.facings_line(map)
      faces = facings(map)
      ids(map).map { |id| "#{PokeAccess::Puzzles.label_of(label(map, id))}: #{PokeAccess::Puzzles.face_name(faces[id])}" }.join(", ")
    end
  end
end

PokeAccess::Game.define("awakening") do
  turns = PokeAccess::AwakeningTurns
  turns::ROOMS.each do |map, (_q, links, _goal, _win)|
    mechanic(:state, map, :part => :turning) do
      auto
      links.keys.each do |id|
        name id, lambda { |_ev| turns.label(map, id) }, :when => lambda { |_ev| !turns.won?(map) }
      end
      on_use links.keys, lambda { |ev| turns.after_use(map, ev.id) }
      info { turns.facings_line(map) }
      hint lambda { turns.plan_line(map, turns.facings(map)) }
      solved { turns.won?(map) }
    end
  end
end
