# The sliding banners plugin: a line painted on a bitmap (with drawTextEx or with pbDrawTextPositions) is
# spoken when that same bitmap slides in through Scene_Map#addSprite. What is pinned: the pairing is by
# identity and not by recency (two banners in flight read each their own line, in slide order), a slid
# bitmap is spoken once, text that never slides is never spoken and cannot pile up, a burst of rows reads
# as one line, and a paint with no letter or digit (Awakening's autosave asterisk) is not a banner.
#
# The harness ships neither paint function nor the FastItemGet addSprite, so the three are defined here and
# the plugin file is evaluated again over them: its wraps install only over functions that exist, and the
# harness loaded it before these existed.
class Scene_Map
  def addSprite(x, y, bitmap); [x, y, bitmap]; end
end unless Scene_Map.method_defined?(:addSprite)

def drawTextEx(bitmap, x, y, width, numlines, text, base = nil, shadow = nil); text; end unless Object.private_method_defined?(:drawTextEx)
def pbDrawTextPositions(bitmap, textpos); textpos; end unless Object.private_method_defined?(:pbDrawTextPositions)

# eval is the harness's own loading mechanism (test/support/harness.rb): it evaluates THIS repo's file by
# absolute path under Harness::ROOT, never external input, the same replay plugins_smoke_spec does.
begin
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "plugins", "slide_banners.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

Suite.define("slide banners: a line painted with drawTextEx is spoken when its bitmap slides in") do
  scene = Scene_Map.new
  boss = Object.new
  SpeakCapture.clear
  drawTextEx(boss, 5, 15, 300, 3, "¡Jefe en la siguiente sala! Prepárate.", nil, nil)
  eq "painting alone says nothing (the banner is not on screen yet)", SpeakCapture.lines, []
  scene.addSprite(-300, 0, boss)
  spoke_once "sliding it in speaks the line", /Jefe en la siguiente sala/
  SpeakCapture.clear
  scene.addSprite(-300, 0, boss)
  eq "and a second slide of the same bitmap says nothing more", SpeakCapture.lines, []

  SpeakCapture.clear
  scene.addSprite(-300, 0, Object.new)
  eq "a bitmap nothing was painted on is silent", SpeakCapture.lines, []

  relation = Object.new
  point = Object.new
  drawTextEx(relation, 5, 15, 300, 2, "¡La relación con Kyle mejoró!", nil, nil)
  drawTextEx(point, 5, 15, 300, 2, "¡Kyle ha ganado un punto de relación!", nil, nil)
  SpeakCapture.clear
  scene.addSprite(-300, 0, point)
  scene.addSprite(-300, 0, relation)
  eq "two banners in flight each read their own line, in slide order, not the most recent paint",
     SpeakCapture.lines.map { |l| l.to_s }, ["¡Kyle ha ganado un punto de relación!", "¡La relación con Kyle mejoró!"]

  repaint = Object.new
  drawTextEx(repaint, 5, 15, 300, 2, "primera", nil, nil)
  drawTextEx(repaint, 5, 15, 300, 2, "Logro desbloqueado: Coleccionista", nil, nil)
  SpeakCapture.clear
  scene.addSprite(-300, 200, repaint)
  eq "a bitmap painted twice carries its last line", SpeakCapture.lines.map { |l| l.to_s }, ["Logro desbloqueado: Coleccionista"]

  early = Object.new
  drawTextEx(early, 5, 15, 300, 2, "olvidada", nil, nil)
  20.times { |i| drawTextEx(Object.new, 0, 0, 100, 1, "ventana #{i}", nil, nil) }
  SpeakCapture.clear
  scene.addSprite(-300, 0, early)
  eq "text that never slid is dropped after a few paints, so windows cannot pile it up", SpeakCapture.lines, []
end

Suite.define("slide banners: a pbDrawTextPositions burst reads as one line, and a wordless paint is no banner") do
  scene = Scene_Map.new
  item = Object.new
  pbDrawTextPositions(item, [["Poción x2", 5, 15, false, nil, nil]])
  SpeakCapture.clear
  scene.addSprite(-300, 200, item)
  eq "the floor-item card reads its own line", SpeakCapture.lines.map { |l| l.to_s }, ["Poción x2"]

  logro = Object.new
  pbDrawTextPositions(logro, [["¡Logro conseguido!", 129, 12, 2, nil, nil], ["Coleccionista", 129, 40, 2, nil, nil]])
  SpeakCapture.clear
  scene.addSprite(516, 25, logro)
  eq "several rows on one card read in paint order", SpeakCapture.lines.map { |l| l.to_s }, ["¡Logro conseguido!, Coleccionista"]

  mark = Object.new
  pbDrawTextPositions(mark, [["*", 10, 15, 0, nil, nil]])
  SpeakCapture.clear
  scene.addSprite(-512, 324, mark)
  eq "the autosave asterisk is not speech", SpeakCapture.lines, []

  both = Object.new
  pbDrawTextPositions(both, [["vieja", 5, 15, 0, nil, nil]])
  drawTextEx(both, 5, 15, 300, 2, "¡Huevo listo!", nil, nil)
  SpeakCapture.clear
  scene.addSprite(516, 25, both)
  eq "whichever function painted last is what the card says", SpeakCapture.lines.map { |l| l.to_s }, ["¡Huevo listo!"]
end
