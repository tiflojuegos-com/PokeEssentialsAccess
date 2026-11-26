# Victory Road's four logic puzzles (maps 785, 789, 793, 795): a row of blocks per gem, each pushed sideways under the
# value of its quality, whose word is a text event of the row above (the leftmost names the quality). A checker reads
# the x each must stand at and opens the gate. Named by gem, quality and value; with the assist, where each goes.
module PokeAccess
  module RebornVrLogic
    GEMS = [:rbc2_gem_ruby, :rbc2_gem_sapphire, :rbc2_gem_emerald, :rbc2_gem_amethyst]
    BLOCK = /Tuner [RBGP]-\d+\z/

    # Map => [gate switch, checker event, {block event => the x it is checked at}], from each checker's page.
    MAPS = {
      785 => [1102, 54, { 9 => 18, 10 => 25, 11 => 32, 12 => 20, 13 => 24, 14 => 29, 15 => 19, 16 => 26, 17 => 31,
                          18 => 17, 19 => 23, 20 => 30 }],
      789 => [1158, 64, { 5 => 19, 6 => 26, 7 => 29, 8 => 38, 9 => 17, 10 => 23, 11 => 32, 12 => 35, 13 => 18,
                          14 => 25, 15 => 31, 16 => 36, 17 => 20, 18 => 24, 19 => 30, 20 => 37 }],
      793 => [1179, 79, { 9 => 23, 10 => 27, 11 => 35, 12 => 40, 13 => 48, 14 => 21, 15 => 28, 16 => 34, 17 => 41,
                          18 => 45, 19 => 24, 20 => 29, 21 => 33, 22 => 39, 23 => 46, 24 => 22, 25 => 30, 26 => 36,
                          27 => 42, 28 => 47 }],
      795 => [1226, 97, { 14 => 18, 15 => 26, 16 => 30, 17 => 37, 18 => 43, 19 => 48, 20 => 21, 21 => 27, 22 => 32,
                          23 => 39, 24 => 45, 25 => 49, 26 => 19, 27 => 24, 28 => 31, 29 => 38, 30 => 42, 31 => 50,
                          32 => 20, 33 => 25, 34 => 33, 35 => 36, 36 => 44, 37 => 51 }]
    }

    # The map's events by tile.
    def self.by_tile
      at = {}
      ($game_map.events || {}).each_value { |e| at[[e.x, e.y]] = e }
      at
    end

    # The words a text event shows, as the game reads them: its last command but the list's end, quotes taken out.
    def self.words(ev)
      page = PokeAccess::World::Mechanics::Links.pages(ev)[0]
      cmd = page && page.list && page.list[-2]
      text = cmd && cmd.parameters[0]
      text.is_a?(String) ? text.delete('"') : nil
    end

    # [gem key, quality, value or nil] of a block at (x,y), found as the game finds them: the first event 5 to 2 rows
    # above is its value, the leftmost of that row its quality, and how far below the row tells the gem.
    def self.reading(at, x, y)
      top = [5, 4, 3, 2].map { |i| at[[x, y - i]] }.compact.first
      return nil unless top
      gem = GEMS[y - top.y - 2]
      corner = top
      5.times do
        left = at[[corner.x - 1, corner.y]]
        break unless left
        corner = left
      end
      gem && [gem, words(corner), corner.equal?(top) ? nil : words(top)]
    end

    # The block's name: its gem, its quality and the value it sits under, and with the assist where it goes.
    def self.label(ev)
      at = by_tile
      r = reading(at, ev.x, ev.y)
      return nil unless r
      i18n = PokeAccess::I18n
      value = r[2] || i18n.t(:rbc2_logic_none)
      name = i18n.t(:rbc2_logic_block, :gem => i18n.t(r[0]), :quality => r[1].to_s, :value => value)
      goal = PokeAccess::Puzzles.assist? && (MAPS[$game_map.map_id] || [])[2]
      tx = goal && goal[ev.id]
      return name unless tx
      return i18n.t(:rbc2_logic_placed, :name => name) if tx == ev.x
      want = reading(at, tx, ev.y)
      key = tx > ev.x ? :rbc2_logic_push_right : :rbc2_logic_push_left
      i18n.t(key, :name => name, :value => (want && want[2]).to_s, :count => (tx - ev.x).abs)
    end

    # How many of the map's blocks stand where the checker wants them.
    def self.placed
      goal = (MAPS[$game_map.map_id] || [])[2] || {}
      goal.count { |id, tx| (e = $game_map.events[id]) && e.x == tx }
    end

    # True when every block stands where the checker wants it.
    def self.all_placed?
      goal = (MAPS[$game_map.map_id] || [])[2] || {}
      !goal.empty? && placed == goal.length
    end
  end
end

PokeAccess::Game.define("reborn") do
  logic = PokeAccess::RebornVrLogic
  logic::MAPS.each do |map, (gate, checker, goal)|
    mechanic(:state, map, :part => :logic) do
      auto
      name logic::BLOCK, lambda { |ev| logic.label(ev) }
      count :rbc2_logic_count, :value => lambda { logic.placed }, :of => goal.length, :assist => true
      right_choice checker, :takes => lambda { logic.all_placed? ? { :switch => gate, :to => true } : nil }
      arrival_hint :rbc2_logic_rule
      hint :rbc2_logic_hint
      solved { $game_switches[gate] }
    end
  end
end
