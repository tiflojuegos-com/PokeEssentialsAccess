# Royal's gym of Piston (map 165): conveyor belts of four colours, each colour reversed as a whole by the floor buttons of
# its colour (switches 151 purple, 152 red, 153 blue, 154 green). Buttons and belts are events with no sprite that act on
# touch; a belt reads the switches of the colours it follows and carries the player by a forced move.
module PokeAccess
  module RoyalBelts
    MAP = 165
    COLORS = { 151 => :royal_g3_color_purple, 152 => :royal_g3_color_red, 153 => :royal_g3_color_blue,
               154 => :royal_g3_color_green }
    BELTS = { 1 => [151], 3 => [151], 5 => [152], 6 => [153], 7 => [152, 153], 14 => [152], 17 => [151],
              18 => [151, 152], 19 => [151], 20 => [153], 22 => [152], 23 => [152], 24 => [152, 153], 28 => [152],
              29 => [152], 30 => [151, 152], 31 => [152], 32 => [151, 152], 33 => [151, 152, 154], 37 => [] }

    # A belt's name: the colours of the buttons that turn it, or just a belt where none does.
    def self.belt_label(ev)
      switches = BELTS[ev.id] || []
      return :royal_g3_belt_plain if switches.empty?
      colors = switches.map { |s| PokeAccess::I18n.t(COLORS[s]) }
      [:royal_g3_belt, { :colors => PokeAccess::Routes::Text.and_list(colors) }]
    end
  end
end

PokeAccess::Game.define("royal") do
  belts = PokeAccess::RoyalBelts
  mechanic(:state, belts::MAP) do
    watch :switch => 151, :label => :royal_g3_belts_purple, :on => :royal_g3_on, :off => :royal_g3_off
    watch :switch => 152, :label => :royal_g3_belts_red, :on => :royal_g3_on, :off => :royal_g3_off
    watch :switch => 153, :label => :royal_g3_belts_blue, :on => :royal_g3_on, :off => :royal_g3_off
    watch :switch => 154, :label => :royal_g3_belts_green, :on => :royal_g3_on, :off => :royal_g3_off
    controls
    name [35, 21, 2, 8], :royal_g3_button_purple, :numbered => true
    name [34, 4, 27, 25], :royal_g3_button_red, :numbered => true
    name [15, 26], :royal_g3_button_blue, :numbered => true
    name 16, :royal_g3_button_green
    avoid [35, 21, 2, 8, 34, 4, 27, 25, 15, 26, 16]
    name belts::BELTS.keys, lambda { |ev| belts.belt_label(ev) }
    solved(nil) { $game_variables[111].to_i >= 1 }
    arrival_hint :royal_g3_rule
    hint :royal_g3_hint
  end
end
