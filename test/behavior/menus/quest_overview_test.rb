# The Modern Quest System's journal (plugins/quest_ui.rb): its rows, its tab, a quest's two pages and Soulstones 2's
# two edits to them; also the row of Marin's favours list (plugins/easy_questing.rb).

# The journal's list, keeping its quests as the plugin's Window_Quest does.
class Window_Quest < Window_DrawableCommand
  attr_accessor :quests
  def initialize(quests = []); super(); @quests = quests; end
end

# The journal as the plugin's scene runs it: pbStartScene paints the tab's heading and fades in, updating the list
# (pbFadeInAndShow { pbUpdate }); swapQuestType puts another tab up, the cursor back on top and its heading painted;
# pbQuest shows a quest from its first page and goes back to the list; the draw methods paint the two pages.
class QuestList_Scene
  attr_accessor :current_quest
  def initialize(active, completed = [])
    @quests = [active, completed]
    @quests_text = ["Active", "Completed"]
    @current_quest = 0
    @sprites = { "itemlist" => Window_Quest.new(active) }
  end

  def list; @sprites["itemlist"]; end

  def pbStartScene
    pbDrawTextPositions(nil, [["Active tasks", 6, -2]])
    list.update
    :started
  end

  def swapQuestType
    list.index = 0
    list.quests = @quests[@current_quest]
    pbDrawTextPositions(nil, [["#{@quests_text[@current_quest]} tasks", 6, 6]])
  end

  def pbQuest(quest)
    quest.new = false
    drawQuestDesc(quest)
    list.refresh
  end

  def drawQuestDesc(_quest); nil; end
  def drawOtherInfo(_quest); nil; end
end

# The plugin evaluated once more over the classes above, as boot does in a game that has them, so its hooks bind.
begin
  verbose = $VERBOSE
  $VERBOSE = nil
  quest_ui = File.join(Harness::ROOT, "plugins", "quest_ui.rb")
  eval(Harness.source(quest_ui), TOPLEVEL_BINDING, quest_ui)
ensure
  $VERBOSE = verbose
end

class QuestOverviewTest < PokeAccessTest
  UI = PokeAccess::QuestUI
  SS2_PROFILE = File.join(Harness::ROOT, "games", "soulstones2", "quests.rb")
  OWN_FORMS = [:overview, :new_badge?].map { |m| [m, UI.method(m)] }
  SS2_FORMS = []
  STAMP = Time.local(2025, 9, 3, 14, 20)
  PAINTED_STAMP = "September 03 2025 14:20"

  Quest = Struct.new(:id, :stage, :location, :time, :story, :new)

  # The plugin's own getters, as the reader calls them with a quest's id.
  class PluginData
    def getName(id); "Mision #{id}"; end
    def getQuestDescription(id); "Resumen de #{id}"; end
    def getStageDescription(id, stage); "Paso #{stage} de #{id}"; end
    def getStageLocation(_id, _stage); "Pueblo Raiz"; end
    def getMaxStagesForQuest(_id); 3; end
    def getQuestGiver(_id); "Abuela Rosa"; end
    def getQuestReward(_id); "Pocion x3"; end
  end

  # Soulstones 2's edited copy: the same getters but an overview per stage.
  class EditedData < PluginData
    def getQuestDescription(id, stage); "Resumen de #{id} en el paso #{stage}"; end
  end

  test "a quest's first page says its name, then its overview, task and place after their labels" do
    with_quest_data(PluginData.new) { journal.drawQuestDesc(quest(:Q1, 2)) }
    assert_equal [[page("Mision Q1", "Resumen de Q1", "Paso 2 de Q1", "Pueblo Raiz"), true]], SpeakCapture.log
  end

  test "Soulstones 2's overview follows the stage the quest is at" do
    with_soulstones2 do
      with_quest_data(EditedData.new) { journal.drawQuestDesc(quest(:Q1, 3)) }
    end
    assert_equal [[page("Mision Q1", "Resumen de Q1 en el paso 3", "Paso 3 de Q1", "Pueblo Raiz"), true]],
                 SpeakCapture.log
  end

  test "a blank overview or task leaves its label unsaid, and a blank place is said as unknown" do
    blank = Class.new(PluginData) do
      def getQuestDescription(_id); ""; end
      def getStageDescription(_id, _stage); "nil"; end
      def getStageLocation(_id, _stage); "nil"; end
    end
    with_quest_data(blank.new) { journal.drawQuestDesc(quest(:Q1, 1)) }
    assert_equal [["Mision Q1. #{t(:quest_location, :text => t(:quest_unset))}", true]], SpeakCapture.log
  end

  test "a quest the journal cannot name, or one with no id, says nothing" do
    nameless = Class.new(PluginData) { def getName(_id); ""; end }
    { "nameless" => [nameless.new, quest(:Q1, 1)], "without an id" => [PluginData.new, quest(nil, 1)] }.each do |what, (data, q)|
      with_quest_data(data) { journal.drawQuestDesc(q) }
      assert_nothing_spoken "for a quest #{what}"
    end
  end

  test "the second page of a quest under way says its stage, giver, where it began, when it started, and hides its reward" do
    with_quest_data(PluginData.new) do
      with_quest_lists([:Q1], []) { journal.drawOtherInfo(quest(:Q1, 2, "Ruta 1", STAMP)) }
    end
    lines = [t(:quest_stage, :n => 2, :tot => 3), t(:quest_giver, :who => "Abuela Rosa"),
             t(:quest_where, :where => "Ruta 1"), t(:quest_time_start, :when => PAINTED_STAMP),
             t(:quest_reward, :what => t(:quest_hidden))]
    assert_equal [[["Mision Q1", *lines].join(". "), true]], SpeakCapture.log
  end

  test "the second page of a completed quest says when it was completed, and its reward" do
    with_quest_data(PluginData.new) do
      with_quest_lists([], [:Q1]) { journal.drawOtherInfo(quest(:Q1, 3, "Ruta 1", STAMP)) }
    end
    lines = [t(:quest_stage, :n => 3, :tot => 3), t(:quest_giver, :who => "Abuela Rosa"),
             t(:quest_where, :where => "Ruta 1"), t(:quest_time_done, :when => PAINTED_STAMP),
             t(:quest_reward, :what => "Pocion x3")]
    assert_equal [[["Mision Q1", *lines].join(". "), true]], SpeakCapture.log
  end

  test "the second page of a quest neither under way nor completed says when it failed" do
    with_quest_data(PluginData.new) do
      with_quest_lists([], []) { journal.drawOtherInfo(quest(:Q1, 1, "Ruta 1", STAMP)) }
    end
    lines = [t(:quest_stage, :n => 1, :tot => 3), t(:quest_giver, :who => "Abuela Rosa"),
             t(:quest_where, :where => "Ruta 1"), t(:quest_time_failed, :when => PAINTED_STAMP),
             t(:quest_reward, :what => "Pocion x3")]
    assert_equal [[["Mision Q1", *lines].join(". "), true]], SpeakCapture.log
  end

  test "the second page of a quest the game cannot list says when it failed, and its reward" do
    failing = lambda { raise NoMethodError, "sin misiones" }
    with_quest_data(PluginData.new) do
      GameFunctions.with(:getActiveQuests => failing, :getCompletedQuests => failing) do
        journal.drawOtherInfo(quest(:Q1, 1, "Ruta 1", STAMP))
      end
    end
    lines = [t(:quest_stage, :n => 1, :tot => 3), t(:quest_giver, :who => "Abuela Rosa"),
             t(:quest_where, :where => "Ruta 1"), t(:quest_time_failed, :when => PAINTED_STAMP),
             t(:quest_reward, :what => "Pocion x3")]
    assert_equal [[["Mision Q1", *lines].join(". "), true]], SpeakCapture.log
  end

  test "the second page says unknown for an unset giver or place, hides an unset reward and leaves out what it lacks" do
    unset = Class.new(PluginData) do
      def getMaxStagesForQuest(_id); nil; end
      def getQuestGiver(_id); "nil"; end
      def getQuestReward(_id); "nil"; end
    end
    with_quest_data(unset.new) do
      with_quest_lists([], [:Q1]) { journal.drawOtherInfo(quest(:Q1, 2, "", nil)) }
    end
    lines = [t(:quest_giver, :who => t(:quest_unset)), t(:quest_where, :where => t(:quest_unset)),
             t(:quest_reward, :what => t(:quest_hidden))]
    assert_equal [[["Mision Q1", *lines].join(". "), true]], SpeakCapture.log
  end

  test "a new quest's row carries the badge from medium" do
    rows = with_quest_data(PluginData.new) { vb_levels { UI.text(list_of(quest(:Q1, 1, nil, nil, false, true)), 0) } }
    assert_equal ["Mision Q1", "Mision Q1, #{t(:quest_new)}", "Mision Q1, #{t(:quest_new)}"], rows
  end

  test "a story quest's row says it is the main story from medium" do
    rows = with_quest_data(PluginData.new) { vb_levels { UI.text(list_of(quest(:Q1, 1, nil, nil, true, false)), 0) } }
    assert_equal ["Mision Q1", "Mision Q1, #{t(:quest_story)}", "Mision Q1, #{t(:quest_story)}"], rows
  end

  test "a quest kept without the story and new flags carries neither mark" do
    bare = Struct.new(:id).new(:Q1)
    assert_equal "Mision Q1", with_quest_data(PluginData.new) { UI.text(list_of(bare), 0) }
  end

  test "at brief the info key keeps the row whole" do
    PokeAccess::Config.verbosity = :brief
    with_quest_data(PluginData.new) { UI.text(list_of(quest(:Q1, 1, nil, nil, true, true)), 0) }
    assert_equal "Mision Q1, #{t(:quest_story)}, #{t(:quest_new)}", PokeAccess::Info.info_text
  end

  test "Soulstones 2 draws the badge only on a new quest still under way" do
    { [[:Q1], true] => "Mision Q1", [[], true] => "Mision Q1, #{t(:quest_new)}",
      [[], false] => "Mision Q1" }.each do |(completed, fresh), row|
      said = with_soulstones2 do
        with_quest_data(PluginData.new) do
          with_quest_lists([], completed) { UI.text(list_of(quest(:Q1, 1, nil, nil, false, fresh)), 0) }
        end
      end
      assert_equal row, said, "new: #{fresh}, completed: #{completed.inspect}"
    end
  end

  test "Soulstones 2 keeps the plugin's badge where the game cannot list its completed quests" do
    said = with_soulstones2 do
      with_quest_data(PluginData.new) do
        GameFunctions.with(:getCompletedQuests => lambda { raise NoMethodError, "sin misiones" }) do
          UI.text(list_of(quest(:Q1, 1, nil, nil, false, true)), 0)
        end
      end
    end
    assert_equal "Mision Q1, #{t(:quest_new)}", said
  end

  test "a row past the list's quests, an empty one or a quest the journal cannot name says nothing" do
    with_quest_data(PluginData.new) do
      { "past the end" => [list_of(quest(:Q1, 1)), 1], "before the start" => [list_of(quest(:Q1, 1)), -1],
        "empty" => [list_of(nil), 0], "of no list" => [Window_Quest.new(nil), 0] }.each do |what, (win, i)|
        assert_nil UI.text(win, i), "for a row #{what}"
      end
    end
    [nil, ""].each do |name|
      nameless = Class.new(PluginData) { define_method(:getName) { |_id| name } }
      assert_nil with_quest_data(nameless.new) { UI.text(list_of(quest(:Q1, 1)), 0) }, "for a quest named #{name.inspect}"
    end
  end

  test "the tab is said as its heading paints it, or by its name where no heading holds it" do
    scene = World.stub_scene(:@quests_text => ["Active", "Completed", "Expired"], :@current_quest => 2)
    { [["Expired tasks", :positions, 6, -2]] => "Expired tasks", [["Pokedex", :positions, 6, -2]] => "Expired",
      [] => "Expired" }.each do |pairs, said|
      UI.category(scene, pairs)
      assert_equal [[said, true]], SpeakCapture.log, "with #{pairs.inspect} painted"
      SpeakCapture.clear
    end
  end

  test "a tab with no name, or none at the journal's index, says nothing" do
    { "a blank name" => ["Active", ""], "no tab there" => ["Active"] }.each do |what, names|
      UI.category(World.stub_scene(:@quests_text => names, :@current_quest => 1), [])
      assert_nothing_spoken "for #{what}"
    end
  end

  test "the journal opens with its tab's heading, then its first quest" do
    with_quest_data(PluginData.new) do
      scene = journal
      assert_equal :started, scene.pbStartScene, "the opening keeps its result"
      assert_equal [["Active tasks", true]], SpeakCapture.log, "the heading as painted; the list quiet while it fades in"
      SpeakCapture.clear
      scene.list.update
      assert_equal ["Mision Q1"], SpeakCapture.lines, "then the first quest, on the list's own update"
    end
  end

  test "a tab change says the new tab's heading, then its first quest queued behind it" do
    with_quest_data(PluginData.new) do
      scene = journal
      scene.pbStartScene
      scene.list.update
      SpeakCapture.clear
      scene.current_quest = 1
      scene.swapQuestType
      scene.list.update
    end
    assert_equal [["Completed tasks", true], ["Mision Q9", false]], SpeakCapture.log
  end

  test "back from a quest's pages, the list says its row again" do
    with_quest_data(PluginData.new) do
      scene = journal
      scene.pbStartScene
      scene.list.update
      scene.pbQuest(scene.list.quests[0])
      SpeakCapture.clear
      scene.list.update
    end
    assert_equal ["Mision Q1"], SpeakCapture.lines
  end

  test "a row of the favours list says the quest's name, and its state from medium" do
    { true => :qu_status_done, false => :qu_status_pending }.each do |done, state|
      row = Struct.new(:name, :completed).new("Busca el gato", done)
      said = "Busca el gato, #{t(state)}"
      assert_equal ["Busca el gato", said, said], vb_levels { PokeAccess::Quests.quest_row(row) }, "completed: #{done}"
    end
  end

  test "a favours-list quest with no name says nothing at any level" do
    [nil, ""].each do |name|
      row = Struct.new(:name, :completed).new(name, false)
      assert_equal [nil, nil, nil], vb_levels { PokeAccess::Quests.quest_row(row) }, "for #{name.inspect}"
    end
  end

  test "a favours-list quest kept without a completed flag is said as pending" do
    row = Struct.new(:name).new("Busca el gato")
    said = "Busca el gato, #{t(:qu_status_pending)}"
    assert_equal ["Busca el gato", said, said], vb_levels { PokeAccess::Quests.quest_row(row) }
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def quest(id, stage, location = nil, time = nil, story = false, fresh = false)
    Quest.new(id, stage, location, time, story, fresh)
  end

  # Page one as the reader says it: the name, then the overview, the task and the place after their labels.
  def page(name, overview, task, place)
    [name, t(:quest_overview, :text => overview), t(:quest_task, :text => task), t(:quest_location, :text => place)].join(". ")
  end

  # The journal on its active tab, Q1 and Q2 under way and Q9 completed.
  def journal
    QuestList_Scene.new([quest(:Q1, 1), quest(:Q2, 1)], [quest(:Q9, 3)])
  end

  # The journal's list holding one quest.
  def list_of(q)
    Window_Quest.new([q])
  end

  # The block's value with $quest_data set to data, put back after.
  def with_quest_data(data)
    had = $quest_data
    $quest_data = data
    yield
  ensure
    $quest_data = had
  end

  # The block's value with the game's getActiveQuests and getCompletedQuests answering those ids.
  def with_quest_lists(active, completed, &blk)
    GameFunctions.with(:getActiveQuests => lambda { active }, :getCompletedQuests => lambda { completed }, &blk)
  end

  # The block's value with Soulstones 2's two edits in place of the plugin's forms, put back after.
  def with_soulstones2
    soulstones2_forms.each { |m, f| UI.define_singleton_method(m, f) }
    yield
  ensure
    OWN_FORMS.each { |m, f| UI.define_singleton_method(m, f) }
  end

  # The forms Soulstones 2's profile leaves, its file evaluated once over the plugin's own as boot does; the overrides
  # listed and the profiles declared are put back.
  def soulstones2_forms
    return SS2_FORMS unless SS2_FORMS.empty?
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    begin
      OWN_FORMS.each { |m, f| UI.define_singleton_method(m, f) }
      eval(Harness.source(SS2_PROFILE), TOPLEVEL_BINDING, SS2_PROFILE)
      SS2_FORMS.concat(OWN_FORMS.map { |m, _f| [m, UI.method(m)] })
    ensure
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
    end
  end
end
