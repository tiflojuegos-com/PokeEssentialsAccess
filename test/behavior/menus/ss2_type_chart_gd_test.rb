# Soulstones 2's Type Match-up chart (games/soulstones2/type_chart.rb): the lines it hands the game's own tts reader, off
# as shipped, are relayed while the chart is up and nowhere else, and Control reads the full match-up.

# The game's own reader's entry point, which the mod wraps by name.
def tts(text, _interrupt = false); text; end

# Soulstones 2's SpeciesTypeMatch_Scene, reduced to the calls its chart makes: the opening lines and first draw, the
# chart's loop (the block, run while it is up), the species list and type question with their own lines, the frame.
class SpeciesTypeMatch_Scene
  attr_accessor :fails

  def initialize(species = [1, 4]); @species = species; @index = 0; end

  def pbTypeMatchUp
    @init = true
    tts("Type Matchup for Bulbasaur.", true)
    tts("USE Button: Jump to Different Species.")
    drawSpeciesTypes(1)
    yield self if block_given?
    raise "the chart failed" if @fails
    :done
  end

  def pbUpdate; :updated; end

  def drawSpeciesTypes(_species, _speak = false)
    tts("Type Matchups for Bulbasaur .")
    @init = false
  end

  def pbChooseSpeciesFromList(default = nil, _current = nil); tts("Bulbasaur"); default; end
  def pbChooseMonoTypeSpecies(default = nil, _current = nil); tts("Select a Type to filter"); tts("Normal"); default; end
end

ss2_type_chart = File.join(Harness::ROOT, "games", "soulstones2", "type_chart.rb")
eval(Harness.source(ss2_type_chart), TOPLEVEL_BINDING, ss2_type_chart)

class Ss2TypeChartGdTest < PokeAccessTest
  # The chart's opening as the game hands it to its reader.
  OPENING = [["Type Matchup for Bulbasaur.", false], ["USE Button: Jump to Different Species.", false]].freeze
  # This game's Effectiveness values by icon: immune, a quarter, half, neutral, double, quadruple.
  VALUES = { :immune? => 0, :barely_effective? => 2, :not_so_effective? => 4, :pretty_effective? => 16,
             :hyper_effective? => 32 }.freeze
  # How each attacking type hits each of a defender's types, 8 being neutral (a pair not listed); against Rock and
  # Ground they draw every icon: Water and Grass quadruple, Fighting double, Normal half, Poison a quarter, Electric none.
  HITS = { [:WATER, :ROCK] => 16, [:WATER, :GROUND] => 16, [:GRASS, :ROCK] => 16, [:GRASS, :GROUND] => 16,
           [:FIGHTING, :ROCK] => 16, [:NORMAL, :ROCK] => 4, [:POISON, :ROCK] => 4, [:POISON, :GROUND] => 4,
           [:ELECTRIC, :GROUND] => 0 }.freeze
  # Only Water hits Rock and Ground harder than neutral.
  WATER_ONLY = { [:WATER, :ROCK] => 16, [:WATER, :GROUND] => 16 }.freeze
  # The attacking types the game lists, its unknown type included.
  TYPES = [:NORMAL, :FIGHTING, :POISON, :WATER, :GRASS, :ELECTRIC, :ROCK, :QMARKS].freeze
  # A species row as GameData::Species.get answers it.
  Species = Struct.new(:real_name, :form, :real_form_name, :types)
  # A type row as GameData::Type.each yields it.
  TypeRow = Struct.new(:id)

  test "relays nothing the game hands its reader outside the chart" do
    tts("Algo fuera de la pantalla.")
    assert_nothing_spoken
  end

  test "speaks the chart's opening lines as it wrote them, queued, leaving out its first draw" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp
    assert_equal OPENING, SpeakCapture.log
  end

  test "keeps the chart's own return" do
    assert_equal :done, SpeciesTypeMatch_Scene.new.pbTypeMatchUp
  end

  test "is quiet again once the chart closes" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp
    SpeakCapture.clear
    tts("Otra vez fuera.")
    assert_nothing_spoken
  end

  test "is quiet again after a chart that raised" do
    chart = SpeciesTypeMatch_Scene.new
    chart.fails = true
    assert_raises(RuntimeError) { chart.pbTypeMatchUp }
    SpeakCapture.clear
    tts("Otra vez fuera.")
    assert_nothing_spoken
  end

  test "announces a species drawn after the opening, queued" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do |chart|
      SpeakCapture.clear
      chart.drawSpeciesTypes(4)
    end
    assert_equal [["Type Matchups for Bulbasaur .", false]], SpeakCapture.log
  end

  test "leaves the species list and the type question to the readers that already say them" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do |chart|
      SpeakCapture.clear
      chart.pbChooseSpeciesFromList(4, 4)
      chart.pbChooseMonoTypeSpecies(4, 4)
    end
    assert_nothing_spoken
  end

  test "the species list and the type question keep their own returns" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do |chart|
      assert_equal [4, 7], [chart.pbChooseSpeciesFromList(4, 1), chart.pbChooseMonoTypeSpecies(7, 1)]
    end
  end

  test "relays again once the species list closes" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do |chart|
      chart.pbChooseSpeciesFromList(4, 4)
      SpeakCapture.clear
      tts("Weak to Fire.")
    end
    assert_equal [["Weak to Fire.", false]], SpeakCapture.log
  end

  test "leaves a message shown over the chart to the dialogue reader" do
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do
      SpeakCapture.clear
      in_message { tts("Has elegido a Bulbasaur.") }
    end
    assert_nothing_spoken
  end

  test "relays a chart opened from inside a message" do
    in_message { SpeciesTypeMatch_Scene.new.pbTypeMatchUp }
    assert_equal OPENING, SpeakCapture.log
  end

  test "with hints left out, drops the lines that name a key and relays the rest" do
    PokeAccess::Config.verbosity = :brief
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do
      ["A Button: Change species.", "LEFT and RIGHT: Change page.", "Weak to Fire Flying."].each { |l| tts(l) }
    end
    assert_equal [["Type Matchup for Bulbasaur.", false], ["Weak to Fire Flying.", false]], SpeakCapture.log
  end

  test "relays nothing of a line whose bytes are not UTF-8, and the game's reader still gets it" do
    garbled = "Type Matchups for Flabébé .".encode("Windows-1252").force_encoding("UTF-8")
    handed = nil
    SpeciesTypeMatch_Scene.new.pbTypeMatchUp do
      SpeakCapture.clear
      handed = tts(garbled)
    end
    assert_same garbled, handed, "the game's reader gets the line"
    assert_nothing_spoken
  end

  test "Control reads the species under the cursor, its types and each icon group strongest first, interrupting" do
    with_chart_data(HITS) do
      chart = SpeciesTypeMatch_Scene.new([:ONIX, :GOLEM])
      chart.instance_variable_set(:@index, 1)
      pressing_ctrl { chart.pbUpdate }
    end
    assert_equal [[matchup("Golem", [[:mv_eff_hyper, "TypeWATER, TypeGRASS"], [:mv_eff_super, "TypeFIGHTING"],
                                     [:mv_eff_weak, "TypeNORMAL"], [:mv_eff_barely, "TypePOISON"],
                                     [:mv_eff_none, "TypeELECTRIC"]]), true]],
                 SpeakCapture.log
  end

  test "Control names a form other than the base after the species" do
    with_chart_data(WATER_ONLY, :GOLEM => Species.new("Golem", 1, "Forma de Alola", [:ROCK, :GROUND])) do
      pressing_ctrl { SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    end
    assert_equal [[matchup("Golem Forma de Alola", [[:mv_eff_hyper, "TypeWATER"]]), true]], SpeakCapture.log
  end

  test "Control leaves out the base form's name" do
    with_chart_data(WATER_ONLY, :GOLEM => Species.new("Golem", 0, "Forma normal", [:ROCK, :GROUND])) do
      pressing_ctrl { SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    end
    assert_equal [[matchup("Golem", [[:mv_eff_hyper, "TypeWATER"]]), true]], SpeakCapture.log
  end

  test "Control leaves out the groups no attacking type falls in, neutral among them" do
    with_chart_data(WATER_ONLY.merge([:POISON, :ROCK] => 4, [:POISON, :GROUND] => 4)) do
      pressing_ctrl { SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    end
    assert_equal [[matchup("Golem", [[:mv_eff_hyper, "TypeWATER"], [:mv_eff_barely, "TypePOISON"]]), true]],
                 SpeakCapture.log
  end

  test "Control counts the game's unknown type as no attacker" do
    with_chart_data(WATER_ONLY.merge([:QMARKS, :ROCK] => 0)) do
      pressing_ctrl { SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    end
    assert_equal [[matchup("Golem", [[:mv_eff_hyper, "TypeWATER"]]), true]], SpeakCapture.log
  end

  test "a frame with no key press says nothing" do
    with_chart_data(HITS) { SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    assert_nothing_spoken
  end

  test "an engine with no Control key never reads the match-up" do
    with_chart_data(HITS) do
      ctrl = Input.send(:remove_const, :CTRL)
      begin
        SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate
      ensure
        Input.const_set(:CTRL, ctrl)
      end
    end
    assert_nothing_spoken
  end

  test "Control with no species under the cursor says nothing" do
    with_chart_data(HITS) do
      pressing_ctrl { SpeciesTypeMatch_Scene.new([]).pbUpdate }
    end
    assert_nothing_spoken
  end

  test "Control over species data that cannot be read says nothing, and the frame goes on" do
    with_chart_data(HITS, {}) do
      pressing_ctrl { assert_equal :updated, SpeciesTypeMatch_Scene.new([:GOLEM]).pbUpdate }
    end
    assert_nothing_spoken
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The full match-up line: the species, its types (Rock and Ground), then each [group key, attacking types].
  def matchup(name, groups)
    ([name, t(:mv_type, :t => "TypeROCK TypeGROUND")] +
     groups.map { |key, types| t(:ss2_matchup_group, :eff => t(key), :types => types) }).join(". ")
  end

  # Runs the block with the game's data as the chart reads it: Effectiveness over hits, GameData::Species.get from
  # species (a missing id raises) and GameData::Type.each over TYPES; all put back after.
  def with_chart_data(hits, species = { :GOLEM => Species.new("Golem", 0, "", [:ROCK, :GROUND]) })
    prior = Object.const_defined?(:Effectiveness, false) ? Object.send(:remove_const, :Effectiveness) : nil
    Object.const_set(:Effectiveness, effectiveness(hits))
    get = GameData::Species.method(:get)
    each = GameData::Type.singleton_class.method_defined?(:each, false) ? GameData::Type.method(:each) : nil
    GameData::Species.define_singleton_method(:get) { |id| species.fetch(id) }
    GameData::Type.define_singleton_method(:each) { |&blk| TYPES.each { |ty| blk.call(TypeRow.new(ty)) } }
    yield
  ensure
    if each
      GameData::Type.define_singleton_method(:each, each)
    elsif GameData::Type.singleton_class.method_defined?(:each, false)
      GameData::Type.singleton_class.send(:remove_method, :each)
    end
    GameData::Species.define_singleton_method(:get, get) if get
    Object.send(:remove_const, :Effectiveness) if Object.const_defined?(:Effectiveness, false)
    Object.const_set(:Effectiveness, prior) if prior
  end

  # The game's Effectiveness module over hits: calculate multiplies how the attack hits each defending type (a
  # second type absent counts neutral), and a predicate per icon tells the values apart.
  def effectiveness(hits)
    m = Module.new
    m.define_singleton_method(:calculate) do |attack, d1, d2|
      hits.fetch([attack, d1], 8) * (d2 ? hits.fetch([attack, d2], 8) : 8) / 8
    end
    VALUES.each { |pred, v| m.define_singleton_method(pred) { |x| x == v } }
    m
  end

  # Runs the block with Control pressed this frame and no other key, Input put back after.
  def pressing_ctrl
    trigger = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| k == Input::CTRL }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trigger)
  end

  # Runs the block with a message window open over whatever is up.
  def in_message
    PokeAccess.message_enter
    yield
  ensure
    PokeAccess.message_leave
  end
end
