# The sliding banners plugin (plugins/slide_banners.rb): the line painted on a bitmap with drawTextEx or
# pbDrawTextPositions is said, queued, when that same bitmap slides in through Scene_Map#addSprite.

# The map's banner slider, which the stubs lack: the plugin binds to it as it loads, so it is evaluated again here.
class Scene_Map
  def addSprite(x, y, bitmap); [x, y, bitmap]; end
end unless Scene_Map.method_defined?(:addSprite)

begin
  verbose = $VERBOSE
  $VERBOSE = nil
  banners = File.join(Harness::ROOT, "plugins", "slide_banners.rb")
  eval(Harness.source(banners), TOPLEVEL_BINDING, banners)
ensure
  $VERBOSE = verbose
end

class SlideBannersTest < PokeAccessTest
  test "a line painted with drawTextEx is said, queued, when its bitmap slides in" do
    boss = Object.new
    paint(boss, "¡Jefe en la siguiente sala! Prepárate.")
    assert_nothing_spoken "painting alone puts nothing on screen"
    slide(boss)
    assert_equal [["¡Jefe en la siguiente sala! Prepárate.", false]], SpeakCapture.log
  end

  test "a bitmap that slides in again says nothing more" do
    boss = Object.new
    paint(boss, "¡Jefe en la siguiente sala!")
    slide(boss)
    SpeakCapture.clear
    slide(boss)
    assert_nothing_spoken
  end

  test "a bitmap nothing was painted on slides in silently" do
    paint(Object.new, "Otra ventana")
    slide(Object.new)
    assert_nothing_spoken
  end

  test "two banners in flight each say their own line, in the order they slide" do
    relation = Object.new
    point = Object.new
    paint(relation, "¡La relación con Kyle mejoró!")
    paint(point, "¡Kyle ha ganado un punto de relación!")
    slide(point)
    slide(relation)
    assert_equal [["¡Kyle ha ganado un punto de relación!", false], ["¡La relación con Kyle mejoró!", false]],
                 SpeakCapture.log
  end

  test "a bitmap painted twice says its last line" do
    card = Object.new
    paint(card, "primera")
    paint(card, "Logro desbloqueado: Coleccionista")
    slide(card)
    assert_equal [["Logro desbloqueado: Coleccionista", false]], SpeakCapture.log
  end

  test "keeps the lines of the last eight bitmaps painted: an older one slides in silently" do
    { 7 => [["recordada", false]], 8 => [] }.each do |others, said|
      SpeakCapture.clear
      early = Object.new
      paint(early, "recordada")
      others.times { |i| paint(Object.new, "ventana #{i}") }
      slide(early)
      assert_equal said, SpeakCapture.log, "with #{others} bitmaps painted after it"
    end
  end

  test "a pbDrawTextPositions burst is one line, its rows joined in paint order" do
    { [["Poción x2", 5, 15, false, nil, nil]] => "Poción x2",
      [["¡Logro conseguido!", 129, 12, 2, nil, nil], ["Coleccionista", 129, 40, 2, nil, nil]] =>
        "¡Logro conseguido!, Coleccionista",
      [["Pesca", 0, 0, 0, nil, nil], ["", 0, 20, 0, nil, nil], ["Pesca", 0, 40, 0, nil, nil],
       ["x3", 0, 60, 0, nil, nil]] => "Pesca, x3",
      [:ruido, ["Baya", 0, 0, 0, nil, nil]] => "Baya" }.each do |rows, line|
      SpeakCapture.clear
      card = Object.new
      pbDrawTextPositions(card, rows)
      slide(card)
      assert_equal [[line, false]], SpeakCapture.log, "for #{rows.inspect}"
    end
  end

  test "a paint with no letter or digit is no banner" do
    mark = Object.new
    pbDrawTextPositions(mark, [["*", 10, 15, 0, nil, nil]])
    slide(mark)
    dots = Object.new
    paint(dots, "...")
    slide(dots)
    assert_nothing_spoken "the autosave asterisk and a row of dots"
  end

  test "a burst that is not a list of rows is no banner" do
    card = Object.new
    pbDrawTextPositions(card, nil)
    slide(card)
    assert_nothing_spoken
  end

  test "whichever function painted last is what the card says" do
    egg = Object.new
    pbDrawTextPositions(egg, [["vieja", 5, 15, 0, nil, nil]])
    paint(egg, "¡Huevo listo!")
    slide(egg)
    assert_equal [["¡Huevo listo!", false]], SpeakCapture.log
  end

  test "a line painted on no bitmap is never said" do
    paint(nil, "Sin lienzo")
    slide(nil)
    assert_nothing_spoken
  end

  private

  # Paints text on bitmap as a banner does, with drawTextEx.
  def paint(bitmap, text)
    drawTextEx(bitmap, 5, 15, 300, 2, text, nil, nil)
  end

  # Slides bitmap in from the left, as the plugins' banners enter the map.
  def slide(bitmap)
    Scene_Map.new.addSprite(-300, 0, bitmap)
  end
end
