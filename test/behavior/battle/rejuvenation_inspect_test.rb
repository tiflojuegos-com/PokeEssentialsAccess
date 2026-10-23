# Rejuvenation's Inspect report: its rows' type and status icons said as the types' names and the status's word, in
# the focused row and in the whole report on the info key; Ctrl's team preview, the game's own reader, runs relayed.
Harness.load_common("rv_common")

# The report's list, as Rejuvenation names its window.
class Window_AdvancedCommandPokemon_NoPageScroll < Window_AdvancedCommandPokemon; end

# The game's team preview, which hands its own reader the team; here it answers whether it ran as a relayed screen.
def ttsPartyPreview(_pkmnindex)
  PokeAccess::OwnVoiceRV.relaying?
end

class RejuvenationInspectTest < PokeAccessTest
  # The game's getTypeName, which answers "" for a type it has no name for.
  TYPE_NAMES = { :getTypeName => lambda { |t| { :FIRE => "Fire", :FLYING => "Flying" }[t].to_s } }
  # The message window above the list.
  Box = Struct.new(:text)
  # The rows a report on Talonflame paints.
  ROWS = ["Typing: <icon=typeFIRE> <icon=typeFLYING>", "Next <img=Graphics/Pictures/Party/statusPOISON> Dmg: 6.3%",
          "<img=Graphics/Pictures/Party/statusSLEEP> Turns: 2", "Speed:  40  +1"]

  class << self
    # The profile's report_text, kept aside by load_profile.
    attr_reader :report
  end

  # Evaluates the profile file once, as boot does. Its report_text is kept aside and core's put back, so the other
  # tests of the process keep core's; with_profile_report puts the profile's in for a test.
  def self.load_profile
    meta = PokeAccess::InspectRV.singleton_class
    core = meta.instance_method(:report_text)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "inspect.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @report = meta.instance_method(:report_text)
  ensure
    meta.send(:define_method, :report_text, core)
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "a run of type icons is said as the types' names, as a list" do
    assert_equal "Typing: Fire, Flying", focused_row(0)
  end

  test "a status icon is said as the status's word, mid-row or opening it" do
    rows = { 1 => "Next #{PokeAccess::I18n.t(:st_poison)} Dmg: 6.3%", 2 => "#{PokeAccess::I18n.t(:st_sleep)} Turns: 2" }
    rows.each { |i, want| assert_equal want, focused_row(i), "row #{i}" }
  end

  test "a row with no icon is said as painted, its padding collapsed" do
    assert_equal "Speed: 40 +1", focused_row(3)
  end

  test "a type the game has no name for is said by its id" do
    assert_equal "Added: Shadow, Fire", focused_row(0, ["Added: <icon=typeSHADOW><icon=typeFIRE>"])
  end

  test "with the game's type names failing, the row is read as the window lists it" do
    failing = { :getTypeName => lambda { |_t| raise ArgumentError, "no type table" } }
    assert_equal ROWS[0], focused_row(0, ROWS, failing)
  end

  test "a cursor past the last row reads nothing" do
    assert_nil focused_row(4)
  end

  test "the info key's report says the message, then each row with its icons worded" do
    text = with_profile_report { PokeAccess::InspectRV.report_text(Box.new("Inspecting Talonflame:"), ROWS[0, 2]) }
    assert_equal "Inspecting Talonflame: Typing: Fire, Flying. Next #{PokeAccess::I18n.t(:st_poison)} Dmg: 6.3%", text
  end

  test "a report whose message window says nothing is its rows alone" do
    [Box.new(nil), Object.new].each do |box|
      assert_equal "Typing: Fire, Flying", with_profile_report { PokeAccess::InspectRV.report_text(box, ROWS[0, 1]) },
                   "for #{box.inspect}"
    end
  end

  test "Ctrl's team preview runs as a relayed screen, which ends with it" do
    seen = with_relay(true) { [ttsPartyPreview(1), PokeAccess::OwnVoiceRV.relaying?] }
    assert_equal [true, false], seen, "relayed while it runs, and no longer once it returns"
  end

  test "with no relay installed, the team preview is left to the game" do
    assert_equal false, with_relay(false) { ttsPartyPreview(1) }
  end

  private

  # The report list's focused row as the reader says it, the cursor on row i of rows, the game naming its types by
  # names.
  def focused_row(i, rows = ROWS, names = TYPE_NAMES)
    win = Window_AdvancedCommandPokemon_NoPageScroll.new(rows)
    win.index = i
    GameFunctions.with(names) { PokeAccess::Menus.focused_text(win) }
  end

  # The block's value with the profile's report_text in core's place and the game's type names in place.
  def with_profile_report
    meta = PokeAccess::InspectRV.singleton_class
    core = meta.instance_method(:report_text)
    meta.send(:define_method, :report_text, self.class.report)
    GameFunctions.with(TYPE_NAMES) { yield }
  ensure
    meta.send(:define_method, :report_text, core)
  end

  # The block's value with the game's reader relay installed (a profile's own_voice installs it) or not.
  def with_relay(installed)
    v = PokeAccess::OwnVoiceRV
    was = v.instance_variable_get(:@active)
    v.instance_variable_set(:@active, installed)
    yield
  ensure
    v.instance_variable_set(:@active, was)
  end
end
