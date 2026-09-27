# Reminiscencia's own screens over stand-ins defined before its profile files load once: the Hoopa gacha's shiny
# prize, the Pokocho maker's cues and results, the achievements' EV limits, Poke Recreo's opening; and the party's
# 1-key lead swap, whose module alone is evaluated (the shared party scene stand-in serves other suites).
module RemMinigames
  RESULTS = [["RESULTADOS", 280, 90, 0], ["Tiempo", 200, 130, 0], ["60", 420, 130, 0], ["Derramado", 200, 160, 0],
             ["2 veces", 400, 160, 0], ["Quemado", 200, 190, 0], ["0 veces", 400, 190, 0], ["", 200, 250, 0],
             ["Nombre: ", 200, 330, 0], ["Pokocho dulce", 290, 330, 0]]
end

def pbAddPokemonRNG(pokemon, _level = nil, _seeform = true)
  PokeAccess.say_dialogue("¡Anthony ha obtenido un #{pokemon.name}!")
  true
end unless Object.private_method_defined?(:pbAddPokemonRNG)

class HoopaGacha
  attr_accessor :prize
  def drawMaintext; pbDrawTextPositions(nil, [["Monedas: 5", 600, 48, 1]]); end
  def startRoulette; pbAddPokemonRNG(@prize); end
end

class Poffin
  def announceStart; :start; end
  def announceFinish; :done; end
  def drawTextAnnouncement(type = 0, _size = 60)
    pbDrawTextPositions(nil, [[type == 0 ? "¡Se quema! ¡Remuévelo!" : "¡Muy rápido! ¡Se desborda!", 320, 240, 2]])
  end
  def showResult(_result, _level, _name)
    pbDrawTextPositions(nil, RemMinigames::RESULTS)
    false
  end
end

class Logros_Scene
  def showTexts(_index)
    pbDrawTextPositions(nil, [["Primeros pasos", 90, 360, 0]])
    drawTextEx(nil, 0, 0, 400, 2, "Captura tu primer Pokémon.", nil, nil)
    drawTextEx(nil, 0, 0, 200, 4, "Máx EV total: 512\nMáx EV/stat: 252", nil, nil)
  end
end

# Poke Recreo as the game builds it: the character kept under its picture folder's name, the berry as an item id,
# and main_loop entered last from the constructor; input reduced to a count of the frames it ran, and checkEating
# as the game's at its end (NO_FOOD_TIME, 300), where the game says the friendship grew.
class PokemonAmie
  attr_reader :mouse_frames
  def initialize(chara = "Lucius", berry = 0)
    @charaName = chara
    @charaName = "PAthan" if @charaName == "Athan"
    @charaName = "Artica" if @charaName == "Ártica"
    @foodName = berry
    @sprites = { "mouth" => Struct.new(:visible).new(false) }
    @eatingTimeCheck = 0
    @finishedFood = false
    @mouse_frames = 0
    main_loop
  end
  def main_loop; :closed; end
  def input; @mouse_frames += 1; end
  def checkEating
    return unless @eatingTimeCheck == 300
    @finishedFood = true
    @foodmode = false
    @eatingTimeCheck = 0
    PokeAccess.say_dialogue("¡La relación con Lucius mejoró!")
  end
end

%w[hoopa pokocho logros amie].each { |f| load File.join(Harness::ROOT, "games", "reminiscencia", "#{f}.rb") }
party_keys = File.join(Harness::ROOT, "games", "reminiscencia", "party_keys.rb")
eval(File.read(party_keys)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, party_keys) unless defined?(PokeAccess::ReminPartyLead)

Suite.define("reminiscencia: a shiny gacha prize is said after the line that names it") do
  shiny = PokeAccess::Party.shiny_word(nil)
  gacha = HoopaGacha.new
  gacha.prize = Poke.build(:name => "Rayquaza", :shiny => true)
  SpeakCapture.clear
  gacha.startRoulette
  eq "the game's line, then the star it is drawn with", SpeakCapture.lines, ["¡Anthony ha obtenido un Rayquaza!", shiny]
  gacha.prize = Poke.build(:name => "Lugia")
  SpeakCapture.clear
  gacha.startRoulette
  eq "a plain one, the line alone", SpeakCapture.lines, ["¡Anthony ha obtenido un Lugia!"]
  SpeakCapture.clear
  pbAddPokemonRNG(Poke.build(:name => "Mew", :shiny => true))
  eq "outside the roulette nothing is added", SpeakCapture.lines, ["¡Anthony ha obtenido un Mew!"]
end

Suite.define("reminiscencia: the Pokocho maker's cues and its results table, once") do
  t = PokeAccess::I18n
  p = Poffin.new
  SpeakCapture.clear
  p.announceStart
  p.drawTextAnnouncement(0)
  p.drawTextAnnouncement(1)
  p.announceFinish
  eq "start, each warning as painted, done", SpeakCapture.lines,
     [t.t(:rem_pokocho_start), "¡Se quema! ¡Remuévelo!", "¡Muy rápido! ¡Se desborda!", t.t(:rem_pokocho_done)]
  SpeakCapture.clear
  3.times { p.showResult(nil, 1, "Pokocho dulce") }
  eq "the table row by row, once while it is repainted", SpeakCapture.lines,
     ["RESULTADOS. Tiempo 60. Derramado 2 veces. Quemado 0 veces. Nombre: Pokocho dulce"]
end

Suite.define("reminiscencia: the achievements' EV limits, once per visit, after the first achievement") do
  scene = Logros_Scene.new
  SpeakCapture.clear
  scene.showTexts(0)
  PokeAccess::ReminLogros.flush
  eq "the two limits, one after the other", SpeakCapture.lines, ["Máx EV total: 512. Máx EV/stat: 252"]
  SpeakCapture.clear
  scene.showTexts(1)
  PokeAccess::ReminLogros.flush
  silent "not again while the screen is open"
  SpeakCapture.clear
  Logros_Scene.new.showTexts(0)
  PokeAccess::ReminLogros.flush
  eq "and again on the next visit", SpeakCapture.lines, ["Máx EV total: 512. Máx EV/stat: 252"]
end

Suite.define("reminiscencia: the 1 key's lead swap names the new lead and the member under the cursor") do
  lead = PokeAccess::ReminPartyLead
  a = Poke.build(:name => "Anthony1")
  b = Poke.build(:name => "Bulbi")
  c = Poke.build(:name => "Chispa")
  party = [a, b, c]
  scene = World.stub_scene(:@party => party, :@activecmd => 2)
  lead.start(scene)
  SpeakCapture.clear
  lead.refreshed(scene)
  silent "a refresh with the same lead says nothing"
  party[0], party[2] = party[2], party[0]
  SpeakCapture.clear
  lead.refreshed(scene)
  eq "the new lead first", SpeakCapture.lines.first, PokeAccess::I18n.t(:rem_party_lead, :name => "Chispa")
  eq "then the member now under the cursor", SpeakCapture.lines.length, 2
  truthy "which is the old lead", SpeakCapture.lines.last.to_s.include?("Anthony1")
  SpeakCapture.clear
  lead.refreshed(scene)
  silent "and only once"
end

# Poke Recreo paints no word and answers only the mouse: as it opens, the character (by its own name, not its
# picture folder's) and the berry, that it is a mouse game, and the keys that close it as the player has them.
Suite.define("reminiscencia: Poke Recreo says who and which berry, that it wants the mouse, and how to leave") do
  t = PokeAccess::I18n
  berry = PokeAccess::Data.item_name(50)
  SpeakCapture.clear
  PokemonAmie.new("Athan", 50)
  eq "the character and the berry, the mouse, and the keys that leave", SpeakCapture.lines,
     [t.t(:rem_amie_open, :who => "Athan, #{berry}", :c => "C", :b => "X")]
  SpeakCapture.clear
  PokemonAmie.new("Ártica", 50)
  truthy "a name kept without its accent is said with it", SpeakCapture.last.to_s.include?("Ártica, #{berry}")
  PokeAccess::Config.rebinds = { :b => 0x51 }
  SpeakCapture.clear
  PokemonAmie.new("Lucius", 50)
  eq "a moved cancel key is said where it is", SpeakCapture.lines,
     [t.t(:rem_amie_open, :who => "Lucius, #{berry}", :c => "C", :b => "Q")]
end

# Holding Down feeds the berry as holding it on the mouth does: each frame counts, with a word at half and nearly
# eaten and the game's own message at the end; without Down, or once it is eaten, the frame runs the game's input.
Suite.define("reminiscencia: holding Down feeds Poke Recreo's berry, with a word at half and nearly eaten") do
  t = PokeAccess::I18n
  scene = PokemonAmie.new("Lucius", 50)
  down = false
  saved = Input.method(:press?)
  Input.define_singleton_method(:press?) { |*b| down && b[0] == Input::DOWN }
  begin
    SpeakCapture.clear
    scene.input
    eq "without Down the game's own input runs", scene.mouse_frames, 1
    down = true
    scene.input
    truthy "held, the mouth opens and the frame feeds instead", PokeAccess.sprite(scene, "mouth").visible &&
           scene.mouse_frames == 1 && scene.instance_variable_get(:@eatingTimeCheck) == 1
    299.times { scene.input }
    eq "a word at half and nearly eaten, then the game's own message", SpeakCapture.lines,
       [t.t(:rem_amie_half), t.t(:rem_amie_nearly), "¡La relación con Lucius mejoró!"]
    scene.input
    eq "once eaten, Down leaves the frame to the game", scene.mouse_frames, 2
  ensure
    Input.define_singleton_method(:press?, saved)
  end
end
