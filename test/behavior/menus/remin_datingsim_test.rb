# Reminiscencia's dating sim (games/reminiscencia: datingsim.rb, datingsim_place.rb) over stand-ins for its screens:
# the hub's options and HUD, the day's results and the day roll, the task screen's gender tabs, place strip, panel
# and character list, the support pairs, and the build screen's recipe table, tabs and material list.
class DatingSimMainScreen
  Window = Struct.new(:text)

  def initialize(commands, index = 0, goal = nil, day = nil)
    @commands = commands
    @index = index
    @sprites = { "nextitem" => Window.new(goal), "daycount" => Window.new(day) }
    main_loop
  end

  def setText; :set; end
  def main_loop; :closed; end
end

class DatingSimResultsScreen
  def initialize(rows); @rows = rows; end
  def drawData; pbDrawTextPositions(nil, @rows); :drawn; end
end

class SlideDay
  def initialize(_loop = nil, _forward = true); end
end

class DatingSimTaskScreen
  Row = Struct.new(:index)
  PANEL = [["Playa -> Ánimo-1", 160, 182], ["Material", 58, 220], ["Objetivo", 258, 220], ["COMENZAR -> C", 96, 430],
           ["Arena", 24, 246], ["Concha", 24, 272], ["---------", 24, 298]]
  FLAGS = [["Graphics/Pictures/DatingSimStuff/flag_objective", 280, 250, 0, 0, -1, -1]]

  def initialize(index = 3, row = 0); @index = index; @cmdwindow = Row.new(row); end

  def drawDataWindow
    pbDrawTextPositions(nil, PANEL)
    pbDrawImagePositions(nil, FLAGS)
    :painted
  end

  def inputs
    setGenderPage if @gender_pressed
    :inputs
  end

  def setGenderPage; :gender; end
end

class DatingSimSupportScreen
  Partners = Struct.new(:index, :commands)

  def initialize(characters, index, partners, total = 6)
    @characters = characters
    @index = index
    @cmdwindow = Partners.new(0, partners)
    @total = total
  end

  def updatePoints; :points; end
  def getTotalPoints(_name, _partner); @total; end
end

class DatingSimBuildScreen
  BUILD = [["Collar Elemental", 480, 142], ["Material", 352, 178], ["Obtenido / Necesario", 442, 178],
           ["CONSTRUIR -> C", 480, 388], ["Roca de Rockruff", 352, 204], ["0/1", 618, 204],
           ["Tela de Shuppet", 352, 230], ["0/1", 618, 230], ["Perla de Shellder", 352, 256], ["0/1", 618, 256]]

  def initialize(tab = 0); @indexTask = tab; end
  def setWindowSelect; :moved; end
  def drawDataWindow; pbDrawTextPositions(nil, BUILD); :drawn; end
end

class Window_CommandPokemonDatingSim
  attr_accessor :index
  def initialize(cmds); @commands = cmds; @index = 0; end
end

class Window_CommandPokemonCraftSim
  attr_accessor :index
  def initialize(cmds, keys = nil); @commands = cmds; @translation_list = keys; @index = 0; end
end

%w[datingsim datingsim_place].each do |f|
  path = File.join(Harness::ROOT, "games", "reminiscencia", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class ReminDatingsimTest < PokeAccessTest
  # The characters' counters as datingGet answers them.
  CHARS = { "Kyle" => { "worklevel" => 3, "cleanlevel" => 1, "status" => 4, "fpPoints" => 2 },
            "Mahina" => { "worklevel" => 2, "cleanlevel" => 1, "status" => 3, "fpPoints" => 5 } }
  # The player's dating-sim counters: the day, the island's cleanliness, the current objective.
  Player = Struct.new(:dateDays, :dateSimClean, :nextObjective)
  TABLE = "Collar Elemental. Material Obtenido / Necesario. Roca de Rockruff 0/1. Tela de Shuppet 0/1. " \
          "Perla de Shellder 0/1. CONSTRUIR: C"
  MALE = "♂"
  FEMALE = "♀"

  test "the hub says its focused option as it opens, then its HUD queued" do
    DatingSimMainScreen.new(%w[Trabajar Limpiar], 1, "Objetivo:\nCollar Elemental\n3 días", "Día 5")
    assert_equal [["Limpiar", true], ["Objetivo: Collar Elemental, 3 días", false], ["Día 5", false]], SpeakCapture.log
  end

  test "the hub says each option it moves to" do
    hub = DatingSimMainScreen.new(%w[Trabajar Limpiar])
    SpeakCapture.clear
    hub.instance_variable_set(:@index, 1)
    assert_equal :set, hub.setText, "the hub's own setText runs"
    assert_equal [["Limpiar", true]], SpeakCapture.log
  end

  test "the hub's HUD joins unlabelled lines with commas and leaves out an empty window" do
    DatingSimMainScreen.new(%w[Trabajar], 0, "", "Día 5\n\nNoche")
    DatingSimMainScreen.new(%w[Trabajar], 0, "Objetivo:", nil)
    assert_equal ["Trabajar", "Día 5, Noche", "Trabajar", "Objetivo:"], SpeakCapture.lines
  end

  test "the hub says nothing for an option it has no list for" do
    DatingSimMainScreen.new(nil)
    assert_nothing_spoken
  end

  test "the day's results are said queued, the cleanliness bar as a number" do
    with_player(5, 40) do
      DatingSimResultsScreen.new([["Resultados", 200, 40], ["OranBerryx2", 200, 80]]).drawData
      assert_equal [["Resultados, OranBerryx2. #{PokeAccess::I18n.t(:rem_clean_pct, :n => 40)}", false]],
                   SpeakCapture.log
    end
  end

  test "the day's results are their rows alone without the player's counters, and nothing without either" do
    DatingSimResultsScreen.new([["Resultados", 200, 40], ["OranBerryx2", 200, 80]]).drawData
    DatingSimResultsScreen.new([]).drawData
    assert_equal ["Resultados, OranBerryx2"], SpeakCapture.lines
  end

  test "the day sleeping rolls to is said cutting in, and whether it went back" do
    t = PokeAccess::I18n
    with_player(5, 40) do
      SlideDay.new(nil, false)
      SlideDay.new(nil, true)
      SlideDay.new(nil)
      assert_equal [[t.t(:rem_day_back, :n => 5), true], [t.t(:rem_day, :n => 5), true], [t.t(:rem_day, :n => 5), true]],
                   SpeakCapture.log
    end
  end

  test "no day is said without the player's day count" do
    SlideDay.new(nil, true)
    assert_nothing_spoken
  end

  test "the day, the results and the task panel speak the mod's language" do
    t = PokeAccess::I18n
    PokeAccess::Config.language = :en
    with_player(5, 40) do
      SlideDay.new(nil, false)
      SlideDay.new(nil, true)
      DatingSimResultsScreen.new([["Results", 200, 40]]).drawData
      panel = DatingSimTaskScreen.new
      panel.drawDataWindow
      panel.inputs
      assert_equal [t.t(:rem_day_back, :n => 5), t.t(:rem_day, :n => 5), "Results. #{t.t(:rem_clean_pct, :n => 40)}",
                    task_panel], SpeakCapture.lines
    end
  end

  test "the task screen's gender tab is said by its sign, the third by a word" do
    { 0 => MALE, 1 => FEMALE, 2 => PokeAccess::I18n.t(:rem_dating_unknown) }.each do |tab, said|
      SpeakCapture.clear
      scene = DatingSimTaskScreen.new
      scene.instance_variable_set(:@indexGender, tab)
      assert_equal :gender, scene.setGenderPage, "the screen's own setGenderPage runs"
      assert_equal [[said, true]], SpeakCapture.log, "tab #{tab}"
    end
  end

  test "the task screen says no gender tab past the third" do
    scene = DatingSimTaskScreen.new
    scene.instance_variable_set(:@indexGender, 3)
    scene.setGenderPage
    assert_nothing_spoken
  end

  test "the gender tab is said when the screen's own input switches it" do
    scene = DatingSimTaskScreen.new
    scene.instance_variable_set(:@indexGender, 1)
    scene.instance_variable_set(:@gender_pressed, true)
    scene.inputs
    assert_equal [[FEMALE, true]], SpeakCapture.log
  end

  test "the task panel is read as painted: the place and its mood, each material, the flagged one marked, the key" do
    with_player(5, 40) do
      scene = DatingSimTaskScreen.new
      assert_equal :painted, scene.drawDataWindow, "the panel paints as the game's"
      assert_equal :inputs, scene.inputs, "the screen's own input runs"
      assert_equal [[task_panel, false]], SpeakCapture.log
    end
  end

  test "the task panel is read cutting in as the place strip moves, queued as a new character brings its own" do
    with_player(5, 40) do
      scene = DatingSimTaskScreen.new
      scene.drawDataWindow
      2.times { scene.inputs }
      scene.instance_variable_set(:@index, 4)
      scene.inputs
      scene.instance_variable_get(:@cmdwindow).index = 1
      scene.inputs
      assert_equal [[task_panel, false], [task_panel, true], [task_panel, false]], SpeakCapture.log
    end
  end

  test "without a painted panel the focused place is said by its name" do
    places = { :beach => [0, 0, "Playa"], :forest => [0, 0, nil], :cave => "Cueva" }
    with_places(places) do
      [0, 1, 2].each do |idx|
        scene = DatingSimTaskScreen.new(idx)
        scene.inputs
      end
      empty = DatingSimTaskScreen.new(0)
      empty.instance_variable_set(:@access_task_panel, "")
      empty.inputs
    end
    assert_equal ["Playa", "forest", "cave", "Playa"], SpeakCapture.lines
  end

  test "a place off either end of the strip, or with no places known, is not said" do
    with_places(:beach => [0, 0, "Playa"]) { [1, -1].each { |idx| DatingSimTaskScreen.new(idx).inputs } }
    DatingSimTaskScreen.new(0).inputs
    assert_nothing_spoken
  end

  test "the panel leaves out dash rows and unplaced text, and marks only a material its flag sits beside" do
    t = PokeAccess::I18n
    pairs = [["Concha", :positions, 24, 300], ["Arena", :positions, 24, 246], ["Sal", :positions, 24, 272],
             ["Roca", :positions, 24, 320], ["-----", :positions, 24, 340], ["suelto", :positions, nil, nil],
             ["sin columna", :positions, nil, 300], ["sin fila", :positions, 24, nil],
             ["+2", :positions, 90, 200], ["Bosque -> Ánimo", :positions, 24, 200]]
    flags = [["flag_objective", 280, 246], ["flag_objective", 280, 280], ["flag_objective", 280, 299],
             ["flag_objective", 280, 329], ["other_icon", 280, 300]]
    assert_equal "Bosque: Ánimo +2. #{t.t(:rem_task_needed, :item => 'Arena')}. #{t.t(:rem_task_needed, :item => 'Sal')}. " \
                 "Concha. Roca", PokeAccess::ReminDatingPlace.panel_text(pairs, flags)
  end

  test "a character row says the levels and the mood its icons show" do
    with_dating_data do
      win = Window_CommandPokemonDatingSim.new(%w[Kyle Mahina])
      win.index = 1
      assert_equal PokeAccess::I18n.t(:rem_dating_row, :name => "Mahina", :work => 2, :clean => 1, :mood => 3),
                   PokeAccess::Menus.focused_text(win)
    end
  end

  test "a character the game keeps only some levels for is said with the rest as zero" do
    with_dating_data(CHARS.merge("Ruby" => { "worklevel" => 3 })) do
      win = Window_CommandPokemonDatingSim.new(%w[Ruby])
      assert_equal PokeAccess::I18n.t(:rem_dating_row, :name => "Ruby", :work => 3, :clean => 0, :mood => 0),
                   PokeAccess::Menus.focused_text(win)
    end
  end

  test "a character with no levels is said by name, and a row past the list not at all" do
    with_dating_data do
      win = Window_CommandPokemonDatingSim.new(%w[Ruby])
      assert_equal "Ruby", PokeAccess::Menus.focused_text(win), "a character the game keeps no levels for"
      win.index = 1
      assert_nil PokeAccess::Menus.focused_text(win), "past the list"
    end
  end

  test "a support pair says the character's points, the partner's with what the pair needs and has, then its levels" do
    t = PokeAccess::I18n
    with_dating_data do
      scene = DatingSimSupportScreen.new([["Kyle", []]], 0, ["Mahina"])
      assert_equal :points, scene.updatePoints, "the screen's own updatePoints runs"
      parts = [t.t(:rem_dating_points, :name => "Kyle", :n => 2),
               t.t(:rem_dating_pair, :name => "Mahina", :n => 5, :req => 6, :tot => 7),
               t.t(:rem_dating_levels_seen, :list => "C"), t.t(:rem_dating_levels_pending, :list => "B, A")]
      assert_equal [[parts.join(". "), true]], SpeakCapture.log
    end
  end

  test "a support pair is said once while neither cursor moves" do
    with_dating_data do
      scene = DatingSimSupportScreen.new([["Kyle", []]], 0, ["Mahina"])
      2.times { scene.updatePoints }
      assert_equal 1, SpeakCapture.log.length
    end
  end

  test "a support pair with no requirement shows dashes, and a character without points is said by name" do
    t = PokeAccess::I18n
    with_dating_data(CHARS.merge("Ruby" => {})) do
      DatingSimSupportScreen.new([["Ruby", []]], 0, ["Mahina"], nil).updatePoints
      parts = ["Ruby", t.t(:rem_dating_pair, :name => "Mahina", :n => 5, :req => "----", :tot => 5),
               t.t(:rem_dating_levels_seen, :list => "C"), t.t(:rem_dating_levels_pending, :list => "B, A")]
      assert_equal [parts.join(". ")], SpeakCapture.lines
    end
  end

  test "a character with no partner in the list is said alone" do
    with_dating_data do
      DatingSimSupportScreen.new([["Kyle", []]], 0, []).updatePoints
      assert_equal [PokeAccess::I18n.t(:rem_dating_points, :name => "Kyle", :n => 2)], SpeakCapture.lines
    end
  end

  test "the support screen says nothing with its cursor off the characters" do
    with_dating_data do
      [[[["Kyle", []]], 1], [[["Kyle", []]], -1], [[["Kyle", []]], nil], [nil, 0]].each do |chars, idx|
        DatingSimSupportScreen.new(chars, idx, ["Mahina"]).updatePoints
      end
    end
    assert_nothing_spoken
  end

  test "a pair's levels: all seen, all to come, or none written" do
    t = PokeAccess::I18n
    {
      [%w[C B A], []] => t.t(:rem_dating_levels_seen, :list => "C, B, A"),
      [%w[C B A], nil] => t.t(:rem_dating_levels_seen, :list => "C, B, A"),
      [%w[C B], %w[C B]] => t.t(:rem_dating_levels_pending, :list => "C, B")
    }.each do |(written, pending), want|
      with_dating_data(CHARS, written, pending) do
        assert_equal want, PokeAccess::ReminDatingSim.support_levels("Kyle", "Mahina"), "#{written} with #{pending.inspect} to come"
      end
    end
    [[], nil].each do |written|
      with_dating_data(CHARS, written, []) do
        assert_nil PokeAccess::ReminDatingSim.support_levels("Kyle", "Mahina"), "#{written.inspect} written"
      end
    end
  end

  test "the build table keeps each count beside its own material, the key's arrow as a colon" do
    scene = DatingSimBuildScreen.new
    assert_equal :drawn, scene.drawDataWindow, "the table paints as the game's"
    assert_equal [[TABLE, true]], SpeakCapture.log
  end

  test "the same build table is not said twice" do
    scene = DatingSimBuildScreen.new
    scene.drawDataWindow
    SpeakCapture.clear
    scene.drawDataWindow
    assert_nothing_spoken
  end

  test "a switched build tab is named before its table, even an unchanged one, and the first tab is not" do
    t = PokeAccess::I18n
    scene = DatingSimBuildScreen.new
    [0, 1, 0].each do |tab|
      scene.instance_variable_set(:@indexTask, tab)
      assert_equal :moved, scene.setWindowSelect, "the screen's own setWindowSelect runs"
      scene.drawDataWindow
    end
    assert_equal [TABLE, "#{t.t(:rem_build_tab_goal)}. #{TABLE}", "#{t.t(:rem_build_tab_all)}. #{TABLE}"],
                 SpeakCapture.lines
  end

  test "each material row says how many the dating bag holds, a single row counting the objective's" do
    counts = { :SAND => 3, :SHELL => 0, :COLLAR => 1 }
    GameFunctions.with(:datingBagQuantity => lambda { |key| counts[key] }) do
      with_player(5, 40, [[:COLLAR, 1]]) do
        list = Window_CommandPokemonCraftSim.new(%w[Arena Concha], [:SAND, :SHELL])
        objective = Window_CommandPokemonCraftSim.new(%w[Collar])
        rows = [0, 1].map { |i| list.index = i; PokeAccess::Menus.focused_text(list) }
        assert_equal ["Arena: 3", "Concha: 0", "Collar: 1"], rows + [PokeAccess::Menus.focused_text(objective)]
      end
    end
  end

  test "a material row whose count is unknown is said by name, and a row past the list not at all" do
    GameFunctions.with(:datingBagQuantity => lambda { |_key| nil }) do
      list = Window_CommandPokemonCraftSim.new(%w[Arena Concha], [:SAND, :SHELL])
      assert_equal "Arena", PokeAccess::Menus.focused_text(list), "no count in the bag"
      untranslated = Window_CommandPokemonCraftSim.new(%w[Arena Concha])
      assert_equal "Arena", PokeAccess::Menus.focused_text(untranslated), "no translation list"
      assert_equal "Collar", PokeAccess::Menus.focused_text(Window_CommandPokemonCraftSim.new(%w[Collar])),
                   "an objective the player has not set"
      list.index = 2
      assert_nil PokeAccess::Menus.focused_text(list), "past the list"
    end
  end

  private

  # The task panel the stand-in paints, as said with a cleanliness of 40.
  def task_panel
    t = PokeAccess::I18n
    "Playa: Ánimo -1. Material Objetivo. #{t.t(:rem_task_needed, :item => 'Arena')}. Concha. COMENZAR: C. " \
      "#{t.t(:rem_clean_pct, :n => 40)}"
  end

  # Runs the block with a player holding the dating sim's counters, the one before put back after.
  def with_player(days, clean, objective = nil)
    saved = $Trainer
    $Trainer = Player.new(days, clean, objective)
    yield
  ensure
    $Trainer = saved
  end

  # Runs the block with the game's dating functions answering: each character's counters, and a pair's support
  # levels written and still to come.
  def with_dating_data(levels = CHARS, written = %w[C B A], pending = %w[B A])
    GameFunctions.with(:datingGet => lambda { |name, get| (levels[name] || {})[get] },
                       :supportWrite => lambda { |_name, _partner| written },
                       :supportCheck => lambda { |_name, _partner| pending }) { yield }
  end

  # Runs the block with the game's date places (DATING_PLACES, by strip order), taken away after.
  def with_places(places)
    Object.const_set(:DATING_PLACES, places)
    yield
  ensure
    Object.send(:remove_const, :DATING_PLACES)
  end
end
