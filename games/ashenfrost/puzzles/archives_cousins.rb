# Ashen Frost's Olde Riverviewe Archives (map 351, Case Six): three hidden children (EV13 to EV15) each add 1 to
# variable 78 as found. The game gives no total until the last, so the count comes with the assist alone.
module PokeAccess
  module AshenArchivesCousins
    MAP = 351
    KIDS = [13, 14, 15]
    VAR = 78
  end
end

PokeAccess::Game.define("ashenfrost") do
  cousins = PokeAccess::AshenArchivesCousins
  mechanic(:state, cousins::MAP) do
    auto
    name cousins::KIDS, :afb_hiding_kid
    count :afb_kids_found, :value => lambda { [$game_variables[cousins::VAR].to_i, cousins::KIDS.length].min },
                           :of => cousins::KIDS.length, :assist => true
    solved(nil, :quiet => true) { $game_variables[cousins::VAR].to_i >= cousins::KIDS.length }
  end
end
