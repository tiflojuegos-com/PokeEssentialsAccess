# Pokemon Ashen Frost's story puzzles, part A (games/ashenfrost/puzzles/): the Duchampe statues and safe, the Rosewell
# spotlights, the Lonardo fireplace and the Lonardo Crypt. Without the assist, what the screen shows; with it, the way.
class AshenfrostPuzzlesAGdTest < PokeAccessTest
  SWITCHES = [67, 71, 88, 96, 102, 103, 104, 106, 107, 108]
  VARS = [39]

  # The bag of the game, holding the items listed.
  class Bag
    def initialize(*items); @items = items; end
    def has?(item); @items.include?(item); end
  end

  def setup
    super
    keyed
    Harness.load_puzzles("ashenfrost")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $bag
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $bag = @bag
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the hall's statues go by their place in reading order, and the assist names the next one in the hall: 7, 3, 1, 6" do
    on_map(109, 34, 9)
    $game_switches[67] = true
    ids = { 21 => [32, 11], 22 => [36, 5], 23 => [32, 5], 24 => [37, 8], 25 => [34, 5], 26 => [38, 5], 27 => [33, 8], 28 => [38, 11] }
    statues = {}
    ids.each { |id, (x, y)| statues[id] = place(id, x, y, "Switch") }
    frame
    assert_equal "{afa_statue n=7}", PokeAccess::Puzzles.piece_name(statues[21])
    assert_equal "{afa_statue n=1}", PokeAccess::Puzzles.piece_name(statues[23])
    assert_equal "{afa_statue n=2}", PokeAccess::Puzzles.piece_name(statues[25])
    refute PokeAccess::Locator.hidden?(statues[25])
    refute(frame.any? { |l| l.include?("afa_statue_next") }, "no order without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afa_statue_next n=7}"
    assert PokeAccess::Locator.hidden?(statues[25])
    refute PokeAccess::Locator.hidden?(statues[22])
    assert_includes right_ways, [32, 11]
    [[1, 3], [2, 1], [3, 6]].each do |pressed, n|
      $game_variables[39] = pressed
      assert_includes frame, "{afa_statue_next n=#{n}}"
    end
    $game_variables[39] = 4
    refute(frame.any? { |l| l.include?("afa_statue_next") }, "the ladder is up")
    $game_variables[39] = 0
    $game_player.x, $game_player.y = 9, 30
    refute(frame.any? { |l| l.include?("afa_statue_next") }, "nothing away from the hall")
  end

  test "the bedroom's smells are named while Truffles sniffs, and the assist keeps the metallic one, then the floorboards and the safe" do
    on_map(110, 27, 13)
    photo = place(17, 33, 10, "HiddenItem")
    stone = place(18, 32, 11, "HiddenItem")
    metal = place(21, 30, 5, "HiddenItem")
    safe = place(13, 30, 4, "Safe")
    frame
    assert_equal "{afa_photo}", PokeAccess::Puzzles.piece_name(photo), "a photo while Sylvester looks"
    refute(listed.any? { |r| r[0] == photo.x && r[1] == photo.y }, "a photo is no puzzle")
    $game_switches[71] = true
    frame
    assert_equal "{afa_smell}", PokeAccess::Puzzles.piece_name(photo)
    assert_equal "{afa_smell}", PokeAccess::Puzzles.piece_name(metal)
    refute PokeAccess::Locator.hidden?(stone)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afa_smell_hint}"
    assert PokeAccess::Locator.hidden?(stone)
    refute PokeAccess::Locator.hidden?(metal)
    $game_switches[71] = false
    $game_self_switches[[110, 21, "A"]] = true
    assert_includes frame, "{afa_floorboards_hint}"
    assert_equal "{afa_floorboards}", PokeAccess::Puzzles.piece_name(metal)
    refute PokeAccess::Locator.hidden?(stone)
    $game_self_switches[[110, 21, "B"]] = true
    $game_self_switches[[110, 13, "A"]] = true
    assert_includes frame, "{afa_safe_hint}"
    assert_equal "{afa_safe}", PokeAccess::Puzzles.piece_name(safe)
    assert_includes right_ways, [safe.x, safe.y]
    $game_self_switches[[110, 13, "B"]] = true
    assert_empty(frame.select { |l| l.include?("afa_") })
  end

  test "the Pump Room's three spots by the water, one of them with the assist, none once the clue is found" do
    on_map(114, 7, 16)
    spots = [[3, 15, 9], [4, 17, 9], [5, 16, 8]].map { |id, x, y| place(id, x, y, "HiddenItem") }
    frame
    assert_equal ["{afa_pump_spot}"] * 3, spots.map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    refute PokeAccess::Locator.hidden?(spots[1])
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_equal [false, true, true], spots.map { |ev| PokeAccess::Locator.hidden?(ev) }
    [3, 4, 5].each { |id| $game_self_switches[[114, id, "A"]] = true }
    frame
    refute PokeAccess::Locator.hidden?(spots[1])
    refute(listed.any? { |r| r[2] == "{afa_pump_spot}" }, "the clue is found")
  end

  test "the gallery's spotlights: its rule, the way back from a light, and the computer leaving its password to the entry" do
    on_map(188, 9, 4)
    assert_includes frame, "{afa_gallery_rule}"
    refute_includes info_key, "{afa_gallery_hint}"
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_includes info_key, "{afa_gallery_hint}"
    $game_switches[88] = true
    frame
    refute_includes info_key, "{afa_gallery_hint}"
    on_map(187, 14, 8)
    frame
    assert_equal "{afa_gallery_caught}", PokeAccess::Puzzles.sent_back_line([9, 20, 188], [14, 8, 187], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([9, 3, 188], [14, 8, 187], :map), "the door of the gallery"
    on_map(189, 7, 11)
    computer = place(1, 7, 10, "Computer")
    PokeAccess::Config.puzzle_assist = true
    refute_includes frame { fire(computer) }, "{puzzle_answer a=Rose}", "assist_answers.rb says it as the entry opens"
  end

  test "the fireplace: the clock's name, then with the assist the bucket, the sink, the fire and the wood in turn" do
    on_map(243, 9, 9)
    $bag = Bag.new
    clock = place(2, 9, 8, "EV002")
    fireplace = place(3, 4, 3, "Fire")
    frame
    assert_equal "{afa_clock}", PokeAccess::Puzzles.piece_name(clock)
    assert_equal "{afa_fireplace}", PokeAccess::Puzzles.piece_name(fireplace)
    refute(frame.any? { |l| l.include?("afa_clock_hint") }, "no way without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afa_clock_hint item=#{PokeAccess::Data.item_name(:BRONZEKEY)}}"
    $game_self_switches[[243, 2, "A"]] = true
    $bag = Bag.new(:BUCKET)
    assert_includes frame, "{afa_bucket_hint item=#{PokeAccess::Data.item_name(:BUCKET)}}"
    $bag = Bag.new(:BUCKETWATER)
    assert_includes frame, "{afa_douse_hint item=#{PokeAccess::Data.item_name(:BUCKETWATER)}}"
    $bag = Bag.new
    $game_self_switches[[243, 3, "A"]] = true
    assert_empty(frame.select { |l| l.include?("afa_") }, "the ladder cools down with the story")
    $game_switches[96] = true
    assert_includes frame, "{afa_wood_hint}"
    $game_self_switches[[243, 3, "C"]] = true
    assert_empty(frame.select { |l| l.include?("afa_") })
  end

  test "the crypt's vases go by their colour; with the assist the riddles' three, and each pushed to its hole in turn" do
    on_map(290, 2, 7)
    red = place(2, 7, 6, "Red")
    orange = place(10, 8, 6, "Orange")
    frame
    assert_equal "{afa_vase_red}", PokeAccess::Puzzles.piece_name(red)
    assert_equal "{afa_vase_orange}", PokeAccess::Puzzles.piece_name(orange)
    refute PokeAccess::Locator.hidden?(orange)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afa_vases_hint}"
    assert PokeAccess::Locator.hidden?(orange)
    refute PokeAccess::Locator.hidden?(red)
    on_map(289, 10, 22)
    vase = place(6, 8, 14, "Vase")
    frame
    assert_equal "{afa_vase_red}", PokeAccess::Puzzles.piece_name(vase)
    assert_equal [[2, 4, "{afa_hole}"], [10, 9, "{afa_hole}"], [19, 4, "{afa_hole}"]], listed.select { |r| r[2] == "{afa_hole}" }
    refute(frame.any? { |l| l.include?("afa_hole_hint") }, "no order without the assist")
    PokeAccess::Config.puzzle_assist = true
    $game_switches[102] = true
    assert_includes frame, "{afa_hole_hint vase={afa_vase_red}}"
    $game_switches[106] = true
    $game_switches[103] = true
    assert_includes frame, "{afa_hole_hint vase={afa_vase_green}}"
    refute(listed.any? { |r| r[0] == 2 && r[1] == 4 }, "a filled hole")
  end

  test "the crypt's switches: with the assist the hall's, then on the icy floor the western one, the northern one undone" do
    on_map(288, 13, 21)
    switch = place(15, 13, 20, "Switch")
    place(16, 27, 18, "Rock I")
    frame
    assert_equal "{afa_crypt_switch}", PokeAccess::Puzzles.piece_name(switch)
    refute(frame.any? { |l| l.include?("afa_hall_switch_hint") }, "no way without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afa_hall_switch_hint}"
    $game_self_switches[[288, 16, "A"]] = true
    refute(frame.any? { |l| l.include?("afa_hall_switch_hint") }, "the rocks are gone")
    on_map(291, 15, 31)
    [[10, 13, 27, 11], [12, 2, 15, 13], [14, 10, 9, 15]].each { |id, x, y, rock| crypt_switch(id, x, y, rock) }
    PokeAccess::Config.puzzle_assist = true
    inst = PokeAccess::World::Mechanics.instances.find { |i| i.spec[:controls] }
    assert_equal({ 10 => [11, "A"], 12 => [13, "A"], 14 => [15, "A"] },
                 Hash[inst.controls.map { |id, w| [id, w[:self]] }], "each switch works its rock's self switch")
    assert_empty(frame.select { |l| l.include?("afa_deep") }, "the route through the controls leads to switch II")
    $game_self_switches[[291, 15, "A"]] = true
    assert_includes frame, "{afa_deep_stopper_hint}"
    assert_includes right_ways, [10, 9]
    $game_self_switches[[291, 15, "A"]] = false
    $game_self_switches[[291, 13, "A"]] = true
    assert_empty(frame.select { |l| l.include?("afa_deep") })
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afa_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afa_kept_t)
    i18n.send(:remove_method, :afa_kept_t)
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # Puts the player on a tile of a map with nothing placed, the flags off and the mechanics forgotten.
  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  # An event on the map with one page that shows a text.
  def place(id, x, y, name, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A switch of map 291 as the game's: its pages take the rock away and back by script, turning its own self switch A.
  def crypt_switch(id, x, y, rock)
    pages = [["true", 0, {}], ["false", 1, { :self_switch_valid => true, :self_switch_ch => "A" }]].map do |v, own, cond|
      list = [TestCmd.new(355, ["pbSetSelfSwitch(#{rock},\"A\",#{v})"]), TestCmd.new(123, ["A", own]), TestCmd.new(0, [])]
      TestPage.new(:trigger => 0, :list => list, :condition => cond)
    end
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Switch", :pages => pages, :active_page => pages[0])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The info key's line on the map.
  def info_key
    PokeAccess::Info.map_text.to_s
  end

  # The puzzle points listed as [x, y, name], by their tile.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end

  # The tiles listed as the right way.
  def right_ways
    listed.select { |_x, _y, name| name == "{puzzle_right_way}" }.map { |x, y, _name| [x, y] }
  end
end
