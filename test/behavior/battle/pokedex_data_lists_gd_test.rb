# The MUI Data Page: the page at the reading's levels, each section's name with what its box paints, a species
# sub-list's cell with its page and box (Return as the way back); an ability or item entry with mark and description.
class PokedexDataListsGdTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21
  # A family list of 14 species, two pages of 12, ending in the Return cell.
  FAMILY = (1..14).map { |n| "SP#{n}".to_sym } + [:RETURN]
  # The box beneath a family member: its evolution method.
  METHOD_BOX = [["<c2=043c3aff>Evolution Method\nLevel 16</c2>", 34, 294]]
  # The stats box as the page paints it: three columns of names, each with its values beside it, under the total.
  STATS_BOX = [["HP\nSpeed", 34, 324], [" 45\n 45", 128, 324], ["Attack\nDefense", 192, 324], [" 49\n 49", 286, 324],
               ["Sp. Atk\nSp. Def", 350, 324], [" 65\n 65", 444, 324], ["Base Stats - Total: 318", 34, 294]]
  # Pikachu's base stats.
  STATS = { :HP => 35, :ATTACK => 55, :DEFENSE => 40, :SPECIAL_ATTACK => 50, :SPECIAL_DEFENSE => 50, :SPEED => 90 }
  # A species' data as the data page reads it.
  DATA = Struct.new(:types, :abilities, :hidden_abilities, :base_stats)
  # The ability sub-list: Static in slot 1, Plus special, Lightning Rod hidden, then the way back.
  ABILITIES = [:STATIC, :PLUS, :LIGHTNINGROD, "Return"]
  # The item sub-list: one berry of each rarity, then the way back.
  ITEMS = [:ORANBERRY, :SITRUSBERRY, :LEPPABERRY, "Return"]

  test "the data page at the reading's levels: the name, then its types and abilities, then its base stats" do
    data = DATA.new([:ELECTRIC], [:STATIC], [], STATS)
    assert_equal pikachu_data_lines, vb_levels { PDX.data_text("Pikachu", data, true) }
  end

  test "the info key keeps the whole data page whatever the level" do
    PokeAccess::Config.verbosity = :brief
    PDX.data_text("Pikachu", DATA.new([:ELECTRIC], [:STATIC], [], STATS), true)
    assert_equal pikachu_data_lines[2], PokeAccess::Info.info_text
  end

  test "the data page drawn is said with what its species' data has" do
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@page_id, :page_data)
    scene.drawPage(1)
    assert_equal [["Species25. #{t(:pdx_type, :t => 'TypeTYPE1')}", true]], SpeakCapture.log
  end

  test "the data page names the hidden abilities apart, leaving out one that is also regular" do
    data = DATA.new([], [:STATIC, :PLUS], [:LIGHTNINGROD, :PLUS], nil)
    assert_equal "Pikachu. #{t(:pdx_ability, :a => 'AbilitySTATIC, AbilityPLUS')}. " \
                 "#{t(:pdx_hidden_ability, :a => 'AbilityLIGHTNINGROD')}",
                 PDX.data_text("Pikachu", data, true)
  end

  test "the data page of a species only seen says its data is unknown" do
    data = DATA.new([:ELECTRIC], [:STATIC], [], STATS)
    assert_equal "Pikachu. #{t(:pdx_unknown_value)}", PDX.data_text("Pikachu", data, false)
  end

  test "a section is said by its name, then what its box paints" do
    assert_equal [["#{t(:pdx_sec_general)}. General Statistics Capture Success Rate: 45%", true]],
                 notes_said(:general, [["General Statistics\nCapture Success Rate: 45%", 34, 294]])
  end

  test "the stats box says the total, then each name beside its value" do
    assert_equal [["#{t(:pdx_sec_stats)}. Base Stats - Total: 318. HP 45, Speed 45. Attack 49, Defense 49. " \
                   "Sp. Atk 65, Sp. Def 65", true]],
                 notes_said(:stats, STATS_BOX)
  end

  test "the box is read left to right whatever order it was painted in" do
    painted = [[" 45\n 45", 128, 324], ["HP\nSpeed", 34, 324]]
    assert_equal [["#{t(:pdx_sec_stats)}. HP 45, Speed 45", true]], notes_said(:stats, painted)
  end

  test "a blank paragraph between names and their values does not part them" do
    painted = [["HP\nSpeed", 34, 324], ["  ", 80, 324], [" 45\n 45", 128, 324]]
    assert_equal [["#{t(:pdx_sec_stats)}. HP 45, Speed 45", true]], notes_said(:stats, painted)
  end

  test "paragraphs side by side are paired only line for line, two lines or more" do
    { [["Capture Rate", 34, 294], ["45%", 200, 294]] => "Capture Rate. 45%",
      [["HP\nSpeed\nAttack", 34, 324], [" 45\n 45", 128, 324]] => "HP Speed Attack. 45 45",
      [["HP\nSpeed", 34, 300], [" 45\n 45", 128, 324]] => "HP Speed. 45 45" }.each do |painted, box|
      assert_equal [["#{t(:pdx_sec_stats)}. #{box}", true]], notes_said(:stats, painted), painted.inspect
      SpeakCapture.clear
    end
  end

  test "with no section passed, the page's own cursor names it" do
    scene = PokemonPokedexInfo_Scene.new
    scene.pbDrawDataNotes
    assert_equal [["#{t(:pdx_sec_general)}. Texto de general.", true]], SpeakCapture.log
  end

  test "a section the page has no name for says its box alone" do
    PokemonPokedexInfo_Scene.new.pbDrawDataNotes(:mystery)
    assert_equal [["Texto de mystery.", true]], SpeakCapture.log
  end

  test "a section with no name and nothing in its box says nothing" do
    assert_equal [], notes_said(:mystery, [])
  end

  test "a section drawn again unchanged is not said again" do
    scene = PokemonPokedexInfo_Scene.new
    scene.pbDrawDataNotes(:general)
    SpeakCapture.clear
    scene.pbDrawDataNotes(:general)
    assert_equal [], SpeakCapture.log
  end

  test "a species cell says the species, the page of several, then the box beneath" do
    assert_equal [["SpeciesSP1. #{t(:pdx_list_page, :n => 1, :tot => 2)}. Evolution Method Level 16", true]],
                 cell_said(opened_list, 0, 0)
  end

  test "the list's draw returns what the game's returns" do
    assert_equal :list_drawn, opened_list.pbDrawSpeciesDataList(FAMILY, 0, 0, 1, :family)
  end

  test "the info key keeps the focused species and its box" do
    cell_said(opened_list, 0, 0)
    assert_equal "SpeciesSP1. Evolution Method Level 16", PokeAccess::Info.info_text
  end

  test "the next cell on the same page leaves the page out" do
    scene = opened_list
    cell_said(scene, 0, 0)
    assert_equal [["SpeciesSP2. Evolution Method Level 16", true]], cell_said(scene, 1, 0)
  end

  test "turning the page says it" do
    scene = opened_list
    cell_said(scene, 0, 0)
    assert_equal [["SpeciesSP13. #{t(:pdx_list_page, :n => 2, :tot => 2)}. Evolution Method Level 16", true]],
                 cell_said(scene, 0, 1)
  end

  test "a list of a single page never says its page" do
    assert_equal [["SpeciesSP1. Evolution Method Level 16", true]], cell_said(opened_list, 0, 0, 0)
  end

  test "a species cell at the reading's levels: the species, then a turned page, then the box" do
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@list_paint, METHOD_BOX)
    said = vb_levels do
      scene.pbChooseSpeciesDataList
      cell_said(scene, 0, 0)
    end
    page = t(:pdx_list_page, :n => 1, :tot => 2)
    assert_equal [[["SpeciesSP1", true]], [["SpeciesSP1. #{page}", true]],
                  [["SpeciesSP1. #{page}. Evolution Method Level 16", true]]], said
  end

  test "the Return cell that ends a list, and a cell past its end, say the way back" do
    list = [:BULBASAUR, :IVYSAUR, :RETURN]
    { 2 => "the Return cell", 3 => "past the end" }.each do |index, what|
      scene = PokemonPokedexInfo_Scene.new
      assert_equal [[t(:back), true]], with_return_cell { cell_said(scene, index, 0, 0, list) }, what
      SpeakCapture.clear
    end
  end

  test "a species cell of a list that ends in Return names the species" do
    list = [:BULBASAUR, :IVYSAUR, :RETURN]
    assert_equal [["SpeciesIVYSAUR", true]],
                 with_return_cell { cell_said(PokemonPokedexInfo_Scene.new, 1, 0, 0, list) }
  end

  test "an ability entry says its slot and its place in the list" do
    assert_equal ["AbilitySTATIC", t(:pdx_ab_slot, :n => 1), t(:list_pos, :i => 1, :n => 3)].join(". "),
                 PDX.data_list_text(ability_page, ABILITIES, 0, :ability)
  end

  test "a hidden or special ability is marked so" do
    { 2 => ["AbilityLIGHTNINGROD", t(:pdx_ab_hidden), t(:list_pos, :i => 3, :n => 3)],
      1 => ["AbilityPLUS", t(:pdx_ab_special), t(:list_pos, :i => 2, :n => 3)] }.each do |index, parts|
      assert_equal parts.join(". "), PDX.data_list_text(ability_page, ABILITIES, index, :ability), "row #{index}"
    end
  end

  test "the last row is the way back" do
    assert_equal t(:dbk_back), PDX.data_list_text(ability_page, ABILITIES, 3, :ability)
  end

  test "an item entry says its rarity and its description" do
    { 0 => ["ItemORANBERRY", t(:pdx_item_common), t(:list_pos, :i => 1, :n => 3), "idescORANBERRY"],
      1 => ["ItemSITRUSBERRY", t(:pdx_item_uncommon), t(:list_pos, :i => 2, :n => 3), "idescSITRUSBERRY"],
      2 => ["ItemLEPPABERRY", t(:pdx_item_rare), t(:list_pos, :i => 3, :n => 3), "idescLEPPABERRY"] }.each do |i, parts|
      assert_equal parts.join(". "), PDX.data_list_text(item_page, ITEMS, i, :item), "row #{i}"
    end
  end

  test "with no list passed, the page's own cursor says which list it is" do
    scene = item_page
    scene.instance_variable_set(:@cursor, :item)
    assert_equal ["ItemORANBERRY", t(:pdx_item_common), t(:list_pos, :i => 1, :n => 3), "idescORANBERRY"].join(". "),
                 PDX.data_list_text(scene, ITEMS, 0, nil)
  end

  test "an entry in no group of the page carries no mark" do
    assert_equal "ItemORANBERRY. #{t(:list_pos, :i => 1, :n => 3)}. idescORANBERRY",
                 PDX.data_list_text(Object.new, ITEMS, 0, :item)
  end

  test "an entry at the reading's levels: name and mark, then its place, then its description" do
    said = vb_levels { PDX.data_list_text(item_page, ITEMS, 0, :item) }
    assert_equal ["ItemORANBERRY. #{t(:pdx_item_common)}",
                  "ItemORANBERRY. #{t(:pdx_item_common)}. #{t(:list_pos, :i => 1, :n => 3)}",
                  "ItemORANBERRY. #{t(:pdx_item_common)}. #{t(:list_pos, :i => 1, :n => 3)}. idescORANBERRY"], said
  end

  test "the info key keeps an entry's name, mark and description" do
    PDX.data_list_text(item_page, ITEMS, 0, :item)
    assert_equal "ItemORANBERRY. #{t(:pdx_item_common)}. idescORANBERRY", PokeAccess::Info.info_text
  end

  test "an ability entry says the ability's description" do
    with_ability_descriptions do
      assert_equal ["AbilitySTATIC", t(:pdx_ab_slot, :n => 1), t(:list_pos, :i => 1, :n => 3), "fullSTATIC"].join(". "),
                   PDX.data_list_text(ability_page, ABILITIES, 0, :ability)
    end
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Pikachu's data page as said in brief, medium and full.
  def pikachu_data_lines
    medium = "Pikachu. #{t(:pdx_type, :t => 'TypeELECTRIC')}. #{t(:pdx_ability, :a => 'AbilitySTATIC')}"
    stats = t(:pdx_stats, :hp => 35, :atk => 55, :def => 40, :spa => 50, :spd => 50, :spe => 90)
    ["Pikachu", medium, "#{medium}. #{stats}"]
  end

  # A data page whose ability groups are regular (Static), special (Plus) and hidden (Lightning Rod).
  def ability_page
    scene = Object.new
    scene.instance_variable_set(:@data_hash, { :ability => { 0 => [:STATIC], 1 => [:LIGHTNINGROD], 2 => [:PLUS] } })
    scene
  end

  # A data page whose held items are common, uncommon and rare berries.
  def item_page
    scene = Object.new
    groups = { 0 => [:ORANBERRY], 1 => [:SITRUSBERRY], 2 => [:LEPPABERRY] }
    scene.instance_variable_set(:@data_hash, { :item => groups })
    scene
  end

  # What drawing a section whose box paints the paragraphs ([text, x, y]) says.
  def notes_said(section, paragraphs)
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@notes_paint, paragraphs)
    scene.pbDrawDataNotes(section)
    SpeakCapture.log.dup
  end

  # A data page with a family list just opened, the evolution method painted beneath each cell.
  def opened_list
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@list_paint, METHOD_BOX)
    scene.pbChooseSpeciesDataList
    scene
  end

  # What drawing the list's cell index on page (of maxpage + 1) says.
  def cell_said(scene, index, page, maxpage = 1, list = FAMILY)
    SpeakCapture.clear
    scene.pbDrawSpeciesDataList(list, index, page, maxpage, :family)
    SpeakCapture.log.dup
  end

  # Runs the block with GameData::Species answering the Return cell as the game does: try_get finds nothing, get
  # raises.
  def with_return_cell
    k = GameData::Species.singleton_class
    had_try = k.method_defined?(:try_get)
    try_get = had_try ? k.instance_method(:try_get) : nil
    get = k.instance_method(:get)
    k.send(:define_method, :try_get) { |i| i == :RETURN ? nil : new(i) }
    k.send(:define_method, :get) { |i| raise ArgumentError, "no species #{i}" if i == :RETURN; new(i) }
    yield
  ensure
    k.send(:define_method, :get, get)
    had_try ? k.send(:define_method, :try_get, try_get) : k.send(:remove_method, :try_get)
  end

  # Runs the block with each ability answering a full description ("full" and its id), as v21 abilities do.
  def with_ability_descriptions
    GameData::Ability.send(:define_method, :full_description) { "full#{@i}" }
    yield
  ensure
    GameData::Ability.send(:remove_method, :full_description)
  end
end
