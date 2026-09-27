# The Purify Chamber's set overview (count, shadow, tempo, purifiable), over a fake of the gen-6 chamber API
# (setCount, getShadow, isPurifiable?, [], class.maximumTempo).
Suite.define("menus: purify chamber set overview") do
  fake_set = Class.new do
    def initialize(len, tempo); @len = len; @tempo = tempo; end
    def length; @len; end
    def tempo; @tempo; end
  end
  shadow = Class.new { def name; "Larvitar oscuro"; end }
  chamber = Class.new do
    def self.maximumTempo; 30; end
    def initialize(sets, shadows, purif); @sets = sets; @shadows = shadows; @purif = purif; end
    def setCount(i); @sets[i] ? @sets[i].length : 0; end
    def [](i); @sets[i]; end
    def getShadow(i); @shadows[i]; end
    def isPurifiable?(i); @purif[i]; end
  end
  pch = chamber.new([fake_set.new(3, 20), fake_set.new(0, 0)], [shadow.new, nil], [true, false])
  pexp = [PokeAccess::I18n.t(:pchm_set, :n => 1), PokeAccess::I18n.t(:pchm_count, :n => 3),
          PokeAccess::I18n.t(:pchm_shadow, :name => "Larvitar oscuro"),
          PokeAccess::I18n.t(:pchm_tempo, :n => 20, :max => 30), PokeAccess::I18n.t(:pchm_purifiable)].join(", ")
  eq "a set with a shadow pokemon", PokeAccess::PurifyChamber.set_text(pch, 0), pexp
  eq "an empty set",
     PokeAccess::PurifyChamber.set_text(pch, 1),
     [PokeAccess::I18n.t(:pchm_set, :n => 2), PokeAccess::I18n.t(:pchm_empty)].join(", ")
  truthy "nil chamber is nil", PokeAccess::PurifyChamber.set_text(nil, 0).nil?

  t = PokeAccess::I18n
  rows = vb_levels { PokeAccess::PurifyChamber.set_text(pch, 0) }
  eq "brief: the set, its shadow Pokemon and whether it can be purified", rows[0],
     [t.t(:pchm_set, :n => 1), t.t(:pchm_shadow, :name => "Larvitar oscuro"), t.t(:pchm_purifiable)].join(", ")
  eq "medium: and how many it holds", rows[1],
     [t.t(:pchm_set, :n => 1), t.t(:pchm_count, :n => 3), t.t(:pchm_shadow, :name => "Larvitar oscuro"),
      t.t(:pchm_purifiable)].join(", ")
  eq "full: the tempo too, as it always said", rows[2], pexp
  PokeAccess::Config.verbosity = :brief
  PokeAccess::PurifyChamber.set_text(pch, 0)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole set", PokeAccess::Info.info_text, pexp
end

# Encounter list: a type header + species (name + Pokedex status), capped at 15 with "and N more". A
# species never seen is a silhouette on screen, and is said as unknown without its name.
Suite.define("menus: encounter list summary") do
  entries = [["Pidgey", :dex_caught], ["Rattata", :dex_seen], ["Caterpie", :dex_unknown]]
  exp = "#{PokeAccess::I18n.t(:enc_type, :type => 'Hierba alta', :n => 3)}: " \
        "Pidgey #{PokeAccess::I18n.t(:dex_caught)}, Rattata #{PokeAccess::I18n.t(:dex_seen)}, " \
        "#{PokeAccess::I18n.t(:dex_unknown)}"
  eq "type plus species", PokeAccess::EncounterList.summary("Hierba alta", entries), exp
  eq "empty is just the header",
     PokeAccess::EncounterList.summary("Agua", []), PokeAccess::I18n.t(:enc_type, :type => "Agua", :n => 0)
  truthy "nil is nil", PokeAccess::EncounterList.summary("x", nil).nil?
  big = (1..17).map { |k| ["Sp#{k}", :dex_seen] }
  truthy "caps at 15 plus the remainder",
         PokeAccess::EncounterList.summary("Cueva", big).include?(PokeAccess::I18n.t(:enc_more, :n => 2)) &&
         !PokeAccess::EncounterList.summary("Cueva", big).include?("Sp16")

  t = PokeAccess::I18n
  rows = vb_levels { PokeAccess::EncounterList.summary("Hierba alta", entries) }
  eq "brief: the type and each species by name", rows[0], "Hierba alta: Pidgey, Rattata, #{t.t(:dex_unknown)}"
  eq "medium: with their state", rows[1],
     "Hierba alta: Pidgey #{t.t(:dex_caught)}, Rattata #{t.t(:dex_seen)}, #{t.t(:dex_unknown)}"
  eq "full: and how many there are", rows[2], exp
  PokeAccess::Config.verbosity = :brief
  eq "the info key's line is whole at any level", PokeAccess::EncounterList.summary("Hierba alta", entries, true), exp
  eq "and an empty type says so at any level", PokeAccess::EncounterList.summary("Agua", []),
     t.t(:enc_type, :type => "Agua", :n => 0)
  PokeAccess::Config.verbosity = :full
end

# Generic auto-detect reads a window's focused entry from its own data: a string, symbol, .name or .text only.
Suite.define("menus: conservative auto-detect of focused entries") do
  win_cmd = Class.new { def initialize(c); @commands = c; end }
  win_items = Class.new { def initialize(i); @items = i; end }
  win_list = Class.new { def initialize(l); @list = l; end }
  named = Class.new { def initialize(n); @n = n; end; def name; @n; end }
  texted = Class.new { def initialize(t); @t = t; end; def text; @t; end }

  eq "entry string", PokeAccess::Menus.entry_text("Bolsa"), "Bolsa"
  eq "entry symbol", PokeAccess::Menus.entry_text(:Pokedex), "Pokedex"
  eq "entry .name", PokeAccess::Menus.entry_text(named.new("Curar")), "Curar"
  eq "entry .text", PokeAccess::Menus.entry_text(texted.new("Hola")), "Hola"
  truthy "entry pair/id/nil is nil",
         PokeAccess::Menus.entry_text([5, 3]).nil? && PokeAccess::Menus.entry_text(7).nil? &&
         PokeAccess::Menus.entry_text(nil).nil?
  eq "generic_focus @commands", PokeAccess::Menus.generic_focus(win_cmd.new(["Uno", "Dos", "Tres"]), 1), "Dos"
  eq "generic_focus @items by .name",
     PokeAccess::Menus.generic_focus(win_items.new([named.new("A"), named.new("B")]), 1), "B"
  truthy "generic_focus pairs are nil (no garbage)",
         PokeAccess::Menus.generic_focus(win_list.new([[1, 2], [3, 4]]), 0).nil?
  truthy "generic_focus out-of-range is nil",
         PokeAccess::Menus.generic_focus(win_cmd.new(["X"]), 5).nil?
end
