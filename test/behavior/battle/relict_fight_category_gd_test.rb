# Relict's fight menu draws a move's category icon from display_category alone (its branch that works Shell Side Arm
# and Photon Geyser out against the foe is commented out), so its profile's line says that category, not the core's.
class RelictFightCategoryGdTest < PokeAccessTest
  # Relict's line, loaded once from its profile and kept apart (with_relict puts it in); the core's stays in place for
  # the other tests of the process.
  META = (class << PokeAccess::BattleScene; self; end)
  CORE = META.instance_method(:fight_category)
  PATH = File.join(Harness::ROOT, "games", "relict", "fight_category.rb")
  eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  RELICT = META.instance_method(:fight_category)
  META.send(:define_method, :fight_category, CORE)

  # Photon Geyser as the fight menu holds it: display_category answers drawn (raised when an exception), its stored
  # category is own, and worked out against the foe on a copy (pbOnStartUse) it comes out physical.
  Geyser = Struct.new(:drawn, :own) do
    def function_code; "CategoryDependsOnHigherDamageIgnoreTargetAbility"; end
    def display_category(_battler); drawn.is_a?(Exception) ? raise(drawn) : drawn; end
    def category; own; end
    def pbOnStartUse(_user, _targets); @calc = 0; end
    def calcCategory; @calc; end
  end

  # A move with no display_category, known by its stored category alone.
  Plain = Struct.new(:category)

  # The user in the fight menu, with no foe ahead of it.
  Battler = Struct.new(:pbDirectOpposing)

  test "without Relict's line, the core works a foe-dependent move out against the foe" do
    assert_equal 0, PokeAccess::BattleScene.fight_category(Geyser.new(1, 2), Battler.new(nil))
  end

  test "says the category display_category gives for the user, the one its icon draws" do
    with_relict do
      assert_equal 1, PokeAccess::BattleScene.fight_category(Geyser.new(1, 2), Battler.new(nil))
    end
  end

  test "answers as the core does where display_category gives no number" do
    cases = { "a move without it" => [Plain.new(2), 2], "a nil" => [Geyser.new(nil, 2), 0],
              "a symbol" => [Geyser.new(:special, 2), 0], "a raise" => [Geyser.new(RuntimeError.new("no"), 2), 0] }
    with_relict do
      cases.each do |what, (move, want)|
        assert_equal want, PokeAccess::BattleScene.fight_category(move, Battler.new(nil)), "for #{what}"
      end
    end
  end

  test "with no user to draw it for, answers the stored category as the core does" do
    with_relict do
      assert_equal 2, PokeAccess::BattleScene.fight_category(Geyser.new(1, 2), nil)
    end
  end

  private

  # Runs the block with Relict's line in place of the core's, which is put back after.
  def with_relict
    META.send(:define_method, :fight_category, RELICT)
    yield
  ensure
    META.send(:define_method, :fight_category, CORE)
  end
end
