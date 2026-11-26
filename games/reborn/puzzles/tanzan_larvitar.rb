# Tanzan Depths' Larvitar room (map 621): four crystals (actions 42 up at (18, 14), 43 left at (17, 15), 44 right at
# (19, 15), 45 down at (18, 16)) send the Larvitar at (11, 18) to the first rock sundae that way within 20 tiles, unless
# a "Gross" rock is first; a meal opens the room (switch 738). With the assist, the plan's moves.
module PokeAccess
  module RebornTanzanLarvitar
    MAP = 621
    LARVITAR = 40
    START = [11, 18]
    OPEN = 738
    YUMS = (1..34).to_a + [38, 39]
    PANELS = { 42 => :up, 43 => :left, 44 => :right, 45 => :down }
    PLAN = [[:up, 7, [11, 16]], [:up, 5, [11, 14]], [:up, 4, [11, 12]], [:right, 15, [13, 12]],
            [:right, 16, [15, 12]], [:right, 17, [17, 12]], [:right, 18, [19, 12]], [:right, 26, [21, 12]],
            [:right, 27, [23, 12]], [:right, 25, [25, 12]], [:right, 33, [27, 12]], [:down, 32, [27, 14]],
            [:down, 34, [27, 16]], [:down, 38, [27, 18]]]

    # The moves of the plan already made, read from where the Larvitar stands and what it has eaten; nil off the plan.
    def self.step
      ev = $game_map.events[LARVITAR]
      return nil unless ev
      at = [ev.x, ev.y]
      k = at == START ? 0 : (PLAN.index { |move| move[2] == at } || -1) + 1
      return nil if k == 0 && at != START
      eaten = PLAN[0...k].map { |move| move[1] }
      YUMS.all? { |id| !!$game_self_switches[[MAP, id, "A"]] == eaten.include?(id) } ? k : nil
    end

    # The hint for the move to make now: the crystal to use, or to leave and come back once off the plan.
    def self.hint
      k = step
      return :rbj_tz_reset unless k
      return nil if k >= PLAN.length
      :"rbj_tz_go_#{PLAN[k][0]}"
    end
  end
end

PokeAccess::Game.define("reborn") do
  lv = PokeAccess::RebornTanzanLarvitar
  mechanic(:state, lv::MAP, :part => :larvitar) do
    auto
    lv::PANELS.each { |id, dir| name id, :"rbj_tz_panel_#{dir}", :when => lambda { |_ev| !$game_switches[lv::OPEN] } }
    name lv::LARVITAR, :rbj_tz_larvitar, :when => lambda { |_ev| !$game_switches[lv::OPEN] }
    room = at(4, 32, 4, 22)
    (0..lv::PLAN.length).each do |k|
      phase(lambda { PokeAccess::Puzzles.assist? && room.call && lv.step == k }, :quiet => true,
            :hint => lambda { lv.hint })
    end
    phase(lambda { PokeAccess::Puzzles.assist? && room.call && lv.step.nil? }, :quiet => true, :hint => :rbj_tz_reset)
    solved(nil, :quiet => true) { $game_switches[lv::OPEN] }
  end
end
