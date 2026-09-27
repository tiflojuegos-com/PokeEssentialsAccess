# The pause menu's info box on the modern scene (PokemonPauseMenu_Scene, v19 on): the Bug-Catching Contest's
# catch and balls, said queued as the menu opens, a piece per line of the box.
Suite.define("pause menu (modern): the contest box is said as the menu opens, queued") do
  scene = PokemonPauseMenu_Scene.new
  scene.pbShowInfo("Caught: Caterpie\nLevel: 7\nBalls: 12")
  eq "each line of the box a piece, queued", SpeakCapture.log, [["Caught: Caterpie, Level: 7, Balls: 12", false]]
  SpeakCapture.clear
  scene.pbShowInfo("")
  silent "an empty box says nothing"
end
