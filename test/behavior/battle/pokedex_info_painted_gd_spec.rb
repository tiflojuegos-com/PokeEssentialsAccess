# The Pokedex entry's info page, read as painted in reading order, plus what it draws as icons (the owned mark, the
# types); the stand-in paints like v21, the entry paragraph first and the rows out of reading order.

# Paints a v21-style info page: entry text through drawTextEx, then header, labels, category and values.
def paint_dex_info(header, category, values, entry, battled = nil)
  lambda do
    drawTextEx(nil, 40, 246, 432, 4, entry)
    rows = [[header, 246, 48]]
    if battled
      rows.push(["Enfrentados:", 314, 164], [battled, 314, 196])
    else
      rows.push(["Altura", 314, 164], ["Peso", 314, 196])
    end
    rows.push([category, 246, 80])
    rows.push([values[0], 470, 164], [values[1], 482, 196]) unless battled
    pbDrawTextPositions(nil, rows)
  end
end

def dex_scene(species, paint)
  scene = PokemonPokedexInfo_Scene.new
  scene.instance_variable_set(:@species, species)
  scene.instance_variable_set(:@form, 0)
  scene.instance_variable_set(:@dexlist, [{ :species => species, :number => 7, :shift => false }])
  scene.instance_variable_set(:@index, 0)
  scene.instance_variable_set(:@paint, paint)
  scene
end

Suite.define("pokedex entry: the info page is read as painted, with the owned mark and the types added") do
  had = $player
  $player = had.dup
  def $player.owned?(_s); true; end
  begin
    scene = dex_scene(:PIKACHU, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "Almacena electricidad."))
    PokeAccess::PokedexInfoV21.reset(scene)
    SpeakCapture.clear
    scene.drawPage(1)
    line = SpeakCapture.lines.join(" ")
    eq "top to bottom and left to right, whatever order it was painted in", line,
       ["007 Pikachu", PokeAccess::I18n.t(:dex_caught), "Pokémon Ratón",
        PokeAccess::I18n.t(:pdx_type, :t => "TypeTYPE1"), "Altura", "0.4 m", "Peso", "6.0 kg",
        "Almacena electricidad."].join(", ")
  ensure
    $player = had
  end
end

Suite.define("pokedex entry: a species only seen keeps its secrets, said as unknown") do
  had = $player
  $player = had.dup
  def $player.owned?(_s); false; end
  begin
    scene = dex_scene(:MEW, paint_dex_info("??? Mew", "Pokémon ?????", ["????.? m", "????.? kg"], ""))
    PokeAccess::PokedexInfoV21.reset(scene)
    SpeakCapture.clear
    scene.drawPage(1)
    line = SpeakCapture.lines.join(" ")
    unk = PokeAccess::I18n.t(:pdx_unknown_short)
    eq "question marks are said as the word, and no type the page does not draw",
       line, ["#{unk} Mew", "Pokémon #{unk}", "Altura", unk, "Peso", unk].join(", ")
  ensure
    $player = had
  end
end

Suite.define("pokedex entry: the encountered count the page swaps in is read, and swapping it back reads again") do
  scene = dex_scene(:PIKACHU, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "E.", "3"))
  PokeAccess::PokedexInfoV21.reset(scene)
  SpeakCapture.clear
  scene.drawPage(1)
  truthy "the count is read where height and weight were", SpeakCapture.lines.join(" ").include?("Enfrentados: 3")
  scene.instance_variable_set(:@paint, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "E."))
  SpeakCapture.clear
  scene.drawPage(1)
  truthy "and the same page swapped back is a new text, so it is said", SpeakCapture.lines.join(" ").include?("Altura, 0.4 m")
end

# Royal's page paints its own "Tipo" label beside the icons, and draws them for a species only seen too, so
# its profile says the bare names right after that label (no second "type" of the mod's), owned or not.
Suite.define("pokedex entry: a page with its own type label gets the bare names after it; Royal says them always") do
  had = $player
  $player = had.dup
  def $player.owned?(_s); false; end
  paint = lambda do
    drawTextEx(nil, 40, 291, 432, 4, "")
    pbDrawTextPositions(nil, [["025 Pikachu", 399, 58], ["Tipo", 327, 153], ["Altura", 327, 194],
                              ["Peso", 327, 235], ["Pokémon ?????", 466, 110], ["????.? m", 547, 194],
                              ["????.? kg", 559, 235]])
  end
  meta = (class << PokeAccess::PokedexInfoV21; self; end)
  meta.send(:alias_method, :royal_spec_shown_types, :shown_types)
  begin
    load File.expand_path("../../../games/royal/dex_types.rb", File.dirname(__FILE__))
    scene = dex_scene(:PIKACHU, paint)
    PokeAccess::PokedexInfoV21.reset(scene)
    SpeakCapture.clear
    scene.drawPage(1)
    unk = PokeAccess::I18n.t(:pdx_unknown_short)
    eq "the names follow the page's label, for a species only seen too", SpeakCapture.lines.join(" "),
       ["025 Pikachu", "Pokémon #{unk}", "Tipo", "TypeTYPE1", "Altura", unk, "Peso", unk].join(", ")
  ensure
    meta.send(:alias_method, :shown_types, :royal_spec_shown_types)
    meta.send(:remove_method, :royal_spec_shown_types)
    $player = had
  end
end

# Royal's size pages stand the species beside a character (a trainer, a person) whom the action button swaps
# for another, repainting the page with its text unchanged, so the character is named and each swap is read.
Suite.define("pokedex entry: a size page says who the species is compared with, and each swap is read") do
  had = $player
  $player = had.dup
  def $player.owned?(_s); true; end
  scene = dex_scene(:PIKACHU, lambda { })
  scene.instance_variable_set(:@page_id, :page_height)
  scene.instance_variable_set(:@hwComparator, 0)
  def scene.pbGetComparisonName(id); ["Hombre", "Snorlax de peluche"][id]; end
  def scene.pbGetComparisonHeight(id); [1.7, 0.6][id]; end
  def scene.pbGetComparisonWeight(id); [62, 5][id]; end
  begin
    PokeAccess::PokedexInfoV21.reset(scene)
    SpeakCapture.clear
    scene.drawPage(4)
    truthy "the height page names the character and his height",
           SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:pdx_compare, :name => "Hombre", :v => "1.7 m"))
    scene.instance_variable_set(:@hwComparator, 1)
    SpeakCapture.clear
    scene.drawPage(4)
    truthy "choosing another repaints the page, and the new one is read",
           SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:pdx_compare, :name => "Snorlax de peluche", :v => "0.6 m"))
    scene.instance_variable_set(:@page_id, :page_weight)
    SpeakCapture.clear
    scene.drawPage(5)
    truthy "and the weight page his weight",
           SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:pdx_compare, :name => "Snorlax de peluche", :v => "5 kg"))
  ensure
    $player = had
  end
end
