# Fire Ash's save-file picker (Multiple save v.19 plugin, ScreenChooseFileSave): the files under a moving panel, the
# chosen file's painted page with the team its icons show, and the load page's two options; the stand-in paints as
# the plugin's drawInfor does. Also its save menu, whose Cancel builds the summary panel and closes it unseen.

# A team icon of the file's page (PokemonIconSprite), which keeps the Pokemon it draws.
MsvIcon = Struct.new(:pokemon)

class ScreenChooseFileSave
  attr_reader :loads

  def initialize(count, gift = false, party = [])
    @count = count; @position = 0; @posinfor = 0; @gift = gift; @party = party; @loads = 0; @sprites = {}
  end
  def fileLoad; @loads += 1; nil; end
  def textPanel(_font = nil); :painted; end
  def drawInfor(type, _font = nil)
    x = 48; y = 32
    title = (type == 0) ? "Save" : (type == 1) ? "Load" : "Delete"
    rows = [[title, 32 + x, 10 + y, 0], ["Badges:", 32 + x, 112 + y, 0], ["3", 206 + x, 112 + y, 1],
            ["Pokédex:", 32 + x, 144 + y, 0], ["45", 206 + x, 144 + y, 1], ["Time:", 32 + x, 176 + y, 0],
            ["1h 2m", 206 + x, 176 + y, 1], ["Ceniza", 112 + x, 64 + y, 0], ["Pueblo Ceniza", 386 + x, 10 + y, 1]]
    rows.push(["Mystery Gift", x + 44, y + 229, 0]) if type == 1 && @gift
    pbDrawTextPositions(nil, rows)
    @party.each_with_index { |pk, i| @sprites["party#{i}"] = MsvIcon.new(pk) }
    :drawn
  end
  def choosePanelInfor; :moved; end
  def move(pos); @position = pos; textPanel; end
  def option(i); @posinfor = i; choosePanelInfor; end
end

# The plugin's save-menu question, answering what the spec puts in $pa_msv_answer.
def pbCustomMessageForSave(_message, _commands, _index)
  $pa_msv_answer
end

# The reader loads again over these, which the harness did not have yet; warnings off for its constants.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  require File.expand_path("../../../plugins/multi_save_v19", File.dirname(__FILE__))
ensure
  $VERBOSE = verbose
end

Suite.define("fire ash save picker: the files, the chosen file's page, and the load options are read") do
  t = PokeAccess::I18n
  screen = ScreenChooseFileSave.new(3, true)

  screen.textPanel
  eq "opening says the focused file and how many there are, queued behind the question that opened it",
     SpeakCapture.log, [[t.t(:load_slot, :n => 1, :tot => 3), false]]

  SpeakCapture.clear
  screen.move(1)
  eq "moving says the next one, cutting the last", SpeakCapture.log, [[t.t(:load_slot, :n => 2, :tot => 3), true]]
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  screen.move(2)
  eq "brief: the file by its number alone", SpeakCapture.lines, [t.t(:load_slot_bare, :n => 3)]
  PokeAccess::Config.verbosity = :full
  screen.move(1)
  SpeakCapture.clear
  screen.textPanel
  silent "a repaint on the same file says nothing"

  SpeakCapture.clear
  eq "the page keeps its own return", screen.drawInfor(1), :drawn
  eq "the page as painted: what Enter does, then each line top to bottom, the gift row last", SpeakCapture.lines,
     ["Load. Pueblo Ceniza. Ceniza. Badges: 3. Pokédex: 45. Time: 1h 2m. Mystery Gift"]
  eq "and the save file is not loaded again to say it", screen.loads, 0

  SpeakCapture.clear
  screen.option(1)
  eq "the row under the page is the Mystery Gift", SpeakCapture.lines, [t.t(:msv_gift)]
  SpeakCapture.clear
  screen.option(0)
  eq "and the page itself continues the game", SpeakCapture.lines, [t.t(:msv_continue)]

  SpeakCapture.clear
  screen.drawInfor(0)
  truthy "a save page says it saves over the file", SpeakCapture.lines.join(" ").index("Save.") == 0
  SpeakCapture.clear
  screen.textPanel
  eq "back on the list, the file is read again", SpeakCapture.lines, [t.t(:load_slot, :n => 2, :tot => 3)]
end

Suite.define("fire ash save picker: a file's page says the team its icons show, before the rows under the page") do
  t = PokeAccess::I18n
  egg = Poke.build(:species => 4)
  def egg.egg?; true; end
  screen = ScreenChooseFileSave.new(1, true, [Poke.build(:species => 1), Poke.build(:species => 25), egg])
  team = t.t(:load_party, :list => [PokeAccess::Data.species_name(1).to_s, PokeAccess::Data.species_name(25).to_s,
                                    t.t(:pty_egg)].join(", "))
  SpeakCapture.clear
  screen.drawInfor(1)
  eq "the page's lines, then the team, then the gift row under the page", SpeakCapture.lines,
     ["Load. Pueblo Ceniza. Ceniza. Badges: 3. Pokédex: 45. Time: 1h 2m. #{team}. Mystery Gift"]
  eq "and the save file is not loaded again to say it", screen.loads, 0
end

# The menu asks Save, Delete or Cancel first and builds the summary panel for Save and Cancel alike; Cancel (or back)
# disposes it before a frame is drawn.
Suite.define("fire ash save menu: the summary panel is read only when Save leaves it on screen") do
  scene = PokemonSave_Scene.new
  $pa_msv_answer = 2
  pbCustomMessageForSave("What do you want to do?", ["Save", "Delete", "Cancel"], 3)
  SpeakCapture.clear
  scene.pbStartScreen
  scene.pbEndScreen
  silent "Cancel or back: the panel closes unseen, and nothing of it is read"

  $pa_msv_answer = 0
  pbCustomMessageForSave("What do you want to do?", ["Save", "Delete", "Cancel"], 3)
  SpeakCapture.clear
  scene.pbStartScreen
  eq "Save: the panel stays up under the next question, and is read queued", SpeakCapture.log,
     [["Ruta 5, Player, Ceniza, Time, 3h 12m, Badges, 3", false]]
  scene.pbEndScreen
end
