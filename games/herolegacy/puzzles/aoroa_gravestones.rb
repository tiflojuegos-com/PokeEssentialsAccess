# Quest 36's gravestones, drawn by the map's tiles: Paiata (map 137, event 41), Taipuia (121, event 101) and Route 16
# (306, event 47). Once Herbert asks for them (variable 67 at 4), each has a hollow that takes one item: an Ice Stone,
# a Hard Stone and an Iron Ball. The game names the item only to a player who carries it, and placing it turns the
# stone's self switch A on. With the assist, the item is said after the epitaph's last line, with the places of the
# gravestones still empty.
module PokeAccess
  module HeroLegacyGravestones
    STONES = { 137 => [41, :ICESTONE], 121 => [101, :HARDSTONE], 306 => [47, :IRONBALL] }

    # True while a map's gravestone waits for its item.
    def self.open?(map_id)
      $game_variables[67].to_i >= 4 && !$game_self_switches[[map_id, STONES[map_id][0], "A"]]
    end

    # The assist's line for a map's gravestone: the item its hollow takes and where the other empty ones stand.
    def self.hint(map_id)
      return nil unless open?(map_id)
      item = PokeAccess::Data.item_name(STONES[map_id][1]).to_s
      others = STONES.keys.sort.select { |m| m != map_id && open?(m) }.map { |m| PokeAccess::Locator.map_name(m) }.compact
      return [:hl_grave_item, { :item => item }] if others.empty?
      [:hl_grave_item_others, { :item => item, :places => others.join(", ") }]
    end
  end
end

PokeAccess::Game.define("herolegacy") do
  graves = PokeAccess::HeroLegacyGravestones
  graves::STONES.each do |map_id, stone|
    mechanic(:state, map_id) do
      auto
      name stone[0], :hl_gravestone, :when => lambda { |_ev| graves.open?(map_id) }
      on_reach stone[0], { :text => 2 }, lambda { graves.hint(map_id) }, :assist => true
    end
  end
end
