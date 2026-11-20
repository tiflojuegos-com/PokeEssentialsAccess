# The Temple of Mesprit (map 184): a sandstorm covers the screen, and hidden gusts (touch events) throw the player
# straight ahead two to six tiles, the same way whatever they face. The lever (event 44) brings out one more gust (event
# 34, its self switch A), drawn. The way on to Mesprit is event 51 at (28, 6). Each gust's page is a move route on the
# player, which the routes read as a carry and ride with the puzzle assist; without it the hidden ones are unseen, stepped
# on as plain ground, as a sighted player meets them in the storm.
module PokeAccess
  module RealideaMesprit
    MAP = 184
    LEVER_GUST = 34
    DONE = 529

    # True for a gust the sandstorm hides: an event of the temple drawn with nothing whose page moves the player.
    def self.hidden_gust?(ev)
      return false unless ($game_map.map_id rescue 0) == MAP
      return false unless ev.character_name.to_s.empty? && ev.tile_id.to_i == 0
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| (c.code rescue 0) == 209 && (c.parameters[0] rescue nil) == -1 }
    end
  end
end

PokeAccess::Routes::Effects.touch_source do |ev|
  PokeAccess::RealideaMesprit.hidden_gust?(ev) && !PokeAccess::Puzzles.assist? ? :unseen : nil
end

PokeAccess::Game.define("realidea") do
  temple = PokeAccess::RealideaMesprit
  mechanic(:state, temple::MAP) do
    auto
    name temple::LEVER_GUST, :rea_mesprit_gust
    arrival_hint :rea_mesprit_rule
    solved(nil, :quiet => true) { $game_switches[temple::DONE] }
  end
end
