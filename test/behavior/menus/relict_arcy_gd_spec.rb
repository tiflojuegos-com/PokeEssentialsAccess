# Relict's own screens (games/relict: arcy.rb, search.rb, load.rb), gamedata pass, over stand-ins shaped as its
# scripts: the starter's shiny, the plate that fuses unread, the Arceus quiz's hearts and clue board, the species
# search's opening, the load panel that paints titles alone and the tower's floor in the Spanish the game paints.
class ShowStarterPokemon
  Help = Struct.new(:text)

  def initialize(pokemon)
    @sprites = { "helpwindow" => Help.new("Ah, #{pokemon.name}. The Big Jaw Pokémon...") }
    main_loop
  end

  def main_loop; :picked; end
end

class GivePlateMessage
  def initialize(plate = :ZAPPLATE, translate = true)
    @translate = translate
    setup(plate)
  end

  def pick_plate_descriptions(_plate); ["\"The Original One breathed alone before the universe came.\""]; end
  def setup(_plate); :shown; end
end

class ArcyContest
  Viewport = Struct.new(:disposed) do
    def dispose; self.disposed = true; end
    def disposed?; disposed; end
  end

  def initialize; @lives = 5; @currentlives = 5; @viewport = Viewport.new(false); end
  def updateHearts; @currentlives; end
  def pick_question; :asked; end
  def dispose; @viewport.dispose; :gone; end

  def addTips
    pbDrawTextPositions(Object.new, [["It's 0.7 m tall.", 2, 2, :left, nil, nil, true],
                                     ["Its color is Red.", 512, 2, :right, nil, nil, true],
                                     ["It has the Water type.", 2, 34, :left, nil, nil, true]])
    :drawn
  end
end

class PokemonEntryScene
  def pbStartScene_Dynamic(helptext, _min, _max, _initial, _subject = 0, _pokemon = nil, commands = [], _flags = [])
    @heading = helptext
    @commands = commands
    drawTextEx(Object.new, 32, 288, 448, 2, "Input thy words upon the keys. Press\nEnter to affirm, or Esc to forswear.")
  end
end

unless $relict_arcy_loaded
  $relict_arcy_loaded = true
  %w[arcy.rb search.rb].each { |f| load File.expand_path("../../../games/relict/#{f}", File.dirname(__FILE__)) }
end

Suite.define("relict starter: a shiny is said after the line, as its sprite shows it") do
  t = PokeAccess::I18n
  SpeakCapture.clear
  ShowStarterPokemon.new(Poke.build(:name => "Totodile", :shiny => true))
  eq "the line, then the shiny, queued", SpeakCapture.log,
     [["Ah, Totodile. The Big Jaw Pokémon... #{t.t(:pk_shiny_hatch)}", false]]
  SpeakCapture.clear
  ShowStarterPokemon.new(Poke.build(:name => "Totodile"))
  eq "a plain one, the line alone", SpeakCapture.log, [["Ah, Totodile. The Big Jaw Pokémon...", false]]
end

Suite.define("relict plate: the untranslated one is an Unown inscription, never the plate's name") do
  t = PokeAccess::I18n
  name = PokeAccess::Data.item_name(:EARTHPLATE)
  SpeakCapture.clear
  GivePlateMessage.new(:EARTHPLATE, false)
  eq "the prologue's plate, which the scene leaves unnamed", SpeakCapture.log, [[t.t(:rel_plate_unown), true]]
  SpeakCapture.clear
  GivePlateMessage.new(:EARTHPLATE)
  eq "a translated one keeps its name and its inscription", SpeakCapture.lines,
     ["#{name}. \"The Original One breathed alone before the universe came.\""]
end

Suite.define("relict quiz: hearts, as the game calls them, from the five a round starts with") do
  t = PokeAccess::I18n
  quiz = ArcyContest.new
  SpeakCapture.clear
  quiz.pick_question
  eq "the five hearts, before the first question", SpeakCapture.log, [[t.t(:rel_lives, :n => 5), false]]
  match "worded as the hearts the game draws and names", t.t(:rel_lives, :n => 5), /\ACorazones: 5\z/
  SpeakCapture.clear
  quiz.instance_variable_set(:@currentlives, 4)
  quiz.updateHearts
  quiz.pick_question
  eq "each one spent, once", SpeakCapture.lines, [t.t(:rel_lives, :n => 4)]
end

Suite.define("relict quiz: the clue board stays on the info key, unsaid, while the quiz is on screen") do
  info = PokeAccess::Info
  board = "It's 0.7 m tall. Its color is Red. It has the Water type."
  quiz = ArcyContest.new
  SpeakCapture.clear
  eq "the board's paint goes on as the game's", quiz.addTips, :drawn
  silent "nothing is said as it is drawn"
  eq "the info key has every clue, row by row", info.info_text, board
  PokeAccess::Locator.refresh_info
  eq "and keeps them through the map frames under the quiz's messages", info.info_text, board
  quiz.dispose
  eq "it lets go of them as the quiz ends", info.info_text, nil
  PokeAccess::Locator.refresh_info
  eq "and the map gives the key back to the trainer", info.instance_variable_get(:@kind), :trainer

  cut = ArcyContest.new
  cut.addTips
  cut.instance_variable_get(:@viewport).dispose
  PokeAccess::Locator.refresh_info
  eq "a quiz gone without closing (its viewport disposed by a reset) holds the key no longer",
     info.instance_variable_get(:@kind), :trainer
  PokeAccess::RelictArcy.close_board
end

Suite.define("relict search: the species search says its heading and help as it opens") do
  SpeakCapture.clear
  PokemonEntryScene.new.pbStartScene_Dynamic("Enter a species", 0, 12, "", 0, nil, ["Arceus"], [:restrict])
  eq "its heading, then its help, both queued", SpeakCapture.log,
     [["Enter a species", false], ["Input thy words upon the keys. Press Enter to affirm, or Esc to forswear.", false]]
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    PokemonEntryScene.new.pbStartScene_Dynamic("Enter Text", 0, 12, "", 0, nil, ["Arceus"], [:restrict])
    eq "without hints, the keys' sentence goes", SpeakCapture.lines, ["Enter Text", "Input thy words upon the keys."]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

Suite.define("relict load: the panels paint their titles alone, so nothing is composed from the save") do
  lp = PokeAccess::LoadPanel
  trainer = Object.new
  def trainer.name; "Mallie"; end
  def trainer.badge_count; 0; end
  args = [["Continue", "New Game"], true, trainer, nil, 3]
  truthy "the core composes a summary from the save", !lp.summary(args).to_s.empty?
  meta = (class << lp; self; end)
  meta.send(:alias_method, :relict_spec_summary, :summary)
  begin
    load File.expand_path("../../../games/relict/load.rb", File.dirname(__FILE__))
    eq "Relict's says nothing beyond the focused command", lp.summary(args), nil
  ensure
    meta.send(:alias_method, :summary, :relict_spec_summary)
    meta.send(:remove_method, :relict_spec_summary)
  end
end

Suite.define("relict: the tower's floor in Spanish as the game paints it (Torre Destino, piso)") do
  t = PokeAccess::I18n
  eq "the floor card", t.t(:rel_floor, :n => 6), "Torre Destino, piso 6"
  eq "the ring's plate, as button_floor_esp", t.t(:rel_panel_floor, :n => 6), "Piso 6"
end
