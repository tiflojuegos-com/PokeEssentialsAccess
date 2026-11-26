# East Gearen's gym (map 484), Venam's stage ringed by teleport tiles: two power switches (events 90 and 91, switches
# 772 and 773) power the backstage warp (event 120). Three numbered floor tiles (events 36, 37 and 35: 2, 3 and 4) count
# a secret code in variable 334; the eight right steps set switch 778 and wake a warp (event 111) to Gearen Alleyway.
module PokeAccess
  module RejuvEastGearenGym
    CODE = [2, 3, 3, 2, 4, 3, 3, 2]
    TILES = { 36 => 2, 37 => 3, 35 => 4 }
    POWER = { 90 => 772, 91 => 773 }

    # A power switch's name, on or off by its game switch.
    def self.power(ev)
      $game_switches[POWER[ev.id]] ? :rjd_eg_power_on : :rjd_eg_power_off
    end

    # With the assist, the code's next tile, from the count the game keeps; nil once it is complete.
    def self.code_hint
      step = $game_variables[334].to_i
      return nil if step < 0 || step >= CODE.length
      [:rjd_eg_code_next, { :n => CODE[step], :step => step + 1 }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  gym = PokeAccess::RejuvEastGearenGym
  mechanic(:state, 484, :part => :stage) do
    auto
    name gym::POWER.keys, lambda { |ev| gym.power(ev) }
    name 120, :rjd_eg_backstage_warp
    hint :rjd_eg_stage_hint
    active { !$game_switches[774] }
    solved { $game_switches[774] }
  end
  mechanic(:state, 484, :part => :code) do
    auto
    name gym::TILES.keys, lambda { |ev| [:rjd_eg_tile, { :n => gym::TILES[ev.id] }] }
    name 111, :rjd_eg_other_warp
    hint lambda { gym.code_hint }
    active { !$game_switches[778] }
    solved { $game_switches[778] }
  end
end
