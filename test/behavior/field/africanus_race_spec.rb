# Africanvs's chariot race (games/africanus/cuadrigas.rb) on a stub scene: the tutorial strip page by page as its
# build paints it, and the race from the scene's state, as loopRace leaves it each frame.
class CarreraCuadrigasScene
  CENTRO_Y = 885
  def showTutorial; end
  def loopRace; end
end
require File.expand_path("../../../games/africanus/cuadrigas", File.dirname(__FILE__))

AfrRacePoint = Struct.new(:x, :y)
AfrRaceSprite = Struct.new(:x, :opacity, :src_rect)
AfrRaceRect = Struct.new(:x, :y, :width, :height)

# A chariot as CuadrigaSprite exposes it; a plain object, since the scene keys its positions by the sprite itself.
class AfrChariot
  attr_accessor :vueltas, :orden, :ps, :stamina, :golpeado, :girando, :aceleracion
  def initialize(vueltas, orden, ps, stamina, golpeado, girando, aceleracion)
    @vueltas = vueltas; @orden = orden; @ps = ps; @stamina = stamina
    @golpeado = golpeado; @girando = girando; @aceleracion = aceleracion
  end
end

Suite.define("africanus race: the tutorial strip is read page by page, and the slide that closes it is not") do
  r = PokeAccess::AfricanusRace
  scene = CarreraCuadrigasScene.new
  strip = AfrRaceSprite.new(0, 0, nil)
  scene.instance_variable_set(:@sprites, { "tutorial" => strip })
  r.hold(scene, :tutorial)
  begin
    SpeakCapture.clear
    r.poll
    spoke "page I on sight, as the Spanish strip paints it", /\ATUTORIAL \(I\) - Movimiento lateral\. Pulsando/
    SpeakCapture.clear
    strip.opacity = 255
    r.poll
    silent "the fade-in says nothing more"

    strip.x = -25
    r.poll
    drawings = "#{PokeAccess::I18n.t(:afr_race_top)}. #{PokeAccess::I18n.t(:afr_race_bottom)}."
    eq "a slide to the left is page II, its two track drawings said as the race says each half", SpeakCapture.lines,
       ["TUTORIAL (II) - Turbo y freno. Pulsando las teclas Izquierda y Derecha se cambia la velocidad. (Depende de " \
        "la zona). #{drawings} Izquierda: TUTO (I) Mov. lateral. X: Cerrar. Derecha: TUTO (III) Colisiones."]
    SpeakCapture.clear
    strip.x = -50
    r.poll
    strip.x = -500
    r.poll
    silent "and the rest of that slide is quiet"

    r.poll
    strip.x = -525
    r.poll
    spoke "the next slide is page III, however far the truncated x drifted", /\ATUTORIAL \(III\) - Colisiones/
    SpeakCapture.clear
    r.poll
    strip.x = -499
    r.poll
    spoke "a slide back to the right is page II again", /\ATUTORIAL \(II\)/

    SpeakCapture.clear
    r.poll
    strip.opacity = 0
    strip.x = -480
    r.poll
    strip.x = 0
    r.poll
    silent "closing fades the strip out and slides it back unseen, saying nothing"
    truthy "the info key holds the page", PokeAccess::Info.info_text.to_s =~ /\ATUTORIAL \(II\)/
  ensure
    r.release
  end
  falsy "and the page leaves the info key with the tutorial", PokeAccess::Info.info_text.to_s =~ /TUTORIAL/
end

Suite.define("africanus race: the English strip is read as it paints, the close key as the player has it") do
  r = PokeAccess::AfricanusRace
  was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
  scene = CarreraCuadrigasScene.new
  scene.instance_variable_set(:@sprites, { "tutorial_eng" => AfrRaceSprite.new(0, 255, nil) })
  PokeAccess::Config.rebinds = { :b => 0x4B }
  PokeAccess::Config.key_hint_letters = PokeAccess::KeyHints::RGSS_LETTERS
  r.hold(scene, :tutorial)
  begin
    SpeakCapture.clear
    r.poll
    spoke "the English page I", /\ATUTORIAL \(I\) - Lateral movement\. By pressing the Up and Down keys/
    spoke "with Cancel's key where the picture paints X", /K: Exit\./
  ensure
    r.release
    PokeAccess::Config.rebinds = was[0]
    PokeAccess::Config.key_hint_letters = was[1]
  end
end

Suite.define("africanus race: countdown, laps, halves and curves, the settled place, HP after a hit, turbo") do
  r = PokeAccess::AfricanusRace
  scene = CarreraCuadrigasScene.new
  q = AfrChariot.new(0, 3, 100, 100, false, false, 0)
  pos = AfrRacePoint.new(2000, 600)
  count = AfrRaceSprite.new(256, 255, AfrRaceRect.new(0, 104, 80, 52))
  scene.instance_variable_set(:@sprites, { "contador" => count })
  scene.instance_variable_set(:@cuadrigas, [q])
  scene.instance_variable_set(:@cuadrigasPos, { q => pos })
  scene.instance_variable_set(:@estado, 0)
  r.hold(scene, :race)
  begin
    SpeakCapture.clear
    r.poll
    r.poll
    count.src_rect.y = 52
    r.poll
    count.src_rect.y = 0
    r.poll
    eq "the countdown's numerals III, II and I as digits, once each", SpeakCapture.lines, ["3", "2", "1"]

    SpeakCapture.clear
    scene.instance_variable_set(:@estado, 1)
    r.poll
    eq "the start: lap one, then the half and what the arrows do there",
       SpeakCapture.log, [["Vuelta 1 de 7", true], ["Mitad superior: izquierda, turbo; derecha, freno", false]]
    eq "and the info key has the race line", PokeAccess::Info.info_text,
       "Vuelta 1 de 7. Puesto 3. PS: 100. Turbo: 100"

    SpeakCapture.clear
    18.times { r.poll }
    silent "the place waits until it has held"
    r.poll
    eq "then says it", SpeakCapture.lines, ["Puesto 3"]

    SpeakCapture.clear
    q.orden = 2
    5.times { r.poll }
    q.orden = 3
    5.times { r.poll }
    silent "a place that flickers is not said"

    SpeakCapture.clear
    q.girando = true
    r.poll
    pos.y = 900
    r.poll
    q.girando = false
    r.poll
    eq "into the curve, over the middle line, out onto the straight", SpeakCapture.lines,
       ["Curva", "Mitad inferior: derecha, turbo; izquierda, freno", "Recta"]

    SpeakCapture.clear
    q.golpeado = true
    q.ps = 94
    r.poll
    silent "a hit says nothing while its loss drains"
    q.golpeado = false
    q.ps = 88
    r.poll
    eq "and the HP once it has", SpeakCapture.lines, ["PS: 88"]

    SpeakCapture.clear
    q.aceleracion = 2
    q.stamina = 91
    r.poll
    q.stamina = 85
    q.aceleracion = 1
    r.poll
    eq "a sprint's end says the turbo left", SpeakCapture.lines, ["Turbo: 85"]
    SpeakCapture.clear
    q.aceleracion = 2
    r.poll
    q.stamina = 0
    q.aceleracion = 0
    r.poll
    r.poll
    eq "and running dry is said once", SpeakCapture.lines, ["Turbo agotado"]

    SpeakCapture.clear
    q.vueltas = 1
    r.poll
    eq "the next lap cuts in", SpeakCapture.log, [["Vuelta 2 de 7", true]]
  ensure
    r.release
  end
  falsy "the race line leaves the info key with the race", PokeAccess::Info.info_text.to_s =~ /Vuelta/
end
