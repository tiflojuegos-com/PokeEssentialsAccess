# FL's Advanced Pokedex (plugins/advanced_pokedex.rb) on its v17 copies (Soulstones, Awakening): a label left with no
# value, "HOLD ITEMS: " on the first line of its column, stays apart from the "EVO: ..." painted three lines below,
# while a label heading a list still takes the entry right under it.
module AdvancedPokedexLabelsSpec
  # The page's text for a sub-page painted with these grid rows ([text, x, y]) above its name and page count.
  def self.read(grid, count)
    pairs = (grid + [["Bulbasaur", 292, 298], [count, 460, 330]]).map { |t, x, y| [t, :positions, x, y] }
    PokeAccess::AdvancedPokedex.text(Object.new, pairs, false)
  end
end

Suite.define("advanced pokedex: an empty label stays apart from a label or a row that does not finish it") do
  spec = AdvancedPokedexLabelsSpec
  page = lambda { |n| PokeAccess::I18n.t(:adv_dex_page, :n => n.to_s, :m => "9") }
  grid = [["HOLD ITEMS: ", 32, 64], ["EVO: Ivysaur at level 16", 32, 160]]
  eq "the empty label and the evolution as two lines, then the page", spec.read(grid, "3/9"),
     ["HOLD ITEMS:", "EVO: Ivysaur at level 16", page.call(3)].join(", ")

  gap = [["HOLD ITEMS: ", 32, 64], ["Ivysaur at level 16", 32, 160],
         ["BASE EXP: 64", 256, 64], ["COLOR: Green", 256, 96]]
  eq "nor does a row lines below it in its column", spec.read(gap, "3/9"),
     ["HOLD ITEMS:", "Ivysaur at level 16", "BASE EXP: 64", "COLOR: Green", page.call(3)].join(", ")

  moves = [["LEVEL MOVES:", 32, 64], ["01 Tackle", 32, 96], ["03 Growl", 32, 128], ["07 Leech Seed", 256, 96]]
  eq "a label heading a list takes the entry on the line under it", spec.read(moves, "4/9"),
     ["LEVEL MOVES: 01 Tackle", "03 Growl", "07 Leech Seed", page.call(4)].join(", ")
end
