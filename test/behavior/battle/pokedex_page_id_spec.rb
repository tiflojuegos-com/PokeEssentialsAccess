# Which page the pokedex entry screen is showing. There are two shapes of that screen and the reader has to
# answer for both: plain Essentials dispatches drawPage(page) on a number, while the Modular UI Scenes plugin
# rewrites the screen into named pages and keeps the current one in @page_id.
#
# Reading only @page_id passed every test we had, because every test -- and every game anyone had checked --
# shipped MUI. On the three that do not (awakening and both Infinite Fusion) the reader fell back to the info
# page on every redraw, so left and right produced identical text and the dedup swallowed it. No error, no
# missing hook, nothing in Hooks.missing: the class is there, drawPage is there, the hook binds perfectly and
# the page just never speaks. That is why the assertion that matters below is that the three plain pages come
# out DIFFERENT from each other -- an implementation that ignores the argument satisfies everything else.
Suite.define("battle: the pokedex page is identified on the plain screen, not just the MUI one") do
  pdx = PokeAccess::PokedexInfoV21
  plain = Object.new

  eq "page 1 is the info page", pdx.page_id(plain, 1), :page_info
  eq "page 2 is the area map", pdx.page_id(plain, 2), :page_area
  eq "page 3 is the forms page", pdx.page_id(plain, 3), :page_forms

  ids = [pdx.page_id(plain, 1), pdx.page_id(plain, 2), pdx.page_id(plain, 3)]
  eq "and the three are told apart, which is the whole bug: identical ids read as one page",
     ids.uniq.length, 3

  # A number the screen never passes must not invent a page; the caller reads nil as the info page rather
  # than announcing something that is not on screen.
  falsy "an unknown page number yields no id", pdx.page_id(plain, 9)
  falsy "and neither does a missing argument", pdx.page_id(plain, nil)
end

# On the four games that ship MUI, @page_id is the authority whenever it is set, whatever number the call
# carried.
Suite.define("battle: MUI's page name still wins over the argument") do
  pdx = PokeAccess::PokedexInfoV21
  mui = Object.new
  mui.instance_variable_set(:@page_id, :page_data)

  eq "the plugin's own page id is used", pdx.page_id(mui, 1), :page_data

  mui.instance_variable_set(:@page_id, :page_area)
  eq "and it keeps winning when the two disagree", pdx.page_id(mui, 1), :page_area
end
