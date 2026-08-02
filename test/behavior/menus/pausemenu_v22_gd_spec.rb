# The v22 pause menu (Essentials v22 UI::PauseMenuVisuals) is the double-read case in its purest form: its
# command list is a REAL Window_CommandPokemon living in @sprites[:commands], so the screen's per-frame
# update_visuals reaches that window's own update -- the very method the generic command reader hooks --
# while the mod also reads the focused command from the screen itself. Two readers, one window, one frame.
# The mod keeps them apart with its OWN @access_dedicated flag (never @ignore_input, the engine flag whose
# collision froze the gen-6 move relearner's cursor), planted by the set_commands hook. Runs only in the
# gamedata pass.

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

# The dedup ivar hangs on the screen, so a pause menu opened again reads its focused command instead of
# assuming the player still remembers where the cursor was.
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
