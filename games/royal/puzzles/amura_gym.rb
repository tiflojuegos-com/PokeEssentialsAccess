# Royal's gym of Amura (map 155): seven buttons set in the wall, each flipping the switch of one colour (blue 116, red 117,
# yellow 118), and the jets of water that block the way while that colour's page draws them. Half of a colour's jets go as
# the other half come. Each button is pressed from beside it.
module PokeAccess
  module RoyalPipes
    MAP = 155
    BLUE_JETS = [1..20, 55..58, 63..66]
    RED_JETS = [21..22, 25..33, 37..44, 67, 77..80]
    YELLOW_JETS = [23..24, 34..36, 45..54, 59..62, 68, 71..76, 104..107]
  end
end

PokeAccess::Game.define("royal") do
  pipes = PokeAccess::RoyalPipes
  mechanic(:state, pipes::MAP) do
    auto
    watch :switch => 116, :label => :royal_g2_pipes_blue, :on => :royal_g2_on, :off => :royal_g2_off
    watch :switch => 117, :label => :royal_g2_pipes_red, :on => :royal_g2_on, :off => :royal_g2_off
    watch :switch => 118, :label => :royal_g2_pipes_yellow, :on => :royal_g2_on, :off => :royal_g2_off
    controls
    obstacle({ :events => pipes::BLUE_JETS }, :label => :royal_g2_jets_blue)
    obstacle({ :events => pipes::RED_JETS }, :label => :royal_g2_jets_red)
    obstacle({ :events => pipes::YELLOW_JETS }, :label => :royal_g2_jets_yellow)
    name 91, :royal_g2_button_blue
    name 88..90, :royal_g2_button_red, :numbered => true
    name 85..87, :royal_g2_button_yellow, :numbered => true
    solved(nil) { $game_variables[94].to_i >= 2 }
    arrival_hint :royal_g2_rule
    hint :royal_g2_hint
  end
end
