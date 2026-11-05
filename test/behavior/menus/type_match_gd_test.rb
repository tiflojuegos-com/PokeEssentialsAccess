# The Type Match-up UI (plugins/type_match.rb): a type or a species said with its place, its types and each column by
# the title the first draw paints and the types its icons show, the first draw queued with the screen's key line and
# the next ones cutting in. Only the type screen's hooks are bound here: Soulstones 2's test binds its own chart's on the
# same SpeciesTypeMatch_Scene in this pass, so the species' draw is called straight.

# The type screen as the plugin's: drawTypes paints what it is handed, the jump list answers what was picked.
class TypeMatch_Scene
  attr_accessor :picked

  def initialize(rows)
    @rows = rows
    @types = [:FIRE, :WATER]
    @index = 0
  end

  def drawTypes(_type)
    pbDrawTextPositions(nil, @rows)
    :drawn
  end

  def pbChooseTypeFromList(_default, _current); @picked; end
  def pbEndScene; end
end

begin
  path = File.join(Harness::ROOT, "plugins", "type_match.rb")
  src = Harness.source(path)
  src.scan(/^PokeAccess::Hooks\.\w+\("TypeMatch_Scene".*?(?:^end|:pbEndScene\))\r?\n/m) do
    eval($~[0], TOPLEVEL_BINDING, path, src[0, $~.begin(0)].count("\n") + 1)
  end
end

class TypeMatchGdTest < PokeAccessTest
  # What the first draw paints before anything else: the column titles, then the key line.
  FIRST = [["Weak", 72, 74], ["Resist", 256, 74], ["Immune", 312, 74], ["USE: Jump", 4, 358],
           ["ARROWS: Navigate", 256, 358], ["BACK: Exit", 508, 358]].freeze
  # A type as GameData::Type answers it, and the game's types: Fire and Ground with their columns, Shadow a pseudo-type.
  TypeRow = Struct.new(:id, :name, :weaknesses, :resistances, :immunities, :pseudo_type)
  TYPES = { :FIRE => TypeRow.new(:FIRE, "Fire", [:WATER, :GROUND], [:GRASS], [], false),
            :WATER => TypeRow.new(:WATER, "Water", [], [], [], false),
            :GROUND => TypeRow.new(:GROUND, "Ground", [], [], [], false),
            :GRASS => TypeRow.new(:GRASS, "Grass", [], [], [], false),
            :ELECTRIC => TypeRow.new(:ELECTRIC, "Electric", [], [], [], false),
            :SHADOW => TypeRow.new(:SHADOW, "Shadow", [], [], [], true) }.freeze
  # A species as GameData::Species answers it.
  SpeciesRow = Struct.new(:name, :types)
  SPECIES = { :ONIX => SpeciesRow.new("Onix", [:ROCK, :GROUND]) }.freeze
  # How each attacking type hits Rock and Ground together: Water and Grass four times, Fire half, Electric not at all.
  HITS = { :WATER => 4.0, :GRASS => 4.0, :FIRE => 0.5, :ELECTRIC => 0.0, :GROUND => 2.0 }.freeze

  test "the first draw of a type says it with its place and each column, queued, with the screen's key line" do
    with_types do
      draw(type_scene, :type, :FIRE, FIRST)
    end
    keys = "USE: Jump. ARROWS: Navigate. BACK: Exit"
    assert_equal [["Fire, #{list_place(1, 2)}. Weak: Water, Ground. Resist: Grass. Immune: #{t(:sum_none)}. #{keys}", false]],
                 SpeakCapture.log
  end

  test "the next type cuts in, without the key line, and the same one again says nothing" do
    scene = type_scene
    with_types do
      draw(scene, :type, :FIRE, FIRST)
      SpeakCapture.clear
      scene.instance_variable_set(:@index, 1)
      draw(scene, :type, :WATER, [])
      draw(scene, :type, :WATER, [])
    end
    none = t(:sum_none)
    assert_equal [["Water, #{list_place(2, 2)}. Weak: #{none}. Resist: #{none}. Immune: #{none}", true]], SpeakCapture.log
  end

  test "a species is said by the name it paints, its types, and the columns the game's predicates sort it into" do
    scene = World.stub_scene(:@species => [:ONIX], :@index => 0)
    with_types do
      draw(scene, :species, :ONIX, FIRST + [["Onix", 256, 10]])
    end
    assert_spoken(/\AOnix, #{list_place(1, 1)}, Rock\/Ground\. Weak: Water, Ground, Grass\. Resist: Fire\. Immune: Electric\./)
  end

  test "a species is said by the name it paints over the data's, and by the data's where it paints none" do
    scene = World.stub_scene(:@species => [:ONIX, :ONIX], :@index => 0)
    with_types do
      draw(scene, :species, :ONIX, FIRST + [["Onyx", 256, 10]])
      scene.instance_variable_set(:@index, 1)
      draw(scene, :species, :ONIX, [])
    end
    assert_match(/\AOnyx,/, SpeakCapture.lines[0])
    assert_match(/\AOnix,/, SpeakCapture.lines[1])
  end

  test "a chart fed with battlers, as one opened in battle is, reads them, and what else it paints after the name" do
    battler = SpeciesRow.new("Onix", [:ROCK, :GROUND])
    scene = World.stub_scene(:@species => [battler], :@index => 0)
    with_types do
      draw(scene, :species, battler, FIRST + [["Onix", 256, 10], ["EV Yield: DEFENSE +1 ", 256, 288]])
      scene.instance_variable_set(:@index, 1)
      draw(scene, :species, battler, [["Onix", 256, 10], ["EV Yield: DEFENSE +1 ", 256, 288]])
    end
    assert_spoken(/\AOnix, #{list_place(1, 1)}, Rock\/Ground\. Weak: Water, Ground, Grass\. Resist: Fire\. Immune: Electric\. EV Yield: DEFENSE \+1\. USE: Jump/)
    assert_match(/Immune: Electric\. EV Yield: DEFENSE \+1\z/, SpeakCapture.log.last[0])
  end

  test "the screen's own draw and jump list reach the reader, each keeping its value, and closing clears the info key" do
    scene = TypeMatch_Scene.new(FIRST)
    with_types do
      assert_equal :drawn, scene.drawTypes(:FIRE)
      assert_spoken_once(/\AFire, #{list_place(1, 2)}\./)
      SpeakCapture.clear
      scene.picked = :FIRE
      assert_equal :FIRE, scene.pbChooseTypeFromList(:FIRE, :FIRE)
      assert_spoken_once(/\AFire, #{list_place(1, 2)}\./)
    end
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "with hints left out the key line is not said, and the info key keeps the line" do
    PokeAccess::Config.verbosity = :brief
    with_types { draw(type_scene, :type, :FIRE, FIRST) }
    assert_equal [["Fire. Weak: Water, Ground. Resist: Grass. Immune: #{t(:sum_none)}", false]], SpeakCapture.log
    assert_equal "Fire. Weak: Water, Ground. Resist: Grass. Immune: #{t(:sum_none)}", PokeAccess::Info.info_text
  end

  test "a jump list closed on the entry shown says it again, queued, and one closed on another leaves it to the draw" do
    scene = type_scene
    with_types { draw(scene, :type, :FIRE, FIRST) }
    SpeakCapture.clear
    PokeAccess::TypeMatch.jump_closed(scene, :WATER)
    assert_nothing_spoken "another entry is drawn next"
    PokeAccess::TypeMatch.jump_closed(scene, :FIRE)
    assert_equal [["Fire, #{list_place(1, 2)}. Weak: Water, Ground. Resist: Grass. Immune: #{t(:sum_none)}", false]],
                 SpeakCapture.log
  end

  test "a draw keeps its own return" do
    with_types do
      assert_equal :drawn, PokeAccess::TypeMatch.draw(type_scene, :type, :FIRE) { :drawn }
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def type_scene
    World.stub_scene(:@types => [:FIRE, :WATER], :@index => 0)
  end

  # Runs a draw that paints rows, as the screen's drawTypes and drawSpeciesTypes do.
  def draw(scene, kind, id, rows)
    PokeAccess::TypeMatch.draw(scene, kind, id) { pbDrawTextPositions(nil, rows) }
  end

  # Runs the block with the game's data as the screen reads it: GameData::Type.get and each over TYPES (Rock read
  # through get only), GameData::Species.get over SPECIES and Effectiveness over HITS against Onix; all put back after.
  def with_types
    rock = TypeRow.new(:ROCK, "Rock", [], [], [], false)
    get = GameData::Type.method(:get)
    sp_get = GameData::Species.method(:get)
    each = GameData::Type.singleton_class.method_defined?(:each, false) ? GameData::Type.method(:each) : nil
    GameData::Type.define_singleton_method(:get) { |id| id == :ROCK ? rock : TYPES.fetch(id) }
    GameData::Type.define_singleton_method(:each) { |&blk| TYPES.each_value { |ty| blk.call(ty) } }
    GameData::Species.define_singleton_method(:get) { |id| SPECIES.fetch(id) }
    prior = Object.const_defined?(:Effectiveness, false) ? Object.send(:remove_const, :Effectiveness) : nil
    Object.const_set(:Effectiveness, effectiveness)
    yield
  ensure
    GameData::Type.define_singleton_method(:get, get)
    GameData::Species.define_singleton_method(:get, sp_get)
    if each
      GameData::Type.define_singleton_method(:each, each)
    elsif GameData::Type.singleton_class.method_defined?(:each, false)
      GameData::Type.singleton_class.send(:remove_method, :each)
    end
    Object.send(:remove_const, :Effectiveness) if Object.const_defined?(:Effectiveness, false)
    Object.const_set(:Effectiveness, prior) if prior
  end

  # Effectiveness as the game's: calculate over HITS (neutral for a type not listed), its three predicates.
  def effectiveness
    m = Module.new
    m.define_singleton_method(:calculate) { |attack, *_defend| HITS.fetch(attack, 1.0) }
    m.define_singleton_method(:super_effective?) { |v| v > 1.0 }
    m.define_singleton_method(:not_very_effective?) { |v| v > 0 && v < 1.0 }
    m.define_singleton_method(:ineffective?) { |v| v == 0 }
    m
  end
end
