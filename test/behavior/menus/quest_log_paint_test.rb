# Marin's quest log (plugins/easy_questing.rb) said in the words its copy paints (the stub paints as Africanvs's):
# counts, empty lists and statuses, the mod's own words only where nothing usable was painted while the log was open.
class QuestLogPaintTest < PokeAccessTest
  Quest = Struct.new(:name, :desc, :npc, :location, :completed)

  NAME = "Derrota a la Unión".freeze
  DESC = "Busca sus guaridas".freeze

  test "on opening says the active count as the cover paints it" do
    run_log([])
    assert_equal [["Activas: 1", true]], SpeakCapture.log
  end

  test "moving to the other category says its count as the cover paints it" do
    run_log([[:pbSwitch, :DOWN]])
    assert_equal ["Activas: 1", "Completas: 0"], SpeakCapture.lines
  end

  test "says an empty list's message as painted, not its title" do
    run_log([[:pbSwitch, :DOWN], [:pbList, 1]])
    assert_equal ["Activas: 1", "Completas: 0", "No has completado ninguna misión"], SpeakCapture.lines
  end

  test "back on the cover says each count in the words the cover paints it again" do
    run_log([[:pbSwitch, :DOWN], [:pbList, 1], [:pbMain], [:pbSwitch, :UP]])
    assert_equal ["Activas: 1", "Completas: 0", "No has completado ninguna misión", "Completadas: 0", "Activas: 1"],
                 SpeakCapture.lines
  end

  test "says the quest in its list by name and status" do
    run_log([[:pbList, 0]])
    assert_equal [["Activas: 1", true], ["#{NAME}, #{t(:qu_status_pending)}", true]], SpeakCapture.log
  end

  test "puts the quest in its list on the info key with its status" do
    run_log([[:pbList, 0]])
    assert_equal t(:qu_line, :name => NAME, :status => t(:qu_status_pending)), PokeAccess::Info.info_text
  end

  test "reads a quest that cannot tell whether it is completed as pending, on the info key too" do
    unsure = Struct.new(:name, :desc, :npc, :location).new(NAME, DESC, "Anaid", "Gades")
    announce_after(quest_log(1, :@ongoing => [unsure]))
    pending = t(:qu_status_pending)
    assert_equal [[["#{NAME}, #{pending}", true]], t(:qu_line, :name => NAME, :status => pending)],
                 [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "clears the info key on a quest with no name" do
    ql = quest_log(1, :@ongoing => [quest, quest(:name => "")])
    infos = [0, 1].map do |row|
      ql.instance_variable_set(:@sel_two, row)
      announce_after(ql)
      PokeAccess::Info.info_text
    end
    assert_equal [t(:qu_line, :name => NAME, :status => t(:qu_status_pending)), nil], infos
  end

  test "says a quest's page with the status it paints and its giver" do
    run_log([[:pbList, 0], [:pbLoad, 0]])
    page = t(:qu_detail, :name => NAME, :status => "Sin completar", :desc => DESC, :npc => "Anaid")
    assert_equal [["Activas: 1", true], ["#{NAME}, #{t(:qu_status_pending)}", true], [page, true]], SpeakCapture.log
  end

  test "records no paint once the log has closed" do
    run_log([])
    pbDrawOutlineText(nil, 0, 0, 512, 384, "Otra pantalla")
    assert_equal false, PokeAccess::Quests.painted?("Otra pantalla")
  end

  test "says a list's message painted alone, its title painted blank" do
    announce_after(quest_log(1), "No hay misiones en curso", "")
    assert_equal [["No hay misiones en curso", true]], SpeakCapture.log
  end

  test "says the mod's words for an empty list that painted nothing, or more than its message and title" do
    announce_after(quest_log(1))
    announce_after(quest_log(1), "Misiones activas", "Sin misiones activas", "Pulsa C")
    assert_equal [t(:qu_none), t(:qu_none)], SpeakCapture.lines
  end

  test "says the mod's words for a category whose count the cover did not paint" do
    announce_after(quest_log(0, :@sel_one => 0))
    announce_after(quest_log(0, :@sel_one => 1))
    assert_equal [t(:qu_ongoing, :n => 1), t(:qu_completed, :n => 0)], SpeakCapture.lines
  end

  test "says the mod's words when the count painted is not the list's" do
    announce_after(quest_log(0, :@sel_one => 0), "Activas: 3", "Completas: 0")
    assert_equal [t(:qu_ongoing, :n => 1)], SpeakCapture.lines
  end

  test "remembers the last twelve lines painted, no more" do
    fill = (1..10).map { |i| "Línea #{i}" }
    announce_after(quest_log(0, :@sel_one => 0), "Activas: 1", "Completas: 0", *fill)
    announce_after(quest_log(0, :@sel_one => 0), "Activas: 1", "Completas: 0", *(fill + ["Línea 11"]))
    assert_equal ["Activas: 1", t(:qu_ongoing, :n => 1)], SpeakCapture.lines
  end

  test "says a quest's page with its place when the page paints the place and not the giver" do
    announce_after(quest_log(2), NAME, "Sin completar", "En Gades")
    assert_equal [t(:qu_detail_place, :name => NAME, :status => "Sin completar", :desc => DESC, :loc => "Gades")],
                 SpeakCapture.lines
  end

  test "says a quest's page with its giver when the page paints neither the place nor the giver" do
    announce_after(quest_log(2), NAME, "Sin completar")
    assert_equal [t(:qu_detail, :name => NAME, :status => "Sin completar", :desc => DESC, :npc => "Anaid")],
                 SpeakCapture.lines
  end

  test "says the place of a quest with no giver whose page paints it" do
    announce_after(quest_log(2, :@ongoing => [quest(:npc => "")]), NAME, "Sin completar", "En Gades")
    assert_equal [t(:qu_detail_place, :name => NAME, :status => "Sin completar", :desc => DESC, :loc => "Gades")],
                 SpeakCapture.lines
  end

  test "says the mod's status words on a page that did not paint the quest's name" do
    announce_after(quest_log(2), "Sin completar", "De Anaid")
    assert_equal [t(:qu_detail, :name => NAME, :status => t(:qu_status_pending), :desc => DESC, :npc => "Anaid")],
                 SpeakCapture.lines
  end

  private

  # The active quest every log holds, with fields changed as given.
  def quest(changes = {})
    q = Quest.new(NAME, DESC, "Anaid", "Gades", false)
    changes.each { |k, v| q[k] = v }
    q
  end

  # Opens the stub Questlog on the one active quest and runs its scripted steps; its settings and the paint record
  # are put back afterwards.
  def run_log(steps)
    Questlog.quests = [quest]
    Questlog.steps = steps
    Questlog.new
  ensure
    Questlog.quests = nil
    Questlog.steps = nil
    PokeAccess::Quests.clear_paint
  end

  # A quest log on screen scene (0 the cover, 1 the active list, 2 its first quest's page), the one active quest
  # listed; ivars override its navigation state.
  def quest_log(scene, ivars = {})
    World.stub_scene({ :@scene => scene, :@mode => 0, :@sel_one => 0, :@sel_two => 0, :@page => 0,
                       :@ongoing => (scene == 1 ? [] : [quest]), :@completed => [] }.merge(ivars))
  end

  # Says ql's focus after the log painted texts, the paint record opened before and closed and emptied after.
  def announce_after(ql, *texts)
    PokeAccess::Quests.open_paint
    texts.each { |text| PokeAccess::Quests.note_paint(text) }
    PokeAccess::Quests.announce(ql)
  ensure
    PokeAccess::Quests.close_paint
    PokeAccess::Quests.clear_paint
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
