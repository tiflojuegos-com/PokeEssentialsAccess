# FL's Advanced Pokedex grid (plugins/advanced_pokedex.rb) as its v17 copies paint it (Soulstones, Awakening): a label
# left with no value stays a line of its own unless the row on the line right under it, in its column and with no
# label of its own, finishes it.
class AdvancedPokedexLabelsTest < PokeAccessTest
  test "keeps an empty label apart from a row with a label of its own" do
    grid = [["HOLD ITEMS: ", 32, 64], ["EVO: Ivysaur at level 16", 32, 160]]
    assert_equal ["HOLD ITEMS:", "EVO: Ivysaur at level 16", page(3)].join(", "), read(grid, "3/9")
  end

  test "keeps an empty label apart from a row lines below it in its column" do
    grid = [["HOLD ITEMS: ", 32, 64], ["Ivysaur at level 16", 32, 160],
            ["BASE EXP: 64", 256, 64], ["COLOR: Green", 256, 96]]
    assert_equal ["HOLD ITEMS:", "Ivysaur at level 16", "BASE EXP: 64", "COLOR: Green", page(3)].join(", "),
                 read(grid, "3/9")
  end

  test "joins a label heading a list to the entry right under it, and the rest of the list stays apart" do
    grid = [["BASE EXP: 64", 32, 64], ["COLOR: Green", 32, 96],
            ["LEVEL MOVES:", 256, 64], ["01 Tackle", 256, 96], ["03 Growl", 256, 128]]
    assert_equal ["BASE EXP: 64", "COLOR: Green", "LEVEL MOVES: 01 Tackle", "03 Growl", page(4)].join(", "),
                 read(grid, "4/9")
  end

  test "keeps an empty label that ends a column apart from the first row of the next" do
    grid = [["BASE EXP: 64", 32, 64], ["EGG MOVES:", 32, 96], ["Tackle", 256, 64], ["Growl", 256, 96]]
    assert_equal ["BASE EXP: 64", "EGG MOVES:", "Tackle", "Growl", page(5)].join(", "), read(grid, "5/9")
  end

  private

  # The page's text for a sub-page painted with these grid rows ([text, x, y]) above its name and its count.
  def read(grid, count)
    pairs = (grid + [["Bulbasaur", 292, 298], [count, 460, 330]]).map { |t, x, y| [t, :positions, x, y] }
    PokeAccess::AdvancedPokedex.text(Object.new, pairs, false)
  end

  # The spoken page count of sub-page n of nine.
  def page(n)
    PokeAccess::I18n.t(:adv_dex_page, :n => n.to_s, :m => "9")
  end
end
