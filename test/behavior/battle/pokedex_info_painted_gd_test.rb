# The v21 Pokedex entry's info page as painted, in reading order with its icons worded, else composed from the
# species' data; the size pages, Royal's with the character beside the species, and an addon's page as painted.
class PokedexInfoPaintedGdTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21
  # The species' data the composed info page reads.
  INFO = Struct.new(:category, :height, :weight, :pokedex_entry)

  class << self
    # Royal's shown_types, kept aside by load_royal.
    attr_reader :royal_types
  end

  # Evaluates Royal's dex_types once, as boot does. Its shown_types is kept aside and core's put back, so the other
  # tests of the process keep core's; with_royal_types puts Royal's in for a test.
  def self.load_royal
    meta = PokeAccess::PokedexInfoV21.singleton_class
    core = meta.instance_method(:shown_types)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "royal", "dex_types.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @royal_types = meta.instance_method(:shown_types)
  ensure
    meta.send(:define_method, :shown_types, core)
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_royal

  test "the info page is said top to bottom and left to right, the caught mark and types after the header" do
    assert_equal [[owned_line.join(", "), true]], with_owned(true) { page_said(pikachu_page) }
  end

  test "the info page at the reading's levels: header and mark, then category and types, then the rest" do
    scene = pikachu_page
    said = with_owned(true) { vb_levels { page_said(scene).map { |text, _i| text } } }
    assert_equal [[owned_line[0, 2].join(", ")], [owned_line[0, 4].join(", ")], [owned_line.join(", ")]], said
  end

  test "the info key keeps the whole painted page whatever the level" do
    PokeAccess::Config.verbosity = :brief
    with_owned(true) { page_said(pikachu_page) }
    assert_equal owned_line.join(", "), PokeAccess::Info.info_text
  end

  test "the info page painted again unchanged is not said again" do
    scene = pikachu_page
    with_owned(true) do
      page_said(scene)
      assert_equal [], page_said(scene)
    end
  end

  test "the entry reopened is read again" do
    scene = pikachu_page
    with_owned(true) do
      page_said(scene)
      PDX.reset(scene)
      assert_equal [[owned_line.join(", "), true]], page_said(scene)
    end
  end

  test "an entry scene on no species says nothing" do
    assert_equal [], page_said(dex_scene(nil, lambda { drawTextEx(nil, 0, 0, 200, 1, "???") }))
  end

  test "a species only seen keeps its secrets: question marks said as unknown, and no types" do
    unk = t(:pdx_unknown_short)
    scene = dex_scene(:MEW, paint_dex_info("??? Mew", "Pokémon ?????", ["????.? m", "????.? kg"], ""))
    assert_equal [[["#{unk} Mew", "Pokémon #{unk}", "Altura", unk, "Peso", unk].join(", "), true]],
                 with_owned(false) { page_said(scene) }
  end

  test "the encountered count the page swaps in is said where the size was" do
    scene = dex_scene(:PIKACHU, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "E.", "3"))
    want = ["007 Pikachu", "Pokémon Ratón", t(:pdx_type, :t => "TypeTYPE1"), "Enfrentados: 3", "E."].join(", ")
    assert_equal [[want, true]], page_said(scene)
  end

  test "the page swapped back to the size is said again" do
    scene = dex_scene(:PIKACHU, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "E.", "3"))
    page_said(scene)
    scene.instance_variable_set(:@paint, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "E."))
    assert_equal [[["007 Pikachu", "Pokémon Ratón", t(:pdx_type, :t => "TypeTYPE1"), "Altura", "0.4 m", "Peso",
                    "6.0 kg", "E."].join(", "), true]],
                 page_said(scene)
  end

  test "a page with its own type label gets the bare type names right after it" do
    scene = dex_scene(:PIKACHU, labelled_paint("Pokémon Ratón", "0.4 m", "6.0 kg"))
    assert_equal [[["025 Pikachu", t(:dex_caught), "Pokémon Ratón", "Tipo", "TypeTYPE1", "Altura", "0.4 m", "Peso",
                    "6.0 kg"].join(", "), true]],
                 with_owned(true) { page_said(scene) }
  end

  test "Royal's page names the types of a species only seen too" do
    unk = t(:pdx_unknown_short)
    scene = dex_scene(:PIKACHU, labelled_paint("Pokémon ?????", "????.? m", "????.? kg"))
    want = ["025 Pikachu", "Pokémon #{unk}", "Tipo", "TypeTYPE1", "Altura", unk, "Peso", unk].join(", ")
    assert_equal [[want, true]], with_owned(false) { with_royal_types { page_said(scene) } }
  end

  test "a page that paints nothing is composed from the species' data and its number in the list" do
    scene = dex_scene(:PIKACHU, lambda { })
    assert_equal [[numbered(7, "SpeciesPIKACHU", t(:pdx_category, :cat => "catPIKACHU"), "dexPIKACHU"), true]],
                 page_said(scene)
  end

  test "the entry of a form is composed from the form's own data" do
    scene = dex_scene(:PIKACHU, lambda { })
    scene.instance_variable_set(:@form, 1)
    want = numbered(7, "SpeciesPIKACHU_1", t(:pdx_category, :cat => "catPIKACHU_1"), "dexPIKACHU_1")
    assert_equal [[want, true]], with_species_forms { page_said(scene) }
  end

  test "an older list row gives way to the species' own dex number where it has one" do
    { 25 => 25, 1 => 1, 0 => 11 }.each do |own, shown|
      scene = dex_scene(:PIKACHU, lambda { })
      scene.instance_variable_set(:@dexlist, [[25, "Pikachu", 0, 0, 12, true]])
      want = numbered(shown, "SpeciesPIKACHU", t(:pdx_category, :cat => "catPIKACHU"), "dexPIKACHU")
      assert_equal [[want, true]], with_dex_numbers(own) { page_said(scene) }, "its own number #{own}"
    end
  end

  test "the composed page at the reading's levels: the name, then the category, then size and entry" do
    info = INFO.new("Ratón", 4, 60, "Almacena electricidad.")
    medium = "Pikachu. #{t(:pdx_category, :cat => 'Ratón')}"
    full = "#{medium}. #{t(:pdx_height, :h => '0,4', :n => 0.4)}. #{t(:pdx_weight, :w => '6,0', :n => 6.0)}. " \
           "Almacena electricidad."
    assert_equal ["Pikachu", medium, full], composed { vb_levels { PDX.info_text(Object.new, "Pikachu", info, true) } }
  end

  test "a composed page whose data has no entry text says the species' own" do
    scene = Object.new
    scene.instance_variable_set(:@species, :PIKACHU)
    ["", nil].each do |entry|
      assert_equal "Pikachu. #{t(:pdx_category, :cat => 'Ratón')}. dexPIKACHU",
                   composed { PDX.info_text(scene, "Pikachu", INFO.new("Ratón", 0, 0, entry), true) },
                   "entry #{entry.inspect}"
    end
  end

  test "a composed page leaves out a category the data does not have" do
    scene = Object.new
    scene.instance_variable_set(:@species, :PIKACHU)
    [nil, ""].each do |category|
      info = INFO.new(category, 0, 0, "Almacena electricidad.")
      assert_equal "Pikachu. Almacena electricidad.", composed { PDX.info_text(scene, "Pikachu", info, true) },
                   "category #{category.inspect}"
    end
  end

  test "a species not caught says so at every level" do
    info = INFO.new("Ratón", 4, 60, "Almacena electricidad.")
    said = composed { vb_levels { PDX.info_text(Object.new, "Pikachu", info, false) } }
    assert_equal ["Pikachu. #{t(:pdx_not_caught)}"] * 3, said
  end

  test "a gen-6 trainer's owned list says whether the species is caught" do
    { true => numbered(7, "Species25", t(:pdx_category, :cat => "cat25"), "dex25"),
      false => numbered(7, "Species25", t(:pdx_not_caught)) }.each do |caught, want|
      owned = []
      owned[25] = caught
      trainer = Struct.new(:owned).new(owned)
      assert_equal [[want, true]], with_player(trainer) { page_said(dex_scene(25, lambda { })) }, "caught: #{caught}"
      SpeakCapture.clear
    end
  end

  test "a player who cannot say what they own leaves the page composed as for one caught" do
    player = Object.new
    def player.owned?(_species); raise ArgumentError, "no dex"; end
    assert_equal [[numbered(7, "Species25", t(:pdx_category, :cat => "cat25"), "dex25"), true]],
                 with_player(player) { page_said(dex_scene(25, lambda { })) }
  end

  test "a size page says the species' measure, unknown for a species only seen" do
    { [4, :pdx_height, :h, true] => "Pikachu. #{t(:pdx_height, :h => '0,4', :n => 0.4)}",
      [60, :pdx_weight, :w, true] => "Pikachu. #{t(:pdx_weight, :w => '6,0', :n => 6.0)}",
      [4, :pdx_height, :h, false] => "Pikachu. #{t(:pdx_unknown_value)}",
      [0, :pdx_height, :h, true] => "Pikachu" }.each do |(value, key, var, owned), want|
      assert_equal want, PDX.measure_text("Pikachu", value, key, var, owned), "#{value} #{key}, owned #{owned}"
    end
  end

  test "Royal's height page says the character the species stands beside, with his height" do
    assert_equal [["SpeciesPIKACHU. #{t(:pdx_compare, :name => 'Hombre', :v => '1.7 m')}", true]],
                 with_owned(true) { page_said(size_page(:page_height, 0), 4) }
  end

  test "choosing another character repaints the size page, and the new one is said" do
    scene = size_page(:page_height, 0)
    with_owned(true) do
      page_said(scene, 4)
      scene.instance_variable_set(:@hwComparator, 1)
      assert_equal [["SpeciesPIKACHU. #{t(:pdx_compare, :name => 'Snorlax de peluche', :v => '0.6 m')}", true]],
                   page_said(scene, 4)
    end
  end

  test "Royal's weight page says the character's weight" do
    assert_equal [["SpeciesPIKACHU. #{t(:pdx_compare, :name => 'Snorlax de peluche', :v => '5 kg')}", true]],
                 with_owned(true) { page_said(size_page(:page_weight, 1), 5) }
  end

  test "a size page with no character beside the species, or one with no name, says the measure alone" do
    plain = dex_scene(:PIKACHU, lambda { })
    plain.instance_variable_set(:@page_id, :page_weight)
    { "no character" => plain, "a character with no name" => size_page(:page_weight, 2) }.each do |what, scene|
      assert_equal [["SpeciesPIKACHU", true]], with_owned(true) { page_said(scene, 5) }, what
    end
  end

  test "a page an addon adds is said as painted, in reading order, each label with its value" do
    paint = lambda { pbDrawTextPositions(nil, [["Hábitat:", 40, 100], ["Pradera", 200, 100], ["Datos", 40, 60]]) }
    assert_equal [["Datos, Hábitat: Pradera", true]], page_said(dex_scene(:PIKACHU, paint), 9)
  end

  test "an addon page that paints nothing says nothing" do
    assert_equal [], page_said(dex_scene(:PIKACHU, lambda { }), 9)
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A composed entry page as said at full: its number and name, then the rest.
  def numbered(n, name, *rest)
    [t(:pdx_number, :n => n, :name => name)].concat(rest).join(". ")
  end

  # Pikachu's owned info page as said at full, row by row.
  def owned_line
    ["007 Pikachu", t(:dex_caught), "Pokémon Ratón", t(:pdx_type, :t => "TypeTYPE1"), "Altura", "0.4 m", "Peso",
     "6.0 kg", "Almacena electricidad."]
  end

  # Pikachu's info page, painted as v21 paints it.
  def pikachu_page
    dex_scene(:PIKACHU, paint_dex_info("007 Pikachu", "Pokémon Ratón", ["0.4 m", "6.0 kg"], "Almacena electricidad."))
  end

  # The paint of a v21 info page: the entry text first (drawTextEx), then header, labels, category and values out of
  # reading order; with battled, the encountered count in the size's place.
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

  # The paint of a page with its own "Tipo" label beside the type icons, as Royal's.
  def labelled_paint(category, height, weight)
    lambda do
      drawTextEx(nil, 40, 291, 432, 4, "")
      pbDrawTextPositions(nil, [["025 Pikachu", 399, 58], ["Tipo", 327, 153], ["Altura", 327, 194], ["Peso", 327, 235],
                                [category, 466, 110], [height, 547, 194], [weight, 559, 235]])
    end
  end

  # An entry scene on species, number 7 of its list, painting with paint.
  def dex_scene(species, paint)
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@species, species)
    scene.instance_variable_set(:@form, 0)
    scene.instance_variable_set(:@dexlist, [{ :species => species, :number => 7, :shift => false }])
    scene.instance_variable_set(:@index, 0)
    scene.instance_variable_set(:@paint, paint)
    scene
  end

  # Royal's size page (:page_height or :page_weight), Pikachu beside the character numbered comparator: a man, or a
  # Snorlax doll.
  def size_page(page_id, comparator)
    scene = dex_scene(:PIKACHU, lambda { })
    scene.instance_variable_set(:@page_id, page_id)
    scene.instance_variable_set(:@hwComparator, comparator)
    def scene.pbGetComparisonName(id); ["Hombre", "Snorlax de peluche"][id]; end
    def scene.pbGetComparisonHeight(id); [1.7, 0.6][id]; end
    def scene.pbGetComparisonWeight(id); [62, 5][id]; end
    scene
  end

  # What drawing page of the scene says.
  def page_said(scene, page = 1)
    SpeakCapture.clear
    scene.drawPage(page)
    SpeakCapture.log.dup
  end

  # The block's value with no page painted before it, as the composed page is read; what was painted is put back.
  def composed
    was = PDX.painted_rows
    PDX.painted_rows = nil
    yield
  ensure
    PDX.painted_rows = was
  end

  # Runs the block with a player who owns every species, or has only seen them.
  def with_owned(owned)
    player = $player.dup
    player.define_singleton_method(:owned?) { |_species| owned }
    with_player(player) { yield }
  end

  # Runs the block with player as $player.
  def with_player(player)
    had = $player
    $player = player
    yield
  ensure
    $player = had
  end

  # Runs the block with GameData::Species answering a form's own data ("<species>_<form>"), as v20 and later do.
  def with_species_forms
    GameData::Species.define_singleton_method(:get_species_form) { |species, form| new("#{species}_#{form}") }
    yield
  ensure
    GameData::Species.singleton_class.send(:remove_method, :get_species_form)
  end

  # Runs the block with every species' own dex number at number.
  def with_dex_numbers(number)
    GameData::Species.send(:define_method, :id_number) { number }
    yield
  ensure
    GameData::Species.send(:remove_method, :id_number)
  end

  # Runs the block with Royal's shown_types in core's place.
  def with_royal_types
    meta = PokeAccess::PokedexInfoV21.singleton_class
    core = meta.instance_method(:shown_types)
    meta.send(:define_method, :shown_types, self.class.royal_types)
    yield
  ensure
    meta.send(:define_method, :shown_types, core)
  end
end
