# Vermilion's gym (map 112): two rows of lasers, events 1, 10, 31 to 33 (switch 43, first row) and 2, 6 to 9 (switch 44,
# second row), between the entrance and Surge. Fourteen trash cans with no sprite hold switches that say "Nothing."; only
# events 18 (switch 43) and 28 (switch 44) work. Surge's win (switch 6) ends it.
PokeAccess::Game.define("fireash") do
  lasers = [1, 10, 31, 32, 33, 2, 6, 7, 8, 9]
  cans = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 28, 29]
  working = [18, 28]
  mechanic(:state, 112) do
    watch :switch => 43, :say => :fa_surge_row_one
    watch :switch => 44, :say => :fa_surge_row_two
    count :fa_surge_switches, :switches => [43, 44], :of => 2, :announce => false
    name lasers, :fa_laser
    name working, lambda { |ev| PokeAccess::Puzzles.assist? ? :fa_trash_can_switch : :fa_trash_can }
    name cans - working, :fa_trash_can, :when => lambda { |_ev| !PokeAccess::Puzzles.assist? }
    hide cans - working, :assist => true
    arrival_hint :fa_surge_rule
    hint :fa_surge_hint
    solved { $game_switches[6] }
  end
end
