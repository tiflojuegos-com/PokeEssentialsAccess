# Cable Club 1.11 (plugins/cable_club.rb) over stand-ins of Sevii's v16 script, driven without its server: the question
# over each menu and text field, the messages, the waiting dots said once until the box shows something else, and the
# team preview with its countdown.

# The scene's writers, each blocking in the game; its ID field, without Anil's character check, answers what was typed.
class SeviiCableClubStub
  def pbShowCommands(_helptext, _commands, _cmd_if_cancel = 0); 0; end
  def pbDisplay(_text); :displayed; end
  def pbDisplayDots(_text); :dots; end
  def pbHideMessageBox; :hidden; end
  def pbEnterText(_helptext, _starttext, _passwordbox, _maxlength); "12345"; end
end

# The v16 preview card: both teams painted at once, and the countdown a timer window shows, refreshed each frame.
class SeviiTeamPreviewStub
  def initialize; @sprites = { "timer" => Struct.new(:text).new("") }; end
  def pbDrawTeamPreviewText(_l, _r, _lp, _rp); :drawn; end
  def update; end
  def tick(text); @sprites["timer"].text = text; update; end
end

# The plugin binds to both stand-ins under the scenes' names, taken away again so no other test finds the plugin.
begin
  scenes = { :TeamPreview_Scene => SeviiTeamPreviewStub, :CableClub_Scene => SeviiCableClubStub }
  scenes.each { |name, stub| Object.const_set(name, stub) }
  path = File.join(Harness::ROOT, "plugins", "cable_club.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  scenes.each_key { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
end

class CableClubTest < PokeAccessTest
  # A party member as the v16 card reads it: the item a number, 0 for none.
  Mon = Struct.new(:name, :gender, :item, :mail)
  ID_QUESTION = "What's the ID of the Trainer you're searching for? (Your ID: 04336)"
  PICK = "Waiting for Ash to pick an activity"

  test "says the question over a yes/no before its options, queued, and keeps the choice" do
    choice = SeviiCableClubStub.new.pbShowCommands("Ash wants to trade!", ["Yes", "No"], 2)
    assert_equal [0, [["Ash wants to trade!", false]]], [choice, SpeakCapture.log]
  end

  test "says a question on two lines as one, as the box paints it" do
    options = ["See Details", "Yes", "No"]
    SeviiCableClubStub.new.pbShowCommands("Ash wants to battle!\nServer Ruleset: Single", options, 3)
    assert_equal ["Ash wants to battle! Server Ruleset: Single"], SpeakCapture.lines
  end

  test "says each message the box displays, queued, and keeps its return" do
    ret = SeviiCableClubStub.new.pbDisplay("The online server is down at the moment.")
    assert_equal [:displayed, [["The online server is down at the moment.", false]]], [ret, SpeakCapture.log]
  end

  test "says the waiting line once, its two lines as one, however often its dots are redrawn" do
    club = SeviiCableClubStub.new
    rets = Array.new(3) { club.pbDisplayDots("Your ID: 04336\nSearching") }
    assert_equal [[:dots] * 3, [["Your ID: 04336 Searching", false]]], [rets, SpeakCapture.log]
  end

  test "says the waiting line again once a declined battle has asked its question in the box" do
    club = SeviiCableClubStub.new
    club.pbDisplayDots(PICK)
    club.pbShowCommands("Ash wants to battle!\nQuick Ruleset: Single Battle", ["See Details", "Yes", "No"], 3)
    club.pbDisplayDots(PICK)
    assert_equal [PICK, "Ash wants to battle! Quick Ruleset: Single Battle", PICK], SpeakCapture.lines
  end

  test "says the waiting line again after a message, a text field or the box hidden in between" do
    { :message => lambda { |c| c.pbDisplay("Ash connected!") },
      :field => lambda { |c| c.pbEnterText(ID_QUESTION, "", false, 5) },
      :hidden => lambda { |c| c.pbHideMessageBox } }.each do |between, act|
      SpeakCapture.clear
      club = SeviiCableClubStub.new
      club.pbDisplayDots(PICK)
      act.call(club)
      club.pbDisplayDots(PICK)
      assert_equal [PICK, PICK], SpeakCapture.lines.select { |l| l == PICK }, "after the #{between}"
    end
  end

  test "says nothing for the box hidden, and keeps its return" do
    assert_equal :hidden, SeviiCableClubStub.new.pbHideMessageBox
    assert_nothing_spoken
  end

  test "says the ID field's question and that the field is empty as it first opens, queued" do
    typed = SeviiCableClubStub.new.pbEnterText(ID_QUESTION, "", false, 5)
    assert_equal ["12345", [["#{ID_QUESTION}. #{PokeAccess::I18n.t(:row_empty)}", false]]], [typed, SpeakCapture.log]
  end

  test "says what the field already holds as it reopens with a rejected ID" do
    SeviiCableClubStub.new.pbEnterText(ID_QUESTION, "123", false, 5)
    assert_equal ["#{ID_QUESTION}. #{PokeAccess::I18n.t(:nm_current, :t => "123")}"], SpeakCapture.lines
  end

  test "reads both teams as the card is drawn, each member's sign and held item as the card shows them" do
    preview("Red", "Ash", [Mon.new("Pikachu", 0, 0), Mon.new("Lapras", 1, 213)], [Mon.new("Magnemite", 2, 0)])
    lapras = PokeAccess::I18n.t(:cc_preview_holds, :name => "Lapras ♀")
    assert_equal [["#{team("Red", "Pikachu ♂, #{lapras}")}. #{team("Ash", "Magnemite")}", false]], SpeakCapture.log
  end

  test "says a member holding a letter by the letter's own icon" do
    preview("Red", "Ash", [Mon.new("Eevee", 1, 122, :mail)], [Mon.new("Pikachu", 0, 0)])
    eevee = PokeAccess::I18n.t(:cc_preview_mail, :name => "Eevee ♀")
    assert_equal ["#{team("Red", eevee)}. #{team("Ash", "Pikachu ♂")}"], SpeakCapture.lines
  end

  test "keeps the card's own return" do
    assert_equal :drawn, preview("Red", "Ash", [], [])
  end

  test "says the countdown as painted on its first second, and nothing on the seconds after" do
    card = SeviiTeamPreviewStub.new
    ["<ac>01:30", "<ac>01:29", "<ac>00:00"].each { |t| card.tick(t) }
    assert_equal [["01:30", false]], SpeakCapture.log
  end

  test "says nothing for the timer left blank while the card fades in" do
    SeviiTeamPreviewStub.new.tick("")
    assert_nothing_spoken
  end

  private

  # Draws a preview card for the two trainers and their parties, answering the card's return.
  def preview(left, right, left_party, right_party)
    SeviiTeamPreviewStub.new.pbDrawTeamPreviewText(left, right, left_party, right_party)
  end

  # A trainer's team as the preview says it.
  def team(trainer, members)
    PokeAccess::I18n.t(:cc_preview_team, :trainer => trainer, :team => members)
  end
end
