# Engine on the gen-6 engine: the era it tells, the ancestor scene_class takes among a fork's alias names, the names
# scene_classes keeps worth hooking, and era_scene's name, given only to the reader whose era runs.

# A screen under its ancestral name, a fork's alias of it (an empty subclass), a second name for the same class and an
# unrelated screen.
class PaSpecBase
  def redraw(n); n; end
end
class PaSpecAlias < PaSpecBase; end
PaSpecBaseTwin = PaSpecBase
class PaSpecOther; end

class SceneAliasTest < PokeAccessTest
  Engine = PokeAccess::Engine

  test "the gen-6 stubs read as the gen-6 era" do
    assert_equal [:gen6, true, false], [Engine.kind, Engine.gen6?, Engine.gamedata?]
  end

  test "a GameData module without its Species table is still the gen-6 era" do
    with_constant(:GameData, Module.new) do
      assert_equal [:gen6, true, false], [Engine.kind, Engine.gen6?, Engine.gamedata?]
    end
  end

  test "with an alias and its ancestor both present, the ancestor is the name to hook in either order" do
    { %w[PaSpecAlias PaSpecBase] => "PaSpecBase", %w[PaSpecBase PaSpecAlias] => "PaSpecBase" }.each do |names, want|
      assert_equal want, Engine.scene_class(*names), "for #{names.inspect}"
    end
  end

  test "a lone name the game has is the name to hook" do
    assert_equal "PaSpecAlias", Engine.scene_class("PaSpecNope", "PaSpecAlias")
  end

  test "with none of the names in the game there is no name to hook" do
    assert_nil Engine.scene_class("PaSpecNope", "PaSpecNeither")
  end

  test "keeps the names worth hooking, in the order asked: no subclass a listed ancestor covers, none the game lacks" do
    { %w[PaSpecBase PaSpecAlias] => %w[PaSpecBase],
      %w[PaSpecAlias PaSpecOther PaSpecBase] => %w[PaSpecOther PaSpecBase],
      %w[PaSpecNope PaSpecOther] => %w[PaSpecOther],
      %w[PaSpecNope PaSpecNeither] => [] }.each do |names, want|
      assert_equal want, Engine.scene_classes(*names), "for #{names.inspect}"
    end
  end

  test "keeps the first of two names for one class" do
    { %w[PaSpecBase PaSpecBaseTwin] => %w[PaSpecBase],
      %w[PaSpecBaseTwin PaSpecBase] => %w[PaSpecBaseTwin] }.each do |names, want|
      assert_equal want, Engine.scene_classes(*names), "for #{names.inspect}"
    end
  end

  test "a GameData reader binds nothing on the gen-6 engine, whichever names the game has" do
    [%w[PaSpecOther PaSpecNope], %w[PaSpecNope PaSpecOther], %w[PaSpecAlias PaSpecBase],
     %w[PaSpecNope PaSpecNeither]].each do |own, other|
      assert_equal "", Engine.era_scene(:gamedata, own, other), "for #{own} with #{other}"
    end
  end

  test "a gen-6 reader takes whichever single name the game has, its own or the other era's" do
    { %w[PaSpecOther PaSpecNope] => "PaSpecOther",
      %w[PaSpecNope PaSpecOther] => "PaSpecOther" }.each do |(own, other), want|
      assert_equal want, Engine.era_scene(:gen6, own, other), "for #{own} with #{other}"
    end
  end

  test "with both names in the game, the gen-6 reader takes the ancestor" do
    { %w[PaSpecAlias PaSpecBase] => "PaSpecBase",
      %w[PaSpecBase PaSpecAlias] => "PaSpecBase" }.each do |(own, other), want|
      assert_equal want, Engine.era_scene(:gen6, own, other), "for #{own} with #{other}"
    end
  end

  test "with neither name in the game, a gen-6 reader binds nothing" do
    assert_equal "", Engine.era_scene(:gen6, "PaSpecNope", "PaSpecNeither")
  end

  test "the gen-6 readers bind the gen-6 scenes the game has, the GameData readers nothing" do
    modern = [PokeAccess::SummaryV21::SCENE, PokeAccess::MoveRelearnerV21::SCENE, PokeAccess::TrainerCardV21::SCENE]
    legacy = [PokeAccess::SummaryGen6::SCENE, PokeAccess::MoveRelearnerGen6::SCENE, PokeAccess::TrainerCard::SCENE]
    assert_equal ["", "", ""], modern, "summary, relearner and trainer card of the GameData era"
    assert_equal ["PokemonSummaryScene", "", "PokemonTrainerCardScene"], legacy,
                 "the same of the gen-6 era (no relearner here)"
  end

  test "a hook on the ancestral name reads the alias's instances too" do
    heard = []
    PokeAccess::Hooks.after_hook(Engine.scene_class("PaSpecAlias", "PaSpecBase"), :redraw) { |_s, r, _a| heard.push(r) }
    PaSpecBase.new.redraw(1)
    PaSpecAlias.new.redraw(2)
    assert_equal [1, 2], heard
  end

  test "the empty name it gives binds nothing and reports nothing missing" do
    before = PokeAccess::Hooks.missing.dup
    assert_equal false, PokeAccess::Hooks.after_hook("", :whatever) { |_s, _r, _a| nil }
    assert_equal before, PokeAccess::Hooks.missing
  end

  private

  # Runs the block with Object's constant name set to value, then puts back what was there, or nothing.
  def with_constant(name, value)
    had = Object.const_defined?(name, false)
    was = Object.const_get(name) if had
    Object.send(:remove_const, name) if had
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, was) if had
  end
end
