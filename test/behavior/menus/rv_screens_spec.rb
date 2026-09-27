# The screens of the engine Reborn, Rejuvenation and Desolation share that the mod reads itself, with no relay of
# the games' own reader: the field notes, the Time & Weather app, the Pokedex form page, the moveset restorer, the
# jukebox and the passwords list (games/rv_common/); and Desolation's Advanced Pokedex and quest log
# (games/desolation/).
Harness.load_common("rv_common")
module RvScreensSpec
  Cache = Struct.new(:pkmn, :moves, :abil, :FEData)
  Field = Struct.new(:name)
  Note = Struct.new(:fieldeffect, :text, :elaboration, :cogwheeltext)
  Header = Struct.new(:text)

  # Two notes of one field, the second with more to read behind it.
  def self.notes(field)
    [Note.new(field, "Electric-type attacks <icon=fieldUp> x1.5", "", ""),
     Note.new(field, "<c=ff0000>Grounded</c> Pokemon <icon=fieldNoSleep>", "They cannot fall asleep.", "")]
  end
end

def pbSelectPasswordToBeToggled(_passwords, _operations_left)
  ["[Exit]", "> blindstep", "    fullivs"].map { |r| PokeAccess::Menus.checkbox_row(r) }
end

class Window_FieldEffectNotes
  attr_accessor :notes, :index, :active
  def initialize(notes, _width)
    @notes = notes
    @commands = notes.map { |n| n.text }
    @index = 0
    @active = true
  end
end

class Scene_FieldNotes_Battle
  def pbStartScene(fieldlayers)
    @index = 0
    @fieldlayers = fieldlayers - [:INDOOR]
    @window = Window_FieldEffectNotes.new(RvScreensSpec.notes(@fieldlayers[0]), 400)
  end

  def pbSwitchFieldNotes
    @window = Window_FieldEffectNotes.new(RvScreensSpec.notes(@fieldlayers[@index]), 400)
  end

  def next_field
    @index += 1
    pbSwitchFieldNotes
  end
end

class Scene_TimeWeather
  def initialize(now, following)
    @sprites = { "header" => RvScreensSpec::Header.new("Time & Weather") }
    @weatherType = now
    @nextWeatherType = following
    @selection = 0
  end

  def pbTimeText
    pbDrawTextPositions(nil, [["14:05", 256, 44, 2, nil]])
    pbDrawTextPositions(nil, [["Mon  5  Sep", 256, 110, 2, nil]])
    pbDrawTextPositions(nil, [["Opal Ward", 256, 153, 2, nil]])
    pbDrawTextPositions(nil, [["18:00", 391, 210, 0, nil]])
  end

  def update; nil; end

  def select(n); @selection = n; end
end

class AdvancedPokedexScene
  def pbStartScene(species)
    @species = species
    @page = 1
    @totalPages = 5
    displayPage
    true
  end

  def displayPage
    pbDrawTextPositions(nil, [["Height: 1.2 m", 32, 64, false, nil, nil], ["Weight: 180.0 kg", 32, 96, false, nil, nil]])
  end

  def turn
    @page += 1
    displayPage
  end
end

module RvScreensSpec
  Text = Struct.new(:text, :y)
end

# The moveset restorer: the stored sets in a command list, repainted with the focused set's moves beside it on each
# cursor move, and a menu of its own for the set chosen.
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

# The jukebox: its scene, and its command list of BGM file names.
class Scene_Jukebox; end
class Window_JukeboxCommand < Window_DrawableCommand; end

# The Pokedex form page as the engine paints it: the species, then its form and gender on one row set apart by spaces;
# pbUpdate runs on opening and after each choice.
class PokedexFormScene
  def initialize(species); @species = species; @form = "Normal"; @gender = "Male"; end

  def pbUpdate
    pbDrawTextPositions(nil, [[@species, 256, 298, 2, nil, nil], ["#{@form}         Gender: #{@gender}", 256, 330, 2, nil, nil]])
  end

  def pbChooseForm
    @gender = "Female"
    pbUpdate
  end
end

class QuestLog_Scene
  def pbStartScene(_commands)
    @sprites = { "commands" => Window_DrawableCommand.new(["Find the Ruins", "???", "Back"]),
                 "subheader" => RvScreensSpec::Text.new("Main Quests", 14) }
  end

  def pbSetCommands(_commands, _index)
    @sprites["subheader"] = RvScreensSpec::Text.new("Side Quests", 14)
  end

  # The list's own loop, run again after each confirm; the stand-in returns at once.
  def pbScene; -1; end
end

class QuestInfo_Scene
  def initialize
    @index = 0
    @currentlog = [["Find the Ruins", 1, [[2, "Talk to Lavender"], [1, "Enter the ruins"], [0, "Hidden"]], "true"]]
    @screens = [0, 1]
    @screen_index = 0
    @sprites = { "header" => RvScreensSpec::Text.new("Find the Ruins", 0),
                 "body 1" => RvScreensSpec::Text.new("Enter the ruins", 56),
                 "body 0" => RvScreensSpec::Text.new("Talk to Lavender", 24) }
  end

  def pbUpdate; nil; end

  def turn
    @screen_index = 1
    @sprites = { "header" => @sprites["header"], "body 0" => RvScreensSpec::Text.new("Report back", 24) }
  end
end

Suite.define("desolation: its quest log says which list is up, its row again back on it, and each quest page") do
  load File.expand_path("../../../games/desolation/quest_log.rb", File.dirname(__FILE__))
  t = PokeAccess::I18n
  SpeakCapture.clear
  log = QuestLog_Scene.new
  log.pbStartScene([])
  log.pbSetCommands([], 0)
  eq "the list opens and swaps saying which one is up", SpeakCapture.lines, ["Main Quests", "Side Quests"]

  list = log.instance_variable_get(:@sprites)["commands"]
  SpeakCapture.clear
  log.pbScene
  list.update
  list.update
  eq "its row is said once", SpeakCapture.lines, ["Find the Ruins"]
  SpeakCapture.clear
  log.pbScene
  list.update
  eq "and again when the list's loop runs again, back from a quest's page", SpeakCapture.lines, ["Find the Ruins"]
  SpeakCapture.clear
  list.index = 1
  list.update
  eq "a quest not found yet is said as unknown, not as its question marks", SpeakCapture.lines, [t.t(:pdx_unknown_short)]

  SpeakCapture.clear
  page = QuestInfo_Scene.new
  page.pbUpdate
  pending = t.t(:qu_status_pending)
  eq "a quest opens with its title and state, the page and each objective with its state", SpeakCapture.lines,
     ["Find the Ruins, #{pending}. #{t.t(:adv_dex_page, :n => 1, :m => 2)}. " \
      "Talk to Lavender, #{t.t(:qu_status_done)}. Enter the ruins, #{pending}"]
  SpeakCapture.clear
  page.pbUpdate
  silent "a still page is not said again"
  page.turn
  page.pbUpdate
  eq "a turned page says where it is and its objectives, not the title again", SpeakCapture.lines,
     ["#{t.t(:adv_dex_page, :n => 2, :m => 2)}. Report back"]
end

Suite.define("rv engine: the Pokedex form page says what it paints, on opening and after each choice") do
  PokeAccess::DexFormsRV.bind
  page = PokedexFormScene.new("Bulbasaur")
  SpeakCapture.clear
  page.pbUpdate
  eq "the species, then its form and gender apart", SpeakCapture.lines, ["Bulbasaur, Normal, Gender: Male"]
  SpeakCapture.clear
  page.pbChooseForm
  eq "the new combination once chosen", SpeakCapture.lines, ["Bulbasaur, Normal, Gender: Female"]
end

Suite.define("rv engine: the moveset restorer says each set with its moves, and what its menu asks") do
  PokeAccess::MoveRestorerRV.bind
  t = PokeAccess::I18n
  scene = MoveRestorerScene.new([{ :name => "Set A", :moves => [["Tackle", :NORMAL, 35], ["Ember", :FIRE, 25]] },
                                 { :name => "Set B", :moves => [["Surf", :WATER, 15]] }])
  SpeakCapture.clear
  scene.pbSetList
  line = SpeakCapture.lines.join(" ")
  truthy "it opens on the question it paints (#{line})", line.index("Restore which moveset?") == 0
  truthy "then the focused set", line.include?("? Set A. ")
  truthy "and its moves with their PP", line.include?("Tackle") && line.include?(t.t(:mv_pp, :pp => 25, :tot => 25))
  truthy "the list's bare name is muted", PokeAccess.dedicated?(scene.sprites["commands"])
  SpeakCapture.clear
  scene.move_to(1)
  eq "a move says the set it lands on, not the question again", SpeakCapture.lines.length, 1
  truthy "with its moves", SpeakCapture.lines[0].index("Set B.") == 0 && SpeakCapture.lines[0].include?("Surf")
  eq "cutting in", SpeakCapture.log[0][1], true
  SpeakCapture.clear
  scene.pbShowCommands("Do what with Set B?", ["Restore", "Delete", "Cancel"])
  spoke "its menu says what it asks", /Do what with Set B\?/
end

Suite.define("rv engine: the jukebox says which track plays, and reads the row again once a choice repaints it") do
  had_scene = $scene
  had_system = $game_system
  begin
    PokeAccess::JukeboxRV.bind
    $scene = Scene_Jukebox.new
    $game_system = Object.new
    def $game_system.playing_bgm; Struct.new(:name).new("Nightclub- Main"); end
    win = Window_JukeboxCommand.new(["Nightclub- Main", "Route 1", "Stop Playing"])
    t = PokeAccess::I18n
    eq "the track painted as playing says so", PokeAccess::Menus.focused_text(win),
       "Nightclub- Main, #{t.t(:rv_jukebox_playing)}"
    win.index = 1
    eq "another is its name", PokeAccess::Menus.focused_text(win), "Route 1"
    def $game_system.getDefaultBGM; Struct.new(:name).new("Route 1"); end
    eq "where the game keeps the Jukebox's own choice (Rejuvenation), that one plays over the map's",
       PokeAccess::Menus.focused_text(win), "Route 1, #{t.t(:rv_jukebox_playing)}"
    PokeAccess::Cursor.changed?(win, :cmd_focus, [1, nil, [3, "Route 1"]])
    win.refresh
    falsy "a repaint after a choice lets the still row be read again", PokeAccess::Cursor.current(win, :cmd_focus)
    $scene = had_scene
    win.index = 0
    eq "off the jukebox nothing is said to play", PokeAccess::Menus.focused_text(win), "Nightclub- Main"
  ensure
    $scene = had_scene
    $game_system = had_system
  end
end

Suite.define("rv engine: the field notes, the Time & Weather app, the passwords and Desolation's Advanced Pokedex") do
  had_cache = $cache
  t = PokeAccess::I18n
  begin
    $cache = RvScreensSpec::Cache.new({}, {}, {}, { :ELECTRIC => RvScreensSpec::Field.new("Electric Terrain"),
                                                   :GRASSY => RvScreensSpec::Field.new("Grassy Terrain") })
    truthy "the stand-in $cache is the engine's", PokeAccess::DataRV.engine?
    PokeAccess::FieldNotesRV.bind
    PokeAccess::TimeWeatherRV.bind
    PokeAccess::PasswordsRV.bind
    load File.expand_path("../../../games/desolation/advanced_dex.rb", File.dirname(__FILE__))

    SpeakCapture.clear
    win = Window_FieldEffectNotes.new(RvScreensSpec.notes(:ELECTRIC), 400)
    eq "a notes list opens with its field's name", SpeakCapture.lines, ["Electric Terrain"]
    eq "a row is the note as painted, its icon worded", PokeAccess::Menus.focused_text(win),
       "Electric-type attacks #{t.t(:rv_icon_up)} x1.5"
    win.index = 1
    eq "and says when confirming shows more", PokeAccess::Menus.focused_text(win),
       "Grounded Pokemon #{t.t(:rv_icon_no_sleep)}, #{t.t(:rv_note_more)}"
    eq "an icon that carries its own spoken text says that", PokeAccess::FieldNotesRV.worded('Hits <icon=typeFIRE,tts="Fire type"> foes'),
       "Hits Fire type foes"
    eq "an icon named in another case is worded all the same (Reborn's cave note)",
       PokeAccess::FieldNotesRV.worded("All Pokemon <icon=fieldfaint> when . . ."),
       "All Pokemon #{t.t(:rv_icon_faint)} when . . ."
    staged = Window_FieldEffectNotes.new([RvScreensSpec::Note.new(:ELECTRIC, "Charge", "", "<c3=ffffff,000000>2</c3>")], 400)
    eq "a stage tab is said after its note", PokeAccess::Menus.focused_text(staged), "Charge, 2"
    silent_notes = Window_FieldEffectNotes.new([RvScreensSpec::Note.new(3, "Plain", "", "")], 400)
    falsy "a field known only by a number the game cannot map is not named", PokeAccess::FieldNotesRV.field_name(silent_notes.notes)
    falsy "no core relay claims the list any more", PokeAccess.dedicated?(win)

    SpeakCapture.clear
    battle = Scene_FieldNotes_Battle.new
    battle.pbStartScene([:ELECTRIC, :INDOOR, :GRASSY])
    eq "a battle's stacked fields open with the first and how many", SpeakCapture.lines,
       ["Electric Terrain, #{t.t(:rv_note_layer, :n => 1, :m => 2)}"]
    SpeakCapture.clear
    battle.next_field
    eq "and each switch says the new field and its place", SpeakCapture.lines,
       ["Grassy Terrain, #{t.t(:rv_note_layer, :n => 2, :m => 2)}"]

    SpeakCapture.clear
    tw = Scene_TimeWeather.new("Rain", "Clear")
    tw.pbTimeText
    eq "the app opens saying the time, date, place and both weathers", SpeakCapture.lines,
       ["Time & Weather. 14:05. Mon 5 Sep. Opal Ward. #{t.t(:rv_tw_now, :w => "Rain")}. " \
        "#{t.t(:rv_tw_next, :at => "18:00", :w => "Clear")}"]
    SpeakCapture.clear
    tw.pbTimeText
    silent "a repaint of the same screen is not said again"
    tw.update
    silent "nothing is framed until the arrows move"
    tw.select(3)
    tw.update
    eq "the frame on the next weather says it and when", SpeakCapture.lines,
       [t.t(:rv_tw_next, :at => "18:00", :w => "Clear")]
    SpeakCapture.clear
    tw.select(1)
    tw.update
    eq "and on the time, the time", SpeakCapture.lines, ["14:05"]
    rj = Scene_TimeWeather.new("Rain", "Snow")
    rj.instance_variable_set(:@access_tw_rows, ["14:05", "Mon 5 Sep", "Grand Dream City", "CURRENT WEATHER", "WEATHER AT 21:00"])
    eq "Rejuvenation's labelled weather row still gives the change time", PokeAccess::TimeWeatherRV.part(rj, 3),
       t.t(:rv_tw_next, :at => "21:00", :w => "Snow")

    on = t.t(:val_on)
    off = t.t(:val_off)
    eq "in the passwords list each password is said with its state, the rest as painted",
       pbSelectPasswordToBeToggled({}, nil), ["[Exit]", "blindstep, #{on}", "fullivs, #{off}"]
    eq "outside it a row keeps its marks", PokeAccess::Menus.checkbox_row("> blindstep"), "> blindstep"

    SpeakCapture.clear
    dex = AdvancedPokedexScene.new
    dex.pbStartScene(:MAGNEZONE)
    eq "the Advanced Pokedex opens with one reading, the first page in it", SpeakCapture.lines.length, 1
    spoke "its painted rows in paint order", /Height: 1\.2 m\. Weight: 180\.0 kg\z/
    SpeakCapture.clear
    dex.turn
    spoke "a turned page is said", /Height: 1\.2 m\. Weight: 180\.0 kg\z/
  ensure
    $cache = had_cache
  end
end

