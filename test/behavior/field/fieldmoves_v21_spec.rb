# The v21 field-move menu: each option focused inside the pbShowCommands loop is read by the refresh_buttons hook,
# which the before-hook on pbShowCommands must not silence.
Suite.define("field moves v21: navigating the menu reads each focused option") do
  cmds = [[:CUT, "Corte", 0, 0], [:SURF, "Surf", 0, 1], [:FLY, "Vuelo", 0, 2]]
  scene = SelectMoveMenu_Scene.new(cmds, [1, 2])
  SpeakCapture.clear
  scene.pbShowCommands
  spoke "the option focused mid-loop is read (Surf)", /Surf/
  spoke "the next option focused mid-loop is read (Vuelo)", /Vuelo/
end
