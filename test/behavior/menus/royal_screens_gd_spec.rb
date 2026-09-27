# Royal's own screens (Currydex, berry picker, creator's notice, league cards, curry results) at their readings'
# levels, gamedata pass. The stand-ins come before the profile files load: a hook on a missing class binds nothing.
class Window_Currydex
  attr_accessor :index
  def initialize(commands); @commands = commands; @index = 0; end
end

class PokemonCurrydex_Scene
  def pbStartScene; :started; end
  def pbEndScene; :ended; end
end

module ResultadosCurry
  LISTADO_CURRYS = [[0, "Curry picante", "Un curry que pica mucho."], [1, "Curry dulce", ""]]
end

def pbCurryRegistered?(id); id == 0; end
def pbCurryDexCount; 1; end
def rangoPuntuacionCurry(best); best >= 90 ? 3 : 1; end

class Window_ChooseBerryMultiple
  attr_accessor :index
  def initialize(bag, filter, scene); @bag = bag; @filterlist = filter; @scene = scene; @index = 0; end
end

class CreadorEventScene
  def pbStartScene; :shown; end
end

module TarjetasLiga
  def self.tarjetas
    [[1, "Brock", nil, "Lore de Brock"], [2, "Misty", nil, "Lore de Misty"], [3, "Surge", nil, "Lore de Surge"]]
  end
end

def tarjeta_desbloqueada?(i); i != 1; end

class TarjetasLiga_Scene
  def initialize; @tarjeta_elegida = 0; end
  def choose(i); @tarjeta_elegida = i; actualizarTarjetasPantalla; end
  def actualizarTarjetasPantalla; :redrawn; end
  def pbEndScene; :ended; end
end

class InfoTarjetasLiga_Scene
  def pbStartScene
    pbDrawTextPositions(nil, [["Brock", 0, 0], ["[C]: Leer la descripción", 0, 300], ["[X]: Salir", 0, 330]])
    :started
  end
  def pbStartActions; :acted; end
  def pbEndScene; :closed; end
end

class ResultadosCurry_Scene
  def initialize(curry); @tipo_de_curry = curry; end
  def pbStartScene; :dish; end
end

class ResultadosCurryPuntos_Scene
  def initialize(rank); @pokemon_puntos = rank; end
  def pbStartScene; :rank; end
end

%w[currydex curry_select creador tarjetas_liga curry_result].each do |f|
  load File.expand_path("../../../games/royal/#{f}.rb", File.dirname(__FILE__))
end

Suite.define("royal currydex: a recipe at the Pokedex reading's level, its description on the info key") do
  t = PokeAccess::I18n
  saved = $PokemonGlobal
  begin
    $PokemonGlobal = Struct.new(:curry_mejor_puntuacion).new([95, -1])
    win = Window_Currydex.new([[0, "Curry picante"], [1, "Curry dulce"]])
    head = t.t(:dexlist_entry, :num => 1, :name => "Curry picante")
    best = t.t(:rcy_best, :n => 95)
    medal = t.t(:rcy_medal_3)
    rows = vb_levels { PokeAccess::Menus.focused_text(win) }
    eq "brief: the number and the name", rows[0], head
    eq "medium: and the medal painted beside the score", rows[1], [head, medal].join(", ")
    eq "full: the best score as well, as it always said", rows[2], [head, best, medal].join(", ")
    truthy "the medal is the painted one, by its colour and stars", medal.include?("bronce")
    eq "each rank has its medal and a rank with no sprite none",
       (1..5).map { |r| PokeAccess::RoyalCurrydex.medal(r) } + [PokeAccess::RoyalCurrydex.medal(-1)],
       [:rcy_medal_1, :rcy_medal_2, :rcy_medal_3, :rcy_medal_4, :rcy_medal_5].map { |k| t.t(k) } + [nil]
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Menus.focused_text(win)
    PokeAccess::Config.verbosity = :full
    eq "the info key says the whole row, and the recipe's description after it", PokeAccess::Info.info_text,
       "#{[head, best, medal].join(", ")}. Un curry que pica mucho."
    eq "and Ctrl+T the row", PokeAccess::Info.row_text, [head, best, medal].join(", ")
    win.index = 1
    eq "an undiscovered recipe says so", PokeAccess::Menus.focused_text(win), t.t(:dexlist_unknown, :num => 2)
    eq "and so does the info key, not the recipe before it", PokeAccess::Info.info_text, t.t(:dexlist_unknown, :num => 2)
    PokemonCurrydex_Scene.new.pbEndScene
    eq "closing the Currydex takes it off the info key", PokeAccess::Info.info_text, nil
  ensure
    $PokemonGlobal = saved
  end
end

Suite.define("royal berry picker: a berry at the bag reading's level, the rest on the info key") do
  t = PokeAccess::I18n
  bag = Struct.new(:pockets).new([nil, nil, nil, nil, nil, [[:ORANBERRY, 3]]])
  scene = Struct.new(:selectedBerries).new([])
  scene.instance_variable_set(:@count, 4)
  win = Window_ChooseBerryMultiple.new(bag, [0], scene)
  name = GameData::Item.get(:ORANBERRY).name
  chosen = t.t(:rcy_chosen, :n => 0, :tot => 4)
  rows = vb_levels { PokeAccess::Menus.focused_text(win) }
  eq "brief: the berry and how many are left", rows[0], "#{name}, 3"
  eq "medium: and how many are chosen", rows[1], "#{name}, 3, #{chosen}"
  PokeAccess::Config.verbosity = :brief
  PokeAccess::Menus.focused_text(win)
  PokeAccess::Config.verbosity = :full
  eq "Ctrl+T says the row whole", PokeAccess::Info.row_text, rows[2]
  win.index = 1
  eq "past the berries, the close row", PokeAccess::Menus.focused_text(win), "CERRAR BOLSA"
end

Suite.define("royal creator: the notice says what its picture writes, and the key that goes on while hints are said") do
  t = PokeAccess::I18n
  enter = t.t(:title_press, :key => t.t(:key_enter))
  SpeakCapture.clear
  CreadorEventScene.new.pbStartScene
  eq "full: the notice and the key", SpeakCapture.last, "#{t.t(:rcr_notice)}. #{enter}"
  truthy "the notice is the picture's own text, the official site included",
         t.t(:rcr_notice).include?("www.skyfangames.blogspot.com")
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  CreadorEventScene.new.pbStartScene
  eq "brief: the notice alone", SpeakCapture.last, t.t(:rcr_notice)
  PokeAccess::Config.verbosity = :full
end

Suite.define("royal curry results: the dish and the rank as painted, in the build's language") do
  SpeakCapture.clear
  ResultadosCurry_Scene.new([3, "Curri picante", "Un curri", "Picante", nil]).pbStartScene
  eq "the dish is its painted name alone", SpeakCapture.lines, ["Curri picante"]
  SpeakCapture.clear
  ResultadosCurryPuntos_Scene.new("Charizard").pbStartScene
  eq "the rank line as the scene composes it", SpeakCapture.lines, ["¡Digno de un Charizard!"]
  with_intl("¡Digno de un" => "Worthy of a") do
    SpeakCapture.clear
    ResultadosCurryPuntos_Scene.new("Koffing").pbStartScene
    eq "and the English build's own words, which translate its _INTL", SpeakCapture.lines, ["Worthy of a Koffing!"]
  end
  SpeakCapture.clear
  ResultadosCurryPuntos_Scene.new("").pbStartScene
  silent "no rank, nothing said"
end

Suite.define("royal league cards: a locked card keeps its place, and the lore leaves the info key with the list") do
  t = PokeAccess::I18n
  scene = TarjetasLiga_Scene.new
  SpeakCapture.clear
  scene.choose(0)
  eq "a card by name and place", SpeakCapture.last, t.t(:list_entry, :name => "Brock", :n => 1, :tot => 3)
  eq "its lore on the info key", PokeAccess::Info.info_text, "Lore de Brock"
  SpeakCapture.clear
  scene.choose(1)
  eq "a locked card says so, in its place", SpeakCapture.last,
     t.t(:list_entry, :name => t.t(:rl_card_locked), :n => 2, :tot => 3)
  eq "and leaves no lore behind", PokeAccess::Info.info_text, nil
  scene.choose(2)
  scene.pbEndScene
  eq "closing the list takes the lore off the info key", PokeAccess::Info.info_text, nil

  SpeakCapture.clear
  scene.choose(0)
  scene.choose(0)
  eq "the grid repaints every frame and says a card once", SpeakCapture.lines,
     [t.t(:list_entry, :name => "Brock", :n => 1, :tot => 3)]
  SpeakCapture.clear
  InfoTarjetasLiga_Scene.new.pbEndScene
  scene.choose(0)
  eq "back from the card's page, the focused card again", SpeakCapture.lines,
     [t.t(:list_entry, :name => "Brock", :n => 1, :tot => 3)]
  SpeakCapture.clear
  scene.choose(0)
  silent "and only once"
  scene.choose(2)

  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  scene.choose(0)
  eq "brief: the card's name alone", SpeakCapture.last, "Brock"
  SpeakCapture.clear
  InfoTarjetasLiga_Scene.new.pbStartScene
  eq "and a card's page without its keys", SpeakCapture.last, "Brock"
  PokeAccess::Config.verbosity = :full
  SpeakCapture.clear
  InfoTarjetasLiga_Scene.new.pbStartScene
  eq "full: with them", SpeakCapture.last, "Brock, [C]: Leer la descripción, [X]: Salir"
end

Suite.define("royal berry picker: the flavour column as the build paints it, through its _INTL") do
  had = GameData.const_defined?(:BerryData)
  unless had
    klass = Class.new
    klass.define_singleton_method(:get) { |_b| Struct.new(:flavor).new({ "Picante" => 10, "Seco" => 5 }) }
    GameData.const_set(:BerryData, klass)
  end
  begin
    eq "the Spanish build's own word", PokeAccess::RoyalCurry.berry_label(:CHERIBERRY, :Flavor), "Picante"
    with_intl("Picante" => "Spicy") do
      eq "and the English build's", PokeAccess::RoyalCurry.berry_label(:CHERIBERRY, :Flavor), "Spicy"
    end
  ensure
    GameData.send(:remove_const, :BerryData) unless had
  end
end
