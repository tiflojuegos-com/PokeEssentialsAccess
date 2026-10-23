# The EV allocator (Level Based Mixed EV System), a mode of the summary's stats page while $evalloc is set: its block
# (pool, reset key, arrow hint) said once as it opens, the stat under the selector as it moves, a value or pool change
# as the page repaints it; silent outside the mode. Each step of the plugin's loop is pbUpdate, then the repaint.
# Gamedata pass.
class EvAllocatorGdTest < PokeAccessTest
  # The plugin's selector sprite, whose index mirrors the cursor the loop keeps in a local.
  Selector = Struct.new(:index)

  # The Pokemon's effort points on each of the page's six rows.
  EVS = { :HP => 84, :ATTACK => 12, :DEFENSE => 0, :SPECIAL_ATTACK => 8, :SPECIAL_DEFENSE => 4, :SPEED => 252 }

  # The block the plugin paints where the ability goes while allocating, as it is said, for a pool of 108.
  BLOCK = "EV Pool: 108, [S] resets EVs, When EV is 0: [<-] to max."

  test "outside the allocator a summary frame says nothing" do
    scene, = summary
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "opening the mode says its block once, queued, and nothing else of the page" do
    scene, = summary
    open_mode(scene)
    assert_equal [[BLOCK, false]], SpeakCapture.log
  end

  test "the stat under the selector follows the block, queued, and a frame where nothing moved says nothing" do
    scene, = summary
    open_mode(scene)
    SpeakCapture.clear
    2.times { scene.pbUpdate }
    assert_equal [[row(:HP, 84), false]], SpeakCapture.log
  end

  test "moving the selector says each row as the mixed mode labels it, Attack's points under both of its rows" do
    scene, selector = opened
    { 1 => row(:ATTACK, 12, :SPECIAL_ATTACK), 3 => row(:SPECIAL_ATTACK, 12, :ATTACK), 2 => row(:DEFENSE, 0),
      5 => row(:SPEED, 252) }.each do |i, want|
      SpeakCapture.clear
      selector.index = i
      scene.pbUpdate
      assert_equal [[want, true]], SpeakCapture.log, "row #{i}"
    end
  end

  test "in purist mode each row is its own stat, shared with none" do
    Settings.const_set(:PURIST_MODE, true)
    scene, selector = opened
    said = [1, 3].map do |i|
      SpeakCapture.clear
      selector.index = i
      scene.pbUpdate
      SpeakCapture.last
    end
    assert_equal [row(:ATTACK, 12), row(:SPECIAL_ATTACK, 8)], said
  ensure
    Settings.send(:remove_const, :PURIST_MODE)
  end

  test "a point moved is said on the repaint with the pool, interrupting, and a repaint with no change is silent" do
    scene, = opened
    scene.pokemon.ev[:HP] = 88
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken "the frame before the repaint"
    paint(scene, "104")
    paint(scene, "104")
    assert_equal [["#{row(:HP, 88)}, #{pool_left('104')}", true]], SpeakCapture.log
  end

  test "the reset key on a stat already at 0 says the pool it gave back" do
    scene, selector = opened
    selector.index = 2
    scene.pbUpdate
    paint(scene, "108")
    scene.pokemon.ev.keys.each { |k| scene.pokemon.ev[k] = 0 }
    SpeakCapture.clear
    scene.pbUpdate
    paint(scene, "512")
    assert_equal [["#{row(:DEFENSE, 0)}, #{pool_left('512')}", true]], SpeakCapture.log
  end

  test "a repaint after moving between the two rows that share Attack says the row with the pool" do
    scene, selector = opened(1)
    selector.index = 3
    scene.pbUpdate
    SpeakCapture.clear
    paint(scene, "108")
    assert_equal [["#{row(:SPECIAL_ATTACK, 12, :ATTACK)}, #{pool_left('108')}", true]], SpeakCapture.log
  end

  test "leaving the mode gives the page back to the summary's reader, which reads it again as a turn" do
    scene, = summary
    page_three(scene)
    page = SpeakCapture.lines
    open_mode(scene)
    scene.pbUpdate
    $evalloc = false
    scene.pbUpdate
    SpeakCapture.clear
    page_three(scene)
    assert_equal 1, page.length, page.inspect
    assert_equal [[page[0], true]], SpeakCapture.log
  end

  test "opening the mode again says its block, then the stat the selector starts on, queued" do
    scene, = opened
    $evalloc = false
    scene.pbUpdate
    SpeakCapture.clear
    open_mode(scene)
    scene.pbUpdate
    assert_equal [[BLOCK, false], [row(:HP, 84), false]], SpeakCapture.log
  end

  test "brief leaves the reset key's hint and the arrow hint out of the block" do
    PokeAccess::Config.verbosity = :brief
    scene, = summary
    open_mode(scene)
    assert_equal [["EV Pool: 108", false]], SpeakCapture.log
  end

  test "with no stat under the selector only the mode's block is said" do
    { "no selector" => lambda { |s| s.instance_variable_set(:@sprites, {}) },
      "a selector past the rows" => lambda { |s| s.instance_variable_get(:@sprites)["EVsel"].index = 6 },
      "a stat the Pokemon keeps no points for" => lambda do |s|
        s.instance_variable_get(:@sprites)["EVsel"].index = 5
        s.pokemon.ev.delete(:SPEED)
      end }.each do |what, unfocus|
      scene, = summary
      unfocus.call(scene)
      SpeakCapture.clear
      open_mode(scene)
      scene.pbUpdate
      scene.pokemon.ev[:HP] = 88
      paint(scene, "104")
      assert_equal [[BLOCK, false]], SpeakCapture.log, what
      $evalloc = false
      scene.pbUpdate
    end
  end

  test "a repaint without the pool's label says nothing while allocating" do
    scene, = opened
    SpeakCapture.clear
    PokeAccess::PaintCapture.arm(:summary_egg)
    pbDrawTextPositions(nil, [["STATS", 0, 0], ["HP", 224, 120]])
    PokeAccess::SummaryV21.speak_page(scene, 3)
    assert_nothing_spoken
  end

  test "the full-description panel is read on the way in, and the game's panel still runs" do
    text = "Levitate: Gives full immunity to all Ground-type moves."
    assert_equal [text, nil], pbFullAbilityWindow(text)
    assert_equal [[text, false]], SpeakCapture.log
  end

  test "an empty full-description panel says nothing" do
    pbFullAbilityWindow("")
    assert_nothing_spoken
  end

  def teardown
    $evalloc = false
    super
  end

  private

  # A summary scene on a Pokemon with EVS, its selector on row index, as the stats page leaves it before allocating.
  def summary(index = 0)
    scene = PokemonSummary_Scene.new(Poke.build(:name => "Chispa", :ev => EVS.dup))
    selector = Selector.new(index)
    scene.instance_variable_set(:@sprites, { "EVsel" => selector })
    scene.pbUpdate
    [scene, selector]
  end

  # A summary scene with the allocator opened on row index and that row said, the log cleared.
  def opened(index = 0)
    scene, selector = summary(index)
    open_mode(scene)
    scene.pbUpdate
    SpeakCapture.clear
    [scene, selector]
  end

  # Raises the allocator's flag and paints its first page, as pbEVAllocation does.
  def open_mode(scene)
    $evalloc = true
    paint(scene, "108")
  end

  # The stats page repainted while allocating with pool left, then read as the summary reads a page.
  def paint(scene, pool)
    PokeAccess::PaintCapture.arm(:summary_egg)
    drawTextEx(nil, 224, 322, 282, 2, "When EV is 0: [<-] to max.")
    pbDrawTextPositions(nil, [["STATS", 0, 0], ["EV Pool:", 224, 290], [pool, 344, 290], ["[S] resets EVs", 362, 290]])
    PokeAccess::SummaryV21.speak_page(scene, 3)
  end

  # The stats page as it paints outside the allocator, read as the summary reads a page.
  def page_three(scene)
    PokeAccess::PaintCapture.arm(:summary_egg)
    drawTextEx(nil, 0, 0, 200, 1, "Page 3")
    PokeAccess::SummaryV21.speak_page(scene, 3)
  end

  # A row as the page labels it, with the stat whose row it lights along with it in the mixed mode.
  def row(stat, n, shared_with = nil)
    name = PokeAccess::Data.stat_name(stat)
    if shared_with
      name = PokeAccess::I18n.t(:ev_shared, :stat => name, :with => PokeAccess::Data.stat_name(shared_with))
    end
    PokeAccess::I18n.t(:ev_row, :stat => name, :n => n)
  end

  def pool_left(n)
    PokeAccess::I18n.t(:ev_pool_left, :n => n)
  end
end
