# The pokedex area page. It is a map of coloured squares, so the only thing a blind player can get from it
# is the text painted over it, and the reader announced a composed line instead: "<species>'s area map",
# every time, on every build. On a species with no known locations Fire Ash paints, in so many words, "Area
# unknown" -- and the mod said there was an area map. That is not a gap, it is the mod asserting something
# the screen denies, which is the worst thing an accessibility reader can do.
#
# It also threw away the region name, the only thing that tells the same page apart between one regional dex
# and another.
#
# Driven through the real hooks, not by arming the capture by hand: the arming lives in a before-hook on
# drawPage and the taking in the after-hook, and a spec that armed it itself would stay green with both of
# them deleted.
Suite.define("pokedex: the page capture is taken on every page, not left armed for the next reader") do
  scene = PokemonPokedexInfo_Scene.new
  PokeAccess::PokedexInfoV21.painted = nil

  scene.drawPage(2)
  eq "what the page painted reached the reader",
     PokeAccess::PokedexInfoV21.painted, "Area unknown, Kanto"

  # Armed and taken means the collector is free again: whatever is painted next belongs to whoever arms it,
  # not to a page nobody took.
  PokeAccess::PaintCapture.arm(:some_other_reader)
  PokeAccess::PaintCapture.note("una fila ajena")
  eq "the next reader's capture is its own",
     PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:some_other_reader)), "una fila ajena"
end

Suite.define("pokedex: the area page says what it paints, and only falls back when it paints nothing") do
  pdx = PokeAccess::PokedexInfoV21

  eq "the page's own rows are what is spoken, the unknown-area notice included",
     pdx.area_text("Pikachu", "Area unknown, Kanto, Pikachu's area"), "Area unknown, Kanto, Pikachu's area"
  eq "a species with locations says its region and whose area it is, with no unknown notice",
     pdx.area_text("Pikachu", "Kanto, Pikachu's area"), "Kanto, Pikachu's area"
  eq "a page that painted no text at all falls back to the composed line",
     pdx.area_text("Pikachu", ""), PokeAccess::I18n.t(:pdx_zone, :name => "Pikachu")
  eq "and so does one that captured nothing", pdx.area_text("Pikachu", nil),
     PokeAccess::I18n.t(:pdx_zone, :name => "Pikachu")
end
