# Original IF map449 has two wide confirmation strips before Erika commits to the other passage.
# Only the representative active choices are targets; the game's interpreter still makes the choice.
class InfiniteFusionForkTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion", "sewers_fork.rb")

  def self.load_adapter
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH) if File.file?(PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles) if profiles
  end
  load_adapter

  def setup
    super
    Harness.load_puzzles("infinitefusion")
    $game_map.map_id = 449
    $game_map.width = 24
    $game_map.height = 20
    World.clear_events
    @right = choice(9, 14)
    choice(10, 15)
    @left = choice(11, 6)
    choice(12, 5)
  end

  test "both passages are named in puzzles and respect the Everything provider with either assist setting" do
    [false, true].each do |assist|
      PokeAccess::Config.puzzle_assist = assist
      assert_equal [[6, 6, t(:if_sewers_left_passage)], [14, 6, t(:if_sewers_right_passage)]], passages.sort_by(&:x).map { |p| [p.x, p.y, p.name] }
      listed = PokeAccess::Locator.candidates(:all).select { |target| passages.include?(target) }
      if PokeAccess::Locator.respond_to?(:everything_targets)
        assert_equal passages, listed
      else
        assert_empty listed, "upstream Everything lacks the puzzle provider until PR21"
      end
    end
  end

  test "passage goals are the actual confirmation strip and keep ordinary route planning" do
    assert_equal 2, passages.length
    passages.each do |target|
      assert_equal [[target.x, target.y]], PokeAccess::Locator.goal_of(target).tiles
      plan = PokeAccess::Locator.route_plan(target)
      assert_equal :walk, plan.kind
      assert_operator plan.route.length, :>, 0
    end
  end

  test "only the two representative choices use the existing object cue" do
    assert_equal :object, PokeAccess::Sound::Scene.family_of(@left)
    assert_equal :object, PokeAccess::Sound::Scene.family_of(@right)
    [10, 12].each { |id| assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[id]) }
  end

  test "the completed empty choice page has no marker or cue" do
    [9, 10, 11, 12].each do |id|
      page = TestPage.new(:list => [TestCmd.new(0, [])])
      old = $game_map.events[id]
      $game_map.events[id] = TestGameEvent.new(:id => id, :x => old.x, :y => old.y, :pages => [page])
    end
    World.next_frame
    assert_empty passages
    assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[9])
    assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[11])
  end

  test "another map and an unrelated active page do not get passage markers" do
    $game_map.map_id = 448
    PokeAccess::World::Mechanics.forget
    World.next_frame
    assert_empty passages
    assert_nil PokeAccess::Sound::Scene.family_of(@left)
    $game_map.map_id = 449
    choice(9, 14, [TestCmd.new(101, ["Unrelated scene."])])
    choice(11, 6, [TestCmd.new(101, ["Unrelated scene."])])
    PokeAccess::World::Mechanics.forget
    World.next_frame
    assert_empty passages
    assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[9])
  end

  private

  def t(key); PokeAccess::I18n.t(key); end

  # The original active confirmation page has choices and writes switch147 only inside the accepted branch.
  def choice(id, x, commands = nil)
    commands ||= [TestCmd.new(101, ["You are going that way?"]), TestCmd.new(102, [["Yes", "No"], 2]),
                  TestCmd.new(402, [0, "Yes"]), TestCmd.new(121, [147, 147, 0], 1), TestCmd.new(404)]
    page = TestPage.new(:trigger => 1, :list => commands)
    event = TestGameEvent.new(:id => id, :x => x, :y => 6, :pages => [page])
    $game_map.events[id] = event
    World.next_frame
    event
  end

  # Only the explicitly labelled passage targets, separate from any existing automatic puzzle targets.
  def passages
    PokeAccess::Puzzles.category_targets.select { |target| [t(:if_sewers_left_passage), t(:if_sewers_right_passage)].include?(target.name) }
  end
end
