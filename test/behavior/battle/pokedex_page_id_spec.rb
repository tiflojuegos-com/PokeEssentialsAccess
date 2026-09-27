# PokedexInfoV21.page_id on the plain screen (awakening, both Infinite Fusion): drawPage's number names the page.
Suite.define("battle: the pokedex page is identified on the plain screen, not just the MUI one") do
  pdx = PokeAccess::PokedexInfoV21
  plain = Object.new

  eq "page 1 is the info page", pdx.page_id(plain, 1), :page_info
  eq "page 2 is the area map", pdx.page_id(plain, 2), :page_area
  eq "page 3 is the forms page", pdx.page_id(plain, 3), :page_forms

  ids = [pdx.page_id(plain, 1), pdx.page_id(plain, 2), pdx.page_id(plain, 3)]
  eq "and the three are told apart, which is the whole bug: identical ids read as one page",
     ids.uniq.length, 3

  eq "a page past the vanilla three is a page of its own", pdx.page_id(plain, 9), :page_other
  falsy "and a missing argument yields no id", pdx.page_id(plain, nil)
end

# With the Modular UI Scenes plugin, @page_id wins over the number whenever it is set.
Suite.define("battle: MUI's page name still wins over the argument") do
  pdx = PokeAccess::PokedexInfoV21
  mui = Object.new
  mui.instance_variable_set(:@page_id, :page_data)

  eq "the plugin's own page id is used", pdx.page_id(mui, 1), :page_data

  mui.instance_variable_set(:@page_id, :page_area)
  eq "and it keeps winning when the two disagree", pdx.page_id(mui, 1), :page_area
end
