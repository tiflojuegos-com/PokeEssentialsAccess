# The Ruins of Alph's five chambers (maps 362, 364, 371, 373 and 374): a panel with no sprite on the north wall opens a
# Tile Puzzle, and each one solved adds 1 to var 40 (self switch A of the panel marks it done). Once var 40 reaches 5 a
# hole (event 4) opens at the top left of the Kabuto chamber (map 364), down to a room with a Mega Stone and a TM.
module PokeAccess
  module GgAlph
    PANELS = { 362 => 6, 364 => 3, 371 => 6, 373 => 6, 374 => 6 }
    SECRET_MAP = 364
    SECRET_HOLE = 4
  end
end

PokeAccess::Game.define("gruelinggold") do
  PokeAccess::GgAlph::PANELS.each do |map, panel|
    mechanic(:state, map) do
      auto
      name panel, :gg_alph_panel, :when => lambda { |_ev| !$game_self_switches[[map, panel, "A"]] }
      name PokeAccess::GgAlph::SECRET_HOLE, :gg_alph_secret_hole if map == PokeAccess::GgAlph::SECRET_MAP
      count :gg_alph_solved, :var => 40, :of => 5, :assist => true
      solved(nil, :quiet => true) { $game_variables[40].to_i >= 5 }
      hint :gg_alph_hint
    end
  end
end
