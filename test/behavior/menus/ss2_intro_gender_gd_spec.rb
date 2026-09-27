# Soulstones 2's "Who are you?" Left/Right choice under two portraits: each side is said with the portrait on it as
# the choice opens. Gamedata pass; what Anil's picture texts, loaded there too, say of the portraits is cleared.
class SS2IntroCommand
  attr_reader :parameters
  def initialize(params); @parameters = params; end
end

class SS2IntroInterpreter
  def initialize(list); @list = list; @index = 0; end
  def command_102; :choice; end
end

class SS2IntroScreen
  attr_reader :pictures
  def initialize; @pictures = [nil] + (1..50).map { |i| Game_Picture.new(i) }; end
end

Suite.define("ss2 intro: the gender choice says which portrait stands on each side") do
  saved = Object.const_defined?(:Interpreter) ? Interpreter : nil
  saved_screen = $game_screen
  t = PokeAccess::I18n
  begin
    Object.send(:remove_const, :Interpreter) if saved
    Object.const_set(:Interpreter, SS2IntroInterpreter)
    load File.expand_path("../../../games/soulstones2/intro_gender.rb", File.dirname(__FILE__))
    $game_screen = SS2IntroScreen.new
    $game_screen.pictures[4].show("introGirl", 1, 450, 178)
    $game_screen.pictures[5].show("introBoy", 1, 250, 178)
    SpeakCapture.clear

    choice = Interpreter.new([SS2IntroCommand.new([["Left", "Right"], 0])])
    eq "the choice keeps its own return", choice.command_102, :choice
    eq "left to right by where the portraits stand, whatever their picture numbers, queued", SpeakCapture.log,
       [[t.t(:ss2_intro_sides, :left => t.t(:ap_boy), :right => t.t(:ap_girl)), false]]

    SpeakCapture.clear
    Interpreter.new([SS2IntroCommand.new([["Yes", "No", "Maybe"], 2])]).command_102
    silent "a choice of any other length says nothing"

    $game_screen.pictures[5].erase
    Interpreter.new([SS2IntroCommand.new([["Yes", "No"], 2])]).command_102
    silent "and with one portrait gone, neither does a later two-row choice"
  ensure
    $game_screen = saved_screen
    Object.send(:remove_const, :Interpreter)
    Object.const_set(:Interpreter, saved) if saved
  end
end
