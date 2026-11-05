# Royal's own screens, gamedata pass: the Currydex at its reading's levels with what it leaves on the info key,
# the creator's notice, the League Cards list and card page, and the curry results.

# The Currydex list: [number, name] rows under the cursor.
class Window_Currydex
  attr_accessor :index
  def initialize(commands); @commands = commands; @index = 0; end
end

# The Currydex screen.
class PokemonCurrydex_Scene
  def pbStartScene; :started; end
  def pbEndScene; :ended; end
end

# The recipes: [number, name, description, flavour, ingredient] each.
module ResultadosCurry
  LISTADO_CURRYS = [[0, "Curri picante", "Un curri en el que las especias resaltan el picante.", nil, nil],
                    [1, "Curri dulce", "", nil, nil]]
end

# The save's curry records, as the game reads them: the recipes found and how many.
def pbCurryRegistered?(curry); $PokemonGlobal.recetas_curry_conseguidas[curry]; end

def pbCurryDexCount
  return 0 if !$PokemonGlobal.recetas_curry_conseguidas
  $PokemonGlobal.recetas_curry_conseguidas.count(true)
end

# The medal rank of a score, as the game ranks it: 1 to 5 by score band, -1 past them.
def rangoPuntuacionCurry(puntuacion)
  return 1 if (0..20).include?(puntuacion)
  return 2 if (21..41).include?(puntuacion)
  return 3 if (42..62).include?(puntuacion)
  return 4 if (63..83).include?(puntuacion)
  return 5 if puntuacion == 84
  -1
end

# The creator's notice at the quick-start intro.
class CreadorEventScene
  def pbStartScene; :shown; end
end

# The League Cards: [id, name, unused, description] each.
module TarjetasLiga
  def self.tarjetas
    [["CARD_LIONEL", "Lionel", false, "Lore de Lionel"], ["CARD_ROSE", "Rose", false, "Lore de Rose"],
     ["CARD_SONIA", "Sonia", false, "Lore de Sonia"], ["CARD_BLANK", "", false, ""]]
  end
end

# Whether the player has the card at a place in the list: all but the second.
def tarjeta_desbloqueada?(indice); indice != 1; end

# The cards list, a sprite grid repainted every frame: choose moves the cursor and repaints.
class TarjetasLiga_Scene
  def initialize; @tarjeta_elegida = 0; end
  def choose(i); @tarjeta_elegida = i; actualizarTarjetasPantalla; end
  def actualizarTarjetasPantalla; :redrawn; end
  def pbEndScene; :ended; end
end

# A card's page: its name and key hints painted as it opens, its description as it is read.
class InfoTarjetasLiga_Scene
  def pbStartScene(_num = 0)
    pbDrawTextPositions(nil, [["Lionel", 256, 40], ["[C]: Leer la descripción", 256, 382], ["[X]: Salir", 256, 412]])
    :started
  end

  def pbStartActions
    drawTextEx(nil, 40, 40, 432, 100, "Lore de Lionel", nil, nil)
    :acted
  end

  def pbEndScene; :closed; end
end

# The results: the dish (@tipo_de_curry, its name second) and the rank's Pokemon (@pokemon_puntos).
class ResultadosCurry_Scene
  def initialize(curry); @tipo_de_curry = curry; end
  def pbStartScene; :dish; end
end

class ResultadosCurryPuntos_Scene
  def initialize(rank); @pokemon_puntos = rank; end
  def pbStartScene; :rank; end
end

[%w[royal currydex], %w[royal_common creador], %w[royal tarjetas_liga],
 %w[royal curry_result]].each do |dir, name|
  path = File.join(Harness::ROOT, "games", dir, "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RoyalScreensGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  # The save's curry records: the recipes found, by number, and each one's best score (-1 never cooked).
  Save = Struct.new(:recetas_curry_conseguidas, :curry_mejor_puntuacion)
  CURRIES = [[0, "Curri picante"], [1, "Curri dulce"]]

  test "leaves each screen's own value to the game" do
    curry = [PokemonCurrydex_Scene.new.pbStartScene, PokemonCurrydex_Scene.new.pbEndScene, CreadorEventScene.new.pbStartScene]
    cards = TarjetasLiga_Scene.new
    page = InfoTarjetasLiga_Scene.new
    shown = [cards.actualizarTarjetasPantalla, cards.pbEndScene, page.pbStartScene, page.pbStartActions, page.pbEndScene]
    results = [ResultadosCurry_Scene.new([0, "Curri"]).pbStartScene, ResultadosCurryPuntos_Scene.new("Koffing").pbStartScene]
    assert_equal [[:started, :ended, :shown], [:redrawn, :ended, :started, :acted, :closed], [:dish, :rank]],
                 [curry, shown, results]
  ensure
    PokeAccess::RoyalTarjetaInfo.back!
  end

  test "reads a recipe at the dex list's level: number and name, the medal from medium, the best score in full" do
    with_save([true, false], [50, -1]) do
      head = I18n.t(:dexlist_entry, :num => 1, :name => "Curri picante")
      best = I18n.t(:rcy_best, :n => 50)
      medal = I18n.t(:rcy_medal_3)
      assert_equal [head, "#{head}, #{medal}", "#{head}, #{best}, #{medal}"], vb_levels { focused(0) }
    end
  end

  test "names the medal each score's rank paints, and none past the ranks" do
    { 10 => :rcy_medal_1, 30 => :rcy_medal_2, 50 => :rcy_medal_3, 70 => :rcy_medal_4, 84 => :rcy_medal_5,
      90 => nil }.each do |score, medal|
      with_save([true], [score]) do
        parts = [I18n.t(:dexlist_entry, :num => 1, :name => "Curri picante"), I18n.t(:rcy_best, :n => score)]
        parts.push(I18n.t(medal)) if medal
        assert_equal parts.join(", "), focused(0), "best score #{score}"
      end
    end
  end

  test "reads a recipe never cooked by number and name alone, and a score of 0 as a score" do
    head = I18n.t(:dexlist_entry, :num => 1, :name => "Curri picante")
    { [-1] => head, nil => head, [0] => [head, I18n.t(:rcy_best, :n => 0), I18n.t(:rcy_medal_1)].join(", ") }.each do |best, row|
      with_save([true], best) { assert_equal row, focused(0), "best scores #{best.inspect}" }
    end
  end

  test "names no medal for a rank without a sprite" do
    assert_equal [nil, nil, nil, nil], [0, -1, 6, nil].map { |rank| PokeAccess::RoyalCurrydex.medal(rank) }
  end

  test "says a recipe as undiscovered where the save cannot tell which were found" do
    with_save(nil, [50]) { assert_equal I18n.t(:dexlist_unknown, :num => 1), focused(0) }
  end

  test "puts the whole recipe row and its description on the info key, and the row on Ctrl+T" do
    with_save([true, false], [50, -1]) do
      PokeAccess::Config.verbosity = :brief
      focused(0)
      row = [I18n.t(:dexlist_entry, :num => 1, :name => "Curri picante"), I18n.t(:rcy_best, :n => 50),
             I18n.t(:rcy_medal_3)].join(", ")
      assert_equal ["#{row}. Un curri en el que las especias resaltan el picante.", row],
                   [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
    end
  end

  test "puts the row alone on the info key for a recipe with no description" do
    with_save([true, true], [50, -1]) do
      focused(1)
      assert_equal I18n.t(:dexlist_entry, :num => 2, :name => "Curri dulce"), PokeAccess::Info.info_text
    end
  end

  test "says an undiscovered recipe as such, on the info key too" do
    with_save([true, false], [50, -1]) do
      unknown = I18n.t(:dexlist_unknown, :num => 2)
      assert_equal [unknown, unknown], [focused(1), PokeAccess::Info.info_text]
    end
  end

  test "reads nothing for a row the list does not have" do
    with_save([true, false], [50, -1]) do
      win = Window_Currydex.new(CURRIES)
      win.index = 2
      assert_nil PokeAccess::Menus.focused_text(win)
    end
  end

  test "takes the recipe off the info key as the Currydex closes" do
    with_save([true, false], [50, -1]) do
      focused(0)
      PokemonCurrydex_Scene.new.pbEndScene
      assert_nil PokeAccess::Info.info_text
    end
  end

  test "says how many recipes were found as the Currydex opens, queued" do
    with_save([true, false], [50, -1]) { PokemonCurrydex_Scene.new.pbStartScene }
    assert_equal [[I18n.t(:rcy_recipes, :n => 1, :tot => 2), false]], SpeakCapture.log
  end

  test "says no recipe count for a game with no recipe list" do
    list = ResultadosCurry::LISTADO_CURRYS
    ResultadosCurry.send(:remove_const, :LISTADO_CURRYS)
    with_save([true, false], [50, -1]) { PokemonCurrydex_Scene.new.pbStartScene }
    assert_nothing_spoken
  ensure
    ResultadosCurry.const_set(:LISTADO_CURRYS, list) unless ResultadosCurry.const_defined?(:LISTADO_CURRYS, false)
  end

  test "says the creator's notice and, while hints are said, the key that goes on" do
    notice = I18n.t(:rcr_notice)
    said = vb_levels do
      SpeakCapture.clear
      CreadorEventScene.new.pbStartScene
      SpeakCapture.log.dup
    end
    hinted = "#{notice}. #{I18n.t(:title_press, :key => I18n.t(:key_enter))}"
    assert_equal [[[notice, true]], [[hinted, true]], [[hinted, true]]], said, "at brief, medium, full"
  end

  test "says the confirm key the player rebound under the creator's notice" do
    PokeAccess::Config.rebinds = { :c => 0x4B }
    CreadorEventScene.new.pbStartScene
    assert_equal ["#{I18n.t(:rcr_notice)}. #{I18n.t(:title_press, :key => "K")}"], SpeakCapture.lines
  end

  test "says a card by name, its place from medium up, and puts its lore on the info key" do
    said = vb_levels do
      SpeakCapture.clear
      TarjetasLiga_Scene.new.choose(0)
      SpeakCapture.log.dup
    end
    placed = [[I18n.t(:list_entry, :name => "Lionel", :n => 1, :tot => 4), true]]
    assert_equal [[[["Lionel", true]], placed, placed], "Lore de Lionel"], [said, PokeAccess::Info.info_text],
                 "at brief, medium, full; the lore on the info key"
  end

  test "says a locked card as locked in its place, leaving no lore on the info key" do
    scene = TarjetasLiga_Scene.new
    scene.choose(0)
    SpeakCapture.clear
    scene.choose(1)
    assert_equal [[[I18n.t(:list_entry, :name => I18n.t(:rl_card_locked), :n => 2, :tot => 4), true]], nil],
                 [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "reads every card by name where the game cannot tell which are unlocked" do
    without_unlock_check { TarjetasLiga_Scene.new.choose(1) }
    assert_equal [I18n.t(:list_entry, :name => "Rose", :n => 2, :tot => 4)], SpeakCapture.lines
  end

  test "says a card once while the grid repaints it" do
    scene = TarjetasLiga_Scene.new
    scene.choose(2)
    scene.choose(2)
    assert_equal [I18n.t(:list_entry, :name => "Sonia", :n => 3, :tot => 4)], SpeakCapture.lines
  end

  test "says nothing for a card with no name, or past the list" do
    { "a card with no name" => 3, "past the list" => 4 }.each do |what, place|
      SpeakCapture.clear
      TarjetasLiga_Scene.new.choose(place)
      assert_nothing_spoken what
    end
  end

  test "takes the lore off the info key as the list closes" do
    scene = TarjetasLiga_Scene.new
    scene.choose(0)
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "says the focused card again on the way back from its page, once" do
    scene = TarjetasLiga_Scene.new
    scene.choose(0)
    InfoTarjetasLiga_Scene.new.pbEndScene
    SpeakCapture.clear
    scene.choose(0)
    scene.choose(0)
    assert_equal [[I18n.t(:list_entry, :name => "Lionel", :n => 1, :tot => 4), true]], SpeakCapture.log
  end

  test "says a card's page as painted, its keys while hints are said" do
    said = vb_levels do
      SpeakCapture.clear
      InfoTarjetasLiga_Scene.new.pbStartScene(0)
      SpeakCapture.log.dup
    end
    keys = [["Lionel, [C]: Leer la descripción, [X]: Salir", true]]
    assert_equal [[["Lionel", true]], keys, keys], said, "at brief, medium, full"
  end

  test "says the description a card's page paints as it is read" do
    InfoTarjetasLiga_Scene.new.pbStartActions
    assert_equal [["Lore de Lionel", true]], SpeakCapture.log
  end

  test "leaves a description painted outside a card's page unsaid, before it or after" do
    drawTextEx(nil, 0, 0, 200, 1, "Antes de abrir la tarjeta", nil, nil)
    before = SpeakCapture.lines.dup
    InfoTarjetasLiga_Scene.new.pbStartActions
    SpeakCapture.clear
    drawTextEx(nil, 0, 0, 200, 1, "Tras cerrar la tarjeta", nil, nil)
    assert_equal [[], []], [before, SpeakCapture.lines]
  end

  test "says the dish by the name the results paint, queued" do
    ResultadosCurry_Scene.new([3, "Curri picante", "Un curri", "Picante", nil]).pbStartScene
    assert_equal [["Curri picante", false]], SpeakCapture.log
  end

  test "says nothing for a dish with no name" do
    { "no dish" => nil, "no name" => [3, nil], "a blank name" => [3, ""],
      "a dish that is no recipe row" => { 1 => "Curri picante" } }.each do |what, curry|
      SpeakCapture.clear
      ResultadosCurry_Scene.new(curry).pbStartScene
      assert_nothing_spoken what
    end
  end

  test "says the rank line as the scene composes it, in the build's words" do
    { ["Charizard", {}] => "¡Digno de un Charizard!",
      ["Koffing", { "¡Digno de un" => "Worthy of a" }] => "Worthy of a Koffing!" }.each do |(rank, words), line|
      SpeakCapture.clear
      with_intl(words) { ResultadosCurryPuntos_Scene.new(rank).pbStartScene }
      assert_equal [[line, false]], SpeakCapture.log, rank
    end
  end

  test "says no rank line without a rank" do
    ResultadosCurryPuntos_Scene.new("").pbStartScene
    ResultadosCurryPuntos_Scene.new(nil).pbStartScene
    assert_nothing_spoken
  end

  private

  # The Currydex row under index, as the list reader says it.
  def focused(index)
    win = Window_Currydex.new(CURRIES)
    win.index = index
    PokeAccess::Menus.focused_text(win)
  end

  # Runs the block over a save with these curry records ($PokemonGlobal), the game's own put back after.
  def with_save(found, best)
    was = $PokemonGlobal
    $PokemonGlobal = Save.new(found, best)
    yield
  ensure
    $PokemonGlobal = was
  end

  # Runs the block in a game whose save cannot tell which cards are unlocked (tarjeta_desbloqueada? raises).
  def without_unlock_check
    kept = Object.instance_method(:tarjeta_desbloqueada?)
    Object.send(:define_method, :tarjeta_desbloqueada?) { |_i| raise NoMethodError, "no card records" }
    Object.send(:private, :tarjeta_desbloqueada?)
    yield
  ensure
    Object.send(:define_method, :tarjeta_desbloqueada?, kept)
    Object.send(:private, :tarjeta_desbloqueada?)
  end
end
