# Ashen Frost's cell of Mordecai (map 453, Case Nine): a chain of things, each page opening the next with a self switch:
# toilet (EV5), shelf rolls (EV8), loose tile (EV17), bench chain (EV11, or EV12 faced from the right), sink (EV6),
# sewer (EV7). The courthouse's (map 454) first event sets its self switch A on arrival. The assist says the next one.
module PokeAccess
  module AshenMordecaiCell
    MAP = 453
    TOILET = 5
    SHELF = 8
    TILE = 17
    BENCH = 11
    SINK = 6
    SEWER = 7
    BENCHES = (9..16).to_a
    COURTHOUSE = 454

    # Whether a self switch of this map's event is on.
    def self.on?(ev, letter)
      $game_self_switches[[MAP, ev, letter]] ? true : false
    end

    # The step the escape is at: what the player is to use next.
    def self.step
      return :toilet unless on?(TOILET, "B")
      return :shelf unless on?(SHELF, "A")
      return :tile unless on?(TILE, "B")
      return :bench unless on?(BENCH, "A")
      return :sink unless on?(SINK, "A")
      :sewer
    end

    # Whether the player is out: the courthouse's first event has seen them in.
    def self.out?
      $game_self_switches[[COURTHOUSE, 1, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  cell = PokeAccess::AshenMordecaiCell
  mechanic(:state, cell::MAP) do
    auto
    name cell::TOILET, :afb_cell_toilet
    name cell::SHELF, :afb_cell_shelf
    name cell::TILE, :afb_cell_tile
    name cell::BENCHES, :afb_cell_bench, :grouped => true
    name cell::SINK, :afb_cell_sink
    name cell::SEWER, :afb_cell_sewer
    right_choice [cell::TOILET, cell::SHELF, cell::SINK], :takes => { :self => "A" }
    { :toilet => cell::TOILET, :shelf => cell::SHELF, :tile => cell::TILE, :bench => cell::BENCH, :sink => cell::SINK,
      :sewer => cell::SEWER }.each do |step, ev|
      phase lambda { PokeAccess::Puzzles.assist? && cell.step == step },
            :hint => "afb_cell_next_#{step}".to_sym, :hidden => right_way(ev)
    end
    solved(nil, :quiet => true) { cell.out? }
  end
end
