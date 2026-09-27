# Realidea's own scenes and screens outside the blocking-loop minigames, entered through the game's own methods and
# functions: Route 17's Porygon-Z beam, the refutation screen and the credits, the fishing minigame, the encounter
# list and the weather names. The stand-ins below are shaped as the game's and exist before the profile loads, so
# its hooks bind to them as they do in the game.

# Route 17's beam: anadircomb fills variable 145 with three of A, S and D; the typed letter is pushed onto
# $Trainer.arraycomb before checkporygon, which clears both on a miss (running paralizarpoke) or on the third right
# letter; paralizarpoke writes status 4, paralysis, on a random member.
def anadircomb
  $game_variables[145] = []
  3.times { $game_variables[145].push(%w[A S D][rand(3)]) }
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
  poke = $Trainer.party[rand($Trainer.party.length) - 1]
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

# The line darpoke shows as the fished Pokemon gives in.
REA_PESCA_WEAK = "¡El Pokémon está débil! ¡Hora de lanzar una Pokéball!"

# The fishing minigame (Faia emblem), down to what input does with the keys on each frame of its loop: back closes
# it and the accept key runs resultado, which takes HP from each side by the frame the press lands on; at no enemy HP
# darpoke shows its message (Kernel.pbMessage, which reaches pbMessageDisplay) before the ball choice.
class Pesca
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
    Kernel.pbMessageDisplay(nil, REA_PESCA_WEAK)
    @cerrar = 1
  end
end

# The encounter window as raZ's plugin (getEncData) and Realidea's adaptation fill it: loadEncounterData sets the
# number of types only on a map with data (else its list is [7]); startUI opens on the first page (loadCurrentPage,
# which reloads the data before painting it) only when there is one.
class EncounterListUI
  def getEncData; @encarray = @pa_species; end

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
load File.expand_path("../../../plugins/simple_encounter_list.rb", File.dirname(__FILE__))

%w[porygon_ray scenes story_minigames encounters].each do |f|
  require File.expand_path("../../../games/realidea/#{f}", File.dirname(__FILE__))
end

# A window holding these species (nil for a map without data) and page type, built without its initializer.
def rea_enc_window(species, name)
  ui = EncounterListUI.allocate
  ui.instance_variable_set(:@pa_species, species)
  ui.instance_variable_set(:@pa_name, name)
  ui
end

def rea_sc(key, vars = nil); PokeAccess::I18n.t(key, vars); end

# A Pokemon as these readers see it.
class ReaScenePoke
  attr_accessor :name, :status
  def initialize(name, status = 0); @name = name; @status = status; end
end

# A letter typed on the beam, as rayosporygon takes it: pushed, then checked.
def rea_ray_press(letter)
  $Trainer.arraycomb.push(letter)
  checkporygon
end

# The fishing minigame with these ivars, built without its initializer (which runs the whole loop).
def rea_pesca(ivars)
  s = Pesca.allocate
  ivars.each { |k, v| s.instance_variable_set(k, v) }
  s
end

# Input.trigger? answering true for the given buttons while a block runs.
module ReaSceneKeys
  @keys = []
  def self.pressed?(k); @keys.include?(k); end

  def self.press(*keys)
    install
    @keys = keys
    yield
  ensure
    @keys = []
    remove
  end

  def self.install
    class << Input
      alias_method :pa_rsk_orig_trigger?, :trigger?
      def trigger?(k); ReaSceneKeys.pressed?(k) || pa_rsk_orig_trigger?(k); end
    end
  end

  def self.remove
    class << Input
      alias_method :trigger?, :pa_rsk_orig_trigger?
    end
  end
end

# The beam through the game's functions: the letters once anadircomb has painted them, each letter before
# checkporygon clears the combo, and the member paralizarpoke paralyses.
Suite.define("realidea Porygon-Z beam: the letters as they appear, each right letter back, and who a miss paralyses") do
  old = $Trainer
  begin
    tr = Object.new
    class << tr; attr_accessor :arraycomb, :party; end
    tr.arraycomb = []
    tr.party = [ReaScenePoke.new("Pika"), ReaScenePoke.new("Chispa")]
    $Trainer = tr
    anadircomb
    combo = $game_variables[145]
    eq "the three letters as they are painted", SpeakCapture.lines, [rea_sc(:rea_ray_keys, :keys => combo.join(", "))]

    SpeakCapture.clear
    combo.each { |letter| rea_ray_press(letter) }
    eq "each right letter is said back, the third too though checkporygon then clears the combo", SpeakCapture.lines, combo
    eq "which it did", [$game_variables[145], tr.arraycomb], [[], []]

    anadircomb
    wrong = (%w[A S D] - [$game_variables[145][0]]).first
    SpeakCapture.clear
    rea_ray_press(wrong)
    hit = tr.party.find { |pk| pk.status == 4 }
    eq "a wrong letter is left to the miss, which names the member it paralysed", SpeakCapture.lines,
       [rea_sc(:rea_ray_hit, :name => hit.name)]

    tr.party.each { |pk| pk.status = 4 }
    anadircomb
    wrong = (%w[A S D] - [$game_variables[145][0]]).first
    SpeakCapture.clear
    rea_ray_press(wrong)
    eq "one already paralysed leaves the miss alone", SpeakCapture.lines, [rea_sc(:rea_ray_miss)]
  ensure
    $Trainer = old
  end
end

# The refutation screen through its constructor and the credits through textofade and Credit#textofade1: the banner
# as actu starts waiting, the break as rompido starts, and each block as it is painted.
Suite.define("realidea refutation and credits: the DANGER banner and its key, the break, each credits block") do
  banner = "#{rea_sc(:rea_dg_danger)} #{rea_sc(:rea_dg_key)}"
  ReaSceneKeys.press(Input::C) { Danganronpa.new }
  eq "the banner and the key that breaks it as the screen waits, then the break", SpeakCapture.log,
     [[banner, true], [rea_sc(:rea_dg_break), true]]
  SpeakCapture.clear
  ReaSceneKeys.press(Input::B) { Danganronpa.new }
  eq "leaving with back breaks nothing", SpeakCapture.lines, [banner]

  SpeakCapture.clear
  textofade("<ac>MÚSICA\n\nemdasche\nKunning Fox\nJobless Music</ac>", 5, 200)
  eq "a block is its heading and its names, queued", SpeakCapture.log, [["MÚSICA: emdasche, Kunning Fox, Jobless Music", false]]
  SpeakCapture.clear
  textofade("<ac></ac>", 1, 20)
  silent "an empty block says nothing"
  maps = "<ac>MAPAS\n\nElena\nMaxewenx/Alfpixel</ac>"
  2.times { textofade(maps, 5, 200) }
  eq "textofade paints each call anew, so each is said", SpeakCapture.lines, ["MAPAS: Elena, Maxewenx/Alfpixel"] * 2

  SpeakCapture.clear
  scene = Credit.new
  5.times { scene.textofade1(maps, 5, 200) }
  eq "the block the credits scene repaints every frame is said once", SpeakCapture.lines, ["MAPAS: Elena, Maxewenx/Alfpixel"]
  SpeakCapture.clear
  scene.textofade1("<ac>AGRADECIMIENTOS\n\nPablus94</ac>", 5, 200)
  eq "and the next block in its turn", SpeakCapture.lines, ["AGRADECIMIENTOS: Pablus94"]
end

# The fishing minigame through input, a frame of its loop: the Pokemon and the HP as it opens, each press rated by
# resultado before its HP, and the rating of the last blow before darpoke's message.
Suite.define("realidea fishing: the Pokemon on the hook as it opens, and each press rated as its picture shows it") do
  pk = Object.new
  def pk.name; "Goldeen"; end
  scene = rea_pesca(:@pokemon => pk, :@nivel => 12, :@frame => 1, :@protahp => 180, :@enemhp => 180)
  scene.input
  eq "the Pokemon and its level first, then the HP", SpeakCapture.lines,
     [rea_sc(:rea_pesca_foe, :name => "Goldeen", :level => 12), rea_sc(:rea_hp, :hp => 180, :ehp => 180)]
  SpeakCapture.clear
  scene.input
  silent "said once"
  { 11 => :rea_pesca_perfect, 10 => :rea_pesca_great, 12 => :rea_pesca_great, 9 => :rea_pesca_good,
    13 => :rea_pesca_good, 8 => :rea_pesca_bad, 14 => :rea_pesca_bad }.each do |frame, key|
    SpeakCapture.clear
    scene.instance_variable_set(:@frame, frame)
    ReaSceneKeys.press(Input::C) { scene.input }
    eq "frame #{frame} is rated as its picture, first", SpeakCapture.log[0], [rea_sc(key), true]
  end
  eq "and the HP the presses cost follow it", SpeakCapture.lines.last, rea_sc(:rea_hp, :hp => 60, :ehp => 20)

  SpeakCapture.clear
  scene.instance_variable_set(:@frame, 11)
  ReaSceneKeys.press(Input::C) { scene.input }
  eq "the blow that leaves it weak is rated before the game's message", SpeakCapture.lines[0, 2],
     [rea_sc(:rea_pesca_perfect), REA_PESCA_WEAK]
end

# The encounter window through startUI: loadEncounterData's no-data line once it has run, and loadCurrentPage's page.
Suite.define("realidea encounter list: the window opens on its first page's line, or on its map having no wild Pokemon") do
  old = $Trainer
  begin
    tr = Object.new
    def tr.owned?(sp); sp == 16; end
    def tr.seen?(sp); true; end
    $Trainer = tr
    def $game_map.name; "Ruta 1"; end
    entries = [[PokeAccess::Data.species_name(16), :dex_caught], [PokeAccess::Data.species_name(19), :dex_seen]]
    rea_enc_window([16, 19], "Hierba Alta").startUI
    eq "a map with data opens on its page: map, type, species and the caught count", SpeakCapture.lines,
       ["#{PokeAccess::EncounterList.summary('Ruta 1: Hierba Alta', entries)}. #{rea_sc(:rea_enc_owned, :n => 1)}"]

    SpeakCapture.clear
    rea_enc_window(nil, nil).startUI
    eq "a map without data says so, once", SpeakCapture.lines, [rea_sc(:enc_none, :loc => "Ruta 1")]

    SpeakCapture.clear
    plain = rea_enc_window([16, 19], nil)
    plain.instance_variable_set(:@pkmnsprite, [Object.new, Object.new])
    plain.getEncData
    PokeAccess::SimpleEncounterList.poll
    eq "raZ's plugin window is read once getEncData has filled it and its icons are drawn", SpeakCapture.lines,
       [PokeAccess::EncounterList.summary("Ruta 1", entries)]
  ensure
    $Trainer = old
    class << $game_map; remove_method :name; end
  end
end

Suite.define("realidea: the weathers the game paints no name for take the mod's words") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  src = File.read(File.join(root, "games", "realidea", "constants.rb"))
  values = []
  src.scan(/^\s*names\(:\w+,\s*(.+)\)\s*$/) { |m| values.concat(eval("{ #{m[0]} }").values) }
  truthy "the profile names weathers", values.length >= 4
  eq "every name is an i18n key", values.reject { |v| v.is_a?(Symbol) }, []
  eq "and every key resolves", values.select { |v| v.is_a?(Symbol) && rea_sc(v) == v.to_s }, []
end
