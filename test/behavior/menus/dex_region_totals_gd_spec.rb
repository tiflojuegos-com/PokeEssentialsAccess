# The multi-dex Pokedex menu's region list (Window_DexesList). Its three-field shape keeps, per region, the
# seen and owned counters AND the region's total, and paints a filled icon for each counter that reached
# it -- the only mark of a complete dex on the screen. The reader said the two counters and nothing of
# the total, so the icon was invisible. The two-field shape (no total) keeps its old line.
class Window_DexesList < Window_CommandPokemon
  attr_accessor :commands2
end

Suite.define("dex menu: a region row says its counters against the total, and a full dex as such") do
  win = Window_DexesList.new(["Kanto", "Johto", "Hoenn"])
  win.commands2 = [[120, 80, 151], [251, 251, 251], [202, 150, 202]]
  t = lambda { |i| win.index = i; PokeAccess::Menus.focused_text(win) }

  eq "seen and owned are said against the region's total",
     t.call(0), PokeAccess::I18n.t(:dex_region_counts_tot, :name => "Kanto", :seen => 120, :owned => 80, :tot => 151)
  eq "every one owned is a complete dex",
     t.call(1), PokeAccess::I18n.t(:dex_region_counts_tot, :name => "Johto", :seen => 251, :owned => 251, :tot => 251) +
                ", " + PokeAccess::I18n.t(:dex_region_complete)
  eq "every one seen but not owned says so, and not complete",
     t.call(2), PokeAccess::I18n.t(:dex_region_counts_tot, :name => "Hoenn", :seen => 202, :owned => 150, :tot => 202) +
                ", " + PokeAccess::I18n.t(:dex_region_all_seen)

  win.commands2 = [[120, 80], [30, 30], [1, 1]]
  eq "the two-field shape has no total to say", t.call(0),
     PokeAccess::I18n.t(:dex_region_counts, :name => "Kanto", :seen => 120, :owned => 80)
end
