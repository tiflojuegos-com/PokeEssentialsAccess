# Soulstones 2's "Who are you?" Left/Right choice under two portraits: as it opens, each side is said with the
# portrait standing on it, queued; any other choice, or any other number of portraits, says nothing.

# One command of an event's list, as the interpreter reads it: its parameters (for Show Choices, the rows and the
# cancel row).
class SS2IntroCommand
  attr_reader :parameters
  def initialize(params); @parameters = params; end
end

# Soulstones 2's Interpreter, bound under the game's name: command_102 opens the choice of the command at @index, and
# the stand-in keeps what had been said by the time it opened.
class SS2IntroInterpreter
  attr_reader :heard_at_open
  def initialize(list); @list = list; @index = 0; end
  def command_102
    @heard_at_open = SpeakCapture.lines.dup
    :choice
  end
end

# Soulstones 2's screen: a hundred pictures, numbered from 1, the map's up to 50 and the battle's from 51.
class SS2IntroScreen
  attr_reader :pictures
  def initialize; @pictures = [nil] + (1..100).map { |i| Game_Picture.new(i) }; end
end

class Ss2IntroGenderGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "soulstones2", "intro_gender.rb")
  PORTRAITS = [["introGirl", 450], ["introBoy", 250]].freeze

  # Evaluates the profile's reader once per process with the stand-in under the game's class name, so its hook binds
  # to the stand-in and stays there; the name and the profile list are put back after.
  def self.bind_reader
    prior = Object.const_defined?(:Interpreter) ? Object.send(:remove_const, :Interpreter) : nil
    profiles = PokeAccess::Game.profiles.dup
    Object.const_set(:Interpreter, SS2IntroInterpreter)
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    Object.send(:remove_const, :Interpreter) if Object.const_defined?(:Interpreter)
    Object.const_set(:Interpreter, prior) if prior
    PokeAccess::Game.profiles.replace(profiles)
  end
  bind_reader

  test "a Left/Right choice says the portrait standing on each side, left to right, queued" do
    { [450, 250] => sides(:ap_boy, :ap_girl), [100, 300] => sides(:ap_girl, :ap_boy) }.each do |(girl_x, boy_x), want|
      assert_equal [[want, false]], said(["Left", "Right"], ["introGirl", girl_x], ["introBoy", boy_x]),
                   "the girl at x #{girl_x}, the boy at x #{boy_x}"
    end
  end

  test "the sides are said before the choice opens, ahead of its rows" do
    choice = interpreter(["Left", "Right"])
    run_choice(screen_with(*PORTRAITS), choice)
    assert_equal [sides(:ap_boy, :ap_girl)], choice.heard_at_open
  end

  test "the choice keeps the game's own return" do
    assert_equal :choice, interpreter(["Left", "Right"]).command_102
  end

  test "a choice of any other length says nothing" do
    [["Yes"], ["Yes", "No", "Maybe"]].each do |rows|
      assert_equal [], said(rows, *PORTRAITS), "#{rows.length} rows"
    end
  end

  test "it says nothing unless exactly two portraits are on screen" do
    one_left = screen_with(*PORTRAITS)
    one_left.pictures[5].erase
    three = screen_with(*(PORTRAITS + [["introGirl", 600]]))
    { "one, the other erased" => one_left, "three" => three }.each do |n, screen|
      assert_equal [], run_choice(screen, interpreter(["Left", "Right"])), n
    end
  end

  test "only the map's pictures are looked at: a portrait on 50 counts, one among the battle's, from 51, does not" do
    { 50 => [], 51 => [[sides(:ap_boy, :ap_girl), false]] }.each do |number, want|
      screen = screen_with(*PORTRAITS)
      screen.pictures[number].show("introGirl", 1, 600, 178)
      assert_equal want, run_choice(screen, interpreter(["Left", "Right"])), "a third portrait on picture #{number}"
    end
  end

  test "a picture that shows no portrait, or fails to give its name, is left out" do
    screen = screen_with(["introBg", 0], *PORTRAITS)
    broken = screen.pictures[7]
    broken.show("introGirl", 1, 50, 178)
    def broken.name; raise "disposed picture"; end
    assert_equal [[sides(:ap_boy, :ap_girl), false]], run_choice(screen, interpreter(["Left", "Right"]))
  end

  test "a portrait whose place cannot be read stands at the left edge" do
    screen = screen_with(*PORTRAITS)
    unplaced = screen.pictures[4]
    def unplaced.x; raise "disposed picture"; end
    assert_equal [[sides(:ap_girl, :ap_boy), false]], run_choice(screen, interpreter(["Left", "Right"]))
  end

  test "no screen, or a choice it cannot read, says nothing" do
    portraits = screen_with(*PORTRAITS)
    { "no screen" => [nil, interpreter(["Left", "Right"])],
      "no command list" => [portraits, SS2IntroInterpreter.new(nil)],
      "a command without parameters" => [portraits, SS2IntroInterpreter.new([SS2IntroCommand.new(nil)])]
    }.each do |what, (screen, choice)|
      assert_equal [], run_choice(screen, choice), what
    end
  end

  private

  # A screen with each [picture name, x] shown, in order, on pictures 4, 5, 6...
  def screen_with(*shown)
    screen = SS2IntroScreen.new
    shown.each_with_index { |(name, x), i| screen.pictures[4 + i].show(name, 1, x, 178) }
    screen
  end

  # An interpreter about to run a Show Choices command with these rows.
  def interpreter(rows)
    SS2IntroInterpreter.new([SS2IntroCommand.new([rows, 0])])
  end

  # What opening the choice says with screen as the game's, the screen put back after.
  def run_choice(screen, choice)
    was = $game_screen
    $game_screen = screen
    SpeakCapture.clear
    choice.command_102
    SpeakCapture.log.dup
  ensure
    $game_screen = was
  end

  # What a choice of these rows says over a screen showing these [picture name, x].
  def said(rows, *shown)
    run_choice(screen_with(*shown), interpreter(rows))
  end

  def sides(left, right)
    PokeAccess::I18n.t(:ss2_intro_sides, :left => PokeAccess::I18n.t(left), :right => PokeAccess::I18n.t(right))
  end
end
