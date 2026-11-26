# Ashen Frost's escape from Priya's condo (map 15, Case Nine): the vent panel (EV9, a tile puzzle) and a hanger (EV2 or
# EV3) make a lockpick in either order; it opens closet door B (EV7), whose second use gives the rope; the rope on the
# mannequin (EV10) frees the player. The core leads the tile puzzle; the assist says what to use next.
module PokeAccess
  module AshenPriyaBasement
    MAP = 15
    PANEL = 9
    HANGERS = [2, 3]
    CLOSET = 7
    MANNEQUIN = 10

    # Whether a self switch of this map's event is on.
    def self.on?(ev, letter = "A")
      $game_self_switches[[MAP, ev, letter]] ? true : false
    end

    # The step the escape is at: what the player is to use next; nil once free.
    def self.step
      return :panel unless on?(PANEL)
      return :hanger unless on?(HANGERS[0])
      return :closet unless on?(CLOSET)
      return :rope unless on?(CLOSET, "B")
      return :mannequin unless on?(MANNEQUIN)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  basement = PokeAccess::AshenPriyaBasement
  mechanic(:state, basement::MAP) do
    auto
    name basement::PANEL, :afb_priya_panel
    name basement::HANGERS, :afb_priya_hanger, :grouped => true
    name basement::CLOSET, :afb_priya_closet
    name basement::MANNEQUIN, :afb_priya_mannequin
    { :panel => [basement::PANEL], :hanger => basement::HANGERS, :closet => [basement::CLOSET],
      :rope => [basement::CLOSET], :mannequin => [basement::MANNEQUIN] }.each do |step, evs|
      phase lambda { PokeAccess::Puzzles.assist? && basement.step == step },
            :hint => "afb_priya_next_#{step}".to_sym, :hidden => right_way(*evs)
    end
    solved(nil, :quiet => true) { basement.step.nil? }
  end
end
