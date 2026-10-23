# Drago2308's Quest Marker (plugins/quest_marker.rb): the locator says what a "quest_marker <picture>" comment shows
# after the event's name, as the profile's quest_markers.rb describes the picture; one it does not describe goes unsaid.
class QuestMarkerTest < PokeAccessTest
  QuestMarker = PokeAccess::QuestMarker
  Locator = PokeAccess::Locator
  # Each profile's pictures and the label each is said with.
  WORDS = {
    "realidea" => { "red" => :qm_excl_yellow, "asul" => :qm_excl_blue, "calavera1" => :qm_skull_white,
                    "calavera2" => :qm_skull_yellow, "calavera3" => :qm_skull_red },
    "awakening" => { "red" => :qm_bubble_blue, "tripletriad" => :qm_vs }
  }.freeze

  test "the marker's picture is the word after quest_marker in the page's first comment" do
    assert_equal "red", QuestMarker.picture(marked_event(1, "quest_marker red"))
  end

  test "a page that does not open with a marker comment has no picture" do
    {
      "a page opening with text" => event_with(1, [TestCmd.new(101, ["Hola"])]),
      "a first comment that is another" => event_with(2, [TestCmd.new(108, ["otra cosa"])]),
      "the marker's words shown as text" => event_with(3, [TestCmd.new(101, ["quest_marker red"])]),
      "a marker comment naming no picture" => event_with(4, [TestCmd.new(108, ["quest_marker"])]),
      "a comment with no text" => event_with(5, [TestCmd.new(108, [])]),
      "the marker comment second" => event_with(6, [TestCmd.new(101, ["Hola"]), TestCmd.new(108, ["quest_marker red"])]),
      "an empty page" => event_with(7, [])
    }.each { |what, ev| assert_nil QuestMarker.picture(ev), what }
  end

  test "without a profile describing it, a picture adds no mark to the target's name" do
    assert_equal [], Locator.name_marks(marked_event(1, "quest_marker red"))
  end

  test "Realidea's pictures are said as its exclamation marks and skulls" do
    with_profile("realidea") do
      WORDS["realidea"].each do |pic, key|
        assert_equal PokeAccess::I18n.t(key), QuestMarker.mark(marked_event(1, "quest_marker #{pic}")), pic
      end
      assert_nil QuestMarker.mark(marked_event(2, "quest_marker tripletriad")), "a picture it does not describe"
    end
  end

  test "Awakening's pictures are said as its speech bubble and VS badge" do
    with_profile("awakening") do
      WORDS["awakening"].each do |pic, key|
        assert_equal PokeAccess::I18n.t(key), QuestMarker.mark(marked_event(1, "quest_marker #{pic}")), pic
      end
      assert_nil QuestMarker.mark(marked_event(2, "quest_marker asul")), "a picture it does not describe"
    end
  end

  test "every picture both games describe has its label in the language" do
    labels = WORDS.values.map { |w| w.values }.flatten
    assert_equal [], labels.select { |k| PokeAccess::I18n.t(k) == k.to_s }
  end

  test "an event without a marker is said with no mark" do
    with_profile("realidea") do
      assert_nil QuestMarker.mark(event_with(1, [TestCmd.new(101, ["Hola"])]))
    end
  end

  test "the locator says the mark right after the event's name" do
    with_profile("realidea") do
      ev = marked_event(1, "quest_marker red")
      $game_map.events[1] = ev
      Locator.instance_variable_set(:@target, ev)
      SpeakCapture.clear
      Locator.announce_selected(true)
      mark = PokeAccess::I18n.t(:qm_excl_yellow)
      where = "2 #{PokeAccess::I18n.t(:dir_up)}"
      steps = PokeAccess::I18n.t(:loc_steps, :n => 1)
      assert_equal [["Senyorita, #{mark}, #{where}, #{steps}", true]], SpeakCapture.log
    end
  end

  private

  # An event at (5, 3) whose live page opens with the comment given and goes on with another.
  def marked_event(id, comment)
    event_with(id, [TestCmd.new(108, [comment]), TestCmd.new(108, ["255"])])
  end

  # An event at (5, 3) named Senyorita whose live page runs list.
  def event_with(id, list)
    TestGameEvent.new(:id => id, :name => "Senyorita", :x => 5, :y => 3,
                      :pages => [TestPage.new(:trigger => 0, :sprite => "BW040", :list => list)])
  end

  # Runs the block with game's quest_markers.rb evaluated as the loader does, the original word, the overrides listed,
  # the profiles defined and the profile's name put back after.
  def with_profile(game)
    word = QuestMarker.method(:word)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    name = PokeAccess::Game.instance_variable_get(:@profile_name)
    path = File.join(Harness::ROOT, "games", game, "quest_markers.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    QuestMarker.define_singleton_method(:word, word)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, name)
  end
end
