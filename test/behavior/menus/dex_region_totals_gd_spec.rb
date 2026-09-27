# The multi-dex region list (Window_DexesList): the three-field shape says seen and owned against the region's total,
# and a complete dex as the filled icons show it; the two-field shape has no total to say.
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

  i18n = PokeAccess::I18n
  complete = i18n.t(:dex_region_complete)
  rows = vb_levels { t.call(1) }
  eq "brief: the region and whether it is complete", rows[0], "Johto, #{complete}"
  eq "medium: with its counters", rows[1],
     i18n.t(:dex_region_counts, :name => "Johto", :seen => 251, :owned => 251) + ", " + complete
  PokeAccess::Config.verbosity = :brief
  t.call(1)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the counters against the total", PokeAccess::Info.info_text,
     i18n.t(:dex_region_counts_tot, :name => "Johto", :seen => 251, :owned => 251, :tot => 251) + ", " + complete

  win.commands2 = [[120, 80], [30, 30], [1, 1]]
  eq "the two-field shape has no total to say", t.call(0),
     PokeAccess::I18n.t(:dex_region_counts, :name => "Kanto", :seen => 120, :owned => 80)
end
