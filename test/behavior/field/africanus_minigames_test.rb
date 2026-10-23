# Africanvs's minigames (games/africanus/minigames.rb) and its tables of truth (tablas.rb) on stand-ins of the game's
# scenes: the cage's tick and kicks, the archery's tick and arrows, the tables' grid by the names its shelves paint,
# and each table's transcription as it is shown.

# Runs a stand-in's blocking loop a frame per entry of @frames: the entry's ivars are set, then the frame's pollers.
module AfrMgLoop
  def run_frames
    (@frames || []).each do |ivars|
      ivars.each { |k, v| instance_variable_set(k, v) }
      PokeAccess::Frame.run_pollers
    end
  end
end

class EscapeGaulScene
  include AfrMgLoop
  PERFECT_KICK_Y = 142
  NUM_KICKS_PER_STATE = 3
  def pbMain; run_frames; end
end

class TheArcherScene
  include AfrMgLoop
  PERFECT_SHOT_Y = 189
  def pbMain; run_frames; end
end

class TablesScreen
  include AfrMgLoop
  def mainLoop; run_frames; end
  def can_access_table?(_index); true; end
  def showImage(_select); end
end

%w[tablas minigames].each do |name|
  path = File.join(Harness::ROOT, "games", "africanus", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class AfricanusMinigamesTest < PokeAccessTest
  Games = PokeAccess::AfricanusMinigames
  Sprite = Struct.new(:x, :y, :visible, :src_rect)
  Rect = Struct.new(:x, :y, :width, :height)

  test "the cage's tick rises toward the perfect kick point and falls past it, once per cursor move" do
    scene = kick_scene
    pitches = ticks(scene, :kick) do
      [62, 102, 142, 142, 182, 222].each { |y| move(scene, "kickpoint", y) }
    end
    assert_equal [80, 115, 150, 115, 80], pitches, "the ends lowest, the perfect point highest, a still cursor quiet"
  end

  test "the cage's tick peaks on 142 when the game names no perfect point" do
    scene = kick_scene
    pitches = with_const(EscapeGaulScene, :PERFECT_KICK_Y, nil) do
      ticks(scene, :kick) { [142, 102].each { |y| move(scene, "kickpoint", y) } }
    end
    assert_equal [150, 115], pitches
  end

  test "a cursor with no travel still ticks highest on the perfect point" do
    kick = kick_scene
    kick.instance_variable_set(:@cursorMaxY, 62)
    kick.instance_variable_set(:@cursorMinY, 62)
    archer = archer_scene
    archer.instance_variable_set(:@cursorMinY, 189)
    archer.instance_variable_set(:@cursorMaxY, 189)
    assert_equal [150], ticks(kick, :kick) { move(kick, "kickpoint", 142) }, "the cage"
    assert_equal [150], ticks(archer, :archer) { move(archer, "selector", 189) }, "the archery"
  end

  test "says each kick once, queued behind the kick's sound, against the nine that fell the door" do
    scene = kick_scene
    hold(scene, :kick) do
      scene.instance_variable_set(:@kickCount, 3)
      Games.poll
      Games.poll
      scene.instance_variable_set(:@kickCount, 4)
      Games.poll
    end
    assert_equal [[PokeAccess::I18n.t(:afr_kick, :n => 3, :total => 9), false],
                  [PokeAccess::I18n.t(:afr_kick, :n => 4, :total => 9), false]], SpeakCapture.log
  end

  test "a cage whose kick cursor is not drawn says its kicks without a tick" do
    scene = EscapeGaulScene.new
    scene.instance_variable_set(:@kickCount, 1)
    assert_equal [], ticks(scene, :kick) { Games.poll }, "no tick"
    assert_equal [PokeAccess::I18n.t(:afr_kick, :n => 1, :total => 9)], SpeakCapture.lines
  end

  test "says nothing before the first kick" do
    [nil, 0].each do |kicks|
      scene = kick_scene
      scene.instance_variable_set(:@kickCount, kicks)
      hold(scene, :kick) { Games.poll }
      assert_nothing_spoken "with #{kicks.inspect} kicks"
    end
  end

  test "counts the kicks that fell the door from the game's kicks per rope state, three when it names none" do
    { 4 => 12, nil => 9 }.each do |per_state, total|
      scene = kick_scene
      scene.instance_variable_set(:@kickCount, 1)
      SpeakCapture.clear
      with_const(EscapeGaulScene, :NUM_KICKS_PER_STATE, per_state) { hold(scene, :kick) { Games.poll } }
      assert_equal [PokeAccess::I18n.t(:afr_kick, :n => 1, :total => total)], SpeakCapture.lines,
                   "with #{per_state.inspect} kicks per state"
    end
  end

  test "the archery's tick peaks on the game's perfect shot, below the travel's midpoint" do
    scene = archer_scene
    pitches = ticks(scene, :archer) do
      [259, 224, 189, 189, 154, 192].each { |y| move(scene, "selector", y) }
    end
    assert_equal [80, 115, 150, 115, 147], pitches, "the lower end lowest, the perfect shot highest, the midpoint short"
  end

  test "the archery's tick peaks on the travel's midpoint when the game names no perfect shot" do
    scene = archer_scene
    pitches = with_const(TheArcherScene, :PERFECT_SHOT_Y, nil) do
      ticks(scene, :archer) { [192, 259].each { |y| move(scene, "selector", y) } }
    end
    assert_equal [150, 80], pitches
  end

  test "says each arrow with the points its numeral shows, not the running total" do
    { 0 => 10, 78 => 7, 172 => 5, 202 => 1 }.each do |cut, points|
      scene = archer_scene(cut)
      scene.instance_variable_set(:@arrowCount, 2)
      scene.instance_variable_set(:@sumPoints, 99)
      SpeakCapture.clear
      hold(scene, :archer) { Games.poll }
      assert_equal [[PokeAccess::I18n.t(:afr_archer, :arrow => 2, :n => points), false]], SpeakCapture.log,
                   "the numeral cut at x #{cut}"
    end
  end

  test "says an arrow once, and the next one as it is shot" do
    scene = archer_scene(78)
    hold(scene, :archer) do
      scene.instance_variable_set(:@arrowCount, 1)
      Games.poll
      Games.poll
      scene.instance_variable_get(:@sprites)["points"].src_rect = Rect.new(202, 0, 21, 72)
      scene.instance_variable_set(:@arrowCount, 2)
      Games.poll
    end
    assert_equal [PokeAccess::I18n.t(:afr_archer, :arrow => 1, :n => 7),
                  PokeAccess::I18n.t(:afr_archer, :arrow => 2, :n => 1)], SpeakCapture.lines
  end

  test "an arrow whose numeral cannot be read says nothing" do
    { "a cut no numeral starts at" => archer_scene(50), "no points sprite" => archer_scene,
      "no sprites drawn" => TheArcherScene.new }.each do |what, scene|
      scene.instance_variable_set(:@arrowCount, 1)
      hold(scene, :archer) { Games.poll }
      assert_nothing_spoken what
    end
  end

  test "an arrow whose numeral is cut late is said once it is" do
    scene = archer_scene(50)
    hold(scene, :archer) do
      scene.instance_variable_set(:@arrowCount, 1)
      Games.poll
      scene.instance_variable_get(:@sprites)["points"].src_rect = Rect.new(78, 0, 94, 72)
      Games.poll
    end
    assert_equal [PokeAccess::I18n.t(:afr_archer, :arrow => 1, :n => 7)], SpeakCapture.lines
  end

  test "says nothing before the first arrow" do
    [nil, 0].each do |arrows|
      scene = archer_scene(78)
      scene.instance_variable_set(:@arrowCount, arrows)
      hold(scene, :archer) { Games.poll }
      assert_nothing_spoken "with #{arrows.inspect} arrows"
    end
  end

  test "says the cell under the selector by the name its shelf paints, cutting in" do
    { [16, 24] => "Sagunto", [262, 24] => "Emporiae", [16, 68] => "Massilia", [262, 68] => "Pisae",
      [16, 332] => "Cirta", [262, 332] => "Cartago" }.each do |(x, y), name|
      scene = tables_screen("tabla", x, y)
      SpeakCapture.clear
      Games.tables(scene)
      assert_equal [[name, true]], SpeakCapture.log, "the selector at (#{x}, #{y})"
    end
  end

  test "the second shelf names its own cells, in either build's prefix" do
    { "tablo" => "Roma I", "tablo_eng" => "Roma I", "tabla_eng" => "Sagunto" }.each do |prefix, name|
      SpeakCapture.clear
      Games.tables(tables_screen(prefix, 16, 24))
      assert_equal [name], SpeakCapture.lines, "the prefix #{prefix}"
    end
  end

  test "marks a cell the player cannot open yet as locked" do
    scene = tables_screen("tabla", 262, 68)
    def scene.can_access_table?(index); index != 3; end
    Games.tables(scene)
    assert_equal [PokeAccess::I18n.t(:afr_table_locked, :name => "Pisae")], SpeakCapture.lines
  end

  test "says a cell once while the selector rests on it" do
    scene = tables_screen("tabla", 16, 24)
    3.times { Games.tables(scene) }
    assert_equal ["Sagunto"], SpeakCapture.lines
  end

  test "says nothing with the selector hidden, above the grid or past it" do
    { "hidden" => [16, 24, false], "above" => [16, 0, true], "past" => [16, 376, true] }.each do |what, (x, y, shown)|
      scene = tables_screen("tabla", x, y)
      scene.instance_variable_get(:@selector).visible = shown
      Games.tables(scene)
      assert_nothing_spoken "the selector #{what}"
    end
  end

  test "a selector that cannot say whether it shows is taken as hidden" do
    scene = tables_screen("tabla", 16, 24)
    scene.instance_variable_set(:@selector, Struct.new(:x, :y).new(16, 24))
    Games.tables(scene)
    assert_nothing_spoken
  end

  test "showing a table says its transcription, cutting in, and keeps it for the info key" do
    scene = tables_screen("tablo_eng", 16, 24)
    scene.showImage(1)
    text = PokeAccess::AfricanusTablas::TEXTS["tablo_eng2"]
    assert_equal [[text, true]], SpeakCapture.log
    assert_equal text, PokeAccess::Info.info_text
  end

  test "a picture with no transcription is said as a full-screen image" do
    [["tabla_fr", 0, true], ["tabla", 20, true], ["tabla", 0, false]].each do |prefix, select, listed|
      scene = tables_screen(prefix, 16, 24)
      scene.instance_variable_set(:@pictures, nil) unless listed
      SpeakCapture.clear
      scene.showImage(select)
      assert_equal [[PokeAccess::I18n.t(:img_fullscreen), true]], SpeakCapture.log,
                   "#{prefix}, picture #{select}#{listed ? '' : ', no pictures listed'}"
    end
  end

  test "each minigame is read while its loop runs, and nothing once it returns" do
    kick = kick_scene
    kick.instance_variable_set(:@frames, [{ :@kickCount => 1 }])
    arrow = archer_scene(0)
    arrow.instance_variable_set(:@frames, [{ :@arrowCount => 1 }])
    table = tables_screen("tabla", 16, 24)
    table.instance_variable_set(:@frames, [{}])
    [[kick, :pbMain, PokeAccess::I18n.t(:afr_kick, :n => 1, :total => 9), :@kickCount],
     [arrow, :pbMain, PokeAccess::I18n.t(:afr_archer, :arrow => 1, :n => 10), :@arrowCount],
     [table, :mainLoop, "Sagunto", nil]].each do |scene, loop_name, said, counter|
      SpeakCapture.clear
      scene.send(loop_name)
      assert_equal [said], SpeakCapture.lines, "#{scene.class} while #{loop_name} runs"
      scene.instance_variable_set(counter, 2) if counter
      scene.instance_variable_get(:@selector).x = 262 unless counter
      SpeakCapture.clear
      PokeAccess::Frame.run_pollers
      assert_nothing_spoken "#{scene.class} after #{loop_name} returned"
    end
  end

  private

  # A cage at the game's kick travel (62 to 222 around 142), its kick cursor shown.
  def kick_scene
    scene = EscapeGaulScene.new
    scene.instance_variable_set(:@sprites, { "kickpoint" => Sprite.new(358, 62, true, nil) })
    scene.instance_variable_set(:@cursorMinY, 62)
    scene.instance_variable_set(:@cursorMaxY, 222)
    scene
  end

  # An archery at the game's travel (125 to 259), its points sprite cut at x (no points sprite for nil).
  def archer_scene(cut = nil)
    scene = TheArcherScene.new
    sprites = { "selector" => Sprite.new(358, 125, true, nil) }
    sprites["points"] = Sprite.new(290, 130, true, Rect.new(cut, 0, 30, 72)) if cut
    scene.instance_variable_set(:@sprites, sprites)
    scene.instance_variable_set(:@cursorMinY, 125)
    scene.instance_variable_set(:@cursorMaxY, 259)
    scene
  end

  # The tables screen as the game builds it for a picture prefix, its selector shown at (x, y).
  def tables_screen(prefix, x, y)
    scene = TablesScreen.new
    scene.instance_variable_set(:@pictures_prefix, prefix)
    scene.instance_variable_set(:@pictures, Array.new(16) { |i| "Graphics/Pictures/tablas/#{prefix}#{i + 1}" })
    scene.instance_variable_set(:@selector, Sprite.new(x, y, true, nil))
    scene
  end

  # Moves a sprite of the held scene to y and reads one frame.
  def move(scene, sprite, y)
    scene.instance_variable_get(:@sprites)[sprite].y = y
    Games.poll
  end

  # Runs the block with scene held as the minigame of that kind, let go after.
  def hold(scene, kind)
    Games.hold(scene, kind)
    yield
  ensure
    Games.release
  end

  # The pitches of the minigame ticks played while the block runs with scene held.
  def ticks(scene, kind)
    pitches = nil
    with_cue_log do |log|
      hold(scene, kind) { yield }
      pitches = log.select { |entry| cue_name(entry).include?("pa_mg_tick") }.map { |entry| entry[2] }
    end
    pitches
  end

  # The block's value with klass's constant name set to value, or removed for nil; the game's value put back after.
  def with_const(klass, name, value)
    was = klass.const_get(name)
    klass.send(:remove_const, name)
    klass.const_set(name, value) unless value.nil?
    yield
  ensure
    klass.send(:remove_const, name) if klass.const_defined?(name, false)
    klass.const_set(name, was)
  end
end
