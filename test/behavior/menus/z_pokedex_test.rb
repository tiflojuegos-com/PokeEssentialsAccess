# Pokemon Z's own dex entry (games/pokemon_z/pokedex.rb): opening it says the species, its types and the first page;
# turning a page says that page as the screen paints it, its place in the entry from medium verbosity up.

# Pokemon Z's entry screen as the game drives it: pbStartScene takes the species and fills the entry as getInfo and the
# move lists do (no pages for a species not caught), painting an owned one's first page; displayPage paints the page
# @page names. It bears the game's name AdvancedPokedexScene only during each test of this file (setup, teardown), as
# Desolation's tests give that name to a stand-in of their own.
class ZAdvancedPokedexScene
  def initialize(entry = {})
    @entry = entry
  end

  def pbStartScene(species)
    @species = species
    @page = 1
    @totalPages = 0
    @entry.each { |k, v| instance_variable_set("@#{k}", v) }
    displayPage if @totalPages.to_i > 0
    true
  end

  def displayPage
    nil
  end

  # Turns to page n and paints it, as the game's C and A do.
  def turn_to(n)
    @page = n
    displayPage
  end
end

class ZPokedexTest < PokeAccessTest
  # The profile, and the keys under which Hooks chains the two hooks it puts on the screen.
  PROFILE = File.join(Harness::ROOT, "games", "pokemon_z", "pokedex.rb")
  SCREEN_HOOKS = %w[AdvancedPokedexScene#pbStartScene AdvancedPokedexScene#displayPage].freeze

  # An owned species' entry as Pokemon Z fills it: three info pages of six lines a column, only the left column of each
  # page painted; twelve level moves over two pages, three egg moves and two machine moves.
  INFO = [
    ["RATIO DE CAPTURA: 190", nil, "PASOS PARA ECLOSIONAR: 2560 (10 ciclos)", nil, "RATIO DE GÉNERO: Macho 50.0%",
     "GRUPO HUEVO: Campo, Hada"],
    [nil, nil, nil, nil, nil, nil],
    ["PS ATQ DEF AES DES VEL TOT", "STATS BASE: 035 055 040 050 050 090 320", nil, "HABILIDADES: Electricidad Estática",
     "HABILIDAD OCULTA: Pararrayos", nil],
    [nil, nil, nil, nil, nil, nil],
    ["OBJETOS SALVAJE: Baya Aranja (común)", "Bola Luminosa (raro)", nil, "EVOLUCIÓN: Raichu, con Piedra Trueno", nil,
     nil],
    [nil, nil, nil, nil, nil, nil]
  ].freeze
  LEVEL_MOVES = ["01 Impactrueno", "01 Gruñido", "05 Látigo", "10 Ataque Rápido", "13 Onda Trueno", "18 Doble Equipo",
                 "21 Chispa", "26 Amago", "29 Bola Voltio", "34 Rayo", "37 Agilidad", "42 Trueno"].freeze
  EGG_MOVES = ["     Encanto", "     Mordisco", "     Sorpresa"].freeze
  MACHINE_MOVES = ["MT06 Tóxico", "MT10 Poder Oculto"].freeze
  OWNED = { :type1 => 13, :type2 => 1, :infoPages => 3, :levelMovesPages => 2, :eggMovesPages => 1, :totalPages => 7,
            :infoArray => INFO, :levelMovesArray => LEVEL_MOVES, :eggMovesArray => EGG_MOVES,
            :machineMovesArray => MACHINE_MOVES }.freeze

  # Each page of that entry as the screen paints it, without its place.
  PAGES = {
    1 => "RATIO DE CAPTURA: 190 PASOS PARA ECLOSIONAR: 2560 (10 ciclos) RATIO DE GÉNERO: Macho 50.0% " \
         "GRUPO HUEVO: Campo, Hada",
    2 => "PS ATQ DEF AES DES VEL TOT STATS BASE: 035 055 040 050 050 090 320 HABILIDADES: Electricidad Estática " \
         "HABILIDAD OCULTA: Pararrayos",
    3 => "OBJETOS SALVAJE: Baya Aranja (común) Bola Luminosa (raro) EVOLUCIÓN: Raichu, con Piedra Trueno",
    4 => "MOVIMIENTOS POR NIVEL: 01 Impactrueno 01 Gruñido 05 Látigo 10 Ataque Rápido 13 Onda Trueno " \
         "18 Doble Equipo 21 Chispa 26 Amago 29 Bola Voltio 34 Rayo",
    5 => "MOVIMIENTOS POR NIVEL: 37 Agilidad 42 Trueno",
    6 => "MOVIMIENTOS HUEVO: Encanto Mordisco Sorpresa",
    7 => "MOVIMIENTOS POR MT Y MO: MT06 Tóxico MT10 Poder Oculto"
  }.freeze

  # Gives Pokemon Z's screen the game's name and the profile's hooks for the test; the class and the hooks another
  # test gave that name are set aside until teardown.
  def setup
    super
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    @held = SCREEN_HOOKS.select { |key| chains.key?(key) }.map { |key| [key, chains.delete(key)] }
    @had = Object.const_defined?(:AdvancedPokedexScene, false) ? Object.send(:remove_const, :AdvancedPokedexScene) : nil
    Object.const_set(:AdvancedPokedexScene, ZAdvancedPokedexScene)
    chains.update(self.class.screen_chains)
  end

  # Takes the name and the hooks back from Pokemon Z's screen and puts back what setup set aside.
  def teardown
    if @held
      chains = PokeAccess::Hooks.instance_variable_get(:@chains)
      SCREEN_HOOKS.each { |key| chains.delete(key) }
      @held.each { |key, list| chains[key] = list }
      Object.send(:remove_const, :AdvancedPokedexScene) if Object.const_defined?(:AdvancedPokedexScene, false)
      Object.const_set(:AdvancedPokedexScene, @had) if @had
    end
    super
  end

  test "opening an owned species' entry says its name, its types and its first page, cutting in" do
    ZAdvancedPokedexScene.new(OWNED).pbStartScene(25)
    assert_equal [["Especie25. #{types('Tipo13/Tipo1')}. #{place(1)} #{PAGES[1]}", true]], SpeakCapture.log
  end

  test "a species of one type is said to be of that type alone" do
    ZAdvancedPokedexScene.new(OWNED.merge(:type2 => 13)).pbStartScene(25)
    assert_equal ["Especie25. #{types('Tipo13')}. #{place(1)} #{PAGES[1]}"], SpeakCapture.lines
  end

  test "opening a species not caught says its name, its types and that it is not caught" do
    ZAdvancedPokedexScene.new(:type1 => 13, :type2 => 1).pbStartScene(25)
    assert_equal [["Especie25. #{types('Tipo13/Tipo1')}. #{PokeAccess::I18n.t(:pdx_not_caught)}.", true]],
                 SpeakCapture.log
  end

  test "a species the game can neither name nor type opens on its first page alone" do
    failing(PBSpecies, :getName) { failing(PBTypes, :getName) { ZAdvancedPokedexScene.new(OWNED).pbStartScene(25) } }
    assert_equal [["#{place(1)} #{PAGES[1]}", true]], SpeakCapture.log
  end

  test "turning to a page says that page as the screen paints it, cutting in" do
    scene = opened(OWNED)
    PAGES.each { |n, words| assert_equal [["#{place(n)} #{words}", true]], turned(scene, n), "page #{n}" }
  end

  test "turning the page of a species not caught says nothing" do
    scene = opened(:type1 => 13, :type2 => 1)
    assert_equal [], turned(scene, 1)
  end

  test "says the page's place in the entry from medium verbosity up" do
    scene = opened(OWNED)
    full = ["#{place(5)} #{PAGES[5]}"]
    assert_equal [[PAGES[5]], full, full], vb_levels { turned(scene, 5).map { |text, _| text } }
  end

  test "says each move list's title in the running build's words" do
    english = { "MOVIMIENTOS POR NIVEL:" => "LEVEL-UP MOVES:", "MOVIMIENTOS HUEVO:" => "EGG MOVES:",
                "MOVIMIENTOS POR MT Y MO:" => "TM AND HM MOVES:" }
    scene = opened(OWNED)
    with_intl(english) do
      { 4 => "MOVIMIENTOS POR NIVEL:", 6 => "MOVIMIENTOS HUEVO:", 7 => "MOVIMIENTOS POR MT Y MO:" }.each do |n, title|
        assert_equal [["#{place(n)} #{PAGES[n].sub(title, english[title])}", true]], turned(scene, n), "page #{n}"
      end
    end
  end

  test "says a title the game's translation fails on in the game's own words" do
    scene = opened(OWNED)
    failing_intl { assert_equal [["#{place(4)} #{PAGES[4]}", true]], turned(scene, 4) }
  end

  test "has no page text without a page, a page count or any pages, or with a count it cannot read" do
    [{ :page => nil }, { :totalPages => nil }, { :totalPages => 0 }, { :totalPages => "7" }].each do |ivars|
      assert_nil PokeAccess::ZPokedex.page_text(entry_at(OWNED.merge(:page => 1).merge(ivars))), ivars.inspect
    end
  end

  test "a page count the entry lacks counts as no pages of that kind" do
    lists = { :infoArray => [["RATIO DE CAPTURA: 190"]], :levelMovesArray => ["01 Impactrueno"],
              :eggMovesArray => ["Encanto"], :machineMovesArray => ["MT06 Tóxico"] }
    {
      { :levelMovesPages => 1, :eggMovesPages => 1, :totalPages => 2, :page => 1 } =>
        "MOVIMIENTOS POR NIVEL: 01 Impactrueno",
      { :infoPages => 1, :eggMovesPages => 1, :totalPages => 2, :page => 2 } => "MOVIMIENTOS HUEVO: Encanto",
      { :infoPages => 1, :levelMovesPages => 1, :totalPages => 3, :page => 3 } => "MOVIMIENTOS POR MT Y MO: MT06 Tóxico"
    }.each do |counts, words|
      assert_equal "#{place(counts[:page], counts[:totalPages])} #{words}",
                   PokeAccess::ZPokedex.page_text(entry_at(lists.merge(counts))), counts.inspect
    end
  end

  test "a one-page entry reads the few lines it has, skipping blank ones" do
    scene = entry_at(:page => 1, :totalPages => 1, :infoPages => 1,
                     :infoArray => [["RATIO DE CAPTURA: 3", nil, "  ", "GRUPO HUEVO: Ninguno"]])
    assert_equal "#{place(1, 1)} RATIO DE CAPTURA: 3 GRUPO HUEVO: Ninguno", PokeAccess::ZPokedex.page_text(scene)
  end

  test "says only the place and the title of a page whose list the entry lacks" do
    lacking = { 1 => [:infoArray, place(1)], 4 => [:levelMovesArray, "#{place(4)} MOVIMIENTOS POR NIVEL:"] }
    lacking.each do |n, (list, said)|
      assert_equal said, PokeAccess::ZPokedex.page_text(entry_at(OWNED.merge(:page => n, list => nil))), "page #{n}"
    end
  end

  private

  # The page's place as the reader says it ahead of the page.
  def place(n, total = 7)
    "#{PokeAccess::I18n.t(:adv_dex_page, :n => n, :m => total)}."
  end

  # The types part of the opening, for the type names it says.
  def types(names)
    PokeAccess::I18n.t(:pdx_type, :t => names)
  end

  # The entry screen opened on species 25 with entry's data, what the opening said cleared.
  def opened(entry)
    scene = ZAdvancedPokedexScene.new(entry)
    scene.pbStartScene(25)
    SpeakCapture.clear
    scene
  end

  # What turning scene to page n says, as [text, interrupt] pairs.
  def turned(scene, n)
    SpeakCapture.clear
    scene.turn_to(n)
    SpeakCapture.log.dup
  end

  # A bare scene holding ivars as its instance variables, for page_text alone.
  def entry_at(ivars)
    scene = Object.new
    ivars.each { |k, v| scene.instance_variable_set("@#{k}", v) }
    scene
  end

  # Runs the block with the game table mod's singleton method name raising; put back after.
  def failing(mod, name)
    original = mod.method(name)
    mod.define_singleton_method(name) { |*_args| raise ArgumentError, "no entry" }
    yield
  ensure
    mod.define_singleton_method(name, original) if original
  end

  # Runs the block with the game's _INTL raising, as a translation it cannot make; the stub's put back after.
  def failing_intl
    Object.send(:alias_method, :pa_failing_intl, :_INTL)
    Object.send(:define_method, :_INTL) { |*_args| raise ArgumentError, "no translation" }
    Object.send(:private, :_INTL)
    yield
  ensure
    Object.send(:alias_method, :_INTL, :pa_failing_intl)
    Object.send(:remove_method, :pa_failing_intl)
  end

  class << self
    # The profile's hooks bound to the screen, by key: the profile evaluated once more on the first call, which setup
    # makes with the screen under the game's name and no hooks under it. Only once, as coverage counts a file's lines
    # from its last evaluation alone.
    def screen_chains
      @screen_chains ||= begin
        eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
        PokeAccess::Hooks.instance_variable_get(:@chains).select { |key, _chain| SCREEN_HOOKS.include?(key) }
      end
    end
  end
end
