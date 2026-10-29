# Realidea's own scenes and story minigames through stand-ins of the game's methods: the Porygon-Z beam, the
# refutation screen, the credits, the ghosts' cries, the fishing, Mankey's duel, the encounter windows and the game's
# own weathers.

# The draws rand makes in the stand-ins of the game's functions, as a test queues them; rand's own once none is left.
module ReaDraws
  @queue = []

  def self.queue; @queue; end

  def self.next(n)
    @queue.empty? ? rand(n) : @queue.shift
  end
end

# Route 17's beam: anadircomb fills variable 145 with three of A, S and D; the typed letter is pushed onto
# $Trainer.arraycomb before checkporygon, which clears both on a miss (running paralizarpoke) or on the third right
# letter; paralizarpoke writes status 4, paralysis, on the member at the drawn index less one.
def anadircomb
  $game_variables[145] = []
  3.times { $game_variables[145].push(%w[A S D][ReaDraws.next(3)]) }
end

def checkporygon
  if $Trainer.arraycomb[$Trainer.arraycomb.length - 1] != $game_variables[145][$Trainer.arraycomb.length - 1]
    $game_variables[145] = []
    $Trainer.arraycomb = []
    paralizarpoke
  elsif $Trainer.arraycomb.length > 2
    $game_variables[145] = []
    $Trainer.arraycomb = []
  end
end

def paralizarpoke
  poke = $Trainer.party[ReaDraws.next($Trainer.party.length) - 1]
  poke.status = 4
end

# The refutation screen CHIGAUYO opens: the constructor runs actu, a loop that runs inputs each frame, where back
# closes it and the accept key breaks the argument (rompido), which closes it too.
class Danganronpa
  def initialize
    @close = 0
    actu
  end

  def inputs
    @close = 1 if Input.trigger?(Input::B)
    rompido if Input.trigger?(Input::C)
  end

  def rompido
    @close = 1
  end

  def actu
    loop do
      Graphics.update
      Input.update
      inputs
      break if @close == 1
    end
  end
end

# The fading text box events show before the credits roll, and the ending's credits scene, down to the method that
# paints a block.
def textofade(_yourtext, _lineas, _wait); end

class Credit
  def textofade1(_text, _lines, _wait); end
end

# The ghosts' cries events paint, jajajafantasma's laugh and nomerecer's words: each painted ten times at random, a
# wait of six frames after each that pumps the input as pbWait does. After each wait the stand-in notes how many lines
# have been said; broken, it raises before its first paint.
module ReaGhosts
  @heard = []
  @broken = false

  class << self
    attr_reader :heard
    attr_accessor :broken
  end

  def self.cry(text)
    @heard = []
    raise "broken" if @broken
    10.times do
      drawTextEx(nil, rand(512), rand(384), 280, 10, text)
      6.times { Graphics.update; Input.update }
      @heard.push(SpeakCapture.lines.length)
    end
  end
end

def jajajafantasma; ReaGhosts.cry("¡Ja, ja, ja!"); end
def nomerecer; ReaGhosts.cry("NO LO MERECEN."); end

# The fishing minigame (Faia emblem), down to what input does with the keys on each frame of its loop: back closes it
# and the accept key runs resultado, which takes HP from each side by the frame the press lands on; at no enemy HP
# darpoke shows its message (Kernel.pbMessage, which reaches pbMessageDisplay) before the ball choice.
class Pesca
  WEAK = "¡El Pokémon está débil! ¡Hora de lanzar una Pokéball!"

  def input
    @cerrar = 1 if Input.trigger?(Input::B)
    resultado if Input.trigger?(Input::C)
  end

  def resultado
    @enemhp -= 40 if @frame == 11
    @enemhp -= 30 if @frame == 10 || @frame == 12
    @protahp -= 10 if @frame == 10 || @frame == 12
    @enemhp -= 20 if @frame == 9 || @frame == 13
    @protahp -= 20 if @frame == 9 || @frame == 13
    @enemhp -= 10 if @frame <= 8 || @frame >= 14
    @protahp -= 30 if @frame <= 8 || @frame >= 14
    @protahp = 0 if @protahp < 0
    @enemhp = 0 if @enemhp < 0
    darpoke if @enemhp <= 0
    @cerrar = 1 if @protahp <= 0
  end

  def darpoke
    Kernel.pbMessageDisplay(nil, WEAK)
    @cerrar = 1
  end
end

# Mankey's duel of provocations, the rival with four hearts in Edward's duel (switch 184): inputs runs each frame,
# moving @seleccion with left and right and wrapping it as the game does, over $Trainer.contestaciones on the reply
# turn (1) and then over $Trainer.insultos; the accept key runs resultado, where the first line of either list (the
# game's joke) costs the player a heart, and on the reply turn the comeback to the rival's provocation costs the rival
# one and passes the turn while any other costs the player one. Edward's lesson and a provocation's draw are left out.
class Mankey
  def initialize(turno, comeback = nil)
    @turno = turno
    @comeback = comeback
    @seleccion = 0
    @vidasprota = 3
    @vidasenemigo = 3
    @vidasenemigo = 4 if $game_switches[184]
  end

  def inputs
    @seleccion += 1 if Input.trigger?(Input::RIGHT)
    @seleccion -= 1 if Input.trigger?(Input::LEFT)
    @seleccion = $Trainer.contestaciones.length - 1 if @seleccion < 0 && @turno == 1
    @seleccion = 0 if @seleccion > $Trainer.contestaciones.length - 1 && @turno == 1
    @seleccion = $Trainer.insultos.length - 1 if @seleccion < 0
    @seleccion = 0 if @seleccion > $Trainer.insultos.length - 1
    resultado if Input.trigger?(Input::C)
  end

  def resultado
    if @seleccion == 0 || (@turno == 1 && $Trainer.contestaciones[@seleccion] != @comeback)
      @vidasprota -= 1
    elsif @turno == 1
      @vidasenemigo -= 1
      @turno = 0
    end
  end
end

# The encounter window as raZ's plugin and Realidea's adaptation fill it: raZ's getEncData puts the map's species in
# @encarray, or [7] on a map without data; Realidea's loadEncounterData sets the number of types only on a map with
# data (else its list is [7]), and startUI opens on the first page (loadCurrentPage, which reloads the data before
# painting it) only when there is one.
class EncounterListUI
  def getEncData; @encarray = @pa_species ? @pa_species.dup : [7]; end

  def loadEncounterData
    if @pa_species
      @num_enc = 1
      @encounterArray = @pa_species
    else
      @encounterArray = [7]
    end
  end

  def loadCurrentPage
    loadEncounterData
    @name = @pa_name
  end

  def startUI
    loadEncounterData
    loadCurrentPage if @num_enc
  end
end

# The readers, evaluated once the stand-ins exist, so their hooks bind to them as they do in the game.
encounter_window = File.join(Harness::ROOT, "plugins", "simple_encounter_list.rb")
eval(Harness.source(encounter_window), TOPLEVEL_BINDING, encounter_window)

%w[porygon_ray scenes story_minigames encounters].each do |f|
  path = File.join(Harness::ROOT, "games", "realidea", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RealideaScenesTest < PokeAccessTest
  # A party member as the beam's readers see it.
  Member = Struct.new(:name, :status)
  # The player as the beam's functions use it.
  BeamTrainer = Struct.new(:arraycomb, :party)
  # The player as the duel's lists hold them.
  Duelist = Struct.new(:insultos, :contestaciones)
  # A credits block the scene repaints, and the line it is said as.
  MAPS = "<ac>MAPAS\n\nElena\nMaxewenx/Alfpixel</ac>"
  MAPS_LINE = "MAPAS: Elena, Maxewenx/Alfpixel"
  # The player's provocations and comebacks as the game keeps them: the two of each it starts with, its joke first,
  # and a provocation learned from the rival's list. The second comeback answers the second provocation.
  INSULTS = ["¡Peleas como un Miltank!", "¡Ante los movimientos enemigos mi Pokémon ni se <b>inmuta</b>!",
             "¡Mis enemigos huyen en cada <b>enfrentamiento</b>!"]
  COMEBACKS = ["Qué Mewdo, qué Mewdo...",
               "Con tu forma de combatir, lo que me extraña es que no acabe en una catástrofe <b>Absoluta</b>."]

  test "the three letters are said as anadircomb paints them" do
    with_trainer(BeamTrainer.new([], [Member.new("Pika", 0)])) do
      draws(0, 1, 2) { anadircomb }
      assert_equal [[t(:rea_ray_keys, :keys => "A, S, D"), true]], SpeakCapture.log
    end
  end

  test "each right letter is said back as it is typed, the third too" do
    with_trainer(BeamTrainer.new([], [Member.new("Pika", 0)])) do
      draws(2, 2, 0) { anadircomb }
      SpeakCapture.clear
      %w[D D A].each { |letter| type_letter(letter) }
      assert_equal [["D", true], ["D", true], ["A", true]], SpeakCapture.log
    end
  end

  test "a letter typed before any combo is painted is not said back" do
    with_trainer(BeamTrainer.new([], [Member.new("Pika", 0)])) do
      $game_variables[145] = 0
      type_letter("A")
      assert_equal [[t(:rea_ray_hit, :name => "Pika"), true]], SpeakCapture.log
    end
  end

  test "a wrong letter is not said back: the miss names the member it paralysed, wherever it stands" do
    { "second" => [[Member.new("Pika", 4), Member.new("Chispa", 0)], 0],
      "first" => [[Member.new("Chispa", 0), Member.new("Pika", 4)], 1] }.each do |place, (party, draw)|
      with_trainer(BeamTrainer.new([], party)) do
        draws(0, 0, 0) { anadircomb }
        SpeakCapture.clear
        draws(draw) { type_letter("S") }
        assert_equal [[t(:rea_ray_hit, :name => "Chispa"), true]], SpeakCapture.log, "Chispa standing #{place}"
      end
    end
  end

  test "a miss on a member already paralysed says the miss alone" do
    with_trainer(BeamTrainer.new([], [Member.new("Pika", 4), Member.new("Chispa", 0)])) do
      draws(0, 0, 0) { anadircomb }
      SpeakCapture.clear
      draws(1) { type_letter("S") }
      assert_equal [[t(:rea_ray_miss), true]], SpeakCapture.log
    end
  end

  test "a combo with no letters in it says nothing" do
    [nil, [], 0].each { |keys| PokeAccess::ReaPorygonRay.combo(keys) }
    assert_nothing_spoken
  end

  test "the refutation screen says its banner and the key that breaks it as it waits" do
    press(Input::B) { Danganronpa.new }
    assert_equal [[banner, true]], SpeakCapture.log
  end

  test "breaking the argument says it broke, after the banner" do
    press(Input::C) { Danganronpa.new }
    assert_equal [[banner, true], [t(:rea_dg_break), true]], SpeakCapture.log
  end

  test "at brief verbosity the banner leaves out the key that breaks it" do
    PokeAccess::Config.verbosity = :brief
    press(Input::B) { Danganronpa.new }
    assert_equal [[t(:rea_dg_danger), true]], SpeakCapture.log
  end

  test "a credits block is said as its heading and its names, queued" do
    textofade("<ac>MÚSICA\n\nemdasche\nKunning Fox\nJobless Music</ac>", 5, 200)
    assert_equal [["MÚSICA: emdasche, Kunning Fox, Jobless Music", false]], SpeakCapture.log
  end

  test "a block of a heading alone is said as the heading" do
    textofade("<ac>FIN</ac>", 1, 20)
    assert_equal [["FIN", false]], SpeakCapture.log
  end

  test "an empty credits block says nothing" do
    textofade("<ac></ac>", 1, 20)
    Credit.new.textofade1("<ac>\n</ac>", 1, 20)
    assert_nothing_spoken
  end

  test "textofade paints each call anew, so a repeated block is said each time" do
    2.times { textofade(MAPS, 5, 200) }
    assert_equal [MAPS_LINE, MAPS_LINE], SpeakCapture.lines
  end

  test "the block the credits scene repaints every frame is said once, and the next block in its turn" do
    scene = Credit.new
    5.times { scene.textofade1(MAPS, 5, 200) }
    scene.textofade1("<ac>AGRADECIMIENTOS\n\nPablus94</ac>", 5, 200)
    assert_equal [MAPS_LINE, "AGRADECIMIENTOS: Pablus94"], SpeakCapture.lines
  end

  test "a blank paint between repaints of a credits block does not make it said again" do
    scene = Credit.new
    scene.textofade1(MAPS, 5, 200)
    scene.textofade1("<ac></ac>", 5, 200)
    scene.textofade1(MAPS, 5, 200)
    assert_equal [MAPS_LINE], SpeakCapture.lines
  end

  test "a ghost's laugh is said once, queued, as the game paints it, though it paints it ten times" do
    jajajafantasma
    assert_equal [["¡Ja, ja, ja!", false]], SpeakCapture.log
  end

  test "the laugh is said as it is first painted, before the game paints it again" do
    jajajafantasma
    assert_equal [1] * 10, ReaGhosts.heard
  end

  test "the ruins' ghost's words are said once, as the game paints them" do
    nomerecer
    assert_equal [["NO LO MERECEN.", false]], SpeakCapture.log
  end

  test "each cry an event plays is said again" do
    2.times { jajajafantasma }
    nomerecer
    assert_equal ["¡Ja, ja, ja!", "¡Ja, ja, ja!", "NO LO MERECEN."], SpeakCapture.lines
  end

  test "a ghost's cry is filed in the history as dialogue" do
    PokeAccess::History.clear
    nomerecer
    assert_equal [:dialogue], PokeAccess::History.lines_of(PokeAccess::History::ALL).map { |m| m.category }
  end

  test "a cry the game breaks off leaves no capture behind: a later paint stays unsaid, the next cry is said" do
    ReaGhosts.broken = true
    assert_raises(RuntimeError) { jajajafantasma }
    ReaGhosts.broken = false
    drawTextEx(nil, 365, 95, 100, 2, "Pts: 400")
    Input.update
    nomerecer
    assert_equal [["NO LO MERECEN.", false]], SpeakCapture.log
  ensure
    ReaGhosts.broken = false
  end

  test "the Pokemon on the hook and its level are said as the fishing opens, then the HP, once" do
    fish = fishing
    2.times { fish.input }
    assert_equal [[t(:rea_pesca_foe, :name => "Goldeen", :level => 12), true],
                  [t(:rea_hp, :hp => 180, :ehp => 180), false]], SpeakCapture.log
  end

  test "each press is rated as the picture the game shows for its frame, before the HP it cost" do
    { 11 => [:rea_pesca_perfect, 180, 140], 10 => [:rea_pesca_great, 170, 150], 12 => [:rea_pesca_great, 170, 150],
      9 => [:rea_pesca_good, 160, 160], 13 => [:rea_pesca_good, 160, 160], 8 => [:rea_pesca_bad, 150, 170],
      14 => [:rea_pesca_bad, 150, 170], 1 => [:rea_pesca_bad, 150, 170] }.each do |at, (rating, hp, ehp)|
      fish = fishing
      fish.input
      SpeakCapture.clear
      fish.instance_variable_set(:@frame, at)
      press(Input::C) { fish.input }
      assert_equal [[t(rating), true], [t(:rea_hp, :hp => hp, :ehp => ehp), false]], SpeakCapture.log, "frame #{at}"
    end
  end

  test "the blow that leaves the Pokemon weak is rated before the game's message" do
    fish = fishing(:@enemhp => 40)
    fish.input
    SpeakCapture.clear
    fish.instance_variable_set(:@frame, 11)
    press(Input::C) { fish.input }
    assert_equal [[t(:rea_pesca_perfect), true], [Pesca::WEAK, false], [t(:rea_hp, :hp => 180, :ehp => 0), false]],
                 SpeakCapture.log
  end

  test "the timing tick sounds once per step of the frame, its pitch peaking on the perfect frame" do
    fish = fishing(:@frame => 8)
    ticks = gauge_ticks do
      [8, 8, 11, 14, 5].each do |at|
        fish.instance_variable_set(:@frame, at)
        fish.input
      end
    end
    assert_equal [0.5, 1.0, 0.5, 0.0], ticks
  end

  test "the Pokemon on the hook whose name the game cannot give is said by its level" do
    nameless = Object.new
    def nameless.name; raise "no name"; end
    fishing(:@pokemon => nameless).input
    assert_equal [[t(:rea_pesca_foe, :name => "", :level => 12), true], [t(:rea_hp, :hp => 180, :ehp => 180), false]],
                 SpeakCapture.log
  end

  test "HP the game holds as no number are not said, and the fishing goes on" do
    fishing(:@protahp => Object.new).input
    assert_equal [[t(:rea_pesca_foe, :name => "Goldeen", :level => 12), true]], SpeakCapture.log
  end

  test "the duel's opening frame says the focused provocation with its place in the list" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      Mankey.new(0).inputs
      assert_equal [entry("¡Peleas como un Miltank!", 1, 3)], lines_besides_hearts(3, 3)
    end
  end

  test "the duel's opening frame says both sides' hearts, the rival's four in Edward's duel" do
    $game_switches[184] = true
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      Mankey.new(0).inputs
      assert_equal 1, SpeakCapture.lines.count(t(:rea_hearts, :n => 3, :e => 4))
    end
  end

  test "the opening frame's hearts are not cut off by the provocation said after them" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      Mankey.new(0).inputs
      hearts = SpeakCapture.lines.index(t(:rea_hearts, :n => 3, :e => 3))
      refute_nil hearts, "the hearts are said"
      cutting = SpeakCapture.log.drop(hearts + 1).select { |_text, interrupt| interrupt }
      assert_equal [], cutting, "nothing interrupts them"
    end
  end

  test "moving says the provocation the game moves to, in its place and wrapping, its markup dropped" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      duel = Mankey.new(0)
      duel.inputs
      SpeakCapture.clear
      [Input::RIGHT, Input::LEFT, Input::LEFT].each { |k| press(k) { duel.inputs } }
      assert_equal [[entry("¡Ante los movimientos enemigos mi Pokémon ni se inmuta!", 2, 3), true],
                    [entry("¡Peleas como un Miltank!", 1, 3), true],
                    [entry("¡Mis enemigos huyen en cada enfrentamiento!", 3, 3), true]], SpeakCapture.log
    end
  end

  test "on the reply turn the comebacks are listed" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      Mankey.new(1).inputs
      assert_equal [entry("Qué Mewdo, qué Mewdo...", 1, 2)], lines_besides_hearts(3, 3)
    end
  end

  test "the same place is said again when the turn passes, though both lists match in place and length" do
    with_trainer(Duelist.new(INSULTS.first(2), COMEBACKS)) do
      duel = Mankey.new(1, COMEBACKS[1])
      duel.inputs
      press(Input::RIGHT) { duel.inputs }
      SpeakCapture.clear
      press(Input::C) { duel.inputs }
      assert_equal [entry("¡Ante los movimientos enemigos mi Pokémon ni se inmuta!", 2, 2)],
                   lines_besides_hearts(3, 2)
    end
  end

  test "a heart lost is said with both sides' hearts, queued" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      duel = Mankey.new(1, COMEBACKS[1])
      duel.inputs
      SpeakCapture.clear
      press(Input::C) { duel.inputs }
      assert_equal [[t(:rea_hearts, :n => 2, :e => 3), false]], SpeakCapture.log
    end
  end

  test "a heart lost as the turn passes is not cut off by the provocation said after it" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      duel = Mankey.new(1, COMEBACKS[1])
      duel.inputs
      press(Input::RIGHT) { duel.inputs }
      SpeakCapture.clear
      press(Input::C) { duel.inputs }
      hearts = SpeakCapture.lines.index(t(:rea_hearts, :n => 3, :e => 2))
      refute_nil hearts, "the hearts are said"
      cutting = SpeakCapture.log.drop(hearts + 1).select { |_text, interrupt| interrupt }
      assert_equal [], cutting, "nothing interrupts them"
    end
  end

  test "at brief verbosity the provocation is said without its place" do
    PokeAccess::Config.verbosity = :brief
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      Mankey.new(0).inputs
      assert_equal ["¡Peleas como un Miltank!"], lines_besides_hearts(3, 3)
    end
  end

  test "a reply turn whose list holds no comeback lists nothing" do
    with_trainer(Duelist.new(INSULTS, [])) do
      Mankey.new(1).inputs
      assert_equal [], lines_besides_hearts(3, 3)
    end
  end

  test "hearts the game holds as no number leave the duel running, its focused line said" do
    with_trainer(Duelist.new(INSULTS, COMEBACKS)) do
      duel = Mankey.new(0)
      duel.instance_variable_set(:@vidasprota, Object.new)
      2.times { duel.inputs }
      assert_equal [entry("¡Peleas como un Miltank!", 1, 3)], SpeakCapture.lines
    end
  end

  test "a map with wild Pokemon opens on its first page: map and type, each species with its state, the caught count" do
    with_page do
      encounter_window([16, 19, 21], "Hierba Alta").startUI
      assert_equal [[PokeAccess.sentences([summary(page_entries), t(:rea_enc_owned, :n => 1)]), true]], SpeakCapture.log
    end
  end

  test "the info key keeps the whole page while the page said follows the verbosity" do
    PokeAccess::Config.verbosity = :brief
    with_page do
      encounter_window([16, 19, 21], "Hierba Alta").startUI
      tail = t(:rea_enc_owned, :n => 1)
      assert_equal [PokeAccess.sentences([summary(page_entries), tail])], SpeakCapture.lines
      assert_equal PokeAccess.sentences([summary(page_entries, true), tail]), PokeAccess::Info.info_text
    end
  end

  test "a map without wild Pokemon says so as the window opens, once" do
    with_page do
      encounter_window(nil, nil).startUI
      assert_equal [[t(:enc_none, :loc => "Ruta 1"), true]], SpeakCapture.log
    end
  end

  test "a species the game's data has no name for is said by its number" do
    with_page do
      without_species_names { encounter_window([16, 19, 21], "Hierba Alta").startUI }
      entries = [["16", :dex_caught], ["19", :dex_seen], ["21", :dex_unknown]]
      assert_equal [PokeAccess.sentences([summary(entries), t(:rea_enc_owned, :n => 1)])], SpeakCapture.lines
    end
  end

  test "a player whose caught Pokemon the game cannot tell counts none caught" do
    with_page do
      def $Trainer.owned?(_sp); raise "no Pokedex"; end
      encounter_window([16, 19, 21], "Hierba Alta").startUI
      entries = [[species(16), :dex_seen], [species(19), :dex_seen], [species(21), :dex_unknown]]
      assert_equal [PokeAccess.sentences([summary(entries), t(:rea_enc_owned, :n => 0)])], SpeakCapture.lines
    end
  end

  test "raZ's window is read the frame after getEncData fills it, once its icons are drawn" do
    with_page do
      window = encounter_window([16, 19], nil)
      window.instance_variable_set(:@pkmnsprite, [Object.new, Object.new])
      window.getEncData
      assert_nothing_spoken "not before the frame"
      PokeAccess::SimpleEncounterList.poll
      PokeAccess::SimpleEncounterList.poll
      entries = [[species(16), :dex_caught], [species(19), :dex_seen]]
      assert_equal [[PokeAccess::EncounterList.summary("Ruta 1", entries), true]], SpeakCapture.log
    end
  end

  test "raZ's window says a species whose icon is dimmed or greyed is not caught" do
    with_page do
      window = encounter_window([16, 19, 21], nil)
      window.instance_variable_set(:@pkmnsprite, [icon(255, 0), icon(120, 0), icon(255, 255)])
      window.getEncData
      PokeAccess::SimpleEncounterList.poll
      entries = [[species(16), :dex_caught], [species(19), :dex_not_caught], [species(21), :dex_not_caught]]
      assert_equal [PokeAccess::EncounterList.summary("Ruta 1", entries)], SpeakCapture.lines
    end
  end

  test "raZ's window counts the faintest dimming or grey as not caught" do
    with_page do
      window = encounter_window([16, 19], nil)
      window.instance_variable_set(:@pkmnsprite, [icon(254, 0), icon(255, 1)])
      window.getEncData
      PokeAccess::SimpleEncounterList.poll
      entries = [[species(16), :dex_not_caught], [species(19), :dex_not_caught]]
      assert_equal [PokeAccess::EncounterList.summary("Ruta 1", entries)], SpeakCapture.lines
    end
  end

  test "raZ's window keeps the whole list for the info key while the list said follows the verbosity" do
    PokeAccess::Config.verbosity = :brief
    with_page do
      window = encounter_window([16, 19, 21], nil)
      window.instance_variable_set(:@pkmnsprite, [Object.new, Object.new, Object.new])
      window.getEncData
      PokeAccess::SimpleEncounterList.poll
      assert_equal [PokeAccess::EncounterList.summary("Ruta 1", page_entries)], SpeakCapture.lines
      assert_equal PokeAccess::EncounterList.summary("Ruta 1", page_entries, true), PokeAccess::Info.info_text
    end
  end

  test "raZ's window says a species the game's data has no name for by its number" do
    with_page do
      window = encounter_window([16, 19], nil)
      window.instance_variable_set(:@pkmnsprite, [Object.new, Object.new])
      window.getEncData
      without_species_names { PokeAccess::SimpleEncounterList.poll }
      entries = [["16", :dex_caught], ["19", :dex_seen]]
      assert_equal [PokeAccess::EncounterList.summary("Ruta 1", entries)], SpeakCapture.lines
    end
  end

  test "raZ's window drops a list whose icons were never drawn" do
    with_page do
      window = encounter_window([16, 19], nil)
      window.instance_variable_set(:@pkmnsprite, [])
      window.getEncData
      PokeAccess::SimpleEncounterList.poll
      window.instance_variable_set(:@pkmnsprite, [Object.new, Object.new])
      PokeAccess::SimpleEncounterList.poll
      assert_nothing_spoken
    end
  end

  test "raZ's window on a map without wild Pokemon says so" do
    with_page do
      encounter_window(nil, nil).getEncData
      PokeAccess::SimpleEncounterList.poll
      assert_equal [[t(:enc_none, :loc => "Ruta 1"), true]], SpeakCapture.log
    end
  end

  test "raZ's window on a map whose data lists no species says it has none" do
    with_page do
      encounter_window([], nil).getEncData
      PokeAccess::SimpleEncounterList.poll
      assert_equal [[t(:enc_none, :loc => "Ruta 1"), true]], SpeakCapture.log
    end
  end

  test "Realidea's own weathers, which the game paints no name for, take the mod's words" do
    assert_equal({ :weather_names => { 9 => :w_aroma },
                   :field_weather_names => { 8 => :w_shadow_sky, 9 => :w_aroma, 10 => :w_ash } }, profile_names)
  end

  test "every weather word the profile names has a text" do
    keys = profile_names.values.map { |table| table.values }.flatten.uniq
    assert_equal [], keys.select { |k| t(k) == k.to_s }
  end

  private

  # The text of an i18n key in the language the test runs in.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The block's value with Input.trigger? answering true for keys alone, the stub's put back after.
  def press(*keys)
    stub = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |key, *_rest| keys.include?(key) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, stub)
  end

  # The block's value with rand's draws in the game's functions set to values, in order.
  def draws(*values)
    ReaDraws.queue.replace(values)
    yield
  ensure
    ReaDraws.queue.clear
  end

  # The block's value with $Trainer standing as trainer, put back after.
  def with_trainer(trainer)
    saved = $Trainer
    $Trainer = trainer
    yield
  ensure
    $Trainer = saved
  end

  # A letter typed on the beam, as rayosporygon takes it: pushed, then checked.
  def type_letter(letter)
    $Trainer.arraycomb.push(letter)
    checkporygon
  end

  # The refutation screen's banner with the key that breaks it.
  def banner
    "#{t(:rea_dg_danger)} #{t(:rea_dg_key)}"
  end

  # The fishing minigame on Goldeen at level 12 with full HP, these ivars over it, built without its initializer (which
  # runs the whole loop).
  def fishing(ivars = {})
    fish = Pesca.allocate
    pk = Object.new
    def pk.name; "Goldeen"; end
    { :@pokemon => pk, :@nivel => 12, :@frame => 1, :@protahp => 180, :@enemhp => 180 }.merge(ivars).each do |k, v|
      fish.instance_variable_set(k, v)
    end
    fish
  end

  # The fractions the block's ticks of the minigame gauge carry, Sound.gauge put back after.
  def gauge_ticks
    ticks = []
    gauge = PokeAccess::Sound.method(:gauge)
    PokeAccess::Sound.define_singleton_method(:gauge) { |fraction| ticks.push(fraction) }
    yield
    ticks
  ensure
    PokeAccess::Sound.define_singleton_method(:gauge, gauge)
  end

  # The block's value on map "Ruta 1" with a player who caught species 16 and saw 16 and 19, both put back after.
  def with_page
    trainer = Object.new
    def trainer.owned?(sp); sp == 16; end
    def trainer.seen?(sp); sp == 16 || sp == 19; end
    def $game_map.name; "Ruta 1"; end
    with_trainer(trainer) { yield }
  ensure
    $game_map.singleton_class.send(:remove_method, :name)
  end

  # The window holding these species (nil for a map without data) and page type, built without its initializer.
  def encounter_window(species, type)
    ui = EncounterListUI.allocate
    ui.instance_variable_set(:@pa_species, species)
    ui.instance_variable_set(:@pa_name, type)
    ui
  end

  # A line of the duel's list as the cursor says it, with its place.
  def entry(line, n, tot)
    t(:list_entry, :name => line, :n => n, :tot => tot)
  end

  # The lines said since the last clear but the hearts line with these counts, wherever and however it was said.
  def lines_besides_hearts(n, e)
    SpeakCapture.lines - [t(:rea_hearts, :n => n, :e => e)]
  end

  # The block's value with the game's data giving no species a name.
  def without_species_names
    nameless = Object.new
    def nameless.species_name(_id); nil; end
    Harness.with_provider(nameless) { yield }
  end

  # A species' name as the data gives it.
  def species(id)
    PokeAccess::Data.species_name(id)
  end

  # The species of the page with_page shows for 16, 19 and 21, as [name, Pokedex state].
  def page_entries
    [[species(16), :dex_caught], [species(19), :dex_seen], [species(21), :dex_unknown]]
  end

  # The page's species line under its map and type header.
  def summary(entries, whole = false)
    PokeAccess::EncounterList.summary("Ruta 1: Hierba Alta", entries, whole)
  end

  # A species icon drawn at this opacity and grey.
  def icon(opacity, gray)
    Struct.new(:opacity, :tone).new(opacity, Struct.new(:gray).new(gray))
  end

  # The name tables games/realidea/constants.rb declares, as {table => {id => key}}, read through a recorder standing
  # for Game.define's block so nothing reaches the toolkit's own tables.
  def profile_names
    tables = {}
    recorder = Object.new
    recorder.define_singleton_method(:names) { |table, map| (tables[table] ||= {}).merge!(map) }
    recorder.define_singleton_method(:method_missing) { |*_args| nil }
    define = PokeAccess::Game.method(:define)
    PokeAccess::Game.define_singleton_method(:define) { |*_args, &blk| recorder.instance_eval(&blk) }
    path = File.join(Harness::ROOT, "games", "realidea", "constants.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    tables
  ensure
    PokeAccess::Game.define_singleton_method(:define, define)
  end
end
