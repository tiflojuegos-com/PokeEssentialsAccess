# Clara's Character Profiles (plugins/character_profiles.rb): the list says its heading as it opens, and the profile
# says each page as drawPage paints it (name, short facts, then paragraphs) with its place among the pages, once per
# page, however often the scene repaints it.

# The list screen, reduced to its heading window and the loop the heading is said ahead of.
class CharacterProfileListScene
  Header = Struct.new(:text)

  def initialize(heading = "Perfiles de personaje")
    @sprites = heading ? { "header" => Header.new(heading) } : {}
  end

  def start; :list_closed; end
end

# The profile screen with drawPage painting what the script paints, in its order: the name, then on the first page the
# paragraphs (origin, partner, description) and the positioned facts (ally, age, sex), on the second the data blocks.
class CharacterPageDisplayScene
  PAGES = 2

  def initialize(profile = {})
    @profile = { :name => "Rojo Fuego", :ally => "Aliado", :age => "10", :gender => "♂", :hometown => "Pueblo Paleta",
                 :partner => "Pikachu", :description => "Un entrenador de Pueblo Paleta.<br><i>Le gustan los trenes.</i>",
                 :data => ["<b>¡Soy yo!</b><br>Prueba de datos 1", "<b>Rojo</b><br>Prueba de datos 2",
                           "Dato no disponible"] }.update(profile)
  end

  def drawPage(id = 0)
    p = @profile
    drawFormattedTextEx(nil, 24, 2, 464, p[:name], nil, nil, 26)
    facts = []
    if id == 0
      facts.push([p[:ally], 96, 232, 2]) if p[:ally]
      facts.push(["Edad:", 24, 264, 0], [p[:age], 168, 264, 1]) if p[:age]
      facts.push(["Sexo:", 24, 296, 0], [p[:gender], 168, 296, 1]) if p[:gender]
      drawFormattedTextEx(nil, 200, 56, 288, "<b>Lugar de origen:</b><br>#{p[:hometown]}", nil, nil, 26)
      drawFormattedTextEx(nil, 200, 110, 288, "<b>Pokémon insignia:</b><br>#{p[:partner]}", nil, nil, 26) if p[:partner]
      drawFormattedTextEx(nil, 200, 184, 288, "<b>Descripción</b><br>#{p[:description]}", nil, nil, 26)
    else
      [56, 168, 280].each_with_index { |y, i| drawFormattedTextEx(nil, 24, y, 464, p[:data][i], nil, nil, 26) }
    end
    pbDrawTextPositions(nil, facts)
    :page_drawn
  end
end

# The plugin's hooks, which the harness's own load of the file left unbound as the classes were not there yet.
CHARACTER_PROFILE_HOOKS = Harness.source(File.join(Harness::ROOT, "plugins", "character_profiles.rb"))
                                 .scan(/^PokeAccess::Hooks\.(?:before_hook|around_hook)\("Character\w+".*?^end\n/m)
CHARACTER_PROFILE_HOOKS.each { |hook| eval(hook, TOPLEVEL_BINDING, "plugins/character_profiles.rb") }

class CharacterProfilesTest < PokeAccessTest
  LABELS = { "chp_page" => "Página %{n} de %{tot}" }.freeze

  FIRST_PAGE = "Rojo Fuego. Página 1 de 2. Aliado. Edad: 10. Sexo: ♂. Lugar de origen: Pueblo Paleta. " \
               "Pokémon insignia: Pikachu. Descripción Un entrenador de Pueblo Paleta. Le gustan los trenes."
  SECOND_PAGE = "Rojo Fuego. Página 2 de 2. ¡Soy yo! Prueba de datos 1. Rojo Prueba de datos 2. Dato no disponible"

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @added = LABELS.keys.reject { |k| table.key?(k) }
    @added.each { |k| table[k] = LABELS[k] }
  end

  def teardown
    @added.each { |k| PokeAccess::I18n.table(:es).delete(k) }
    super
  end

  test "the plugin hooks the list's start and the profile's page drawing" do
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    assert_equal 2, CHARACTER_PROFILE_HOOKS.length
    assert_equal [true, true], ["CharacterProfileListScene#start", "CharacterPageDisplayScene#drawPage"].map { |k| chains.key?(k) }
  end

  test "opening the profile reads the first page, name first, then the short facts, then the paragraphs, queued" do
    CharacterPageDisplayScene.new.drawPage(0)
    assert_equal [[FIRST_PAGE, false]], SpeakCapture.log
  end

  test "a page change reads the second page, interrupting" do
    scene = CharacterPageDisplayScene.new
    scene.drawPage(0)
    scene.drawPage(1)
    assert_equal [[FIRST_PAGE, false], [SECOND_PAGE, true]], SpeakCapture.log
  end

  test "going back reads the first page again, and a page drawn with no page given is the first" do
    scene = CharacterPageDisplayScene.new
    scene.drawPage(0)
    scene.drawPage(1)
    scene.drawPage
    assert_equal [FIRST_PAGE, SECOND_PAGE, FIRST_PAGE], SpeakCapture.lines
  end

  test "a page repainted as it stands, as LEFT on the first page does, is not read again" do
    scene = CharacterPageDisplayScene.new
    3.times { scene.drawPage(0) }
    assert_equal [FIRST_PAGE], SpeakCapture.lines
  end

  test "each profile screen starts afresh, queued" do
    2.times { CharacterPageDisplayScene.new.drawPage(0) }
    assert_equal [[FIRST_PAGE, false], [FIRST_PAGE, false]], SpeakCapture.log
  end

  test "leaves out the facts and paragraphs the profile does not have" do
    CharacterPageDisplayScene.new(:ally => nil, :partner => nil, :age => nil).drawPage(0)
    assert_equal ["Rojo Fuego. Página 1 de 2. Sexo: ♂. Lugar de origen: Pueblo Paleta. " \
                  "Descripción Un entrenador de Pueblo Paleta. Le gustan los trenes."], SpeakCapture.lines
  end

  test "says the page's place only while positions are said" do
    said = vb_levels do
      SpeakCapture.clear
      CharacterPageDisplayScene.new.drawPage(0)
      SpeakCapture.lines.first
    end
    assert_equal [FIRST_PAGE.sub(" Página 1 de 2.", ""), FIRST_PAGE, FIRST_PAGE], said
  end

  test "leaves the place out where the scene keeps no count of its pages" do
    pages = CharacterPageDisplayScene.send(:remove_const, :PAGES)
    begin
      CharacterPageDisplayScene.new.drawPage(0)
    ensure
      CharacterPageDisplayScene.const_set(:PAGES, pages)
    end
    assert_equal [FIRST_PAGE.sub(" Página 1 de 2.", "")], SpeakCapture.lines
  end

  test "hands back what the game's drawPage returns" do
    assert_equal :page_drawn, CharacterPageDisplayScene.new.drawPage(1)
  end

  test "a page that painted nothing the reader can take is said by its place alone" do
    PokeAccess::CharacterProfiles.page(CharacterPageDisplayScene.new, 1, [])
    assert_equal [t(:chp_page, :n => 2, :tot => 2)], SpeakCapture.lines
  end

  test "a screen with no page count and no paint says nothing" do
    pages = CharacterPageDisplayScene.send(:remove_const, :PAGES)
    begin
      PokeAccess::CharacterProfiles.page(CharacterPageDisplayScene.new, 0, [])
    ensure
      CharacterPageDisplayScene.const_set(:PAGES, pages)
    end
    assert_nothing_spoken
  end

  test "the list says its heading as it opens, queued, and hands back its loop's value" do
    ret = CharacterProfileListScene.new.start
    assert_equal [:list_closed, [["Perfiles de personaje", false]]], [ret, SpeakCapture.log]
  end

  test "a list with no heading window says nothing" do
    CharacterProfileListScene.new(nil).start
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
