# Arcky's region map (Royal): the extended preview's progress page (drawDataMain) said as it opens, the map's name as
# the bottom bar shows it and then each box, kept for the info key until the preview closes, which gives the key back
# to the square; again back from the encounter table or reopened, never for a redraw of the page in view. The bar's
# own name reader stays quiet about the name the page says. Core's bar listener and the plugin's page hooks are
# evaluated again over the stand-ins below, which hold the game's names only while they bind.
module ArckyProgressSpec
  # The page's text sprite as the reader asks it: whether it shows, and the bitmap the page is painted on.
  Text = Struct.new(:visible, :bitmap)

  # The extended preview's state (ExtendedState): the page, or the encounter table over it.
  Box = Struct.new(:page) do
    def isMain; page == :main; end
  end

  # MapBottomSprite as Royal and the plugin make it: each setter that changes its text repaints all four on its own
  # bitmap.
  class Bar
    def initialize(name, place)
      @mapname = name
      @maplocation = place
      @mapdetails = "Centro Pokémon"
      @previewName = ""
      @bitmap = Object.new
    end

    def mapname=(value); return if @mapname == value; @mapname = value; refresh; end
    def maplocation=(value); return if @maplocation == value; @maplocation = value; refresh; end
    def mapdetails=(value); return if @mapdetails == value; @mapdetails = value; refresh; end

    def refresh
      pbDrawTextPositions(@bitmap, [[@mapname, 18, 4], [@maplocation, 18, 360], [@mapdetails, 496, 360],
                                    [@previewName, 400, 4]])
    end
  end

  # PokemonRegionMap_Scene's page: drawDataMain writes the map's name and progress to the bar, clears its place and
  # detail, and paints the boxes' rows on the page's own bitmap; hideExtendedPreview hides it, the cursor's square
  # (@mapX, @mapY) unmoved, whose detail pbGetMapDetails gives.
  class Scene
    attr_reader :sprites

    def initialize(data, rows, detail = "Centro Pokémon")
      @sprites = { "mapbottom" => Bar.new("Región Royal", "Ruta 1"), "extendedText" => Text.new(false, Object.new) }
      @extendedBox = Box.new(:main)
      @data = data
      @rows = rows
      @detail = detail
      @mapX = 7
      @mapY = 3
    end

    def pbGetMapDetails(x, y)
      [x, y] == [@mapX, @mapY] ? @detail : ""
    end

    def hideExtendedPreview
      @sprites["extendedText"].visible = false
      :hidden
    end

    def page=(page); @extendedBox.page = page; end

    def drawDataMain
      @sprites["mapbottom"].mapname = "#{@data[:name]} #{@data[:progress]}" if @data
      @sprites["mapbottom"].maplocation = ""
      @sprites["mapbottom"].mapdetails = ""
      pbDrawTextPositions(@sprites["extendedText"].bitmap, @rows.map { |t| [t, 16, 12, :left] })
      :page_drawn
    end
  end
end

arcky_names = [:PokemonRegionMap_Scene, :MapBottomSprite]
arcky_held = arcky_names.map { |n| [n, Object.const_defined?(n) ? Object.const_get(n) : nil] }
begin
  arcky_held.each { |n, k| Object.send(:remove_const, n) if k }
  Object.const_set(:PokemonRegionMap_Scene, ArckyProgressSpec::Scene)
  Object.const_set(:MapBottomSprite, ArckyProgressSpec::Bar)
  ui = File.join(Harness::ROOT, "core", "menus", "v21", "ui_v21.rb")
  ui_src = Harness.source(ui)
  bar_at = ui_src.index('PokeAccess::Hooks.after_hook("MapBottomSprite", :mapname=)')
  bar_end = ui_src.index("\n", ui_src.index(/^end\s*$/, bar_at)) + 1
  eval(ui_src[bar_at...bar_end], TOPLEVEL_BINDING, ui, ui_src[0, bar_at].count("\n") + 1)
  arcky = File.join(Harness::ROOT, "plugins", "arcky_region_map.rb")
  arcky_src = Harness.source(arcky)
  [/^PokeAccess::Hooks\.around_hook\("PokemonRegionMap_Scene", :drawDataMain.*?^end\r?\n/m,
   /^PokeAccess::Hooks\.after_hook\("PokemonRegionMap_Scene", :hideExtendedPreview.*?^end\r?\n/m,
   /^PokeAccess::Hooks\.before_hook\("MapBottomSprite", :mapname=.*?^end\r?\n/m].each do |part|
    found = arcky_src.match(part)
    eval(found[0], TOPLEVEL_BINDING, arcky, arcky_src[0, found.begin(0)].count("\n") + 1)
  end
ensure
  arcky_names.each { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
  arcky_held.each { |n, k| Object.const_set(n, k) if k }
end

class ArckyProgressGdTest < PokeAccessTest
  Scene = ArckyProgressSpec::Scene
  YARDA = { :name => "Pueblo Yarda", :progress => "" }
  ROWS = ["Encuentros salvajes:", "     3 avistados", "     2 capturados", "     1 derrotados", " ", "Entrenadores",
          "     2 de 4 derrotados.", " ", "Objetos", "     ¡Has encontrado todos los Objetos!", " "]
  PAGE = "Pueblo Yarda. Encuentros salvajes: 3 avistados, 2 capturados, 1 derrotados. Entrenadores, 2 de 4 " \
         "derrotados. Objetos, ¡Has encontrado todos los Objetos!"

  test "opening says the map's name and each box, cutting in, and leaves the bar's repaints out" do
    Scene.new(YARDA, ROWS).drawDataMain
    assert_equal [[PAGE, true]], SpeakCapture.log
  end

  test "the info key keeps the page" do
    Scene.new(YARDA, ROWS).drawDataMain
    assert_equal PAGE, PokeAccess::Info.info_text
  end

  test "the bar's name reader says nothing more for the name the page said" do
    PokeAccess::Cursor.store(nil, :regionname, "Región Royal")
    Scene.new(YARDA, ROWS).drawDataMain
    PokeAccess::Frame.run_pollers
    assert_equal [PAGE], SpeakCapture.lines
  end

  test "a name the bar gets once the page is drawn, back on the map, is still its reader's" do
    PokeAccess::Cursor.store(nil, :regionname, "Región Royal")
    scene = Scene.new(YARDA, ROWS)
    scene.drawDataMain
    scene.sprites["mapbottom"].mapname = "Región Royal"
    PokeAccess::Frame.run_pollers
    assert_equal [PAGE, "Región Royal"], SpeakCapture.lines
  end

  test "the progress the bar shows beside the name is said with it" do
    Scene.new({ :name => "Pueblo Yarda", :progress => "- 45.5%" }, ["Objetos", "     1 de 2 encontrados."]).drawDataMain
    assert_equal ["Pueblo Yarda - 45.5%. Objetos, 1 de 2 encontrados."], SpeakCapture.lines
  end

  test "a place with no data says the name the bar keeps and the page's one line" do
    Scene.new(nil, ["No hay datos para esta ubicación."]).drawDataMain
    assert_equal ["Región Royal. No hay datos para esta ubicación."], SpeakCapture.lines
  end

  test "left and right redrawing the page in view say nothing more" do
    shown_page.drawDataMain
    assert_equal [PAGE], SpeakCapture.lines
  end

  test "back from the encounter table the page is said again" do
    scene = shown_page
    scene.page = :subOne
    scene.drawDataMain
    assert_equal [PAGE, PAGE], SpeakCapture.lines
  end

  test "reopened on the same map the page is said again" do
    scene = shown_page
    scene.sprites["extendedText"].visible = false
    scene.drawDataMain
    assert_equal [PAGE, PAGE], SpeakCapture.lines
  end

  test "the page keeps what the game's drawDataMain returns" do
    assert_equal :page_drawn, Scene.new(YARDA, ROWS).drawDataMain
  end

  test "closing the preview gives the info key back to the detail of the square under the cursor" do
    scene = shown_page
    assert_equal :hidden, scene.hideExtendedPreview
    assert_equal "Centro Pokémon", PokeAccess::Info.info_text
  end

  test "closing it over a square with no detail leaves the page off the info key" do
    scene = Scene.new(YARDA, ROWS, "")
    scene.drawDataMain
    scene.hideExtendedPreview
    assert_nil PokeAccess::Info.info_text
  end

  private

  # A page drawn as it opens and then shown, as getExtendedInfo leaves it.
  def shown_page
    scene = Scene.new(YARDA, ROWS)
    scene.drawDataMain
    scene.sprites["extendedText"].visible = true
    scene
  end
end
