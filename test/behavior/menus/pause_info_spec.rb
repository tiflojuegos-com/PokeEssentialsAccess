# The classic pause menu's info box (Safari steps and balls, the Bug-Catching Contest's catch), read queued as the
# menu opens, a piece per line, before the focused command; pause_info_gd_spec pins the modern one.
Suite.define("pause menu: the Safari box is said as the menu opens, queued") do
  scene = PokemonMenu_Scene.new
  scene.pbShowInfo("Pasos: 120/600\nBalls: 30")
  eq "the box keeps its text", scene.info, "Pasos: 120/600\nBalls: 30"
  eq "each line of the box a piece, queued", SpeakCapture.log, [["Pasos: 120/600, Balls: 30", false]]
end
