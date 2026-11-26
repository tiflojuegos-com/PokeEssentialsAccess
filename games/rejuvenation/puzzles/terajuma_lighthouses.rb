# Terajuma's lighthouses, (map 120, variable 311 at 6): plasma balls send the player back; six floor buttons set the
# reusable switches 1370, 1371, 1373, 1374, 1375 (the last opens the Ampharos room), so any of 32 sets can greet the
# arrival (7,47). Buttons 41 and 43 fade the ball at (21,47) out without changing its page while 1371 is off.
module PokeAccess
  module RejuvLighthousePlasma
    SWITCHES = [1370, 1371, 1373, 1374, 1375]
    BUTTONS = { 38 => 1, 39 => 2, 41 => 3, 45 => 4, 43 => 5, 47 => 6 }
    ROOMS = [[3, 10, 45, 55], [3, 7, 56, 62], [8, 13, 57, 62], [11, 16, 45, 50], [11, 15, 52, 56], [14, 23, 57, 62],
             [17, 20, 45, 50], [21, 24, 45, 50], [24, 29, 56, 62]]
    # The next button by the set of switches and the room, in ROOMS order: 0 once the way is open, nil where no way
    # reaches that room with that set.
    PLAN = {
      "00000" => [38, 45, 45, 38, 45, nil, nil, nil, nil],
      "00001" => [38, 45, 45, 38, 45, nil, nil, nil, nil],
      "00010" => [38, 47, 47, 38, 47, 47, nil, nil, 47],
      "00011" => [38, 0, 0, 38, 0, 0, nil, nil, 0],
      "00100" => [45, 45, 45, nil, 45, nil, nil, nil, nil],
      "00101" => [45, 45, 45, nil, 45, nil, nil, nil, nil],
      "00110" => [47, 47, 47, nil, 47, 47, nil, nil, 47],
      "00111" => [0, 0, 0, nil, 0, 0, nil, nil, 0],
      "01000" => [38, nil, nil, 38, nil, nil, 41, 41, nil],
      "01001" => [38, nil, nil, 38, nil, nil, 41, 41, nil],
      "01010" => [38, nil, nil, 38, nil, nil, 41, 41, nil],
      "01011" => [38, nil, nil, 38, nil, nil, 41, 41, nil],
      "01100" => [45, nil, nil, nil, 45, nil, 41, 41, nil],
      "01101" => [45, nil, nil, nil, 45, nil, 41, 41, nil],
      "01110" => [45, nil, nil, nil, 45, nil, 41, 41, nil],
      "01111" => [45, nil, nil, nil, 45, nil, 41, 41, nil],
      "10000" => [43, 43, nil, 43, nil, nil, 43, nil, nil],
      "10001" => [43, 43, nil, 43, nil, nil, 43, nil, nil],
      "10010" => [43, 43, nil, 43, nil, nil, 43, nil, nil],
      "10011" => [43, 43, nil, 43, nil, nil, 43, nil, nil],
      "10100" => [45, 45, 45, nil, 45, nil, nil, nil, nil],
      "10101" => [45, 45, 45, nil, 45, nil, nil, nil, nil],
      "10110" => [47, 47, 47, nil, 47, 47, nil, nil, 47],
      "10111" => [0, 0, 0, nil, 0, 0, nil, nil, 0],
      "11000" => [43, 43, nil, 43, nil, nil, 43, 43, nil],
      "11001" => [43, 43, nil, 43, nil, nil, 43, 43, nil],
      "11010" => [43, 43, nil, 43, nil, nil, 43, 43, nil],
      "11011" => [43, 43, nil, 43, nil, nil, 43, 43, nil],
      "11100" => [45, 45, nil, 38, 45, nil, 38, 38, nil],
      "11101" => [45, 45, nil, 38, 45, nil, 38, 38, 0],
      "11110" => [43, 43, nil, 38, 43, nil, 38, 38, nil],
      "11111" => [43, 43, nil, 38, 43, nil, 38, 38, nil]
    }

    # The five switches as a string of 0 and 1, in SWITCHES order.
    def self.state
      SWITCHES.map { |s| $game_switches[s] ? "1" : "0" }.join
    end

    # True on the second basement while its balls are the way on.
    def self.live?
      $game_variables[311].to_i == 6 && $game_player.x <= 30 && $game_player.y >= 43
    end

    # The player's room, its place in ROOMS, or nil past the last ball.
    def self.room
      x = $game_player.x
      y = $game_player.y
      ROOMS.index { |r| x >= r[0] && x <= r[1] && y >= r[2] && y <= r[3] }
    end

    # The next step from the player's room under the live switches: a button's event id, :open once no ball is left on
    # the way to the Ampharos room, or :restart where the plan has no way.
    def self.next_step
      r = room
      return :open unless r
      step = PLAN[state][r]
      return :restart if step.nil?
      step == 0 ? :open : step
    end

    # The assist's line: the next button by its number, that the way is open, or how to set the buttons off again.
    def self.hint
      step = next_step
      return :rjg_lh_open if step == :open
      return :rjg_lh_restart if step == :restart
      [:rjg_lh_next, { :n => BUTTONS[step] }]
    end

    # True while an event is drawn.
    def self.drawn?(ev)
      !ev.character_name.to_s.empty? || ev.tile_id.to_i > 0
    end

    # True while a ball keeps its drawn page but is faded out to nothing, still in the way.
    def self.unseen?(ev)
      drawn?(ev) && (ev.opacity rescue 255).to_i <= 0
    end

    # True while a ball is listed: drawn and seen, or faded out with the assist, which tells the barrier.
    def self.listed?(ev)
      drawn?(ev) && (!unseen?(ev) || PokeAccess::Puzzles.assist?)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  lh = PokeAccess::RejuvLighthousePlasma
  mechanic(:state, 120, :part => :plasma) do
    auto
    name lh::BUTTONS.keys, lambda { |ev| [:rjg_lh_button, { :n => lh::BUTTONS[ev.id] }] }
    name(/anim_plasma/, lambda { |ev| lh.unseen?(ev) ? :rjg_lh_unseen : :rjg_lh_ball },
         :when => lambda { |ev| lh.listed?(ev) })
    hide(/anim_plasma/, :when => lambda { |ev| lh.unseen?(ev) && !PokeAccess::Puzzles.assist? })
    avoid lh::BUTTONS.keys
    active { lh.live? }
    hint lambda { lh.hint }
    solved { $game_variables[311].to_i >= 7 }
  end
end
