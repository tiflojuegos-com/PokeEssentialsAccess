# Fire Ash's save-file picker (Multiple save v.19): the files under a moving panel, the chosen file's page and team,
# the load page's two options, and the save menu's summary panel, read only when Save leaves it on screen.

# The plugin's file picker, painting its page as its drawInfor does.
class ScreenChooseFileSave
  # A team icon of the file's page (PokemonIconSprite), which keeps the Pokemon it draws.
  Icon = Struct.new(:pokemon)

  attr_reader :loads
  # Rows painted with the page besides the plugin's own, as [text, y], for the page's edge.
  attr_accessor :extra

  def initialize(count, gift = false, party = [])
    @count = count; @position = 0; @posinfor = 0; @gift = gift; @party = party; @loads = 0; @sprites = {}; @extra = []
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
    @extra.each { |text, row_y| rows.push([text, x + 44, row_y, 0]) }
    pbDrawTextPositions(nil, rows)
    @party.each_with_index { |pk, i| @sprites["party#{i}"] = Icon.new(pk) }
    :drawn
  end
  def choosePanelInfor; :moved; end
  def move(pos); @position = pos; textPanel; end
  def option(i); @posinfor = i; choosePanelInfor; end
end

# The plugin's save-menu question, answering what the test puts in $pa_msv_answer.
def pbCustomMessageForSave(_message, _commands, _index)
  $pa_msv_answer
end

# The reader is evaluated again over the stand-ins above, which the harness did not have when it loaded it; warnings
# off for its constants.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "plugins", "multi_save_v19.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

class MultiSaveV19GdTest < PokeAccessTest
  # The lines of the stand-in's page under its title, as the page lays them out top to bottom.
  PAGE = "Pueblo Ceniza. Ceniza. Badges: 3. Pokédex: 45. Time: 1h 2m"
  # The save scene stub's summary panel, as its markup reads cleaned.
  PANEL = "Ruta 5, Player, Ceniza, Time, 3h 12m, Badges, 3"

  test "opening the picker says the focused file and how many there are, queued behind the question" do
    ScreenChooseFileSave.new(3).textPanel
    assert_equal [[t(:load_slot, :n => 1, :tot => 3), false]], SpeakCapture.log
  end

  test "moving says the file now focused, interrupting" do
    opened(3).move(1)
    assert_equal [[t(:load_slot, :n => 2, :tot => 3), true]], SpeakCapture.log
  end

  test "a file is said with how many there are down to medium, by its number alone in brief" do
    said = vb_levels do
      SpeakCapture.clear
      ScreenChooseFileSave.new(3).textPanel
      SpeakCapture.lines
    end
    full = t(:load_slot, :n => 1, :tot => 3)
    assert_equal [[t(:load_slot_bare, :n => 1)], [full], [full]], said
  end

  test "a repaint on the same file says nothing" do
    opened(3).textPanel
    assert_nothing_spoken
  end

  test "the load page is read as painted, interrupting: what Enter does, each line top to bottom, the gift row last" do
    opened(3, true).drawInfor(1)
    assert_equal [["Load. #{PAGE}. Mystery Gift", true]], SpeakCapture.log
  end

  test "each page starts with what Enter does on it" do
    { 0 => "Save", 2 => "Delete" }.each do |type, title|
      opened(3, true).drawInfor(type)
      assert_equal ["#{title}. #{PAGE}"], SpeakCapture.lines, "page type #{type}"
    end
  end

  test "the team its icons show follows the page's lines and goes before the rows under the page" do
    egg = Poke.build(:species => 4)
    def egg.egg?; true; end
    opened(1, true, [Poke.build(:species => 1), Poke.build(:species => 25), egg]).drawInfor(1)
    team = t(:load_party, :list => "Species1, Species25, #{t(:pty_egg)}")
    assert_equal ["Load. #{PAGE}. #{team}. Mystery Gift"], SpeakCapture.lines
  end

  test "a row on the page's last line is read with the page, one just under it after the team" do
    screen = opened(1, false, [Poke.build(:species => 25)])
    screen.extra = [["Fila 254", 254], ["Fila 255", 255]]
    screen.drawInfor(1)
    team = t(:load_party, :list => "Species25")
    assert_equal ["Load. #{PAGE}. Fila 254. #{team}. Fila 255"], SpeakCapture.lines
  end

  test "reads the page off its paint, without loading the save file again" do
    screen = opened(3, true)
    screen.drawInfor(1)
    assert_equal 0, screen.loads
  end

  test "hands the game the page's own return value" do
    assert_equal :drawn, opened(3).drawInfor(1)
  end

  test "the load page's highlight continues the game on the page and opens the Mystery Gift on the row under it" do
    screen = opened(3, true)
    screen.drawInfor(1)
    { 1 => t(:msv_gift), 0 => t(:msv_continue) }.each do |row, want|
      SpeakCapture.clear
      screen.option(row)
      assert_equal [[want, true]], SpeakCapture.log, "the highlight on row #{row}"
    end
  end

  test "back on the list after a page, the focused file is read again, queued" do
    screen = opened(3)
    screen.move(1)
    screen.drawInfor(1)
    SpeakCapture.clear
    screen.textPanel
    assert_equal [[t(:load_slot, :n => 2, :tot => 3), false]], SpeakCapture.log
  end

  test "the save menu's summary panel is read, queued, only when Save leaves it on screen" do
    { "no question asked" => [nil, [[PANEL, false]]], "Save" => [0, [[PANEL, false]]], "Delete" => [1, []],
      "Cancel or back" => [2, []] }.each do |what, (answer, want)|
      after_answer(answer) { PokemonSave_Scene.new.pbStartScreen }
      assert_equal want, SpeakCapture.log, what
    end
  end

  private

  # The mod's line for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A picker of count files opened on the first, its opening read cleared.
  def opened(count, gift = false, party = [])
    screen = ScreenChooseFileSave.new(count, gift, party)
    screen.textPanel
    SpeakCapture.clear
    screen
  end

  # Runs the block once the save menu's first question was answered with answer (nil: no question asked), the spoken
  # log cleared first; the answer is forgotten afterwards.
  def after_answer(answer)
    PokeAccess::MultiSaveV19.note_answer(nil)
    unless answer.nil?
      $pa_msv_answer = answer
      pbCustomMessageForSave("What do you want to do?", ["Save", "Delete", "Cancel"], 3)
    end
    SpeakCapture.clear
    yield
  ensure
    $pa_msv_answer = nil
    PokeAccess::MultiSaveV19.note_answer(nil)
  end
end
