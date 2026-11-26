# Dullfern Forest (map 25, episodes 7 and 8). Its spider webs are named and cleared by field.rb; with the assist, five
# of them (variables 79 to 83) shut the way west. Ariana's Chirp Perfect (event 127, switch 266): a pointer (variable
# 427) sweeps a bar between 54 and 460 by variable 429 per twentieth of a second, rising while switch 100 is on, and
# confirm must land in the green zone (variables 430 and 431); seven hits end it (429 from 3 to 24). Only the pictures
# show the sweep, so a tick sounds LEAD_STEPS ahead; with the assist, answering No to "Are you ready" skips it (switch
# 267).
module PokeAccess
  module SlldChirp
    MAP = 25
    LOW = 54
    HIGH = 460
    # Steps of the pointer, a twentieth of a second each, between the tick and the press it asks for.
    LEAD_STEPS = 4
    # The variables of the five webs that shut the way west, from the entrance on.
    WEBS = [79, 80, 81, 82, 83]

    # True while Ariana offers the game and it is not done.
    def self.offered?
      $game_switches[266] && !$game_switches[267]
    end

    # True while the bar is on screen.
    def self.running?
      ($game_map.map_id rescue 0) == MAP && ($game_screen.pictures[3].name rescue "") == "QTE_pointer"
    end

    # Where the pointer will be after steps, bouncing off the bar's ends as the event does.
    def self.ahead(pos, speed, rising, steps)
      steps.times do
        pos += rising ? speed : -speed
        rising = true if pos <= LOW
        rising = false if pos >= HIGH
      end
      pos
    end

    # Hits so far, from the speed the hits raise.
    def self.hits
      [($game_variables[429] - 3) / 3, 0].max
    end

    # Each frame of the bar: the tick as the pointer, a reaction later, comes into the zone.
    def self.poll
      return @inside = nil unless running?
      v = $game_variables
      at = ahead(v[427], v[429], $game_switches[100], LEAD_STEPS)
      inside = at >= v[430] && at <= v[431]
      PokeAccess::Sound.earcon(:minigame) if inside && @inside == false
      @inside = inside
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  chirp = PokeAccess::SlldChirp
  mechanic(:state, chirp::MAP, :part => :webs) do
    auto
    active { PokeAccess::Puzzles.assist? && chirp::WEBS.any? { |v| $game_variables[v] < 1 } }
    hint :slld_webs_hint
  end
  mechanic(:state, chirp::MAP, :part => :chirp) do
    auto
    count :slld_chirp_hits, :value => lambda { chirp.hits }, :of => 7, :assist => true, :hide_zero => true
    on_use 127, lambda { |_ev| chirp.offered? ? [:puzzle_answer, { :a => "No" }] : nil }, :assist => true
    active { chirp.offered? }
  end
  poll_each_frame { chirp.poll }
end
