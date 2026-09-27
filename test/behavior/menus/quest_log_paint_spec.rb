# The quest log (plugins/easy_questing.rb) through its hooks on the stub Questlog, which paints as Africanvs's copy
# does: the cover's counts, an empty list's message and a quest's status are said as painted, never in the words of
# another copy ("Activos", "Sin favores"); the qu_ keys stand in only where nothing was caught.
AfrQuest = Struct.new(:name, :desc, :npc, :location, :completed)

Suite.define("quest log: cover, empty list, cover again and a quest's page are said as the copy paints them") do
  quest = AfrQuest.new("Derrota a la Unión", "Busca sus guaridas", "Anaid", "Gades", false)
  Questlog.quests = [quest]
  Questlog.steps = [[:pbSwitch, :DOWN], [:pbList, 1], [:pbMain], [:pbSwitch, :UP], [:pbList, 0], [:pbLoad, 0]]
  begin
    SpeakCapture.clear
    Questlog.new
    lines = SpeakCapture.lines
  ensure
    Questlog.quests = nil
    Questlog.steps = nil
  end
  eq "the cover's two counts as its constructor paints them", lines[0, 2], ["Activas: 1", "Completas: 0"]
  eq "an empty list's message, not its title", lines[2], "No has completado ninguna misión"
  eq "back on the cover, the count as it is painted again", lines[3, 2], ["Completadas: 0", "Activas: 1"]
  eq "a quest in its list", lines[5], PokeAccess::Quests.quest_row(quest)
  eq "its page with the status it paints", lines[6], "Derrota a la Unión, Sin completar. Busca sus guaridas. De Anaid"
  eq "and nothing else", lines.length, 7

  pbDrawOutlineText(nil, 0, 0, 512, 384, "Otra pantalla")
  falsy "with the log closed nothing is recorded", PokeAccess::Quests.painted?("Otra pantalla")
end

# A copy that paints its empty list's title as "" (Awakening) leaves the message alone; with nothing caught, the
# mod's own words stand in.
Suite.define("quest log: a lone empty-list message is said, and the qu_ keys stand in for missing paint") do
  qs = PokeAccess::Quests
  ql = Object.new
  ql.instance_variable_set(:@ongoing, [])
  ql.instance_variable_set(:@completed, [])
  ql.instance_variable_set(:@scene, 1)
  ql.instance_variable_set(:@mode, 0)
  ql.instance_variable_set(:@sel_two, 0)
  qs.open_paint
  begin
    ["No hay misiones en curso", ""].each { |t| qs.note_paint(t) }
    SpeakCapture.clear
    qs.announce(ql)
    eq "the message on its own", SpeakCapture.lines, ["No hay misiones en curso"]

    qs.clear_paint
    ql.instance_variable_set(:@scene, 0)
    ql.instance_variable_set(:@sel_one, 0)
    SpeakCapture.clear
    qs.announce(ql)
    eq "a cover with no count caught", SpeakCapture.lines, [PokeAccess::I18n.t(:qu_ongoing, :n => 0)]
  ensure
    qs.close_paint
    qs.clear_paint
  end
end
