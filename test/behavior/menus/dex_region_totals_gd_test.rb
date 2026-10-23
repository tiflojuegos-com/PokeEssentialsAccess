# The multi-dex region list (Window_DexesList): a region's seen and owned counters, against its total where the row
# has one, with the complete and all-seen marks its filled icons show, at the Pokedex reading's levels; the info key
# keeps the whole row. Gamedata pass.
class Window_DexesList < Window_CommandPokemon
  attr_accessor :commands2
end

class DexRegionTotalsGdTest < PokeAccessTest
  REGIONS = ["Kanto", "Johto", "Hoenn", "Sinnoh"]

  test "a region says seen and owned against its total, and a complete or an all-seen dex as such" do
    win = dexes([[120, 80, 151], [251, 251, 251], [202, 150, 202], [1, 0, 1]])
    { 0 => counts_tot("Kanto", 120, 80, 151),
      1 => "#{counts_tot('Johto', 251, 251, 251)}, #{t(:dex_region_complete)}",
      2 => "#{counts_tot('Hoenn', 202, 150, 202)}, #{t(:dex_region_all_seen)}",
      3 => "#{counts_tot('Sinnoh', 1, 0, 1)}, #{t(:dex_region_all_seen)}" }.each do |i, want|
      assert_equal want, row(win, i), "row #{i}"
    end
  end

  test "brief says the region and its mark, medium adds the counters and full their total" do
    win = dexes([[120, 80, 151], [251, 251, 251]])
    complete = t(:dex_region_complete)
    assert_equal ["Kanto", counts("Kanto", 120, 80), counts_tot("Kanto", 120, 80, 151)], vb_levels { row(win, 0) }
    assert_equal ["Johto, #{complete}", "#{counts('Johto', 251, 251)}, #{complete}",
                  "#{counts_tot('Johto', 251, 251, 251)}, #{complete}"],
                 vb_levels { row(win, 1) }
  end

  test "the info key keeps the whole row at any level" do
    win = dexes([[251, 251, 251]])
    PokeAccess::Config.verbosity = :brief
    row(win, 0)
    assert_equal "#{counts_tot('Kanto', 251, 251, 251)}, #{t(:dex_region_complete)}", PokeAccess::Info.info_text
  end

  test "a row with no total says its counters, with no mark even when it owns all it has seen" do
    win = dexes([[120, 80], [30, 30]])
    assert_equal counts("Kanto", 120, 80), row(win, 0)
    assert_equal counts("Johto", 30, 30), row(win, 1)
  end

  test "a total of 0 is no total" do
    assert_equal counts("Kanto", 0, 0), row(dexes([[0, 0, 0]]), 0)
  end

  test "the older list keeps its counters in seen and owned lists, and the row past them is its name alone" do
    win = Window_DexesList.new(["Kanto", "Johto", "Salir"])
    win.instance_variable_set(:@seen, [120, 30])
    win.instance_variable_set(:@owned, [80, 30])
    assert_equal [counts("Kanto", 120, 80), counts("Johto", 30, 30), "Salir"], (0..2).map { |i| row(win, i) }
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The list of REGIONS with each row's painted counters, [seen, owned] or [seen, owned, total].
  def dexes(counters)
    win = Window_DexesList.new(REGIONS.first(counters.length))
    win.commands2 = counters
    win
  end

  # The text the list's row i is read with.
  def row(win, i)
    win.index = i
    PokeAccess::Menus.focused_text(win)
  end

  def counts(name, seen, owned)
    t(:dex_region_counts, :name => name, :seen => seen, :owned => owned)
  end

  def counts_tot(name, seen, owned, tot)
    t(:dex_region_counts_tot, :name => name, :seen => seen, :owned => owned, :tot => tot)
  end
end
