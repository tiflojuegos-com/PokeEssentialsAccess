# Chrysalis Courtyard (map 391), the second trial's summoning board: console 46 waits for arrow presses (switch 802 on),
# each moving both pins (events 36 and 37) two tiles, short at a wall or the other pin. A phase (variable 680 at 0, 2 or
# 4) is won with both pins on its two marks, either way round; switch 803 is the end. The assist adds the next press.
module PokeAccess
  module RejuvPins
    MAP = 391
    PINS = [36, 37]
    BOARD = 46
    # Variable 680 while a phase is open => its two marks, west first.
    MARKS = { 0 => [[85, 25], [91, 25]], 2 => [[83, 27], [93, 23]], 4 => [[85, 23], [95, 27]] }
    # Per phase: the pins' tiles [x36, y36, x37, y37] => direction to press. Phase 2 restarts elsewhere than at
    # Reset when a pin is caught between marks.
    PLANS = {
      0 => { [83, 29, 93, 29] => 8, [83, 27, 93, 27] => 8, [83, 25, 93, 25] => 4, [83, 25, 91, 25] => 4,
             [83, 25, 89, 25] => 6 },
      2 => { [81, 27, 95, 29] => 4, [81, 27, 93, 29] => 8, [81, 27, 93, 27] => 8, [81, 27, 93, 25] => 8,
             [81, 27, 93, 23] => 6, [81, 27, 85, 23] => 2, [81, 29, 85, 25] => 6, [83, 29, 87, 25] => 6,
             [83, 29, 89, 25] => 6, [83, 29, 91, 25] => 6, [83, 29, 93, 25] => 8 },
      4 => { [89, 25, 87, 29] => 4, [87, 25, 87, 29] => 4, [85, 25, 87, 29] => 8, [85, 23, 87, 27] => 6,
             [85, 23, 89, 27] => 6, [85, 23, 91, 27] => 6, [85, 23, 93, 27] => 6 }
    }
    DIR_WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The open phase, by variable 680, or nil between phases and once the board is done.
    def self.stage
      return nil if $game_switches[803]
      v = $game_variables[680].to_i
      MARKS.key?(v) ? v : nil
    end

    # True while the console waits for a press on this map.
    def self.live?
      $game_map.map_id == MAP && $game_switches[802] && !stage.nil?
    end

    # The pins' tiles as [x36, y36, x37, y37], or nil without both.
    def self.tiles
      evs = PINS.map { |id| $game_map.events[id] }
      return nil if evs.include?(nil)
      evs.map { |ev| [ev.x, ev.y] }.flatten
    end

    # A pin's line: on a mark, or how far the nearer mark lies from it.
    def self.pin_line(n, x, y)
      marks = MARKS[stage]
      i = marks.index(marks.min_by { |m| (m[0] - x).abs + (m[1] - y).abs })
      mark = PokeAccess::I18n.t(i == 0 ? :rje_pins_west : :rje_pins_east)
      dist = PokeAccess::Puzzles.offset_phrase(marks[i][0] - x, marks[i][1] - y)
      return PokeAccess::I18n.t(:rje_pins_on, :n => n, :mark => mark) if dist.empty?
      PokeAccess::I18n.t(:rje_pins_far, :n => n, :mark => mark, :dist => dist)
    end

    # With the assist, the next press of the plan, or the way back onto it.
    def self.advice(t)
      d = PLANS[stage][t]
      return PokeAccess::I18n.t(:rje_pins_next, :dir => PokeAccess::I18n.t(DIR_WORDS[d])) if d
      PokeAccess::I18n.t(:rje_pins_reset, :key => PokeAccess::KeyHints.key(:x, "A"))
    end

    # Where both pins stand and, with the assist, what to press; nil while the board is not live.
    def self.line
      t = live? && tiles
      return nil unless t
      parts = [pin_line(1, t[0], t[1]), pin_line(2, t[2], t[3])]
      parts.push(advice(t)) if PokeAccess::Puzzles.assist?
      PokeAccess.sentences(parts)
    end

    # Says the line once the pins stop after a press or the board opens or resets, unless a message is up.
    def self.poll
      return @told = nil unless $game_map && live?
      return if PINS.any? { |id| (ev = $game_map.events[id]) && ev.moving? }
      return if ($game_temp.message_window_showing rescue false)
      t = tiles
      return if t.nil? || t == @told
      @told = t
      PokeAccess.speak(line, true)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  pins = PokeAccess::RejuvPins
  mechanic(:state, pins::MAP, :part => :pins) do
    auto
    name pins::BOARD, :rje_pins_board, :when => lambda { |_ev| !$game_switches[803] }
    name pins::PINS, lambda { |ev| [:rje_pins_name, { :n => pins::PINS.index(ev.id) + 1 }] }
    active { pins.live? }
    info { pins.line }
    solved(nil, :quiet => true) { $game_switches[803] }
  end
  poll_each_frame { PokeAccess::RejuvPins.poll }
end
