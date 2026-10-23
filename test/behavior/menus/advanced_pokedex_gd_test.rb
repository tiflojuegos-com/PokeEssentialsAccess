# FL's Advanced Pokedex on the fourth entry page (plugins/advanced_pokedex.rb), gamedata pass: a sub-page is read down
# each column with its count, the name and the types leading on the way in, and drawPage(4) is said by this reader
# alone; a page an addon adds past it is the core page reader's, read as painted.

# The entry scene with the plugin's sub-page painter, which paints what a test hands it in @sub_paint. The plugin's
# reader was evaluated before the stub had it, so its displaySubPage hook is evaluated again over it.
class PokemonPokedexInfo_Scene
  def displaySubPage
    @sub_paint.call if @sub_paint
    :sub_page
  end
end

path = File.join(Harness::ROOT, "plugins", "advanced_pokedex.rb")
src = Harness.source(path)
at = src.index('PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :displaySubPage')
eval(src[at..-1], TOPLEVEL_BINDING, path, src[0, at].count("\n") + 1)

class AdvancedPokedexGdTest < PokeAccessTest
  NAME = ["Pikachu", 292, 298]
  STATS = [["PS: 35", 30, 66], ["Velocidad: 90", 254, 66], ["Ataque: 55", 30, 98], ["Defensa: 40", 254, 98]]

  test "reads a sub-page down its first column, then the second, then its count" do
    assert_equal ["PS: 35", "Ataque: 55", "Velocidad: 90", "Defensa: 40", page(2, 7)].join(", "),
                 page_text(STATS + [NAME, count(2, 7)])
  end

  test "says the count from medium verbosity up, a page being a position" do
    grid = "PS: 35, Ataque: 55, Velocidad: 90, Defensa: 40"
    counted = "#{grid}, #{page(2, 7)}"
    assert_equal [grid, counted, counted], vb_levels { page_text(STATS + [NAME, count(2, 7)]) }
  end

  test "leads with the name and the types the icons show on the way in" do
    moves = [["MOVIMIENTOS POR NIVEL:", 30, 66], ["Nv. 1 Impactrueno", 30, 98], ["Nv. 5 Gruñido", 254, 98]]
    assert_equal ["Pikachu", type_line("TypeELECTRIC"), "MOVIMIENTOS POR NIVEL: Nv. 1 Impactrueno", "Nv. 5 Gruñido",
                  page(1, 7)].join(", "),
                 page_text(moves + [NAME, count(1, 7)], true, :@type1 => :ELECTRIC)
  end

  test "names the types from the form's data where the page keeps it, else from the two type ids it read" do
    form = Struct.new(:types)
    {
      { :@data => form.new([:FIRE]), :@type1 => :WATER } => type_line("TypeFIRE"),
      { :@type1 => :GRASS, :@type2 => :POISON } => type_line("TypeGRASS TypePOISON"),
      { :@type1 => :ELECTRIC, :@type2 => :ELECTRIC } => type_line("TypeELECTRIC"),
      {} => nil
    }.each do |ivars, types|
      assert_equal ["Pikachu", types, page(1, 7)].compact.join(", "), page_text([NAME, count(1, 7)], true, ivars),
                   "for #{ivars.inspect}"
    end
  end

  test "takes the bottom 40 pixels for the name and the count, and every row above them for the grid" do
    assert_equal "Nv. 50 Trueno, #{page(1, 7)}", page_text([["Nv. 50 Trueno", 30, 289], NAME, count(1, 7)]),
                 "a row 41 pixels above the count is grid"
    assert_equal ["Pikachu", type_line("TypeELECTRIC"), page(1, 7)].join(", "),
                 page_text([["Pikachu", 292, 290], count(1, 7)], true, :@type1 => :ELECTRIC),
                 "a name 40 pixels above the count is still the name"
  end

  test "finds the name beside the count wherever the count sits in the bottom band" do
    {
      "below the name" => [NAME, count(1, 7)],
      "above the name" => [["1/7", 460, 300], ["Pikachu", 292, 330]],
      "left of the name" => [["1/7", 30, 330], ["Pikachu", 292, 330]]
    }.each do |where, rows|
      assert_equal "Pikachu, #{page(1, 7)}", page_text(rows, true), "the count #{where}"
    end
  end

  test "gives no text for a page with nothing painted at a place, not even its types" do
    scene = World.stub_scene(:@type1 => :ELECTRIC)
    [nil, [], [["Pikachu", :dtex, nil, nil]], [["Pikachu", :positions, nil, 298]],
     [["Pikachu", :positions, 292, nil]]].each do |pairs|
      assert_nil PokeAccess::AdvancedPokedex.text(scene, pairs, true), "for #{pairs.inspect}"
    end
  end

  test "says only the name and the types of an entry not owned, which paints neither grid nor count" do
    ivars = { :@type1 => :ELECTRIC }
    assert_equal ["Pikachu, #{type_line("TypeELECTRIC")}", nil],
                 [page_text([NAME], true, ivars), page_text([NAME], false, ivars)]
  end

  test "passes over a blank row of the grid" do
    assert_equal "PS: 35, #{page(1, 7)}", page_text([["  ", 30, 66], ["PS: 35", 30, 98], NAME, count(1, 7)])
  end

  test "reads a sub-page the buttons flip without the name and the types, interrupting" do
    flip(dex_scene, [["PS: 35", 30, 66], ["Ataque: 55", 30, 98]], "2/7")
    assert_equal [["PS: 35, Ataque: 55, #{page(2, 7)}", true]], SpeakCapture.log
  end

  test "keeps displaySubPage's own return" do
    assert_equal :sub_page, flip(dex_scene, [["PS: 35", 30, 66]], "2/7")
  end

  test "says nothing more for a flip to a sub-page that reads as the last one" do
    scene = dex_scene
    flip(scene, [["PS: 35", 30, 66]], "2/7")
    flip(scene, [["PS: 35", 30, 66]], "2/7")
    assert_equal ["PS: 35, #{page(2, 7)}"], SpeakCapture.lines
  end

  test "says page 4 as drawPage opens it, once and by this reader alone, interrupting" do
    dex_scene.drawPage(4)
    assert_equal [[page_four, true]], SpeakCapture.log
  end

  test "keeps drawPage's own return on page 4" do
    assert_equal 4, dex_scene.drawPage(4)
  end

  test "says nothing more when page 4 is drawn again as it was" do
    scene = dex_scene
    draw(scene, 4)
    assert_equal [], draw(scene, 4)
  end

  test "lets the core page reader say a page again on the way back from page 4" do
    scene = dex_scene
    before = draw(scene, 1)
    draw(scene, 4)
    after = draw(scene, 1)
    assert_equal 1, before.length, "page 1 is said on the way in"
    assert_equal before, after, "and again on the way back"
  end

  test "says page 4 again on the way back to it from another page" do
    scene = dex_scene
    draw(scene, 4)
    draw(scene, 1)
    assert_equal [page_four], draw(scene, 4)
  end

  test "leaves a page an addon adds past page 4 to the core page reader, read as painted" do
    scene = dex_scene
    rows = [["Datos avanzados", 30, 30], ["PS: 35", 30, 66]]
    scene.instance_variable_set(:@paint, lambda { pbDrawTextPositions(nil, rows) })
    scene.drawPage(5)
    assert_equal [["Datos avanzados, PS: 35", true]], SpeakCapture.log
  end

  private

  # The page's text for these painted rows ([text, x, y]) on a scene holding the given instance variables.
  def page_text(rows, entering = false, ivars = {})
    pairs = rows.map { |t, x, y| [t, :positions, x, y] }
    PokeAccess::AdvancedPokedex.text(World.stub_scene(ivars), pairs, entering)
  end

  # The page count row as painted, sub-page n of m.
  def count(n, m)
    ["#{n}/#{m}", 460, 330]
  end

  # The spoken page count, sub-page n of m.
  def page(n, m)
    PokeAccess::I18n.t(:adv_dex_page, :n => n.to_s, :m => m.to_s)
  end

  # The types line for the type names the data gives.
  def type_line(names)
    PokeAccess::I18n.t(:pdx_type, :t => names)
  end

  # An electric entry whose page 4 paints its name, its count and two rows of its grid.
  def dex_scene
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@type1, :ELECTRIC)
    scene.instance_variable_set(:@paint, page_four_paint)
    scene
  end

  # The paint of the scene's page 4.
  def page_four_paint
    lambda do
      pbDrawTextPositions(nil, [["Pikachu", 292, 298], ["1/7", 460, 330]])
      pbDrawTextPositions(nil, [["PS: 35", 30, 66], ["Ataque: 55", 30, 98]])
    end
  end

  # What page 4 says on the way in.
  def page_four
    ["Pikachu", type_line("TypeELECTRIC"), "PS: 35", "Ataque: 55", page(1, 7)].join(", ")
  end

  # Flips the scene's page 4 to a sub-page painting these grid rows ([text, x, y]) above the name and the count
  # "n/m"; answers displaySubPage's return.
  def flip(scene, grid, count)
    scene.instance_variable_set(:@sub_paint, lambda { pbDrawTextPositions(nil, grid + [NAME, [count, 460, 330]]) })
    scene.displaySubPage
  end

  # The lines said while the scene draws page n: page 4 with its own paint, any other with the stub's.
  def draw(scene, n)
    scene.instance_variable_set(:@paint, n == 4 ? page_four_paint : nil)
    SpeakCapture.clear
    scene.drawPage(n)
    SpeakCapture.lines.dup
  end
end
