# The power panels of the Amethyst caves: seven panels (PANELS, by map) each add one to variable 342 once (self switch
# C). The grid 36 of the Mines, used facing up once variable 343 is 1, starts only with 342 at exactly 6, so a seventh
# panel leaves it dead; starting it sets 343 to 3.
module PokeAccess
  module RejuvAmethystPanels
    PANELS = { 162 => [11, 12], 109 => [20, 23, 24], 159 => [8], 161 => [9] }
    NEEDED = 6

    # Panels switched on so far, as the lights show them.
    def self.lit
      [$game_variables[342].to_i, NEEDED].min
    end

    # True once the grid has started.
    def self.done?
      $game_variables[343].to_i >= 3
    end

    # A panel's name: with the assist, once six are on and the grid has not started, one to leave alone.
    def self.label(ev)
      spare = PokeAccess::Puzzles.assist? && $game_variables[342].to_i >= NEEDED && !done?
      spare ? :rj_amethyst_panel_spare : :rj_amethyst_panel
    end

    # True while a panel has not been switched on.
    def self.unused?(ev)
      !$game_self_switches[[$game_map.map_id, ev.id, "C"]]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  amethyst = PokeAccess::RejuvAmethystPanels
  amethyst::PANELS.each do |map, ids|
    mechanic(:state, map, :part => :power_panels) do
      auto
      name ids, lambda { |ev| amethyst.label(ev) }, :when => lambda { |ev| amethyst.unused?(ev) }
      if map == 162
        name 36, :rj_amethyst_grid, :when => lambda { |_ev| $game_variables[343].to_i >= 1 && !amethyst.done? }
        count :rj_amethyst_lights, :value => lambda { amethyst.lit }, :of => amethyst::NEEDED, :announce => false
      else
        active { PokeAccess::Puzzles.assist? && !amethyst.done? }
        count :rj_amethyst_panels_on, :value => lambda { amethyst.lit }, :of => amethyst::NEEDED, :assist => true
      end
      hint :rj_amethyst_hint
      solved(nil, :quiet => true) { amethyst.done? }
    end
  end
end
