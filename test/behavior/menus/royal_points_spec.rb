# royal's trainer-points screen (PokemonOptionPuntos_Scene): the running total under the sliders is a
# standing window the scene rewrites after every edit, and it is what the sliders are spent against. The
# stand-in is declared before the profile loads, because a watch on a class that does not exist yet
# registers nothing.
class PokemonOptionPuntos_Scene
  attr_reader :sprites
  def initialize; @sprites = { "puntos_totales" => FakeTextWin.new }; end
  def pbStartScene; @sprites["puntos_totales"].text = "Puntos totales: 12"; end
  def pbEndScene; end
end

require File.expand_path("../../../games/royal/puntos", File.dirname(__FILE__))

Suite.define("royal points: the running total is read on open and after every slider edit") do
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    truthy "the scene takes the engine's lifecycle", !iw.unentered.include?("PokemonOptionPuntos_Scene")

    scene = PokemonOptionPuntos_Scene.new
    SpeakCapture.clear
    scene.pbStartScene
    iw.tick
    spoke "the total painted on open is read", /12/

    scene.sprites["puntos_totales"].text = "Puntos totales: 9"
    SpeakCapture.clear
    iw.tick
    spoke "spending points is read as the new total", /9/

    SpeakCapture.clear
    iw.tick
    silent "and an unchanged total says nothing"

    scene.pbEndScene
    scene.sprites["puntos_totales"].text = "Puntos totales: 30"
    SpeakCapture.clear
    iw.tick
    silent "once the screen closes the window is nobody's"
  ensure
    iw.enter(prev)
  end
end
