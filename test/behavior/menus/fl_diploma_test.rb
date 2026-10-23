# FL's Diploma (plugins/fl_diploma.rb) over a stand-in of its scene, painting as the script does: the player's name and
# the signature in one call, the main text after it. The certificate is said once as the scene opens, top to bottom as it
# lies on the screen, and kept on the info key until the scene ends.
class DiplomaScene
  DEFAULT_ROWS = [["Player: Ash", 256, 38, 2], ["Game Freak", 416, 320, 1]]

  def initialize(rows = DEFAULT_ROWS, main_y = 96)
    @rows = rows
    @main_y = main_y
  end

  def pbStartScene(main_text, _image_path)
    pbDrawTextPositions(nil, @rows) unless @rows.empty?
    drawTextEx(nil, 112, @main_y, 304, 8, main_text, nil, nil)
    :started
  end

  def pbEndScene
    :ended
  end
end
diploma_path = File.join(Harness::ROOT, "plugins", "fl_diploma.rb")
eval(Harness.source(diploma_path), TOPLEVEL_BINDING, diploma_path)

class FlDiplomaTest < PokeAccessTest
  MAIN = "This document is issued in recognition of your magnificent achievement."
  CERTIFICATE = "Player: Ash. #{MAIN} Game Freak"

  test "says the certificate top to bottom as it lies, not as it was painted, queued" do
    DiplomaScene.new.pbStartScene(MAIN, "Graphics/Pictures/diploma")
    assert_equal [[CERTIFICATE, false]], SpeakCapture.log
  end

  test "says the control codes and line breaks of the main text as the screen shows them" do
    DiplomaScene.new.pbStartScene("Well done,\n\\c[2]champion", "Graphics/Pictures/diploma")
    assert_equal ["Player: Ash. Well done, champion. Game Freak"], SpeakCapture.lines
  end

  test "reads the older copy that adds the ID and the play time, which paints its text lower down" do
    rows = [["Player: Ash     ID: 12345", 72, 64], ["Time: 3:45", 72, 96], ["PURPLE ZAFFRE", 416, 288, 1]]
    DiplomaScene.new(rows, 144).pbStartScene(MAIN, "Graphics/Pictures/diploma")
    assert_equal ["Player: Ash ID: 12345. Time: 3:45. #{MAIN} PURPLE ZAFFRE"], SpeakCapture.lines
  end

  test "keeps the certificate on the info key until the scene ends" do
    scene = DiplomaScene.new
    scene.pbStartScene(MAIN, "Graphics/Pictures/diploma")
    assert_equal CERTIFICATE, PokeAccess::Info.info_text
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "says nothing, and leaves the info key alone, when the certificate paints no text" do
    DiplomaScene.new([]).pbStartScene("", "Graphics/Pictures/diploma")
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text
  end

  test "hands back what the scene's own methods answer" do
    scene = DiplomaScene.new
    assert_equal [:started, :ended], [scene.pbStartScene(MAIN, "Graphics/Pictures/diploma"), scene.pbEndScene]
  end

  test "says the certificate once for each time the scene opens" do
    2.times { DiplomaScene.new.pbStartScene(MAIN, "Graphics/Pictures/diploma") }
    assert_equal [CERTIFICATE, CERTIFICATE], SpeakCapture.lines
  end
end
