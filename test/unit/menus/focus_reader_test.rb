# FocusReader, the declared "say the focused entry when the cursor moves" reader: index from an instance variable or a
# @sprites window, entries from a list, the first read queued unless told otherwise, a fresh start per screen.

class FocusIvarScene; attr_accessor :index; def initialize; @index = 0; end; def update; end; end
class FocusItemsScene; attr_accessor :index, :rows; def initialize(rows); @rows = rows; @index = 0; end; def update; end; end
class FocusSpriteScene
  def initialize(win); @sprites = { "list" => win }; end
  def update; @sprites["list"].update; end
end
class FocusInterruptScene; attr_accessor :index; def initialize; @index = 0; end; def update; end; end
class FocusCloseScene; attr_accessor :index; def initialize; @index = 0; end; def update; end; def pbEndScene; end; end
class FocusMarkedScene; attr_accessor :index; def initialize; @index = 0; end; def update; end; def pbEndScene; end; end
class FocusKeyScene; attr_accessor :index, :page; def initialize; @index = 0; @page = 1; end; def update; end; end

class FocusReaderTest < PokeAccessTest
  test "says the entry under an index, the first read queued and each move cutting in" do
    PokeAccess::FocusReader.define("FocusIvarScene") { |i| "row #{i}" }
    scene = FocusIvarScene.new
    [0, 0, 2].each { |i| scene.index = i; scene.update }

    assert_equal [["row 0", false], ["row 2", true]], SpeakCapture.log
  end

  test "with :close, keeps each line on the info key, and forgets it as the screen closes" do
    PokeAccess::FocusReader.define("FocusCloseScene", :close => :pbEndScene) { |i| i == 2 ? nil : "row #{i}" }
    scene = FocusCloseScene.new
    scene.update
    assert_equal "row 0", PokeAccess::Info.info_text
    assert_equal "row 0", PokeAccess::Info.row_text
    scene.index = 1
    scene.update
    assert_equal "row 1", PokeAccess::Info.info_text
    scene.index = 2
    scene.update
    assert_equal "row 1", PokeAccess::Info.info_text, "a line of nothing leaves the last on the key"
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "with :close, says each line and keeps it clean on the info key, and an empty one leaves the last" do
    PokeAccess::FocusReader.define("FocusMarkedScene", :close => :pbEndScene) { |i| i == 1 ? "" : "Pueblo\\c[1]" }
    scene = FocusMarkedScene.new
    scene.update
    assert_equal [["Pueblo", false]], SpeakCapture.log
    assert_equal "Pueblo", PokeAccess::Info.info_text
    scene.index = 1
    scene.update
    assert_equal "Pueblo", PokeAccess::Info.info_text
  ensure
    PokeAccess::Info.clear_text
  end

  test "without :close, leaves the info key alone" do
    PokeAccess::Info.set_info(:text, "the screen's own")
    PokeAccess::FocusReader.define("FocusIvarScene") { |i| "row #{i}" }
    scene = FocusIvarScene.new
    scene.index = 3
    scene.update
    assert_equal "the screen's own", PokeAccess::Info.info_text
  ensure
    PokeAccess::Info.clear_text
  end

  test "hands the block the entry of a list and reads again when the entry under a still cursor changes" do
    PokeAccess::FocusReader.define("FocusItemsScene", :items => :@rows) { |row, i| "#{row} (#{i + 1})" }
    scene = FocusItemsScene.new(%w[Potion Antidote])
    scene.update
    scene.rows = %w[Ether Antidote]
    scene.update
    scene.index = 5
    scene.update

    assert_equal [["Potion (1)", false], ["Ether (1)", true]], SpeakCapture.log
  end

  test "reads a window of the scene's sprites and leaves it to itself" do
    PokeAccess::FocusReader.define("FocusSpriteScene", :index => "list") { |i| "leaf #{i}" }
    win = Window_DrawableCommand.new(%w[Spring Summer])
    scene = FocusSpriteScene.new(win)
    scene.update
    win.index = 1
    scene.update

    assert_equal [["leaf 0", false], ["leaf 1", true]], SpeakCapture.log
    assert PokeAccess.dedicated?(win), "the generic command-window reader stays off the window"
  end

  test "lets the first read cut in too with :queue false, and says nothing for a negative index" do
    PokeAccess::FocusReader.define("FocusInterruptScene", :queue => false) { |i| "choice #{i}" }
    scene = FocusInterruptScene.new
    scene.update
    scene.index = -1
    scene.update

    assert_equal [["choice 0", true]], SpeakCapture.log
  end

  test "reads again when what its key gives changes under a still cursor" do
    PokeAccess::FocusReader.define("FocusKeyScene", :key => proc { |scene, i| [scene.page, i] }) do |i, scene|
      "page #{scene.page}, row #{i}"
    end
    scene = FocusKeyScene.new
    scene.update
    scene.page = 2
    scene.update

    assert_equal [["page 1, row 0", false], ["page 2, row 0", true]], SpeakCapture.log
  end

  test "calls a block with no more values than it takes" do
    {
      proc { |a| a } => 1,
      proc { |a, b| [a, b] } => [1, 2],
      proc { |*a| a } => [1, 2, 3]
    }.each do |blk, expected|
      assert_equal expected, PokeAccess::FocusReader.call_with(blk, [1, 2, 3]), "for arity #{blk.arity}"
    end
  end
end
