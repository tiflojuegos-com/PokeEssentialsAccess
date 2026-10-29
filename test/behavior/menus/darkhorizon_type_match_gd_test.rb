# Dark Horizon's Type Match-up UI (games/darkhorizon/type_match.rb): a type or a species said with its place, its
# types and each column by the title the first draw paints and the types its icons show, the first draw queued with
# the screen's key line and the next ones cutting in. Only the reader's module is evaluated: Soulstones 2's test binds
# its own chart's hooks on the same SpeciesTypeMatch_Scene in this pass.

# The profile's shared helpers (constants.rb's module), loaded once and without the profile's settings.
unless defined?(PokeAccess::DarkHorizon)
  constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
  src = Harness.source(constants)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, constants, src[0, src.index(part)].count("\n") + 1)
end

begin
  path = File.join(Harness::ROOT, "games", "darkhorizon", "type_match.rb")
  src = Harness.source(path)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, path, src[0, src.index(part)].count("\n") + 1)
end

class DarkhorizonTypeMatchGdTest < PokeAccessTest
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
    PokeAccess::DHTypeMatch.jump_closed(scene, :WATER)
    assert_nothing_spoken "another entry is drawn next"
    PokeAccess::DHTypeMatch.jump_closed(scene, :FIRE)
    assert_equal [["Fire, #{list_place(1, 2)}. Weak: Water, Ground. Resist: Grass. Immune: #{t(:sum_none)}", false]],
                 SpeakCapture.log
  end

  test "a draw keeps its own return" do
    with_types do
      assert_equal :drawn, PokeAccess::DHTypeMatch.draw(type_scene, :type, :FIRE) { :drawn }
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
    PokeAccess::DHTypeMatch.draw(scene, kind, id) { pbDrawTextPositions(nil, rows) }
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
