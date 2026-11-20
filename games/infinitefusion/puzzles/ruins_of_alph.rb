# Ruins of Alph's tablets (chambers A to E, maps 345, 347, 348, 352 and 353): each tablet adds its chamber's letter to var 156,
# and the common event 21 wipes the string at a wrong letter and, at the seventh right one of ABDECBA, opens the Hidden Chamber
# (switch 340).
PokeAccess::Game.define("infinitefusion") do
  order = "ABDECBA"
  chambers = { 345 => "A", 347 => "B", 348 => "C", 352 => "D", 353 => "E" }
  open_chamber = lambda { $game_switches[340] }
  typed = lambda do
    word = $game_variables[156]
    word.is_a?(String) && word =~ /\A[A-E]*\z/ ? word.length : 0
  end

  chambers.each do |map, letter|
    mechanic(:state, map) do
      auto
      name 1, lambda { |_ev| PokeAccess::Puzzles.assist? ? [:ifu_alph_tablet_letter, { :letter => letter }] : :ifu_alph_tablet },
           :when => lambda { |_ev| !open_chamber.call }
      hint lambda {
        n = typed.call
        n < order.length ? [:ifu_alph_hint, { :order => order.split("").join(", "), :next => order[n, 1] }] : nil
      }
      active { PokeAccess::Puzzles.assist? && !open_chamber.call }
    end
  end
end
