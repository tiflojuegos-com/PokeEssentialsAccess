# Infinite Fusion's quest log (games/infinitefusion/quest_branches.rb): each quest keeps its branch, the colour its name
# is painted in, where Marin's plugin keeps a giver ("Hotel Quests"), and its row says it from medium.
class IfQuestBranchesGdTest < PokeAccessTest
  QUESTS = PokeAccess::Quests.singleton_class
  PATH = File.join(Harness::ROOT, "games", "infinitefusion", "quest_branches.rb")
  Quest = Struct.new(:name, :npc, :completed)

  # Evaluates the profile file once, as boot does, and answers its quest_row; the core's is put back for the other
  # tests of the process (with_branches puts the profile's in).
  def self.load_profile
    core = QUESTS.instance_method(:quest_row)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      QUESTS.instance_method(:quest_row)
    ensure
      QUESTS.send(:define_method, :quest_row, core)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  CORE_QUEST_ROW = QUESTS.instance_method(:quest_row)
  IF_QUEST_ROW = load_profile

  test "a quest's row says its branch from medium, between its name and its status" do
    quest = Quest.new("Mushroom Gathering", "Hotel Quests", false)
    rows = with_branches { vb_levels { PokeAccess::Quests.quest_row(quest) } }
    whole = "Mushroom Gathering, Hotel Quests, #{PokeAccess::I18n.t(:qu_status_pending)}"
    assert_equal ["Mushroom Gathering", whole, whole], rows
  end

  test "a quest's status follows whether it is completed, a quest with no such flag counting as not" do
    done = PokeAccess::I18n.t(:qu_status_done)
    pending = PokeAccess::I18n.t(:qu_status_pending)
    { Quest.new("Lost Medicine", "Field Quests", true) => done,
      Quest.new("Lost Medicine", "Field Quests", false) => pending,
      Struct.new(:name, :npc).new("Lost Medicine", "Field Quests") => pending }.each do |quest, status|
      assert_equal "Lost Medicine, Field Quests, #{status}", row(quest), quest.inspect
    end
  end

  test "a quest with no branch reads as the core's row" do
    [nil, ""].each do |npc|
      quest = Quest.new("Lost Medicine", npc, false)
      assert_equal PokeAccess::Quests.quest_row(quest), row(quest), npc.inspect
    end
  end

  test "a quest with no name reads nothing, whatever its branch" do
    [nil, ""].each { |name| assert_nil row(Quest.new(name, "Hotel Quests", false)), name.inspect }
  end

  private

  # A quest's row as the profile reads it.
  def row(quest)
    with_branches { PokeAccess::Quests.quest_row(quest) }
  end

  # Runs the block with the profile's quest_row in place of the core's, put back afterwards.
  def with_branches
    QUESTS.send(:define_method, :quest_row, IF_QUEST_ROW)
    yield
  ensure
    QUESTS.send(:define_method, :quest_row, CORE_QUEST_ROW)
  end
end
