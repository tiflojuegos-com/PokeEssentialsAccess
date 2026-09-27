# Reminiscencia's dating sim over stand-ins for its screens, defined before the profile files load once: the build
# table keeps each count beside its material and names a switched tab, the support pairs say their levels, the task
# list says each character's levels and mood, its panel the flags and the cleanliness, and the day and cleanliness
# lines come from lang/.
module RemDatingFixture
  CHARS = { "Kyle" => { "worklevel" => 3, "cleanlevel" => 1, "status" => 4, "fpPoints" => 2 },
            "Mahina" => { "worklevel" => 2, "cleanlevel" => 1, "status" => 3, "fpPoints" => 5 } }

  BUILD = [["Collar Elemental", 480, 142], ["Material", 352, 178], ["Obtenido / Necesario", 442, 178],
           ["CONSTRUIR -> C", 480, 388], ["Roca de Rockruff", 352, 204], ["0/1", 618, 204],
           ["Tela de Shuppet", 352, 230], ["0/1", 618, 230], ["Perla de Shellder", 352, 256], ["0/1", 618, 256]]

  PANEL = [["Playa -> Ánimo-1", 160, 182], ["Material", 58, 220], ["Objetivo", 258, 220], ["COMENZAR -> C", 96, 430],
           ["Arena", 24, 246], ["Concha", 24, 272], ["---------", 24, 298]]
  FLAGS = [["Graphics/Pictures/DatingSimStuff/flag_objective", 280, 250, 0, 0, -1, -1]]

  Player = Struct.new(:dateDays, :dateSimClean)

  # Runs the block with a player that has the dating sim's counters, restoring the one before.
  def self.with_player(days, clean)
    saved = $Trainer
    $Trainer = Player.new(days, clean)
    yield
  ensure
    $Trainer = saved
  end
end

def datingGet(name, get); (RemDatingFixture::CHARS[name] || {})[get]; end unless Object.private_method_defined?(:datingGet)
def supportWrite(_a, _b); %w[C B A]; end unless Object.private_method_defined?(:supportWrite)
def supportCheck(_a, _b); %w[B A]; end unless Object.private_method_defined?(:supportCheck)

class DatingSimBuildScreen
  def setWindowSelect; :moved; end
  def drawDataWindow; pbDrawTextPositions(nil, RemDatingFixture::BUILD); end
end

class DatingSimSupportScreen
  def updatePoints; :points; end
  def getTotalPoints(_a, _b); 6; end
end

class DatingSimTaskScreen
  def drawDataWindow
    pbDrawTextPositions(nil, RemDatingFixture::PANEL)
    pbDrawImagePositions(nil, RemDatingFixture::FLAGS)
  end
  def inputs; :inputs; end
  def setGenderPage; :gender; end
end

class SlideDay
  def initialize(_loop = nil, _forward = true); end
end

class Window_CommandPokemonDatingSim
  attr_accessor :index
  def initialize(cmds); @commands = cmds; @index = 0; end
end

load File.join(Harness::ROOT, "games", "reminiscencia", "datingsim.rb")
load File.join(Harness::ROOT, "games", "reminiscencia", "datingsim_place.rb")

Suite.define("reminiscencia dating sim: the build table keeps each count beside its own material") do
  scene = DatingSimBuildScreen.new
  scene.instance_variable_set(:@indexTask, 0)
  SpeakCapture.clear
  scene.drawDataWindow
  eq "row by row, as painted, the key's arrow as a colon",
     SpeakCapture.lines, ["Collar Elemental. Material Obtenido / Necesario. Roca de Rockruff 0/1. " \
                          "Tela de Shuppet 0/1. Perla de Shellder 0/1. CONSTRUIR: C"]
  SpeakCapture.clear
  scene.drawDataWindow
  silent "the same table is not said twice"
end

Suite.define("reminiscencia dating sim: a switched build tab is named before its table") do
  t = PokeAccess::I18n
  scene = DatingSimBuildScreen.new
  scene.instance_variable_set(:@indexTask, 0)
  scene.setWindowSelect
  scene.drawDataWindow
  SpeakCapture.clear
  scene.instance_variable_set(:@indexTask, 1)
  scene.setWindowSelect
  scene.drawDataWindow
  truthy "the objective tab leads, even over an unchanged table", SpeakCapture.last.to_s.start_with?("#{t.t(:rem_build_tab_goal)}. Collar Elemental")
  SpeakCapture.clear
  scene.instance_variable_set(:@indexTask, 0)
  scene.setWindowSelect
  scene.drawDataWindow
  truthy "and back to every recipe", SpeakCapture.last.to_s.start_with?(t.t(:rem_build_tab_all))
end

Suite.define("reminiscencia dating sim: a support pair says which levels it has seen and which are to come") do
  t = PokeAccess::I18n
  scene = DatingSimSupportScreen.new
  scene.instance_variable_set(:@characters, [["Kyle", []]])
  scene.instance_variable_set(:@index, 0)
  scene.instance_variable_set(:@cmdwindow, Struct.new(:index, :commands).new(0, ["Mahina"]))
  SpeakCapture.clear
  scene.updatePoints
  line = SpeakCapture.last.to_s
  truthy "the levels seen, teal on screen", line.include?(t.t(:rem_dating_levels_seen, :list => "C"))
  truthy "and the ones to come, dark red", line.include?(t.t(:rem_dating_levels_pending, :list => "B, A"))
end

Suite.define("reminiscencia dating sim: a task row says the levels and the mood its icons show") do
  t = PokeAccess::I18n
  win = Window_CommandPokemonDatingSim.new(["Kyle", "Mahina"])
  win.index = 1
  eq "name, work and cleaning levels, mood of four", PokeAccess::Menus.focused_text(win),
     t.t(:rem_dating_row, :name => "Mahina", :work => 2, :clean => 1, :mood => 3)
end

Suite.define("reminiscencia dating sim: the task panel with its flags and the cleanliness, from lang/") do
  t = PokeAccess::I18n
  RemDatingFixture.with_player(5, 40) do
    PokeAccess::Config.language = :en
    scene = DatingSimTaskScreen.new
    scene.instance_variable_set(:@index, 3)
    scene.instance_variable_set(:@cmdwindow, Struct.new(:index).new(0))
    scene.drawDataWindow
    SpeakCapture.clear
    scene.inputs
    eq "the place and its mood, each material, the flagged one marked, the key, the cleanliness",
       SpeakCapture.lines, ["Playa: Ánimo -1. Material Objetivo. #{t.t(:rem_task_needed, :item => 'Arena')}. Concha. " \
                            "COMENZAR: C. #{t.t(:rem_clean_pct, :n => 40)}"]
    truthy "in the mod's language", SpeakCapture.last.to_s.include?("Cleanliness: 40 percent")
  end
end

Suite.define("reminiscencia dating sim: the day and the results' cleanliness speak the mod's language") do
  RemDatingFixture.with_player(5, 40) do
    PokeAccess::Config.language = :en
    SpeakCapture.clear
    SlideDay.new(nil, false)
    eq "a day that went back", SpeakCapture.lines, ["Day 5, going back"]
    SpeakCapture.clear
    SlideDay.new(nil, true)
    eq "a day forward", SpeakCapture.lines, ["Day 5"]
    eq "the results' bar as a number", PokeAccess::ReminDatingSim.results_text(["Results", "OranBerryx2"]),
       "Results, OranBerryx2. Cleanliness: 40 percent"
  end
end
