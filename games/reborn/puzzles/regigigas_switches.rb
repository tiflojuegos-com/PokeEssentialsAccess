# Chrysolia Deepwoods (map 840), Regigigas' quest: secret switches hidden in trees and rocks each take variable 588 one
# further, in the order Smeargle paints. Two unnumbered switches, (106,73) outside the Arceus hall and (93,73) inside,
# swap its statues and hops (switch 1385): the hall is walked in with it on and crossed with it off.
module PokeAccess
  module RebornRegigigas
    MAP = 840
    QUEST = 588
    NEXT = { 1 => 44, 4 => 47, 5 => 48, 6 => 52, 7 => 53, 8 => 54, 9 => 55, 10 => 73, 11 => 74, 12 => 78, 14 => 91,
             15 => 92, 16 => 93, 17 => 94 }
    STATUES = [59, 60]
    OUTSIDE = 59
    INSIDE = 60
    LAYOUT = 1385
    HALL = [79, 97, 73, 77]
    STATUE_STAGES = { 10 => :west, 11 => :east, 12 => :west }
    ONWARD = [[70, 87], [71, 87]]
    BOULDERS = [[79, [95, 56]], [80, [98, 56]]]
    DONE = 18

    # The quest's count.
    def self.count
      $game_variables[QUEST].to_i
    end

    # True while the player stands in the Arceus hall.
    def self.in_hall?
      x0, x1, y0, y1 = HALL
      (x0..x1).include?($game_player.x) && (y0..y1).include?($game_player.y)
    end

    # The statue switch the next numbered one waits for, as [event, hint], or nil when the statues stand right.
    def self.statue_step
      need = STATUE_STAGES[count]
      return nil unless need
      on = $game_switches[LAYOUT] ? true : false
      if need == :west
        return [OUTSIDE, :rbrd_gigas_statues_in] if !on && !in_hall?
        return [INSIDE, :rbrd_gigas_statues_west] if on
      elsif !on
        return [INSIDE, :rbrd_gigas_statues_east]
      end
      nil
    end

    # The switch to press next: a statue switch, or the numbered one.
    def self.next_id
      s = statue_step
      s ? s[0] : NEXT[count]
    end

    # The name of a numbered switch: with the assist, the next one to press says so.
    def self.label(ev)
      PokeAccess::Puzzles.assist? && next_id == ev.id ? :rbi_gigas_switch_next : :rbi_gigas_switch
    end

    # The name of a statue switch: with the assist, the next one to press says so.
    def self.statue_label(ev)
      PokeAccess::Puzzles.assist? && next_id == ev.id ? :rbrd_gigas_statues_next : :rbi_gigas_statues
    end

    # True once a boulder stands at its place.
    def self.placed?(id, xy)
      ev = $game_map.events[id]
      ev && ev.x == xy[0] && ev.y == xy[1] ? true : false
    end

    # With the assist, what the count waits for: a statue switch, a switch or the tiles past the first; the boulders'
    # part says theirs.
    def self.hint
      s = statue_step
      return s[1] if s
      return :rbi_gigas_hint_onward if count == 2
      NEXT[count] ? :rbi_gigas_hint : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  gigas = PokeAccess::RebornRegigigas
  mechanic(:state, gigas::MAP, :part => :switches) do
    auto
    name gigas::NEXT.values, lambda { |ev| gigas.label(ev) }
    name gigas::STATUES, lambda { |ev| gigas.statue_label(ev) }
    gigas::ONWARD.each do |xy|
      spot :at => xy, :label => :rbi_gigas_onward, :assist => true, :onto => true, :when => lambda { gigas.count == 2 }
    end
    gigas::BOULDERS.each do |_id, xy|
      spot :at => xy, :label => :rbi_gigas_boulder_goal, :assist => true, :when => lambda { gigas.count == 13 }
    end
    hint lambda { gigas.hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !gigas.hint.nil? }
    solved(nil, :quiet => true) { gigas.count >= gigas::DONE }
  end
  mechanic(:state, gigas::MAP, :part => :boulders) do
    auto
    gigas::BOULDERS.each_with_index do |(id, (x, y)), i|
      phase lambda { gigas.count == 13 && gigas::BOULDERS[0, i].all? { |b| gigas.placed?(*b) } && !gigas.placed?(id, [x, y]) },
            :quiet => true, :hint => :rbi_gigas_hint_boulders,
            :track => { :event => id, :label => :rbrd_gigas_boulder, :goal => [x, y, x, y], :goal_label => :rbi_gigas_boulder_goal }
    end
  end
end
