# The quest journal's detail page (Modern Quest System) opens with the overview; Soulstones 2's copy takes the stage
# too, getQuestDescription(quest, stage).

QuestOverviewQuest = Struct.new(:id, :stage)

# The plugin's own getters, as the shared reader calls them.
class QuestOverviewPluginData
  def getName(id); "Mision #{id}"; end
  def getQuestDescription(id); "Resumen de #{id}"; end
  def getStageDescription(id, stage); "Paso #{stage} de #{id}"; end
  def getStageLocation(_id, _stage); "Pueblo Raiz"; end
end

# Soulstones 2's edited copy: the same getters but an overview per stage.
class QuestOverviewEditedData < QuestOverviewPluginData
  def getQuestDescription(id, stage); "Resumen de #{id} en el paso #{stage}"; end
end

Suite.define("quests: the detail page opens with the plugin's overview") do
  $quest_data = QuestOverviewPluginData.new
  PokeAccess::QuestUI.detail(QuestOverviewQuest.new(:Q1, 2), :description)
  eq "name, overview, stage and place, in the page's order, each after its painted label", SpeakCapture.lines,
     [QuestSpec.page("Mision Q1", "Resumen de Q1", "Paso 2 de Q1", "Pueblo Raiz")]
end

# Soulstones 2's profile redefines two of the reader's methods: loaded once, its forms put in place for a suite and
# the plugin's put back after it.
module QuestSpec
  PLUGIN = { :overview => PokeAccess::QuestUI.method(:overview), :new_badge? => PokeAccess::QuestUI.method(:new_badge?) }

  # Page one as the reader says it: the name, then the overview, the task and the location after their labels.
  def self.page(name, overview, task, place)
    t = PokeAccess::I18n
    [name, t.t(:quest_overview, :text => overview), t.t(:quest_task, :text => task),
     t.t(:quest_location, :text => place)].join(". ")
  end

  def self.with_ss2
    unless @ss2
      load File.expand_path("../../../games/soulstones2/quests.rb", File.dirname(__FILE__))
      @ss2 = { :overview => PokeAccess::QuestUI.method(:overview), :new_badge? => PokeAccess::QuestUI.method(:new_badge?) }
    end
    @ss2.each { |m, f| PokeAccess::QuestUI.define_singleton_method(m, f) }
    yield
  ensure
    PLUGIN.each { |m, f| PokeAccess::QuestUI.define_singleton_method(m, f) }
  end
end

Suite.define("quests: Soulstones 2's overview follows the stage it is at") do
  QuestSpec.with_ss2 do
    begin
      $quest_data = QuestOverviewEditedData.new
      PokeAccess::QuestUI.detail(QuestOverviewQuest.new(:Q1, 3), :description)
      eq "the edited overview is read for the current stage", SpeakCapture.lines,
         [QuestSpec.page("Mision Q1", "Resumen de Q1 en el paso 3", "Paso 3 de Q1", "Pueblo Raiz")]
    ensure
      $quest_data = nil
    end
  end
end

# The "new" badge is an icon the row draws on the quest's own flag, and Soulstones 2's copy leaves it off the
# quests already completed.
Suite.define("quests: the new badge is said where the row draws it") do
  $quest_data = QuestOverviewPluginData.new
  begin
    q = Struct.new(:id, :story, :new).new(:Q1, false, true)
    win = World.stub_scene(:@quests => [q])
    eq "the quest's own flag", PokeAccess::QuestUI.text(win, 0), "Mision Q1, #{PokeAccess::I18n.t(:quest_new)}"
    PokeAccess::Config.verbosity = :brief
    eq "brief: the quest's name without its badge", PokeAccess::QuestUI.text(win, 0), "Mision Q1"
    eq "and the info key keeps the badge", PokeAccess::Info.info_text, "Mision Q1, #{PokeAccess::I18n.t(:quest_new)}"
    PokeAccess::Config.verbosity = :full
    QuestSpec.with_ss2 do
      Object.send(:define_method, :getCompletedQuests) { [:Q1] }
      eq "Soulstones 2 draws no badge on a completed quest", PokeAccess::QuestUI.text(win, 0), "Mision Q1"
      Object.send(:define_method, :getCompletedQuests) { [] }
      eq "and still does on one under way", PokeAccess::QuestUI.text(win, 0), "Mision Q1, #{PokeAccess::I18n.t(:quest_new)}"
    end
  ensure
    Object.send(:remove_method, :getCompletedQuests) rescue nil
    $quest_data = nil
  end
end

# Every suite of this file leaves the reader as the plugin has it.
Suite.define("quests: the plugin's own forms are back after the Soulstones 2 suites") do
  $quest_data = QuestOverviewPluginData.new
  begin
    PokeAccess::QuestUI.detail(QuestOverviewQuest.new(:Q1, 2), :description)
    eq "the plugin's overview again", SpeakCapture.lines,
       [QuestSpec.page("Mision Q1", "Resumen de Q1", "Paso 2 de Q1", "Pueblo Raiz")]
  ensure
    $quest_data = nil
  end
end

Suite.define("quests: a row of the favours list says its state from medium") do
  q = Struct.new(:name, :completed).new("Busca el gato", true)
  rows = vb_levels { PokeAccess::Quests.quest_row(q) }
  eq "brief: the name", rows[0], "Busca el gato"
  eq "medium: and whether it is done", rows[1], "Busca el gato, #{PokeAccess::I18n.t(:qu_status_done)}"
end

# The second page labels the quest's time by its state (drawOtherInfo): start for an active quest, completion for a
# completed one, failure for any other.
Suite.define("quests: the second page's time says whether it is when the quest started, ended or failed") do
  t = PokeAccess::I18n
  q = Struct.new(:id, :stage, :location, :time).new(:Q1, 2, "Ruta 1", Time.local(2025, 9, 3, 14, 20))
  at = "September 03 2025 14:20"
  $quest_data = QuestOverviewPluginData.new
  begin
    Object.send(:define_method, :getActiveQuests) { [:Q1] }
    Object.send(:define_method, :getCompletedQuests) { [] }
    lines = PokeAccess::QuestUI.other_lines(q, :Q1)
    truthy "an active quest's time is when it started", lines.include?(t.t(:quest_time_start, :when => at))
    Object.send(:define_method, :getActiveQuests) { [] }
    Object.send(:define_method, :getCompletedQuests) { [:Q1] }
    lines = PokeAccess::QuestUI.other_lines(q, :Q1)
    truthy "a completed one's, when it was completed", lines.include?(t.t(:quest_time_done, :when => at))
    Object.send(:define_method, :getCompletedQuests) { [] }
    lines = PokeAccess::QuestUI.other_lines(q, :Q1)
    truthy "and any other's, when it failed", lines.include?(t.t(:quest_time_failed, :when => at))
  ensure
    Object.send(:remove_method, :getActiveQuests) rescue nil
    Object.send(:remove_method, :getCompletedQuests) rescue nil
    $quest_data = nil
  end
end

# The tab's heading is painted to a bitmap as "{1} tasks": the reader says the painted row that holds the tab's name.
Suite.define("quests: the tab is said as its heading paints it") do
  scene = World.stub_scene(:@quests_text => ["Active", "Completed", "Expired"], :@current_quest => 2)
  SpeakCapture.clear
  PokeAccess::QuestUI.category(scene, [["Expired tasks", :positions, 6, -2]])
  eq "the painted heading", SpeakCapture.lines, ["Expired tasks"]
  SpeakCapture.clear
  PokeAccess::QuestUI.category(scene, [])
  eq "the tab's name where no heading holding it was painted", SpeakCapture.lines, ["Expired"]
end

Suite.define("quests: a blank overview or task leaves its label unsaid, a blank location is said as unknown") do
  blank = Class.new(QuestOverviewPluginData) do
    def getQuestDescription(_id); ""; end
    def getStageDescription(_id, _stage); "nil"; end
    def getStageLocation(_id, _stage); "nil"; end
  end
  $quest_data = blank.new
  begin
    SpeakCapture.clear
    PokeAccess::QuestUI.detail(QuestOverviewQuest.new(:Q1, 1), :description)
    eq "the name and the location's unknown", SpeakCapture.lines,
       [["Mision Q1", PokeAccess::I18n.t(:quest_location, :text => PokeAccess::I18n.t(:quest_unset))].join(". ")]
  ensure
    $quest_data = nil
  end
end

# The journal's opening, as the plugin's pbStartScene runs it: the tab's heading painted, then the fade-in
# (pbFadeInAndShow { pbUpdate }) updating the list inside. Defined here, the plugin evaluated once more over it.
class Window_Quest < Window_DrawableCommand
  def initialize(quests = []); super(); @quests = quests; end
end

class QuestList_Scene
  def initialize(quests); @quests_text = ["Active", "Completed"]; @current_quest = 0; @list = Window_Quest.new(quests); end
  def pbStartScene
    pbDrawTextPositions(nil, [["Active tasks", 6, -2]])
    @list.update
    :started
  end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.expand_path("../../../plugins/quest_ui.rb", File.dirname(__FILE__))
ensure
  $VERBOSE = verbose
end

Suite.define("quests: the journal opens with its tab's heading, then its first quest") do
  $quest_data = QuestOverviewPluginData.new
  begin
    scene = QuestList_Scene.new([QuestOverviewQuest.new(:Q1, 1), QuestOverviewQuest.new(:Q2, 1)])
    SpeakCapture.clear
    eq "the opening keeps its result", scene.pbStartScene, :started
    eq "the heading as painted, interrupting; the list quiet while the journal fades in", SpeakCapture.log,
       [["Active tasks", true]]
    SpeakCapture.clear
    scene.instance_variable_get(:@list).update
    eq "then the first quest, on the list's own update", SpeakCapture.lines, ["Mision Q1"]
  ensure
    $quest_data = nil
  end
end
