# Mirage Woods (map 149): trees, walls, cliffs, a tent, trucks and bridges that are mirages, drawn like the real ones.
# Walked into, each fades and can be crossed, and some take others with them; behind them lie Mirage Cave (the wall at
# 14,56) and hidden items. The way through the woods does not need them.
module PokeAccess
  module RejuvMirageWoods
    NAME = /\AMirage (Tree|CLIFF|Tent|wall|Truck|Bridge)\z/i

    # True once a mirage has faded, as the game draws it.
    def self.faded?(ev)
      (ev.opacity rescue 255).to_i < 255
    end

    # True while a mirage is drawn, by a sheet or a tile.
    def self.drawn?(ev)
      !ev.character_name.to_s.empty? || ev.tile_id.to_i > 0
    end

    # A mirage's name: faded for anyone; still whole, with the assist alone.
    def self.label(ev)
      return :rjg_mw_faded if faded?(ev)
      PokeAccess::Puzzles.assist? ? :rjg_mw_mirage : nil
    end

    # True while a mirage is listed: drawn, and faded or with the assist.
    def self.listed?(ev)
      drawn?(ev) && (faded?(ev) || PokeAccess::Puzzles.assist?)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  mw = PokeAccess::RejuvMirageWoods
  mechanic(:state, 149, :part => :mirages) do
    auto
    name(mw::NAME, lambda { |ev| mw.label(ev) }, :when => lambda { |ev| mw.listed?(ev) })
    active { PokeAccess::Puzzles.assist? }
    hint :rjg_mw_hint
  end
end
