# Beryl Gym (map 162): six panels (events 7, 8, 12, 13, 14 and 15, in reading order) each flip a set of the six reactor
# tubes, switches 101 to 106, on red and off blue. A parallel event opens the door (switch 99) once all six are red, or
# all six blue after the police ambush (switch 98).
module PokeAccess
  module RebornBerylGym
    PANELS = [[7, [101, 102, 104]], [8, [101, 102, 103, 105]], [12, [102, 103, 106]],
              [13, [101, 104, 105]], [14, [102, 104, 105, 106]], [15, [103, 105, 106]]]
    TUBES = [101, 102, 103, 104, 105, 106]
    AMBUSH = 98
    OPEN = 99

    # True when the door waits for the tubes red, false for blue.
    def self.goal_red?; !$game_switches[AMBUSH]; end

    # The panels to press, by their place 1 to 6, fewest that turn every tube to the goal; empty when none.
    def self.presses
      wrong = TUBES.reject { |s| ($game_switches[s] ? true : false) == goal_red? }
      return [] if wrong.empty?
      best = nil
      (1...(1 << PANELS.length)).each do |mask|
        picked = (0...PANELS.length).select { |i| mask[i] == 1 }
        flips = Hash.new(0)
        picked.each { |i| PANELS[i][1].each { |s| flips[s] += 1 } }
        next unless TUBES.all? { |s| (flips[s] % 2 == 1) == wrong.include?(s) }
        best = picked if best.nil? || picked.length < best.length
      end
      (best || []).map { |i| i + 1 }
    end

    # With the assist, the panels to press for the door's colour.
    def self.hint
      list = presses
      return nil if list.empty?
      [goal_red? ? :rba_bg_hint_red : :rba_bg_hint_blue, { :list => list.join(", ") }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  beryl = PokeAccess::RebornBerylGym
  mechanic(:state, 162) do
    name beryl::PANELS.map { |id, _tubes| id }, :rba_bg_panel, :numbered => true
    beryl::TUBES.each_with_index do |s, i|
      watch :switch => s, :label => [:rba_bg_tube, { :n => i + 1 }], :on => :rba_bg_red, :off => :rba_bg_blue
    end
    hint lambda { beryl.hint }
    active { !$game_switches[beryl::OPEN] }
    solved(:rba_bg_open) { $game_switches[beryl::OPEN] }
  end
end
