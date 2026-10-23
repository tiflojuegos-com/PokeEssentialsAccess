# Africanvs's chariot race (games/africanus/cuadrigas.rb) on a stand-in of its scene: the tutorial strip page by page
# as its build paints it, and the race from the scene's state each frame, while the game's loops run.
class CarreraCuadrigasScene
  CENTRO_Y = 885

  def showTutorial; run_frames; end
  def loopRace; run_frames; end

  # A loop of the game cut down to its frames: each entry of @frames is run on the scene, then the frame's pollers.
  def run_frames
    (@frames || []).each do |step|
      step.call(self)
      PokeAccess::Frame.run_pollers
    end
  end
end

path = File.join(Harness::ROOT, "games", "africanus", "cuadrigas.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class AfricanusRaceTest < PokeAccessTest
  Race = PokeAccess::AfricanusRace
  Strip = Struct.new(:x, :opacity, :src_rect)
  Rect = Struct.new(:x, :y, :width, :height)
  Point = Struct.new(:x, :y)
  PAGE_I = "TUTORIAL (I) - Movimiento lateral. Pulsando las teclas Arriba y Abajo se realizan los desplazamientos " \
           "laterales, con los que adelantar, golpear o esquivar contrincantes. X: Cerrar. Derecha: TUTO (II) Turbo."
  PAGE_III = "TUTORIAL (III) - Colisiones. Al entrar en contacto con otra cuadriga, un muro exterior o la Spina " \
             "(centro) se produce una colisión que causa daños. Tras el golpe, los corredores se repelerán y " \
             "frenarán un poco. Izquierda: TUTO (II) Turbo. X: Cerrar. Derecha: TUTO (IV) Interfaz."
  PAGE_IV = "TUTORIAL (IV) - Interfaz. Contador de vueltas. Posición en carrera. PS y Turbo. Control de velocidad. " \
            "Izquierda: TUTO (III) Colisiones. X: Cerrar."
  PAGE_I_ENG = "TUTORIAL (I) - Lateral movement. By pressing the Up and Down keys, you can move laterally to " \
               "overtake, hit or dodge opponents. X: Exit. Right: TUTO (II) Turbo."

  # A chariot as CuadrigaSprite exposes it; a plain object, since the scene keys its positions by the sprite itself.
  class Chariot
    attr_accessor :vueltas, :orden, :ps, :stamina, :golpeado, :girando, :aceleracion

    def initialize
      @vueltas = 0
      @orden = 3
      @ps = 100
      @stamina = 100
      @golpeado = false
      @girando = false
      @aceleracion = 0
    end
  end

  test "reads page I as the strip comes into sight, cutting in" do
    strip = Strip.new(0, 0, nil)
    held(tutorial_scene(strip), :tutorial) { Race.poll }
    assert_equal [[PAGE_I, true]], SpeakCapture.log
  end

  test "says nothing more while the strip fades in" do
    strip = Strip.new(0, 0, nil)
    held(tutorial_scene(strip), :tutorial) do
      Race.poll
      SpeakCapture.clear
      strip.opacity = 255
      Race.poll
      Race.poll
    end
    assert_nothing_spoken
  end

  test "a slide to the left reads page II as it starts, its track drawings said as the race says each half" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      Race.poll
      SpeakCapture.clear
      [-25, -50, -500, -500].each { |x| strip.x = x; Race.poll }
    end
    assert_equal [[page_ii, true]], SpeakCapture.log, "once, as the slide starts"
  end

  test "each further slide to the left reads the next page, however far the x drifted" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      [0, -25, -500, -500].each { |x| strip.x = x; Race.poll }
      SpeakCapture.clear
      [-525, -1000].each { |x| strip.x = x; Race.poll }
    end
    assert_equal [PAGE_III], SpeakCapture.lines
  end

  test "a slide to the right reads the page before" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      [0, -25, -500, -500, -525, -1000, -1000].each { |x| strip.x = x; Race.poll }
      SpeakCapture.clear
      [-999, -980].each { |x| strip.x = x; Race.poll }
    end
    assert_equal [page_ii], SpeakCapture.lines
  end

  test "a slide past either end of the strip stays on its last page" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      Race.poll
      SpeakCapture.clear
      strip.x = 25
      Race.poll
      assert_equal [PAGE_I], SpeakCapture.lines, "right of page I"
      [25, -25, -25, -50, -50, -75, -75, -100, -100].each { |x| strip.x = x; Race.poll }
      SpeakCapture.clear
      strip.x = -125
      Race.poll
    end
    assert_equal [PAGE_IV], SpeakCapture.lines, "left of page IV"
  end

  test "the slide that closes the strip, faded out, says nothing" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      Race.poll
      SpeakCapture.clear
      strip.opacity = 0
      [-20, 0].each { |x| strip.x = x; Race.poll }
    end
    assert_nothing_spoken
  end

  test "the info key holds the page while the strip is up, and lets it go with the tutorial" do
    strip = Strip.new(0, 255, nil)
    held(tutorial_scene(strip), :tutorial) do
      Race.poll
      assert_equal PAGE_I, PokeAccess::Info.info_text, "while it is up"
    end
    assert_nil PokeAccess::Info.info_text, "after"
  end

  test "the English strip is read as it paints" do
    held(tutorial_scene(Strip.new(0, 255, nil), "tutorial_eng"), :tutorial) { Race.poll }
    assert_equal [PAGE_I_ENG], SpeakCapture.lines
  end

  test "the close key is said as the player has it bound" do
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.rebinds = { :b => 0x4B }
    PokeAccess::Config.key_hint_letters = PokeAccess::KeyHints::RGSS_LETTERS
    held(tutorial_scene(Strip.new(0, 255, nil)), :tutorial) { Race.poll }
    assert_equal [PAGE_I.sub("X: Cerrar.", "K: Cerrar.")], SpeakCapture.lines
  ensure
    PokeAccess::Config.rebinds = was[0]
    PokeAccess::Config.key_hint_letters = was[1]
  end

  test "a strip it cannot place says nothing" do
    [tutorial_scene(Strip.new(nil, 255, nil)), CarreraCuadrigasScene.new].each do |scene|
      held(scene, :tutorial) { Race.poll }
      assert_nothing_spoken
    end
  end

  test "counts down the numerals III, II and I as digits, once each, cutting in" do
    count = Strip.new(256, 255, Rect.new(0, 104, 80, 52))
    scene = race_scene(Chariot.new, 0, "contador" => count)
    held(scene, :race) do
      Race.poll
      Race.poll
      count.src_rect.y = 52
      Race.poll
      count.src_rect.y = 0
      Race.poll
    end
    assert_equal [["3", true], ["2", true], ["1", true]], SpeakCapture.log
  end

  test "a numeral is said as soon as it shows at all" do
    held(race_scene(Chariot.new, 0, "contador" => Strip.new(256, 1, Rect.new(0, 52, 80, 52))), :race) { Race.poll }
    assert_equal ["2"], SpeakCapture.lines
  end

  test "a numeral faded out, cut empty or that cannot say its opacity is not said" do
    { "faded out" => Strip.new(256, 0, Rect.new(0, 104, 80, 52)),
      "cut empty" => Strip.new(256, 255, Rect.new(0, 104, 80, 0)),
      "no opacity" => Struct.new(:x, :src_rect).new(256, Rect.new(0, 104, 80, 52)) }.each do |what, count|
      held(race_scene(Chariot.new, 0, "contador" => count), :race) { Race.poll }
      assert_nothing_spoken what
    end
  end

  test "the start says lap one, cutting in, then the half the chariot is in and what the arrows do there" do
    { 600 => :afr_race_top, 885 => :afr_race_bottom, 900 => :afr_race_bottom, nil => :afr_race_top }.each do |y, half|
      SpeakCapture.clear
      held(race_scene(Chariot.new, 1, {}, y), :race) { Race.poll }
      assert_equal [[PokeAccess::I18n.t(:afr_race_lap, :n => 1, :total => 7), true], [PokeAccess::I18n.t(half), false]],
                   SpeakCapture.log, "the chariot at y #{y.inspect}"
    end
  end

  test "the info key repeats the race line" do
    q = Chariot.new
    q.vueltas = 2
    q.ps = 94.4
    q.stamina = 61.6
    held(race_scene(q, 1), :race) do
      Race.poll
      assert_equal PokeAccess::I18n.t(:afr_race_status, :lap => 3, :total => 7, :place => 3, :hp => 94, :turbo => 62),
                   PokeAccess::Info.info_text
    end
  end

  test "says the place, queued, once it has held for twenty frames" do
    held(race_scene(Chariot.new, 1), :race) do
      Race.poll
      SpeakCapture.clear
      18.times { Race.poll }
      assert_nothing_spoken "nineteen frames"
      Race.poll
      assert_equal [[PokeAccess::I18n.t(:afr_race_place, :n => 3), false]], SpeakCapture.log, "the twentieth"
      SpeakCapture.clear
      20.times { Race.poll }
    end
    assert_nothing_spoken "and not again while it holds"
  end

  test "a place that flickers is not said" do
    q = Chariot.new
    held(race_scene(q, 1), :race) do
      Race.poll
      SpeakCapture.clear
      [2, 3, 2, 3].each { |place| q.orden = place; 5.times { Race.poll } }
    end
    assert_nothing_spoken
  end

  test "says the curve and the straight as the chariot turns, and the half as it crosses the middle line" do
    q = Chariot.new
    pos = Point.new(2000, 600)
    scene = race_scene(q, 1)
    scene.instance_variable_set(:@cuadrigasPos, { q => pos })
    held(scene, :race) do
      Race.poll
      SpeakCapture.clear
      q.girando = true
      Race.poll
      pos.y = 900
      Race.poll
      q.girando = false
      Race.poll
    end
    assert_equal [[PokeAccess::I18n.t(:afr_race_curve), false], [PokeAccess::I18n.t(:afr_race_bottom), false],
                  [PokeAccess::I18n.t(:afr_race_straight), false]], SpeakCapture.log
  end

  test "says the HP a hit leaves once its loss has drained" do
    q = Chariot.new
    held(race_scene(q, 1), :race) do
      Race.poll
      SpeakCapture.clear
      q.golpeado = true
      q.ps = 94
      Race.poll
      assert_nothing_spoken "while it drains"
      q.golpeado = false
      q.ps = 88.4
      Race.poll
      Race.poll
    end
    assert_equal [[PokeAccess::I18n.t(:afr_race_hp, :n => 88), false]], SpeakCapture.log
  end

  test "says the turbo a sprint leaves when it ends, however little" do
    [85, 1].each do |left|
      q = Chariot.new
      SpeakCapture.clear
      held(race_scene(q, 1), :race) do
        Race.poll
        SpeakCapture.clear
        q.aceleracion = 2
        q.stamina = left + 6
        Race.poll
        assert_nothing_spoken "while it sprints"
        q.stamina = left
        q.aceleracion = 1
        Race.poll
        Race.poll
      end
      assert_equal [[PokeAccess::I18n.t(:afr_race_turbo, :n => left), false]], SpeakCapture.log, "#{left} left"
    end
  end

  test "says once that the turbo ran dry, mid-sprint or not" do
    q = Chariot.new
    held(race_scene(q, 1), :race) do
      Race.poll
      SpeakCapture.clear
      q.aceleracion = 2
      q.stamina = 0
      Race.poll
      q.aceleracion = 0
      Race.poll
    end
    assert_equal [[PokeAccess::I18n.t(:afr_race_turbo_empty), false]], SpeakCapture.log
  end

  test "the next lap cuts in" do
    q = Chariot.new
    held(race_scene(q, 1), :race) do
      Race.poll
      SpeakCapture.clear
      q.vueltas = 1
      Race.poll
    end
    assert_equal [[PokeAccess::I18n.t(:afr_race_lap, :n => 2, :total => 7), true]], SpeakCapture.log
  end

  test "a race with no chariot says nothing" do
    held(race_scene(nil, 1), :race) { Race.poll }
    assert_nothing_spoken
  end

  test "the race line leaves the info key with the race, and letting nothing go leaves another screen's line" do
    held(race_scene(Chariot.new, 1), :race) { Race.poll }
    assert_nil PokeAccess::Info.info_text, "after the race"
    PokeAccess::Info.set_info(:text, "otra pantalla")
    Race.release
    assert_equal "otra pantalla", PokeAccess::Info.info_text, "with no race held"
  end

  test "the tutorial is read while the game shows it, and its page leaves the info key after" do
    scene = tutorial_scene(Strip.new(0, 255, nil))
    scene.instance_variable_set(:@frames, [lambda { |_s| }])
    scene.showTutorial
    assert_equal [PAGE_I], SpeakCapture.lines, "while it shows"
    assert_nil PokeAccess::Info.info_text, "after"
  end

  test "the race is read while the game's race loop runs, and nothing once it returns" do
    q = Chariot.new
    scene = race_scene(q, 1)
    scene.instance_variable_set(:@frames, [lambda { |_s| }])
    scene.loopRace
    assert_equal [PokeAccess::I18n.t(:afr_race_lap, :n => 1, :total => 7), PokeAccess::I18n.t(:afr_race_top)],
                 SpeakCapture.lines, "while it runs"
    SpeakCapture.clear
    q.vueltas = 1
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken "after"
  end

  private

  # Page II as the Spanish strip paints it, its two track drawings in the words the race uses for each half.
  def page_ii
    drawings = "#{PokeAccess::I18n.t(:afr_race_top)}. #{PokeAccess::I18n.t(:afr_race_bottom)}."
    "TUTORIAL (II) - Turbo y freno. Pulsando las teclas Izquierda y Derecha se cambia la velocidad. (Depende de la " \
      "zona). #{drawings} Izquierda: TUTO (I) Mov. lateral. X: Cerrar. Derecha: TUTO (III) Colisiones."
  end

  # A scene showing the tutorial strip under the sprite name its build uses.
  def tutorial_scene(strip, name = "tutorial")
    scene = CarreraCuadrigasScene.new
    scene.instance_variable_set(:@sprites, { name => strip })
    scene
  end

  # A race scene in state estado (0 before the start, 1 running) with one chariot, at y on the track if given.
  def race_scene(chariot, estado, sprites = {}, y = 600)
    scene = CarreraCuadrigasScene.new
    scene.instance_variable_set(:@sprites, sprites)
    scene.instance_variable_set(:@cuadrigas, chariot ? [chariot] : [])
    scene.instance_variable_set(:@cuadrigasPos, (chariot && y) ? { chariot => Point.new(2000, y) } : {})
    scene.instance_variable_set(:@estado, estado)
    scene
  end

  # Runs the block with scene held in that phase, let go after.
  def held(scene, kind)
    Race.hold(scene, kind)
    yield
  ensure
    Race.release
  end
end
