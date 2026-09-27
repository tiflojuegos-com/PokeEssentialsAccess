# FL's Set the Controls (plugins/fl_set_controls.rb) over the gen-6 stubs of its window and scene: each row as painted,
# a key just bound, and the text box polled each frame while pbMain runs.
module FlSetControlsSpec
  Control = Struct.new(:controlAction, :keyName)

  # A text box stand-in with the text reader the poll reads, as the game's message window has.
  def self.box(text = "")
    Struct.new(:text).new(text)
  end
end

Suite.define("fl set controls: each row as painted, then the Default and Exit captions") do
  fl = PokeAccess::FlSetControls
  ctrl = FlSetControlsSpec::Control
  win = Window_PokemonControls.new([ctrl.new("Action", "C"), ctrl.new("Registered #4", "T")])
  eq "an action and its key", fl.row(win, 1), PokeAccess::I18n.t(:chr_value, :name => "Registered #4", :value => "T")
  eq "past the actions, the Default and Exit captions", [fl.row(win, 2), fl.row(win, 3)], ["Default", "Exit"]
  win.index = 3
  eq "the focused row is read through the plugin's extractor", PokeAccess::Menus.focused_text(win), "Exit"
end

Suite.define("fl set controls: a key just bound is said on its row, interrupting the prompt") do
  win = Window_PokemonControls.new([FlSetControlsSpec::Control.new("Action", "C")])
  SpeakCapture.clear
  win.setNewInput("V")
  eq "the row with its new key", SpeakCapture.log, [[PokeAccess::I18n.t(:chr_value, :name => "Action", :value => "V"), true]]
end

# Insurgence's copy takes a new key away from any other row that had it, which then paints "None" (key code 0).
Suite.define("fl set controls: rows a new key was taken from are said after the row that got it") do
  t = PokeAccess::I18n
  coded = Struct.new(:controlAction, :keyCode) do
    def keyName; keyCode == 0 ? "None" : keyCode.chr; end
  end
  rows = [coded.new("Up", 87), coded.new("Action", 67), coded.new("Menu", 88)]
  win = Window_PokemonControls.new(rows)
  win.index = 1
  before = PokeAccess::FlSetControls.codes(win)
  rows[0].keyCode = 0
  rows[1].keyCode = 87
  SpeakCapture.clear
  PokeAccess::FlSetControls.rebound(win, before)
  eq "the row with its new key, then the one left without, interrupting", SpeakCapture.log,
     [[PokeAccess.sentences([t.t(:chr_value, :name => "Action", :value => "W"), t.t(:chr_value, :name => "Up", :value => "None")]),
       true]]
end

Suite.define("fl set controls: the text box is said each time its line changes while pbMain runs") do
  box = FlSetControlsSpec.box("View/Change your controls")
  win = Window_PokemonControls.new([FlSetControlsSpec::Control.new("Action", "C")])
  rebound = PokeAccess::I18n.t(:chr_value, :name => "Action", :value => "V")
  steps = ["View/Change your controls", "Press a new key.", lambda { win.setNewInput("V") }, "", "",
           "Fill all fields!", "Press a new key."]
  SpeakCapture.clear
  PokemonControlsScene.new(win, box, steps).pbMain
  eq "the line on show at opening queued, then the prompt, the key bound, blanks quiet, and each new line",
     SpeakCapture.log,
     [["View/Change your controls", false], ["Press a new key.", true], [rebound, true],
      ["Fill all fields!", true], ["Press a new key.", true]]
  SpeakCapture.clear
  box.text = "Press a new key!"
  PokeAccess::Keys.run_frame_pollers
  silent "with the screen closed its box is nobody's"
end

Suite.define("fl set controls: Default puts every key back and says so, the cursor staying on its row") do
  ctrl = FlSetControlsSpec::Control
  win = Window_PokemonControls.new([ctrl.new("Action", "V")])
  win.index = 1
  SpeakCapture.clear
  win.update
  silent "a frame that changes nothing says nothing"
  win.defaults = [ctrl.new("Action", "C")]
  win.update
  eq "the whole list swapped for the defaults is said once", SpeakCapture.log,
     [[PokeAccess::I18n.t(:rmp_all_reset), true]]
  SpeakCapture.clear
  win.index = 0
  win.setNewInput("B")
  win.update
  eq "a key bound on its row is that row's, not a reset", SpeakCapture.lines,
     [PokeAccess::I18n.t(:chr_value, :name => "Action", :value => "B")]
end
