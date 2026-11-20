# Abandoned Subway (map 396): fourteen control panels, each turning its lever through two or three positions (variables
# 251 to 264, from 0, said as each is pressed); Cara (event 2) checks the nine true ones and boards the train with switch
# 177 once they stand at 0, 0, 1, 0, 1, 2, 1, 1, 2, and "Reset Tracks" puts them all back at 0, said in her own words.
# The five "Fake" panels move rails that lead nowhere. The panels are numbered in reading order, as the screen shows them.
module PokeAccess
  module SoulstonesSubway
    # Panels in reading order: [event, variable, positions, right position or nil for a fake one].
    PANELS = [[98, 258, 2, 1], [109, 259, 3, 2], [131, 261, 3, nil], [149, 263, 2, nil], [87, 257, 3, 1],
              [74, 256, 3, 2], [118, 260, 2, nil], [140, 262, 2, nil], [64, 255, 2, 1], [160, 264, 3, nil],
              [48, 254, 2, 0], [32, 253, 3, 1], [12, 251, 2, 0], [22, 252, 2, 0]]
    BOARDED = 177

    # The panel's number in reading order, from 1.
    def self.number(ev_id)
      PANELS.index { |p| p[0] == ev_id }.to_i + 1
    end

    # The name of a panel: its number, and with the assist whether it is a fake one.
    def self.label(ev)
      fake = PANELS.find { |p| p[0] == ev.id }[3].nil?
      [fake && PokeAccess::Puzzles.assist? ? :ss1_subway_fake : :ss1_subway_panel, { :n => number(ev.id) }]
    end

    # What pressing a panel shows, said as its page starts: the position its lever moves to; nothing once aboard, as the
    # panels no longer move.
    def self.press_line(ev)
      return nil if $game_switches[BOARDED]
      panel = PANELS.find { |p| p[0] == ev.id }
      [:ss1_subway_moved, { :n => number(ev.id), :pos => ($game_variables[panel[1]].to_i + 1) % panel[2] }]
    end

    # The presses each true panel still needs, as [[number, presses], ...].
    def self.presses
      out = []
      PANELS.each_with_index do |(_ev, var, size, right), i|
        next if right.nil?
        n = (right - $game_variables[var].to_i) % size
        out.push([i + 1, n]) if n > 0
      end
      out
    end

    # The assist's line: the presses left, panel by panel, or to ask Cara.
    def self.hint
      left = presses
      return :ss1_subway_ready if left.empty?
      parts = left.map { |n, k| PokeAccess::I18n.t(:ss1_subway_press, :panel => n, :n => k) }
      [:ss1_subway_hint, { :list => PokeAccess::Routes::Text.and_list(parts) }]
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  sub = PokeAccess::SoulstonesSubway

  mechanic(:state, 396) do
    auto
    on_use sub::PANELS.map { |p| p[0] }, lambda { |ev| sub.press_line(ev) }

    name sub::PANELS.map { |p| p[0] }, lambda { |ev| sub.label(ev) },
         :when => lambda { |_ev| !$game_switches[sub::BOARDED] }
    arrival_hint :ss1_subway_rule, :once => true
    hint lambda { sub.hint }
    solved { $game_switches[sub::BOARDED] }
  end
end
