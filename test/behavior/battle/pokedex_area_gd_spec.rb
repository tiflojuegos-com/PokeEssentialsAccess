# The v21 Pokedex pages say what they paint. drawPage's hooks arm the paint capture and take it on every page,
# leaving it free for the next reader.
Suite.define("pokedex: the page capture is taken on every page, not left armed for the next reader") do
  scene = PokemonPokedexInfo_Scene.new
  PokeAccess::PokedexInfoV21.painted = nil

  scene.drawPage(2)
  eq "what the page painted reached the reader",
     PokeAccess::PokedexInfoV21.painted, "Area unknown, Kanto"

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

# The forms page paints the species and the label of the form on show ("Male" or "Female" for a species whose
# sexes look different, which has no form name in its data), and that painted line is what is said.
Suite.define("pokedex: the forms page says the form it shows, the sex included") do
  pdx = PokeAccess::PokedexInfoV21
  data = Object.new
  def data.form_name; nil; end
  eq "the painted species and label are what is spoken", pdx.forms_text("Pikachu", data, "Pikachu, Female"),
     "Pikachu, Female"
  eq "with nothing painted, a species with no form name falls back to the composed line",
     pdx.forms_text("Pikachu", data, nil), PokeAccess::I18n.t(:pdx_forms, :name => "Pikachu")
end

# The area page names its lit squares: pbGetEncounterPoints matched back to the town map's points. Royal's Arcky's
# Region Map numbers them by the map picture's width (800 pixels, 50 squares).
class PokemonRegionMap_Scene
  LEFT = 0 unless const_defined?(:LEFT)
  RIGHT = 29 unless const_defined?(:RIGHT)
  SQUARE_WIDTH = 16 unless const_defined?(:SQUARE_WIDTH)
end

Suite.define("pokedex: the area page names the places its squares light") do
  pdx = PokeAccess::PokedexInfoV21
  scene = Object.new
  town = Struct.new(:point).new([[3, 2, "Ruta 1"], [4, 2, "Ruta 1"], [10, 5, "Bosque"], [12, 7, "Cueva"]])
  scene.instance_variable_set(:@mapdata, town)
  def scene.pbGetEncounterPoints
    lit = []
    [[3, 2], [4, 2], [10, 5]].each { |x, y| lit[x + y * 30] = true }
    lit
  end
  eq "each lit place once, in the game's names, the unlit one left out", pdx.area_places(scene),
     ["placeRuta 1", "placeBosque"]
  eq "joined after what the page painted", pdx.area_text("Pikachu", "Kanto", ["placeRuta 1"]),
     "Kanto. #{PokeAccess::I18n.t(:pdx_places, :list => 'placeRuta 1')}"
  eq "a page with no such method adds nothing", pdx.area_places(Object.new), []

  arcky = Object.new
  arcky.instance_variable_set(:@mapdata, Struct.new(:point).new([[15, 62, "Ruta 1"], [25, 103, "Otra"]]))
  arcky.instance_variable_set(:@mapWidth, 800)
  def arcky.pbGetEncounterPoints; lit = []; lit[15 + 62 * 50] = true; lit; end
  eq "a page that sizes its map by the picture is read by that width", pdx.area_places(arcky), ["placeRuta 1"]
end

# What a v19 area page (Fire Ash, both Infinite Fusions; no pbGetEncounterPoints) lights its squares from: the
# encounter tables of the current version and each map's town-map position and size.
def pdx_v19_area_world
  enc = Struct.new(:types, :map)
  meta = Struct.new(:town_map_position, :town_map_size)
  tables = [enc.new([:PIKACHU], 1), enc.new([:PIKACHU], 2), enc.new([:PIKACHU], 3), enc.new([:RATTATA], 4),
            enc.new([:PIKACHU], 5)]
  metas = { 1 => meta.new([0, 3, 2], [2, "11"]), 2 => meta.new([0, 10, 5], nil), 3 => meta.new([1, 1, 1], nil),
            4 => meta.new([0, 12, 7], nil), 5 => meta.new([0, 14, 9], nil) }
  GameData.const_set(:Encounter, Class.new) unless GameData.const_defined?(:Encounter)
  GameData::Encounter.define_singleton_method(:each_of_version) { |_v, &b| tables.each(&b) }
  GameData::MapMetadata.define_singleton_method(:try_get) { |m| metas[m] }
  $PokemonGlobal.define_singleton_method(:encounter_version) { 0 }
end

# A v19 area scene, with pbFindEncounter on the scene as in all three games (never a global).
def pdx_v19_area_scene
  scene = Object.new
  def scene.pbFindEncounter(types, species); types.include?(species); end
  scene
end

Suite.define("pokedex (v19): the area page names the places its own inline loop lights") do
  pdx = PokeAccess::PokedexInfoV21
  had_encounter = GameData.const_defined?(:Encounter)
  begin
    pdx_v19_area_world
    $game_switches[50] = false
    scene = pdx_v19_area_scene
    scene.instance_variable_set(:@species, :PIKACHU)
    scene.instance_variable_set(:@region, 0)
    points = [[3, 2, "Ruta 1"], [4, 2, "Ruta 1 Norte"], [10, 5, "Bosque"], [12, 7, "Cueva"], [1, 1, "Cabo Lejano"],
              [14, 9, "Isla", nil, nil, nil, nil, 50]]
    scene.instance_variable_set(:@mapdata, { 0 => [nil, nil, points] })
    eq "the lit places, the second square of a two-square map included; not a map of another region (its " \
       "square is a place here too), another species, or a point still hidden",
       pdx.area_places(scene), ["placeRuta 1", "placeRuta 1 Norte", "placeBosque"]
    width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    falsy "a hidden point's square is not lit at all, not only left unnamed", pdx.inline_encounter_points(scene)[14 + 9 * width]
    $game_switches[50] = true
    eq "the hidden point counts once its switch is on", pdx.area_places(scene),
       ["placeRuta 1", "placeRuta 1 Norte", "placeBosque", "placeIsla"]
  ensure
    $game_switches.delete(50)
    GameData.send(:remove_const, :Encounter) if !had_encounter && GameData.const_defined?(:Encounter)
    class << GameData::MapMetadata; remove_method :try_get; end
    GameData::MapMetadata.define_singleton_method(:try_get) { |_i| nil }
    class << $PokemonGlobal; remove_method :encounter_version; end
  end
end

# The data page's ability and item sub-list (MUI Pokedex Data Page, and Soulstones 2's edited Enhanced Pokedex):
# three rows under a cursor sprite, each marked with its group, and the description painted beneath.
Suite.define("pokedex data: the ability and item sub-list reads the entry, its mark and its text") do
  pdx = PokeAccess::PokedexInfoV21
  t = PokeAccess::I18n
  scene = Object.new
  scene.instance_variable_set(:@data_hash, { :ability => { 0 => [:STATIC], 1 => [:LIGHTNINGROD] } })
  list = [:STATIC, :LIGHTNINGROD, "Return"]
  eq "a regular ability says its slot and position", pdx.data_list_text(scene, list, 0, :ability),
     ["Ability" + "STATIC", t.t(:pdx_ab_slot, :n => 1), t.t(:list_pos, :i => 1, :n => 2)].join(". ")
  eq "the hidden one is marked hidden", pdx.data_list_text(scene, list, 1, :ability),
     ["Ability" + "LIGHTNINGROD", t.t(:pdx_ab_hidden), t.t(:list_pos, :i => 2, :n => 2)].join(". ")
  eq "the last row is the way back", pdx.data_list_text(scene, list, 2, :ability), t.t(:dbk_back)

  data = Struct.new(:types, :abilities, :hidden_abilities, :base_stats).new([], [:STATIC], [:LIGHTNINGROD], nil)
  truthy "and the data page names the hidden ability", pdx.data_text("Pikachu", data, true).index(
    t.t(:pdx_hidden_ability, :a => "AbilityLIGHTNINGROD"))
end

Suite.define("pokedex pages at the Pokedex pages reading's level, and the info key keeps each page whole") do
  pdx = PokeAccess::PokedexInfoV21
  t = PokeAccess::I18n
  stats = { :HP => 35, :ATTACK => 55, :DEFENSE => 40, :SPECIAL_ATTACK => 50, :SPECIAL_DEFENSE => 50, :SPEED => 90 }
  data = Struct.new(:types, :abilities, :hidden_abilities, :base_stats).new([:ELECTRIC], [:STATIC], [], stats)
  statline = t.t(:pdx_stats, :hp => 35, :atk => 55, :def => 40, :spa => 50, :spd => 50, :spe => 90)
  ability = t.t(:pdx_ability, :a => "AbilitySTATIC")
  rows = vb_levels { pdx.data_text("Pikachu", data, true) }
  eq "the data page in brief: the name", rows[0], "Pikachu"
  truthy "medium: its types and abilities, not its stats", rows[1].include?(ability) && !rows[1].include?(statline)
  truthy "full: the base stats too", rows[2].include?(statline)
  PokeAccess::Config.verbosity = :brief
  pdx.data_text("Pikachu", data, true)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole data page", PokeAccess::Info.info_text, rows[2]

  pdx.instance_variable_set(:@painted_rows, nil)
  info = Struct.new(:category, :height, :weight, :pokedex_entry).new("Ratón", 4, 60, "Almacena electricidad.")
  page = vb_levels { pdx.info_text(Object.new, "Pikachu", info, true) }
  eq "the entry page in brief: the name", page[0], "Pikachu"
  eq "medium: and its category", page[1], "Pikachu. #{t.t(:pdx_category, :cat => "Ratón")}"
  truthy "full: its size and its entry too", page[2].end_with?("Almacena electricidad.") && page[2].length > page[1].length
  eq "one not caught says so at any level", vb_levels { pdx.info_text(Object.new, "Pikachu", info, false) }[0],
     "Pikachu. #{t.t(:pdx_not_caught)}"
end
