# Rejuvenation's entry screens of the Pokedex and PC searches (games/rejuvenation/text_entry.rb): the type pick, whose
# reels paint only icons, and the bounded text entry with its matches, whose keyboard window never runs the core's
# update. The screens stand in below as the game builds them; the profile file is loaded once.
module RejuvEntrySpec
  TYPES = { :getTypeName => lambda { |t| t.to_s.capitalize } }

  def self.load_profile
    return if @loaded
    load File.expand_path("../../../games/rejuvenation/text_entry.rb", File.dirname(__FILE__))
    @loaded = true
  end
end

class PokemonTypeReel
  attr_writer :selected
  def initialize(index, reel); @index = index; @reel = reel; @pos = 0; @selected = false; end
  def selected; @reel[@pos]; end
  def up; return unless @selected; @pos = (@pos - 1) % @reel.length; end
  def down; return unless @selected; @pos = (@pos + 1) % @reel.length; end
  def toggleSelect; @selected = !@selected; end
end

class PokemonTypeSelectionScreen
  attr_reader :sprites
  def pbStartScene(helptext, _starttypes)
    @sprites = { "entry" => FakeTextWin.new(helptext),
                 "type1" => PokemonTypeReel.new(0, [:NORMAL, :FIRE, :WATER]),
                 "type2" => PokemonTypeReel.new(1, [nil, :NORMAL, :FIRE, :WATER]),
                 "helpwindow" => FakeTextWin.new("Select types using the arrow keys.\nPress ESC to cancel, or ENTER to confirm.") }
    @sprites["type1"].selected = true
  end
end

class Window_BoundedTextEntry_Keyboard
  attr_accessor :active, :matchingnames, :highlightindex
  def initialize(names); @names = names; @matchingnames = names; @highlightindex = -1; @active = true; end
  def update; nil; end
end

class BoundedPokemonEntryScene
  attr_reader :sprites
  def pbStartScene(_helptext, names)
    @sprites = { "entry" => Window_BoundedTextEntry_Keyboard.new(names),
                 "helpwindow" => FakeTextWin.new("Enter text using the keyboard.  Press\nESC to cancel, or ENTER to confirm.") }
  end
end

Suite.define("rejuvenation entry: the type pick says the question, each reel's type and the reel it moves to") do
  RejuvEntrySpec.load_profile
  t = PokeAccess::I18n
  GameFunctions.with(RejuvEntrySpec::TYPES) do
    scene = PokemonTypeSelectionScreen.new
    SpeakCapture.clear
    scene.pbStartScene("Which types?", [])
    eq "the question, then the first reel, queued", SpeakCapture.log[0][1], false
    match "the question comes first", SpeakCapture.lines[0], /\AWhich types\?/
    match "then the first reel's type", SpeakCapture.lines[0], /#{Regexp.escape(t.t(:rj_type_slot, :n => 1, :t => "Normal"))}/
    r1 = scene.sprites["type1"]
    r2 = scene.sprites["type2"]
    SpeakCapture.clear
    r1.down
    r2.down
    eq "down names the new type of the reel in use, and only it", SpeakCapture.lines, ["Fire"]
    SpeakCapture.clear
    r1.toggleSelect
    r2.toggleSelect
    eq "left or right says the other reel and its blank", SpeakCapture.lines,
       [t.t(:rj_type_slot, :n => 2, :t => t.t(:sum_none))]
  end
end

Suite.define("rejuvenation entry: the bounded entry says its matches, the picked one, and holds the mod's keys") do
  RejuvEntrySpec.load_profile
  t = PokeAccess::I18n
  scene = BoundedPokemonEntryScene.new
  SpeakCapture.clear
  scene.pbStartScene("Name of the move?", ["Tackle", "Thunder", "Thunderbolt"])
  match "the question and how many match, with the first", SpeakCapture.lines[0],
        /\AName of the move\?.*#{Regexp.escape(t.t(:rj_matches, :n => 3, :first => "Tackle"))}/
  win = scene.sprites["entry"]
  win.update
  truthy "an active field holds the mod's keys", PokeAccess::Keys.instance_variable_get(:@typing_ttl) > 0
  SpeakCapture.clear
  win.matchingnames = ["Thunder", "Thunderbolt"]
  win.update
  eq "a key that narrows the matches says what is left, queued behind its echo", SpeakCapture.log,
     [[t.t(:rj_matches, :n => 2, :first => "Thunder"), false]]
  SpeakCapture.clear
  win.update
  silent "nothing again while nothing changes"
  win.highlightindex = 2
  win.update
  eq "down picks a match and says it with its place", SpeakCapture.log, [["Thunderbolt, #{t.t(:list_pos, :i => 2, :n => 2)}", true]]
end
