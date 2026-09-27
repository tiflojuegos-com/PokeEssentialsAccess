# The v22 pause menu (UI::PauseMenuVisuals): its command list is a real Window_CommandPokemon, so set_commands claims
# it with @access_dedicated (never @ignore_input) and each frame reads the focused command once. Gamedata pass.

def pausemenu_v22_commands
  [[:pokedex, :pokemon, :bag], ["Pokedex", "Pokemon", "Bolsa"]]
end

Suite.define("v22 pause menu: set_commands claims the command window for the dedicated reader") do
  vis = UI::PauseMenuVisuals.new
  win = vis.sprites[:commands]
  falsy "a fresh command window is not claimed", win.instance_variable_get(:@access_dedicated)

  vis.set_commands(pausemenu_v22_commands)
  truthy "set_commands marks the window so the generic reader skips it",
         win.instance_variable_get(:@access_dedicated)

  SpeakCapture.clear
  win.index = 1
  win.update
  silent "the window's own update is no longer read generically, even driven on its own"
end

Suite.define("v22 pause menu: a frame reads the focused command exactly once") do
  vis = UI::PauseMenuVisuals.new
  vis.set_commands(pausemenu_v22_commands)

  SpeakCapture.clear
  vis.update_visuals
  eq "the first frame reads the focused command once, not once per reader",
     SpeakCapture.lines, ["Pokedex"]

  SpeakCapture.clear
  vis.update_visuals
  silent "a frame with the cursor unmoved says nothing"

  SpeakCapture.clear
  vis.sprites[:commands].index = 2
  vis.update_visuals
  eq "moving the cursor reads the new command, once", SpeakCapture.lines, ["Bolsa"]
end

# The dedup lives on the screen, so a reopened pause menu reads its focused command again.
Suite.define("v22 pause menu: reopening the menu reads the focused command again") do
  first = UI::PauseMenuVisuals.new
  first.set_commands(pausemenu_v22_commands)
  first.update_visuals
  SpeakCapture.clear
  first.update_visuals
  silent "the same menu on the same command stays silent"

  SpeakCapture.clear
  again = UI::PauseMenuVisuals.new
  again.set_commands(pausemenu_v22_commands)
  again.update_visuals
  eq "a reopened pause menu reads the focused command again", SpeakCapture.lines, ["Pokedex"]
end
