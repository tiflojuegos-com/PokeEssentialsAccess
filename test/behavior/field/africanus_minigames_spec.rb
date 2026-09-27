# Africanvs's minigame readers (games/africanus/minigames.rb and tablas.rb) on stub scenes: the truth tables' grid is
# said by the names its backgrounds paint, each arrow by the points its numeral shows, each kick against the nine that
# fell the door.
class EscapeGaulScene
  NUM_KICKS_PER_STATE = 3
  def pbMain; end
end
class TheArcherScene
  def pbMain; end
end
class TablesScreen
  def mainLoop; end
  def can_access_table?(_index); true; end
end
require File.expand_path("../../../games/africanus/tablas", File.dirname(__FILE__))
require File.expand_path("../../../games/africanus/minigames", File.dirname(__FILE__))

AfrMgSprite = Struct.new(:x, :y, :visible, :src_rect)
AfrMgRect = Struct.new(:x, :y, :width, :height)

Suite.define("africanus tables: each cell is said by the name its shelf paints, a locked one marked") do
  m = PokeAccess::AfricanusMinigames
  scene = TablesScreen.new
  sel = AfrMgSprite.new(16, 24, true, nil)
  scene.instance_variable_set(:@selector, sel)
  scene.instance_variable_set(:@pictures_prefix, "tabla")
  def scene.can_access_table?(index); index != 3; end

  SpeakCapture.clear
  m.tables(scene)
  eq "the first cell of bg.png", SpeakCapture.lines, ["Sagunto"]

  SpeakCapture.clear
  sel.x = 262
  sel.y = 68
  m.tables(scene)
  eq "a locked cell keeps its painted name", SpeakCapture.lines, ["Pisae, bloqueada"]

  other = TablesScreen.new
  other.instance_variable_set(:@selector, AfrMgSprite.new(16, 200, true, nil))
  other.instance_variable_set(:@pictures_prefix, "tablo_eng")
  SpeakCapture.clear
  m.tables(other)
  eq "the English build's prefix still names the second shelf, whose bg2.png both builds show",
     SpeakCapture.lines, ["Sagunto II"]
end

Suite.define("africanus archery: each arrow is said with the points its numeral shows, not the running total") do
  m = PokeAccess::AfricanusMinigames
  scene = TheArcherScene.new
  pts = AfrMgSprite.new(0, 0, true, AfrMgRect.new(78, 0, 94, 72))
  scene.instance_variable_set(:@sprites, { "points" => pts })
  scene.instance_variable_set(:@arrowCount, 1)
  scene.instance_variable_set(:@sumPoints, 7)

  SpeakCapture.clear
  m.hold(scene, :archer)
  begin
    m.poll
    eq "the VII numeral is seven points", SpeakCapture.lines, ["Flecha 1: 7 puntos"]
    SpeakCapture.clear
    m.poll
    silent "and it is said once for that arrow"

    pts.src_rect = AfrMgRect.new(202, 0, 21, 72)
    scene.instance_variable_set(:@arrowCount, 2)
    scene.instance_variable_set(:@sumPoints, 8)
    m.poll
    eq "the next arrow's own point, in the singular", SpeakCapture.lines, ["Flecha 2: 1 punto"]
  ensure
    m.release
  end
end

Suite.define("africanus cage: each kick is said against the nine that fell the door") do
  m = PokeAccess::AfricanusMinigames
  scene = EscapeGaulScene.new
  scene.instance_variable_set(:@kickCount, 0)

  SpeakCapture.clear
  m.hold(scene, :kick)
  begin
    m.poll
    silent "before the first kick nothing is said"
    scene.instance_variable_set(:@kickCount, 3)
    m.poll
    eq "the kick that tears the ropes, queued behind the kick's sound", SpeakCapture.log, [["Patada 3 de 9", false]]
    SpeakCapture.clear
    m.poll
    silent "once per kick"
  ensure
    m.release
  end
end
