# Stolen Cargo (map 79): a belt runs up column 17. Arrow 22 at (17,27) sends the player left, or up with switch 1151;
# arrow 37 at (17,20) up, or right with 1152; monitors (57 and 48 on 1151, 69 on 1152), used facing up, flip them. Shock
# floors hurt and push only once switch 60 shorts the factory out. Door 47 resets arrow 22 and switch 60, not arrow 37.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 79, :part => :cargo) do
    auto
    name [48, 57], lambda { |_ev| PokeAccess::Puzzles.assist? ? :rj_cargo_monitor_lower : :rj_cargo_monitor }
    name 69, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rj_cargo_monitor_upper : :rj_cargo_monitor }
    name 22, lambda { |_ev| $game_switches[1151] ? :rj_cargo_arrow_up : :rj_cargo_arrow_left }
    name 37, lambda { |_ev| $game_switches[1152] ? :rj_cargo_arrow_right : :rj_cargo_arrow_up }
    name [43, 44, 45, 49], lambda { |_ev| $game_switches[60] ? :rj_cargo_floor_off : :rj_cargo_shock }
    name 71..74, lambda { |_ev| $game_switches[60] ? :rj_cargo_floor_off : :rj_cargo_shock }, :grouped => true
    active { PokeAccess::Puzzles.assist? }
    hint lambda { $game_switches[1151] && !$game_switches[1152] ? :rj_cargo_hint_straight : :rj_cargo_hint }
  end
end
