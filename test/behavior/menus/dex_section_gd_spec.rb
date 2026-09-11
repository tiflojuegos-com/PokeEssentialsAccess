# The data page of the rewritten pokedex entry: ten sections the player walks with the cursor, each drawn as
# one paragraph. The name of the section is what says WHICH paragraph this is.
#
# Two things were wrong. The section was read from @cursor even when the page had been told to draw a
# different one -- the page's own rule is "cursor = @cursor if !cursor", so the argument wins -- and
# :encounter, the first section of the page and the one that says where the species is FOUND, was missing
# from the table, so it arrived with its paragraph and no name at all.
Suite.define("pokedex data page: the section named is the one drawn, and all ten have a name") do
  scene = PokemonPokedexInfo_Scene.new
  scene.cursor = :general

  SpeakCapture.clear
  scene.pbDrawDataNotes
  match "with no argument it follows the cursor", SpeakCapture.lines.join(" "),
        /#{PokeAccess::I18n.t(:pdx_sec_general)}/

  SpeakCapture.clear
  scene.pbDrawDataNotes(:stats)
  line = SpeakCapture.lines.join(" ")
  match "an argument wins over the cursor, as it does for the page itself", line,
        /#{PokeAccess::I18n.t(:pdx_sec_stats)}/
  falsy "and the section the cursor sits on is not the one named",
        line.include?(PokeAccess::I18n.t(:pdx_sec_general))

  SpeakCapture.clear
  scene.pbDrawDataNotes(:encounter)
  match "the section that says where the species is found has a name too", SpeakCapture.lines.join(" "),
        /#{PokeAccess::I18n.t(:pdx_sec_encounter)}/

  ten = [:encounter, :general, :stats, :family, :habitat, :shape, :egg, :item, :ability, :moves]
  missing = ten.reject { |k| PokeAccess::PokedexInfoV21::SECTIONS[k] }
  eq "every section the page draws has a word for it", missing, []
end
