# Serenity Labs: five ladder pieces (map 324 events 4 to 6, map 325 events 15 and 16) add to variable 73 from 2 to 7
# once the virologist asks; then Radon (map 328, event 21) asks for six sewers welded shut, one door on each of six maps
# (switch 130 on), each adding to variable 74 and clearing its switch (412 to 417). Counts wait for the info key.
module PokeAccess
  module AshenSerenityLabs
    SEWERS = { 317 => [6, 415], 320 => [16, 416], 324 => [16, 413], 325 => [32, 412], 327 => [4, 414], 334 => [19, 417] }
    PIECES = { 324 => [4, 5, 6], 325 => [15, 16] }

    # The ladder pieces found, while the virologist waits for them; nil before or after.
    def self.pieces
      v = $game_variables[73].to_i
      v >= 2 && v < 7 ? v - 2 : nil
    end

    # True while sewers are left to weld.
    def self.welding?
      $game_switches[130] && $game_variables[74].to_i < 6 ? true : false
    end

    # The sewers welded, at most the six asked for.
    def self.welded
      [$game_variables[74].to_i, 6].min
    end

    # With the assist, the rooms whose sewer is still open, by the game's own map names; how many are left where a room
    # has no name to say.
    def self.sewers_hint
      left = SEWERS.keys.sort.select { |m| $game_switches[SEWERS[m][1]] }
      return nil if left.empty?
      names = left.map { |m| PokeAccess::Locator.map_name(m).to_s.strip }
      return [:afi_sl_sewers_left, { :n => left.length }] if names.any? { |n| n.empty? }
      [:afg_sl_sewers_hint, { :rooms => PokeAccess::Routes::Text.and_list(names) }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  sl = PokeAccess::AshenSerenityLabs
  sl::PIECES.each do |map, ids|
    mechanic(:state, map, :part => :ladder) do
      auto
      name ids, :afg_sl_piece
      count :afg_sl_pieces, :value => lambda { sl.pieces.to_i }, :of => 5, :announce => false
      solved(nil, :quiet => true) { $game_variables[73].to_i >= 7 }
      active { !sl.pieces.nil? }
    end
  end
  sl::SEWERS.each do |map, sewer|
    mechanic(:state, map, :part => :sewers) do
      auto
      name sewer[0], :afg_sl_sewer, :when => lambda { |_ev| sl.welding? && $game_switches[sewer[1]] ? true : false }
      count :afg_sl_welded, :value => lambda { sl.welded }, :of => 6, :announce => false
      hint lambda { sl.sewers_hint }
      solved(nil, :quiet => true) { $game_variables[74].to_i >= 6 }
      active { sl.welding? }
    end
  end
end
