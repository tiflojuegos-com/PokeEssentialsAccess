# The gen-6 Pokedex entry page read as painted: the header's own number, question marks as unknown (a species only
# seen keeps its category back), and for an owned one the owned mark and the types it draws as icons.
Suite.define("pokedex entry gen-6: read as painted, a species only seen keeps its category back") do
  dummy = Struct.new(:species, :kind, :height, :weight, :dexEntry, :type1, :type2).new(25, "Ratón", 4, 60,
                                                                                      "Almacena electricidad.", 13, 13)
  had = $Trainer
  $Trainer = had.dup
  $Trainer.instance_variable_set(:@owned, [])
  def $Trainer.owned; @owned; end
  begin
    scene = PokemonPokedexScene.new
    scene.dummypokemon = dummy
    scene.instance_variable_set(:@shown_number, 7)
    unk = PokeAccess::I18n.t(:pdx_unknown_short)

    SpeakCapture.clear
    scene.pbChangeToDexEntry(25)
    seen = SpeakCapture.lines.join(" ")
    truthy "the header's own number is read first", seen.start_with?("007")
    truthy "a species only seen: its category as the page writes it, unknown", seen.include?("Pokémon #{unk}")
    falsy "never the category it keeps back", seen.include?("Ratón")
    falsy "nor a type it does not draw", seen.include?(PokeAccess::Data.type_name(13).to_s)

    $Trainer.owned[25] = true
    SpeakCapture.clear
    scene.pbChangeToDexEntry(25)
    got = SpeakCapture.lines.join(" ")
    truthy "owned: the owned mark after the header", got.include?(", #{PokeAccess::I18n.t(:dex_caught)}, Pokémon Ratón")
    truthy "the types it draws as icons, after the category",
           got.include?("Pokémon Ratón, #{PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Data.type_name(13))}")
    truthy "the height beside its label, in reading order", got.include?("Alt., 0.4 m")
    truthy "and the entry last, though it was painted first", got.end_with?("Almacena electricidad.")
  ensure
    $Trainer = had
  end
end

# The copies older than v16 (Insurgence's) keep no dummy pokemon on the page: the species is the one the page was
# changed to, and the types an owned one draws as icons come from the dex data.
Suite.define("pokedex entry gen-6: a page with no dummy pokemon is read from the species it shows") do
  had = $Trainer
  $Trainer = had.dup
  $Trainer.instance_variable_set(:@owned, [])
  def $Trainer.owned; @owned; end
  begin
    scene = PokemonPokedexScene.new
    SpeakCapture.clear
    scene.pbChangeToDexEntry(25)
    truthy "a species only seen is read", SpeakCapture.lines.join(" ").include?(PBSpecies.getName(25))
    $Trainer.owned[25] = true
    SpeakCapture.clear
    scene.pbChangeToDexEntry(25)
    got = SpeakCapture.lines.join(" ")
    truthy "owned: the owned mark", got.include?(PokeAccess::I18n.t(:dex_caught))
    truthy "and its types, from the dex data",
           got.include?(PokeAccess::I18n.t(:pdx_type, :t => PokeAccess::Data.type_name(13)))
  ensure
    $Trainer = had
  end
end
