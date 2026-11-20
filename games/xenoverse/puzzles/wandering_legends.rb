# Legendaries that change place as the player nears them. The past Aranciopoli (map 428): Mew (event 4) flees as the
# player steps by (switch 469), then shows up elsewhere twice (events 24 and 25, switches 470 and 471) before it fights at
# event 26. The DNA Zone (map 434): the triangle moves each time it is touched (switches 475 to 478) until Deoxys comes.
# A sighted player sees each one vanish, so it is said as it goes; the lists show where it went.
module PokeAccess
  module XenoLegends
    PAST = 428
    MEW = [4, 24, 25, 26]
    MEW_JUMPS = [469, 470, 471]
    DNA = 434
    TRIANGLE = /\ATriangle_/
    TRIANGLE_MOVES = [475, 476, 477, 478]

    # Mew's name as the game's data gives it.
    def self.mew
      PokeAccess::Data.species_name(:MEW)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  legends = PokeAccess::XenoLegends
  mechanic(:state, legends::PAST) do
    auto
    name legends::MEW, lambda { |_ev| legends.mew }
    legends::MEW_JUMPS.each do |sw|
      watch :switch => sw, :say => lambda { [:xv_legend_gone, { :pokemon => legends.mew }] }
    end
  end

  mechanic(:state, legends::DNA) do
    auto
    name legends::TRIANGLE, :xv_triangle
    legends::TRIANGLE_MOVES.each { |sw| watch :switch => sw, :say => :xv_triangle_moved }
  end
end
