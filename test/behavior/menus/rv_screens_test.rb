# What the mod says on the screens of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/) and on
# Desolation's own (games/desolation/): notes, clock, forms, movesets, jukebox, passwords, quests, Advanced Pokedex.

# The passwords list (pbSelectPasswordToBeToggled): the game's function runs the list, each row read as the command
# reader reads it.
def pbSelectPasswordToBeToggled(rows, _operations_left)
  rows.map { |r| PokeAccess::Menus.checkbox_row(r) }
end

# The field notes list (Window_FieldEffectNotes): a command list over its notes' painted texts.
class Window_FieldEffectNotes < Window_AdvancedCommandPokemon
  attr_reader :notes

  def initialize(notes, _width)
    @notes = notes
    super(notes.map { |n| n.text })
  end
end

# A battle's field notes (Scene_FieldNotes_Battle): a notes list per field layer but the indoor one, the first built as
# it opens and the next by pbSwitchFieldNotes; notes_of gives each field's notes.
class Scene_FieldNotes_Battle
  def initialize(notes_of); @notes_of = notes_of; end

  def pbStartScene(fieldlayers)
    @index = 0
    @fieldlayers = fieldlayers - [:INDOOR]
    @window = Window_FieldEffectNotes.new(@notes_of[@fieldlayers[0]], 400)
  end

  def pbSwitchFieldNotes
    @window = Window_FieldEffectNotes.new(@notes_of[@fieldlayers[@index]], 400)
  end

  def next_field
    @index += 1
    pbSwitchFieldNotes
  end
end

# The Time & Weather app (Scene_TimeWeather): pbTimeText paints its rows ([text, x, y]); update runs each frame with
# the selection frame on a part (@selection 0 none, 1 the time, 2 the weather now, 3 the next one), and repaints the
# rows a rest moved the clock to.
class Scene_TimeWeather
  def initialize(rows, now, following)
    @rows = rows
    @sprites = { "header" => FakeTextWin.new("Time & Weather") }
    @weatherType = now
    @nextWeatherType = following
    @selection = 0
  end

  def pbTimeText
    @rows.each { |text, x, y| pbDrawTextPositions(nil, [[text, x, y, 2, nil]]) }
  end

  def update
    return unless @rested
    @rows = @rested
    @rested = nil
    pbTimeText
  end

  def rest(rows); @rested = rows; end

  def select(n); @selection = n; end
end

# The Pokedex form page (PokedexFormScene): pbUpdate paints the species, then its form and gender on one row set apart
# by spaces, on opening and after each choice.
class PokedexFormScene
  def initialize(species, form, gender); @species = species; @form = form; @gender = gender; end

  def pbUpdate
    pbDrawTextPositions(nil, [[@species, 256, 298, 2, nil, nil],
                              ["#{@form}         Gender: #{@gender}", 256, 330, 2, nil, nil]])
  end

  def pbChooseForm(gender)
    @gender = gender
    pbUpdate
  end
end

# The moveset restorer (MoveRestorerScene): the stored sets in a command list; pbSetList repaints the question at the
# top, the sets' names and, beside them, the focused set's moves (name, type icon, PP); pbShowCommands is its menu.
class MoveRestorerScene
  attr_reader :sprites

  def initialize(sets)
    @movesets = sets
    @sprites = { "commands" => Window_DrawableCommand.new(sets.map { |s| s[:name] }) }
  end

  def pbSetList
    names = []
    @movesets.each_with_index { |s, i| names.push([s[:name], 292, 114 + 32 * i, 0, nil, nil]) }
    pbDrawTextPositions(nil, [["Restore which moveset?", 6, 8, 0, nil, nil]] + names)
    pbDrawSetMoves
  end

  def pbDrawSetMoves
    y = 82
    rows = []
    icons = []
    @movesets[@sprites["commands"].index][:moves].each do |name, type, pp|
      icons.push(["Graphics/Icons/type#{type}", 12, y + 2, 0, 0, 64, 28])
      rows.push([name, 80, y, 0, nil, nil], ["PP", 112, y + 32, 0, nil, nil], ["#{pp}/#{pp}", 230, y + 32, 1, nil, nil])
      y += 64
    end
    pbDrawTextPositions(nil, rows)
    pbDrawImagePositions(nil, icons)
  end

  def pbShowCommands(_message, _commands, index = 0); index; end

  def move_to(i)
    @sprites["commands"].index = i
    pbSetList
  end
end

# The jukebox (Scene_Jukebox) and its list of BGM file names (Window_JukeboxCommand).
class Scene_Jukebox; end
class Window_JukeboxCommand < Window_DrawableCommand; end

# Desolation's quest log (QuestLog_Scene): pbStartScene builds the quest list under a subheader naming it, pbSetCommands
# swaps to the other list, and pbScene is the list's loop, run again after each confirm (here it returns at once).
class QuestLog_Scene
  def initialize(subheader); @subheader = subheader; end

  def pbStartScene(_commands)
    @sprites = { "commands" => Window_DrawableCommand.new(["Find the Ruins", "???", "Back"]) }
    @sprites["subheader"] = FakeTextWin.new(@subheader) if @subheader
  end

  # The side quests put in the list, the loop having painted their subheader first.
  def pbSetCommands(newcommands, newindex)
    @sprites["subheader"] = FakeTextWin.new("Side Quests")
    @sprites["commands"].commands = newcommands
    @sprites["commands"].index = newindex
  end

  def pbScene; -1; end
end

# A quest's page (QuestInfo_Scene), whose state the tests set as the game holds it; pbUpdate runs each frame.
class QuestInfo_Scene
  def pbUpdate; nil; end
end

# Desolation's Advanced Pokedex (the game's AdvancedPokedexScene): an owned entry opens on its first page, painted by
# displayPage, and turn goes to the next; one not caught paints no page. Its types are set as the first page is
# painted, or after it for one not caught. Pokemon Z's tests keep a screen of their own under the game's name, so this
# one takes the name only while its tests run (with_desolation_dex).
class DesolationAdvancedPokedexScene
  def initialize(owned, types); @owned = owned; @types = types; end

  def pbStartScene(species)
    @species = species
    @type1 = @type2 = nil
    @page = 1
    @totalPages = 0
    if @owned
      @totalPages = 5
      @type1, @type2 = @types
      displayPage
    end
    @type1, @type2 = @types unless @type1
    true
  end

  def displayPage
    pbDrawTextPositions(nil, [["Height: 1.2 m", 32, 64, false, nil, nil],
                              ["Weight: 180.0 kg", 32, 96, false, nil, nil]])
  end

  def turn
    @page += 1
    displayPage
  end
end

# Loaded once the game's classes exist, as the mod loads in a game: off the engine (no $cache) the common binds none
# of its readers to them, so the test binds each once below.
Harness.load_common("rv_common")

class RvScreensTest < PokeAccessTest
  # The game's data: a field note (Reborn's and Desolation's, with a stage tab; Rejuvenation's, with a stage note
  # besides), the engine's $cache with its fields' and types' tables, and a named entry of those tables.
  Note = Struct.new(:fieldeffect, :text, :elaboration, :cogwheeltext)
  RejuvenationNote = Struct.new(:fieldeffect, :text, :elaboration, :cogwheeltext, :note)
  Cache = Struct.new(:pkmn, :moves, :abil, :FEData, :types)
  Named = Struct.new(:name)

  # An objective's window on a quest page, its text and its height on the page; and one the game disposed of.
  Body = Struct.new(:text, :y)
  DisposedBody = Struct.new(:text, :y) do
    def disposed?; true; end
  end

  FIELDS = { :ELECTRIC => Named.new("Electric Terrain"), :GRASSY => Named.new("Grassy Terrain") }
  ELECTRIC_NOTES = [Note.new(:ELECTRIC, "Electric-type attacks <icon=fieldUp> x1.5", "", ""),
                    Note.new(:ELECTRIC, "<c=ff0000>Grounded</c> Pokemon <icon=fieldNoSleep>",
                             "They cannot fall asleep.", "")]
  NOTES_OF = { :ELECTRIC => ELECTRIC_NOTES,
               :GRASSY => [Note.new(:GRASSY, "Grass-type attacks <icon=fieldUp> x1.5", "", "")] }
  REBORN_CLOCK = [["14:05", 256, 44], ["Mon  5  Sep", 256, 110], ["Opal Ward", 256, 153], ["18:00", 391, 210]]
  REJUVENATION_CLOCK = [["14:05", 256, 50], ["Mon 5 Sep - Day", 256, 110], ["Grand Dream City", 256, 154],
                        ["CURRENT WEATHER", 70, 210], ["WEATHER AT 21:00", 274, 210]]
  SETS = [{ :name => "Set A", :moves => [["Tackle", :NORMAL, 35], ["Ember", :FIRE, 25]] },
          { :name => "Set B", :moves => [["Surf", :WATER, 15]] }]
  QUEST = ["Find the Ruins", 1, [[2, "Talk to Lavender"], [1, "Enter the ruins"], [0, "Hidden"]], "true"]
  QUEST_BODY = [["Enter the ruins", 56], ["Talk to Lavender", 24]]

  # Desolation's readers: the quest log's, bound as this file loads, and the Advanced Pokedex's, bound the first time
  # a test needs it (with_desolation_dex), whose hooks the toolkit chains under names starting with DEX_HOOKS.
  QUEST_LOG = File.join(Harness::ROOT, "games", "desolation", "quest_log.rb")
  ADVANCED_DEX = File.join(Harness::ROOT, "games", "desolation", "advanced_dex.rb")
  DEX_HOOKS = "AdvancedPokedexScene#"

  [PokeAccess::FieldNotesRV, PokeAccess::TimeWeatherRV, PokeAccess::DexFormsRV, PokeAccess::MoveRestorerRV,
   PokeAccess::JukeboxRV, PokeAccess::PasswordsRV].each { |reader| reader.bind }
  eval(Harness.source(QUEST_LOG), TOPLEVEL_BINDING, QUEST_LOG)

  # How a marked row reads once the passwords reader is bound, before any passwords list has run.
  ROW_BEFORE_ANY_LIST = PokeAccess::Menus.checkbox_row("> blindstep")

  test "a notes list opens with its field's name, cutting in" do
    with_cache { Window_FieldEffectNotes.new(ELECTRIC_NOTES, 400) }
    assert_equal [["Electric Terrain", true]], SpeakCapture.log
  end

  test "a notes list's first row is its note as painted, the icon worded, queued after the field's name" do
    with_cache { Window_FieldEffectNotes.new(ELECTRIC_NOTES, 400).update }
    assert_equal [["Electric Terrain", true], ["Electric-type attacks #{t(:rv_icon_up)} x1.5", false]], SpeakCapture.log
  end

  test "a row whose note shows more on confirming says so, its markup dropped" do
    with_cache do
      win = Window_FieldEffectNotes.new(ELECTRIC_NOTES, 400)
      win.update
      SpeakCapture.clear
      win.index = 1
      win.update
    end
    assert_equal [["Grounded Pokemon #{t(:rv_icon_no_sleep)}, #{t(:rv_note_more)}", true]], SpeakCapture.log
  end

  test "a row says the text the list paints, a translated build's, over the note's own" do
    with_cache do
      win = Window_FieldEffectNotes.new([Note.new(:ELECTRIC, "Electric-type attacks <icon=fieldUp> x1.5", "", "")], 400)
      win.commands = ["Ataques de tipo Eléctrico <icon=fieldUp> x1,5"]
      SpeakCapture.clear
      win.update
    end
    assert_equal [["Ataques de tipo Eléctrico #{t(:rv_icon_up)} x1,5", false]], SpeakCapture.log
  end

  test "a notes list that keeps no texts of its own says each note's" do
    with_cache do
      win = Window_FieldEffectNotes.new([Note.new(:ELECTRIC, "Charge <icon=fieldUp>", "", "")], 400)
      win.commands = nil
      SpeakCapture.clear
      win.update
    end
    assert_equal [["Charge #{t(:rv_icon_up)}", false]], SpeakCapture.log
  end

  test "a note's stage tab is said after it" do
    assert_equal ["Charge, 2"], row_said(Note.new(:ELECTRIC, "Charge", "", "<c3=ffffff,000000>2</c3>"))
  end

  test "a Rejuvenation note's own stage note is said after it" do
    note = RejuvenationNote.new(:ELECTRIC, "Charge", "", "", "<c=ec5800>3</c>+")
    assert_equal ["Charge, 3+"], row_said(note)
  end

  test "each icon of a note is worded: its own spoken text, the mod's word in any case, an unknown or a known type" do
    { 'Hits <icon=typeFIRE,tts="Fire type"> foes' => "Hits Fire type foes",
      "All Pokemon <icon=fieldfaint> when . . ." => "All Pokemon #{t(:rv_icon_faint)} when . . .",
      "<icon=fieldChange> <icon=typeQMARK>" => "#{t(:rv_icon_change)} #{t(:rv_icon_unknown_type)}",
      "Boosts <icon=typeFIRE> moves" => "Boosts #{t(:pdx_type, :t => PokeAccess::Data.type_name(:FIRE))} moves",
      "Shines <icon=sparkle> bright" => "Shines bright" }.each do |painted, said|
      assert_equal [said], row_said(Note.new(:ELECTRIC, painted, "", "")), "for #{painted.inspect}"
    end
  end

  test "a field icon is worded as a type only where the engine has that type" do
    types = { :GRASS => Named.new("Grass") }
    { "<icon=fieldGrass> attacks" => "#{t(:pdx_type, :t => PokeAccess::Data.type_name(:GRASS))} attacks",
      "<icon=fieldRock> attacks" => "attacks" }.each do |painted, said|
      assert_equal [said], row_said(Note.new(:ELECTRIC, painted, "", ""), types), "for #{painted.inspect}"
    end
  end

  test "a field known only by a number the game cannot map is not named as its list opens" do
    with_cache { Window_FieldEffectNotes.new([Note.new(3, "Plain", "", "")], 400) }
    assert_nothing_spoken
  end

  test "where the game maps fields by number, a list keyed by number is named through it and one by name as it is" do
    { 1 => "Electric Terrain", :GRASSY => "Grassy Terrain" }.each do |field, name|
      SpeakCapture.clear
      GameFunctions.with(:fieldIDToSym => lambda { |id| id.is_a?(Integer) ? { 1 => :ELECTRIC }[id] : :INDOOR }) do
        with_cache { Window_FieldEffectNotes.new([Note.new(field, "Charge", "", "")], 400) }
      end
      assert_equal [[name, true]], SpeakCapture.log, "for a list keyed by #{field.inspect}"
    end
  end

  test "a game that names its fields itself has its own name said" do
    GameFunctions.with(:getFieldName => lambda { |fe| fe == :ELECTRIC ? "<b>Campo Eléctrico</b>" : "" }) do
      with_cache { Window_FieldEffectNotes.new(ELECTRIC_NOTES, 400) }
    end
    assert_equal [["Campo Eléctrico", true]], SpeakCapture.log
  end

  test "a field the game's own namer fails on is not named" do
    GameFunctions.with(:getFieldName => lambda { |_fe| raise NoMethodError, "undefined method 'name' for nil" }) do
      with_cache { Window_FieldEffectNotes.new(ELECTRIC_NOTES, 400) }
    end
    assert_nothing_spoken
  end

  test "an empty notes list says nothing as it opens" do
    with_cache { Window_FieldEffectNotes.new([], 400) }
    assert_nothing_spoken
  end

  test "a battle's stacked fields open with the first and how many, the indoor one not counted" do
    with_cache { Scene_FieldNotes_Battle.new(NOTES_OF).pbStartScene([:ELECTRIC, :INDOOR, :GRASSY]) }
    assert_equal [["Electric Terrain, #{t(:rv_note_layer, :n => 1, :m => 2)}", true]], SpeakCapture.log
  end

  test "each switch of a battle's notes says the new field and its place" do
    with_cache do
      battle = Scene_FieldNotes_Battle.new(NOTES_OF)
      battle.pbStartScene([:ELECTRIC, :INDOOR, :GRASSY])
      SpeakCapture.clear
      battle.next_field
    end
    assert_equal [["Grassy Terrain, #{t(:rv_note_layer, :n => 2, :m => 2)}", true]], SpeakCapture.log
  end

  test "a battle on a single field opens with just its name" do
    with_cache { Scene_FieldNotes_Battle.new(NOTES_OF).pbStartScene([:ELECTRIC, :INDOOR]) }
    assert_equal [["Electric Terrain", true]], SpeakCapture.log
  end

  test "a battle's place among its fields is said once: a list built after it says only its field" do
    with_cache do
      Scene_FieldNotes_Battle.new(NOTES_OF).pbStartScene([:ELECTRIC, :GRASSY])
      SpeakCapture.clear
      Window_FieldEffectNotes.new(NOTES_OF[:GRASSY], 400)
    end
    assert_equal [["Grassy Terrain", true]], SpeakCapture.log
  end

  test "the Time & Weather app opens saying its title, the time, date and place, and both weathers" do
    Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear").pbTimeText
    assert_equal [["Time & Weather. 14:05. Mon 5 Sep. Opal Ward. #{t(:rv_tw_now, :w => "Rain")}. " \
                   "#{t(:rv_tw_next, :at => "18:00", :w => "Clear")}", true]], SpeakCapture.log
  end

  test "Rejuvenation's app, which labels its weather row, still gives the time of the change" do
    Scene_TimeWeather.new(REJUVENATION_CLOCK, "Rain", "Snow").pbTimeText
    assert_equal [["Time & Weather. 14:05. Mon 5 Sep - Day. Grand Dream City. #{t(:rv_tw_now, :w => "Rain")}. " \
                   "#{t(:rv_tw_next, :at => "21:00", :w => "Snow")}", true]], SpeakCapture.log
  end

  test "a repaint of the open app says nothing" do
    app = Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear")
    app.pbTimeText
    SpeakCapture.clear
    app.pbTimeText
    assert_nothing_spoken
  end

  test "the app's frame says nothing until the arrows move it" do
    app = Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear")
    app.pbTimeText
    SpeakCapture.clear
    app.update
    assert_nothing_spoken
  end

  test "the app's frame says each part it lands on, cutting in" do
    app = Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear")
    app.pbTimeText
    SpeakCapture.clear
    [1, 2, 3].each do |part|
      app.select(part)
      app.update
    end
    assert_equal [["14:05", true], [t(:rv_tw_now, :w => "Rain"), true],
                  [t(:rv_tw_next, :at => "18:00", :w => "Clear"), true]], SpeakCapture.log
  end

  test "the app's frame resting on a part says it once" do
    app = Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear")
    app.pbTimeText
    SpeakCapture.clear
    app.select(1)
    3.times { app.update }
    assert_equal [["14:05", true]], SpeakCapture.log
  end

  test "after a rest moves the clock, the app's frame says the new time" do
    app = Scene_TimeWeather.new(REBORN_CLOCK, "Rain", "Clear")
    app.pbTimeText
    app.rest([["16:30", 256, 44]] + REBORN_CLOCK.drop(1))
    app.update
    SpeakCapture.clear
    app.select(1)
    app.update
    assert_equal [["16:30", true]], SpeakCapture.log
  end

  test "off the engine the field key says the weather and no clock" do
    GameFunctions.with(:pbGetTimeNow => lambda { Time.local(2026, 9, 28, 14, 5) }) do
      with_cache(nil) { PokeAccess::Battle.announce_overworld }
    end
    assert_equal [[t(:ow_clear), true]], SpeakCapture.log
  end

  test "on the engine the field key says the game's clock after the weather, its time and day of the week" do
    GameFunctions.with(:pbGetTimeNow => lambda { Time.local(2026, 9, 28, 14, 5) }) do
      with_cache { PokeAccess::Battle.announce_overworld }
    end
    assert_equal [["#{t(:ow_clear)}, 14:05, #{t(:wday_1)}", true]], SpeakCapture.log
  end

  test "the game's clock gives the hour and minute in two figures and the day of the week" do
    (0..6).each do |wday|
      clock = GameFunctions.with(:pbGetTimeNow => lambda { Time.local(2026, 10, 4 + wday, 9, 5) }) do
        with_cache { PokeAccess::Battle.clock_text }
      end
      assert_equal "09:05, #{t(:"wday_#{wday}")}", clock, "on day #{wday} of the week"
    end
  end

  test "a game clock that gives no time, or fails, gives the field key no clock" do
    { "a text" => lambda { "14:05" }, "an error" => lambda { raise "no clock" },
      "a time with no minutes" => lambda { Class.new { def hour; 9; end; def wday; 1; end }.new } }.each do |what, now|
      clock = GameFunctions.with(:pbGetTimeNow => now) { with_cache { PokeAccess::Battle.clock_text } }
      assert_nil clock, "for #{what}"
    end
  end

  test "the form page says the species, then its form and gender apart, cutting in" do
    PokedexFormScene.new("Bulbasaur", "Normal", "Male").pbUpdate
    assert_equal [["Bulbasaur, Normal, Gender: Male", true]], SpeakCapture.log
  end

  test "a choice on the form page says the new combination" do
    page = PokedexFormScene.new("Bulbasaur", "Normal", "Male")
    page.pbUpdate
    SpeakCapture.clear
    page.pbChooseForm("Female")
    assert_equal [["Bulbasaur, Normal, Gender: Female", true]], SpeakCapture.log
  end

  test "the moveset restorer opens on its question, the focused set and its moves, queued" do
    MoveRestorerScene.new(SETS).pbSetList
    moves = [move_line("Tackle", :NORMAL, 35), move_line("Ember", :FIRE, 25)].join(", ")
    assert_equal [["Restore which moveset? Set A. #{t(:sm_moves, :list => moves)}", false]], SpeakCapture.log
  end

  test "a move in the restorer says the set it lands on and its moves, cutting in, and not the question" do
    scene = MoveRestorerScene.new(SETS)
    scene.pbSetList
    SpeakCapture.clear
    scene.move_to(1)
    assert_equal [["Set B. #{t(:sm_moves, :list => move_line("Surf", :WATER, 15))}", true]], SpeakCapture.log
  end

  test "the restorer's list does not say its sets' bare names" do
    scene = MoveRestorerScene.new(SETS)
    scene.pbSetList
    SpeakCapture.clear
    scene.sprites["commands"].update
    assert_nothing_spoken
  end

  test "a set whose moves the restorer does not paint is said by its name alone" do
    MoveRestorerScene.new([{ :name => "Set C", :moves => [] }]).pbSetList
    assert_equal [["Restore which moveset? Set C", false]], SpeakCapture.log
  end

  test "the restorer's menu says what it asks" do
    MoveRestorerScene.new(SETS).pbShowCommands("Do what with Set B?", ["Restore", "Delete", "Cancel"])
    assert_equal [["Do what with Set B?", false]], SpeakCapture.log
  end

  test "the jukebox says the track it paints as playing plays" do
    on_jukebox(Named.new("Nightclub- Main")) { jukebox_list.update }
    assert_equal [["Nightclub- Main, #{t(:rv_jukebox_playing)}", false]], SpeakCapture.log
  end

  test "a move in the jukebox says the track by its name, cutting in" do
    on_jukebox(Named.new("Nightclub- Main")) do
      list = jukebox_list
      list.update
      SpeakCapture.clear
      list.index = 1
      list.update
    end
    assert_equal [["Route 1", true]], SpeakCapture.log
  end

  test "where the game keeps the jukebox's own choice, that one is said to play" do
    lines = on_jukebox(Named.new("Nightclub- Main"), Named.new("Route 1")) do
      list = jukebox_list
      [0, 1].map { |i| list.index = i; PokeAccess::Menus.focused_text(list) }
    end
    assert_equal ["Nightclub- Main", "Route 1, #{t(:rv_jukebox_playing)}"], lines
  end

  test "off the jukebox or with no track playing, no track is said to play" do
    { "another scene" => [Object.new, Named.new("Nightclub- Main")],
      "no track" => [Scene_Jukebox.new, nil] }.each do |what, (scene, bgm)|
      text = on_jukebox(bgm, nil, scene) { PokeAccess::Menus.focused_text(jukebox_list) }
      assert_equal "Nightclub- Main", text, "with #{what}"
    end
  end

  test "with no game system to ask, the jukebox says no track plays" do
    text = on_jukebox(Named.new("Nightclub- Main")) do
      $game_system = nil
      PokeAccess::Menus.focused_text(jukebox_list)
    end
    assert_equal "Nightclub- Main", text
  end

  test "the jukebox's repaint after a choice reads the still row again" do
    on_jukebox(Named.new("Route 1")) do
      list = jukebox_list
      list.update
      list.update
      SpeakCapture.clear
      list.refresh
      list.update
    end
    assert_equal [["Nightclub- Main", false]], SpeakCapture.log
  end

  test "in the passwords list each password is said with its state, the other rows as painted" do
    rows = pbSelectPasswordToBeToggled(["[Exit]", "> blindstep", "    fullivs", "[Add password]"], 3)
    assert_equal ["[Exit]", "blindstep, #{t(:val_on)}", "fullivs, #{t(:val_off)}", "[Add password]"], rows
  end

  test "a toggle row in the passwords list still reads as a toggle" do
    assert_equal ["Hard mode, #{t(:val_on)}"], pbSelectPasswordToBeToggled(["[X] Hard mode"], 3)
  end

  test "before any passwords list has run, a row keeps its marks" do
    assert_equal "> blindstep", ROW_BEFORE_ANY_LIST
  end

  test "outside the passwords list a row keeps its marks" do
    rows = ["> blindstep", "    fullivs"]
    assert_equal rows, rows.map { |r| PokeAccess::Menus.checkbox_row(r) }
  end

  test "after a passwords list that failed, rows keep their marks" do
    assert_raises(NoMethodError) { pbSelectPasswordToBeToggled(nil, 3) }
    assert_equal "> blindstep", PokeAccess::Menus.checkbox_row("> blindstep")
  end

  test "the quest log says which list is up as it opens, cutting in" do
    QuestLog_Scene.new("Main Quests").pbStartScene([])
    assert_equal [["Main Quests", true]], SpeakCapture.log
  end

  test "swapping the quest log's lists says the new one, its row queued after it" do
    log = QuestLog_Scene.new("Main Quests")
    log.pbStartScene([])
    log.pbScene
    quest_list(log).update
    SpeakCapture.clear
    log.pbSetCommands(["Defeat the Gym", "Back"], 0)
    quest_list(log).update
    assert_equal [["Side Quests", true], ["Defeat the Gym", false]], SpeakCapture.log
  end

  test "a quest log that paints no subheader says nothing as it opens" do
    QuestLog_Scene.new(nil).pbStartScene([])
    assert_nothing_spoken
  end

  test "the quest log's row is said once, queued after the list's name" do
    log = QuestLog_Scene.new("Main Quests")
    log.pbStartScene([])
    log.pbScene
    2.times { quest_list(log).update }
    assert_equal [["Main Quests", true], ["Find the Ruins", false]], SpeakCapture.log
  end

  test "back on the quest log from a quest's page, its row is said again" do
    log = QuestLog_Scene.new("Main Quests")
    log.pbStartScene([])
    log.pbScene
    quest_list(log).update
    SpeakCapture.clear
    log.pbScene
    quest_list(log).update
    assert_equal [["Find the Ruins", false]], SpeakCapture.log
  end

  test "a quest not found yet is said as unknown, not as its question marks" do
    log = QuestLog_Scene.new("Main Quests")
    log.pbStartScene([])
    log.pbScene
    quest_list(log).update
    SpeakCapture.clear
    quest_list(log).index = 1
    quest_list(log).update
    assert_equal [[t(:pdx_unknown_short), true]], SpeakCapture.log
  end

  test "a quest page opens with its title and state, its page of how many, and each objective top to bottom" do
    quest_page(QUEST, QUEST_BODY).pbUpdate
    assert_equal [["#{quest_line("Find the Ruins", :pending)}. #{t(:adv_dex_page, :n => 1, :m => 2)}. " \
                   "#{quest_line("Talk to Lavender", :done)}. #{quest_line("Enter the ruins", :pending)}", true]],
                 SpeakCapture.log
  end

  test "a still quest page is not said again" do
    page = quest_page(QUEST, QUEST_BODY)
    page.pbUpdate
    SpeakCapture.clear
    page.pbUpdate
    assert_nothing_spoken
  end

  test "a turned quest page says which page it is and its objectives, not the title again" do
    page = quest_page(QUEST, QUEST_BODY)
    page.pbUpdate
    SpeakCapture.clear
    page.instance_variable_set(:@screen_index, 1)
    page.instance_variable_set(:@sprites, page_sprites(QUEST, [["Report back", 24]]))
    page.pbUpdate
    assert_equal [["#{t(:adv_dex_page, :n => 2, :m => 2)}. Report back", true]], SpeakCapture.log
  end

  test "a quest of one page says no page number" do
    quest_page(QUEST, [["Talk to Lavender", 24]], 1).pbUpdate
    assert_equal [["#{quest_line("Find the Ruins", :pending)}. #{quest_line("Talk to Lavender", :done)}", true]],
                 SpeakCapture.log
  end

  test "an objective with no state in the quest is said bare" do
    quest_page(QUEST, [["Hidden", 24], ["Not in the quest", 56]], 1).pbUpdate
    assert_equal [["#{quest_line("Find the Ruins", :pending)}. Hidden. Not in the quest", true]], SpeakCapture.log
  end

  test "an objective painted in the game's translation still finds its state" do
    with_intl("Talk to Lavender" => "Habla con Lavanda") { quest_page(QUEST, [["Habla con Lavanda", 24]], 1).pbUpdate }
    assert_equal [["#{quest_line("Find the Ruins", :pending)}. #{quest_line("Habla con Lavanda", :done)}", true]],
                 SpeakCapture.log
  end

  test "an objective's window the game disposed of is not said" do
    page = quest_page(QUEST, [["Talk to Lavender", 24]], 1)
    page.instance_variable_get(:@sprites)["body 9"] = DisposedBody.new("Enter the ruins", 56)
    page.pbUpdate
    assert_equal [["#{quest_line("Find the Ruins", :pending)}. #{quest_line("Talk to Lavender", :done)}", true]],
                 SpeakCapture.log
  end

  test "a quest page whose quest the log does not hold says its title and objectives bare" do
    page = quest_page(QUEST, [["Talk to Lavender", 24]], 1)
    page.instance_variable_set(:@index, 4)
    page.pbUpdate
    assert_equal [["Find the Ruins. Talk to Lavender", true]], SpeakCapture.log
  end

  test "an owned entry of the Advanced Pokedex opens with the species, its types and its first page, cutting in" do
    with_desolation_dex { DesolationAdvancedPokedexScene.new(true, [:ELECTRIC, :STEEL]).pbStartScene(:MAGNEZONE) }
    assert_equal [["#{species(:MAGNEZONE)}. #{types(:ELECTRIC, :STEEL)}. #{t(:adv_dex_page, :n => 1, :m => 5)}. " \
                   "Height: 1.2 m. Weight: 180.0 kg", true]], SpeakCapture.log
  end

  test "an entry not caught opens with the species, its types and that it is not caught" do
    with_desolation_dex { DesolationAdvancedPokedexScene.new(false, [:ELECTRIC, :STEEL]).pbStartScene(:MAGNEZONE) }
    assert_equal [["#{species(:MAGNEZONE)}. #{types(:ELECTRIC, :STEEL)}. #{t(:pdx_not_caught)}", true]],
                 SpeakCapture.log
  end

  test "a turned page of the Advanced Pokedex says its place and its rows, cutting in" do
    with_desolation_dex { turn_dex }
    assert_equal [["#{t(:adv_dex_page, :n => 2, :m => 5)}. Height: 1.2 m. Weight: 180.0 kg", true]], SpeakCapture.log
  end

  test "the Advanced Pokedex leaves the page's place out at brief verbosity" do
    lines = with_desolation_dex do
      vb_levels do
        turn_dex
        SpeakCapture.lines
      end
    end
    paged = "#{t(:adv_dex_page, :n => 2, :m => 5)}. Height: 1.2 m. Weight: 180.0 kg"
    assert_equal [["Height: 1.2 m. Weight: 180.0 kg"], [paged], [paged]], lines
  end

  test "an entry's types are said once each, and not at all when it has none" do
    { [:ELECTRIC, :ELECTRIC] => "#{species(:PIKACHU)}. #{types(:ELECTRIC)}. #{t(:pdx_not_caught)}",
      [:ELECTRIC, nil] => "#{species(:PIKACHU)}. #{types(:ELECTRIC)}. #{t(:pdx_not_caught)}",
      [nil, nil] => "#{species(:PIKACHU)}. #{t(:pdx_not_caught)}" }.each do |pair, said|
      SpeakCapture.clear
      with_desolation_dex { DesolationAdvancedPokedexScene.new(false, pair).pbStartScene(:PIKACHU) }
      assert_equal [said], SpeakCapture.lines, "for #{pair.inspect}"
    end
  end

  private

  # The mod's text for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The block's value with $cache as the engine's (FIELDS for its fields, types for its types), or with none for nil;
  # the cache there before is put back after.
  def with_cache(types = {})
    was = $cache
    $cache = types ? Cache.new({}, {}, {}, FIELDS, types) : nil
    yield
  ensure
    $cache = was
  end

  # What a notes list of the one note says for its row, past the field's name.
  def row_said(note, types = {})
    with_cache(types) do
      win = Window_FieldEffectNotes.new([note], 400)
      SpeakCapture.clear
      win.update
    end
    SpeakCapture.lines
  end

  # One move of the restorer's panel as the moves line says it: name, type and PP.
  def move_line(name, type, pp)
    "#{name}. #{t(:mv_type, :t => PokeAccess::Data.type_name(type))}. #{t(:mv_pp, :pp => pp, :tot => pp)}"
  end

  # The block's value on the jukebox scene (or on scene), $game_system playing bgm and keeping default as the jukebox's
  # own choice when given; the scene and the system there before are put back after.
  def on_jukebox(bgm, default = nil, scene = Scene_Jukebox.new)
    was = [$scene, $game_system]
    system = Object.new
    system.define_singleton_method(:playing_bgm) { bgm }
    system.define_singleton_method(:getDefaultBGM) { default } if default
    $scene = scene
    $game_system = system
    yield
  ensure
    $scene, $game_system = was
  end

  # The jukebox's list of tracks, on its first.
  def jukebox_list
    Window_JukeboxCommand.new(["Nightclub- Main", "Route 1", "Stop Playing"])
  end

  # The quest log's list of quests.
  def quest_list(log)
    log.instance_variable_get(:@sprites)["commands"]
  end

  # A quest page as Desolation holds it: the quest ([title, state, [[state, objective]...]]) first in its log, the
  # objectives' windows its body paints ([text, y]), and how many pages it has, on its first.
  def quest_page(quest, body, pages = 2)
    page = QuestInfo_Scene.new
    { :@index => 0, :@currentlog => [quest], :@screens => (0...pages).to_a, :@screen_index => 0,
      :@sprites => page_sprites(quest, body) }.each { |ivar, v| page.instance_variable_set(ivar, v) }
    page
  end

  # A quest page's sprites: the header with its title and a window per objective painted.
  def page_sprites(quest, body)
    sprites = { "header" => FakeTextWin.new(quest[0]) }
    body.each_with_index { |(text, y), i| sprites["body #{i}"] = Body.new(text, y) }
    sprites
  end

  # A quest's title or objective with its state (:done or :pending) as the quest page says it.
  def quest_line(text, state)
    t(:qu_line, :name => text, :status => t(:"qu_status_#{state}"))
  end

  # Runs the block with DesolationAdvancedPokedexScene under the game's name and the Desolation reader's hooks on it,
  # bound the first time; what held that name and those hooks before (Pokemon Z's screen, in its tests) is put back.
  def with_desolation_dex
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = chains.select { |key, _chain| key.start_with?(DEX_HOOKS) }
    held.each_key { |key| chains.delete(key) }
    prior = Object.const_defined?(:AdvancedPokedexScene, false) ? Object.send(:remove_const, :AdvancedPokedexScene) : nil
    Object.const_set(:AdvancedPokedexScene, DesolationAdvancedPokedexScene)
    chains.update(self.class.desolation_dex_chains)
    yield
  ensure
    if held
      Object.send(:remove_const, :AdvancedPokedexScene) if Object.const_defined?(:AdvancedPokedexScene, false)
      Object.const_set(:AdvancedPokedexScene, prior) if prior
      chains.delete_if { |key, _chain| key.start_with?(DEX_HOOKS) }
      chains.update(held)
    end
  end

  # An owned Magnezone's entry in the Advanced Pokedex, opened and turned to its second page, the opening's speech
  # cleared.
  def turn_dex
    dex = DesolationAdvancedPokedexScene.new(true, [:ELECTRIC, :STEEL])
    dex.pbStartScene(:MAGNEZONE)
    SpeakCapture.clear
    dex.turn
  end

  # A species' name as the data gives it.
  def species(id)
    PokeAccess::Data.species_name(id)
  end

  # The type part of an entry's opening, its types' names as the data gives them.
  def types(*ids)
    t(:pdx_type, :t => ids.map { |id| PokeAccess::Data.type_name(id) }.join("/"))
  end

  class << self
    # The Desolation Advanced Pokedex reader's hook chains by name: the reader evaluated once, on the first call, which
    # with_desolation_dex makes with the stand-in under the game's name and no hooks left under it.
    def desolation_dex_chains
      @desolation_dex_chains ||= begin
        eval(Harness.source(ADVANCED_DEX), TOPLEVEL_BINDING, ADVANCED_DEX)
        PokeAccess::Hooks.instance_variable_get(:@chains).select { |key, _chain| key.start_with?(DEX_HOOKS) }
      end
    end
  end
end
