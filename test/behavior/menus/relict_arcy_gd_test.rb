# Relict's own screens (games/relict: arcy.rb, search.rb, load.rb) over stand-ins shaped as its scripts: the tower's
# floor card and map mode, the starter's shiny, the plate handed over, the Arceus quiz's hearts and clue board, the
# species search's opening and the load panel that paints titles alone.
class ShowStarterPokemon
  Help = Struct.new(:text)

  def initialize(pokemon, line = "Ah, #{pokemon.name}. The Big Jaw Pokémon...")
    @sprites = { "helpwindow" => Help.new(line) }
    main_loop
  end

  def main_loop; :picked; end
end

class GivePlateMessage
  # The inscriptions pick_plate_descriptions gives, by plate: a list as the game keeps them, or a bare line.
  INSCRIPTIONS = { :EARTHPLATE => ["\"The Original One breathed alone before the universe came.\""],
                   :SKYPLATE => "\"It shaped the sky.\"", :BLANKPLATE => [] }

  def initialize(plate = :ZAPPLATE, translate = true)
    @translate = translate
    setup(plate)
  end

  def pick_plate_descriptions(plate); INSCRIPTIONS[plate]; end
  def setup(_plate); :shown; end
end

class ArcyContest
  Viewport = Struct.new(:disposed) do
    def dispose; self.disposed = true; end
    def disposed?; disposed; end
  end

  # The clues the board paints (text, x, y, align...), two to a row.
  TIPS = [["It's 0.7 m tall.", 2, 2, :left, nil, nil, true], ["Its color is Red.", 512, 2, :right, nil, nil, true],
          ["It has the Water type.", 2, 34, :left, nil, nil, true]]

  def initialize(tips = TIPS); @tips = tips; @lives = 5; @currentlives = 5; @viewport = Viewport.new(false); end
  def updateHearts; @currentlives; end
  def pick_question; :asked; end
  def dispose; @viewport.dispose; :gone; end

  def addTips
    pbDrawTextPositions(Object.new, @tips)
    :drawn
  end
end

class NextFloor
  def setup; :shown; end
end

class PokemonEntryScene
  def pbStartScene_Dynamic(helptext, _min, _max, _initial, _subject = 0, _pokemon = nil, commands = [], _flags = [])
    @heading = helptext
    @commands = commands
    drawTextEx(Object.new, 32, 288, 448, 2, "Input thy words upon the keys. Press\nEnter to affirm, or Esc to forswear.")
  end
end

def rewriteDungeonLayoutAll; :rewritten; end

%w[arcy search].each do |f|
  path = File.join(Harness::ROOT, "games", "relict", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RelictArcyGdTest < PokeAccessTest
  LOAD = File.join(Harness::ROOT, "games", "relict", "load.rb")
  BOARD = "It's 0.7 m tall. Its color is Red. It has the Water type."
  HELP = "Input thy words upon the keys. Press Enter to affirm, or Esc to forswear."

  test "the floor card says the floor it shows, counted from one, as the game paints it" do
    with_floor(5) do
      assert_equal :shown, NextFloor.new.setup, "the card's own setup still runs"
      assert_equal [["Torre Destino, piso 6", true]], SpeakCapture.log
    end
  end

  test "the floor card says nothing while the tower keeps no floor" do
    NextFloor.new.setup
    assert_nothing_spoken
  end

  test "the dungeon map's mode is said as it switches" do
    t = PokeAccess::I18n
    { 0 => :rel_map_small, 1 => :rel_map_large, 2 => :rel_map_off, 7 => :rel_map_small }.each do |stage, key|
      with_layout_stage(stage) do
        SpeakCapture.clear
        assert_equal :rewritten, rewriteDungeonLayoutAll, "the game's rewrite runs"
        assert_equal [[t.t(key), true]], SpeakCapture.log, "stage #{stage}"
      end
    end
  end

  test "a map mode that is no number is not said" do
    with_layout_stage(Object.new) do
      rewriteDungeonLayoutAll
      assert_nothing_spoken
    end
  end

  test "a shiny starter is said after its line, queued, as its sprite shows it" do
    ShowStarterPokemon.new(Poke.build(:name => "Totodile", :shiny => true))
    assert_equal [["Ah, Totodile. The Big Jaw Pokémon... #{PokeAccess::I18n.t(:pk_shiny_hatch)}", false]],
                 SpeakCapture.log
  end

  test "a plain starter is its line alone" do
    ShowStarterPokemon.new(Poke.build(:name => "Totodile"))
    assert_equal [["Ah, Totodile. The Big Jaw Pokémon...", false]], SpeakCapture.log
  end

  test "a starter shown without a line is said by its shiny alone, or not at all" do
    ShowStarterPokemon.new(Poke.build(:name => "Totodile", :shiny => true), "")
    assert_equal [[PokeAccess::I18n.t(:pk_shiny_hatch), false]], SpeakCapture.log, "a shiny one"
    SpeakCapture.clear
    ShowStarterPokemon.new(Poke.build(:name => "Totodile"), "")
    assert_nothing_spoken "a plain one"
  end

  test "an untranslated plate is said as an Unown inscription, never by its name" do
    GivePlateMessage.new(:EARTHPLATE, false)
    assert_equal [[PokeAccess::I18n.t(:rel_plate_unown), true]], SpeakCapture.log
  end

  test "a translated plate is said by its name and its inscription" do
    name = PokeAccess::Data.item_name(:EARTHPLATE)
    GivePlateMessage.new(:EARTHPLATE)
    assert_equal [["#{name}. \"The Original One breathed alone before the universe came.\"", true]], SpeakCapture.log
  end

  test "a translated plate keeps what it has of its name and inscription" do
    sky = PokeAccess::Data.item_name(:SKYPLATE)
    blank = PokeAccess::Data.item_name(:BLANKPLATE)
    GivePlateMessage.new(:SKYPLATE)
    GivePlateMessage.new(:BLANKPLATE)
    [nil, ""].each { |name| with_item_names(name) { GivePlateMessage.new(:EARTHPLATE) } }
    inscription = "\"The Original One breathed alone before the universe came.\""
    assert_equal ["#{sky}. \"It shaped the sky.\"", blank, inscription, inscription], SpeakCapture.lines
  end

  test "a plate with neither name nor inscription says nothing" do
    with_item_names(nil) { GivePlateMessage.new(:BLANKPLATE) }
    assert_nothing_spoken
  end

  test "the quiz says the five hearts a round starts with before its first question, queued" do
    ArcyContest.new.pick_question
    assert_equal [[PokeAccess::I18n.t(:rel_lives, :n => 5), false]], SpeakCapture.log
  end

  test "the quiz says each heart lost once" do
    quiz = ArcyContest.new
    quiz.pick_question
    SpeakCapture.clear
    quiz.instance_variable_set(:@currentlives, 4)
    quiz.updateHearts
    quiz.pick_question
    assert_equal [[PokeAccess::I18n.t(:rel_lives, :n => 4), false]], SpeakCapture.log
  end

  test "the quiz says no hearts before it has set them" do
    quiz = ArcyContest.new
    quiz.instance_variable_set(:@currentlives, nil)
    quiz.pick_question
    assert_nothing_spoken
  end

  test "the hearts and the ring's floor plate are worded as the game does in Spanish" do
    t = PokeAccess::I18n
    assert_equal "Corazones: 5", t.t(:rel_lives, :n => 5), "the hearts the quiz draws and names"
    assert_equal "Piso 6", t.t(:rel_panel_floor, :n => 6), "the ring's plate, as button_floor_esp"
  end

  test "the clue board stays on the info key, unsaid, while its quiz is on screen" do
    with_board do
      PokeAccess::Locator.refresh_info
      quiz = ArcyContest.new
      assert_equal :drawn, quiz.addTips, "the board's paint goes on as the game's"
      assert_nothing_spoken "nothing is said as it is drawn"
      assert_equal BOARD, PokeAccess::Info.info_text, "the info key has every clue, row by row, as soon as it is drawn"
      assert_equal BOARD, map_info, "and keeps them through the map frames under the quiz's messages"
    end
  end

  test "a quiz painting no clue keeps the board already there" do
    with_board do
      ArcyContest.new.addTips
      ArcyContest.new([]).addTips
      assert_equal BOARD, map_info
    end
  end

  test "the board is let go as its quiz closes" do
    with_board do
      quiz = ArcyContest.new
      quiz.addTips
      assert_equal :gone, quiz.dispose, "the quiz's own dispose runs"
      assert_equal PokeAccess::Info.trainer_info, map_info, "the map's key is the trainer's again"
    end
  end

  test "the board is let go when told, even with its quiz's viewport alive" do
    with_board do
      ArcyContest.new.addTips
      PokeAccess::RelictArcy.close_board
      assert_equal PokeAccess::Info.trainer_info, map_info
    end
  end

  test "a quiz whose viewport is gone or cannot tell holds the key no longer" do
    with_board do
      { "disposed by a reset" => ArcyContest::Viewport.new(true), "no answer" => Object.new }.each do |what, vp|
        quiz = ArcyContest.new
        quiz.addTips
        quiz.instance_variable_set(:@viewport, vp)
        assert_equal PokeAccess::Info.trainer_info, map_info, what
      end
    end
  end

  test "the species search says its heading and then its help, both queued" do
    PokemonEntryScene.new.pbStartScene_Dynamic("Enter a species", 0, 12, "", 0, nil, ["Arceus"], [:restrict])
    assert_equal [["Enter a species", false], [HELP, false]], SpeakCapture.log
  end

  test "the species search leaves the keys' sentence out when hints are not said" do
    PokeAccess::Config.verbosity = :brief
    PokemonEntryScene.new.pbStartScene_Dynamic("Enter Text", 0, 12, "", 0, nil, ["Arceus"], [:restrict])
    assert_equal ["Enter Text", "Input thy words upon the keys."], SpeakCapture.lines
  end

  test "the load panel composes nothing from the save, as Relict paints titles alone" do
    trainer = Object.new
    def trainer.name; "Mallie"; end
    def trainer.badge_count; 0; end
    args = [["Continue", "New Game"], true, trainer, nil, 3]
    save = PokeAccess::I18n.t(:load_save, :name => "Mallie")
    assert_match(/\A#{Regexp.escape(save)}/, PokeAccess::LoadPanel.summary(args), "the core composes one from the save")
    with_relict_load { assert_nil PokeAccess::LoadPanel.summary(args) }
  end

  private

  # The line the info key gives on the map, as a frame of the map publishes it.
  def map_info
    PokeAccess::Locator.refresh_info
    PokeAccess::Info.info_text
  end

  # Runs the block with the clue board let go before and after, which outlives a test as the module's own.
  def with_board
    PokeAccess::RelictArcy.close_board
    yield
  ensure
    PokeAccess::RelictArcy.close_board
  end

  # Runs the block with the tower on floor n (counted from zero, as $PokemonGlobal.dungeonFloor keeps it).
  def with_floor(n)
    $PokemonGlobal.define_singleton_method(:dungeonFloor) { n }
    yield
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :dungeonFloor)
  end

  # Runs the block with the dungeon map in mode stage ($layoutStage), put back after.
  def with_layout_stage(stage)
    was = $layoutStage
    $layoutStage = stage
    yield
  ensure
    $layoutStage = was
  end

  # Runs the block with every item name answering name, the real lookup put back after.
  def with_item_names(name)
    real = PokeAccess::Data.method(:item_name)
    PokeAccess::Data.define_singleton_method(:item_name) { |*_a| name }
    yield
  ensure
    PokeAccess::Data.define_singleton_method(:item_name, real)
  end

  # Runs the block with Relict's load panel override in place, the core's summary put back after.
  def with_relict_load
    meta = (class << PokeAccess::LoadPanel; self; end)
    meta.send(:alias_method, :relict_test_summary, :summary)
    eval(Harness.source(LOAD), TOPLEVEL_BINDING, LOAD)
    yield
  ensure
    meta.send(:alias_method, :summary, :relict_test_summary)
    meta.send(:remove_method, :relict_test_summary)
  end
end
