# Pokemon Reborn's puzzles of the remate J (games/reborn/puzzles/): Genesect's extra generators and their Zygarde Cells,
# the way back onto the plan from any spinner state in Devon's third sub-puzzle (map 631), the order and Honey of the
# Aventurine Woods with their ways in, the New World's gates and Route 1's pairs shared between rams and rides, and the
# Cut tree on Rhodochrine's way round. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesRbrjTest < PokeAccessTest
  SWITCHES = (1729..1748).to_a + (761..775).to_a + (294..379).to_a + [391, 1373, 1374, :Blindstep]
  VARS = [77, 572, 637, 655, 656]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::RebornAventurineBugs.forget
    PokeAccess::RebornRhodochrineStory.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "after Genesect the extra generators' plan goes on to the three Zygarde Cells, used from on top" do
    gen = PokeAccess::RebornGenesect
    on_map(877, 30, 5)
    cell = place(206, 9, 82, "He")
    [1730, 1731, 1732, 1734, 1735, 1736, 1737, 1739, 1741, 1742].each { |s| $game_switches[s] = true }
    $game_variables[637] = 28
    assert_equal "{rbrj_gen_cell}", PokeAccess::Puzzles.piece_name(cell)
    refute_includes info_key, "rbrd_gen_"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [135, :use, false], gen.target
    assert_includes info_key, "{rbrd_gen_hint_insert drive={rbrd_gen_shock}}"
    [1729, 1743, 1745].each { |s| $game_switches[s] = true }
    assert_equal [206, :here, false], gen.target
    assert_includes info_key, "{rbrj_gen_hint_cell}"
    assert_includes listed, [9, 82, "{rbrj_gen_cell_spot}"]
    assert_equal "{rbrd_gen_next what={rbrj_gen_cell}}", PokeAccess::Puzzles.piece_name(cell)
    $game_switches[1744] = true
    assert_equal "{rbrj_gen_cell_open}", PokeAccess::Puzzles.piece_name(cell)
    [1746, 1747, 1748].each { |s| $game_switches[s] = true }
    assert gen.cells_done?
    assert_nil gen.target
  end

  test "the extra generators' plan holds as the story raises the quest's count past Genesect, 29 to 32" do
    gen = PokeAccess::RebornGenesect
    on_map(877, 30, 5)
    [1730, 1731, 1732, 1734, 1735, 1736, 1737, 1739, 1741, 1742].each { |s| $game_switches[s] = true }
    PokeAccess::Config.puzzle_assist = true
    (28..32).each do |n|
      $game_variables[637] = n
      assert_equal [135, :use, false], gen.target, "quest count #{n}"
    end
    $game_switches[1741] = false
    assert_equal [161, :use, true], gen.target, "off the plan, the receptor that brings it back"
  end

  test "the plan before Genesect keeps to its own switches whatever the extra generators show" do
    gen = PokeAccess::RebornGenesect
    on_map(877, 31, 101)
    $game_variables[637] = 10
    $game_switches[1743] = true
    assert_equal [4, :step, false], gen.target
  end

  test "Devon's third sub-puzzle gives the next move from where the player stands and how the spinners lie" do
    devon = PokeAccess::RebornDevon
    on_map(631, 29, 25)
    [762, 764].each { |s| $game_switches[s] = true }
    refute_includes info_key, "rbrj_devon_"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [29, 25, :walk, 8, 22, 26], devon.recovery_move
    assert_includes info_key, "{rbrj_devon_ride dir={dir_n} lx=22 ly=26 x=29 y=25}"
    $game_switches[770] = true
    assert_equal [29, 25, :walk, 8, 29, 20], devon.recovery_move, "one spinner turned: the same step ends by the computer"
    $game_player.x, $game_player.y = 29, 20
    $game_switches[769] = true
    $game_switches[770] = false
    assert_includes info_key, "{rbrj_devon_use cx=30 cy=20 dir={dir_e} x=29 y=20}"
    assert_includes listed, [29, 20, "{rbrj_devon_from}"]
  end

  test "Devon's last two steps of 631 lead to the computer and out, and an unknown state falls back on the step" do
    devon = PokeAccess::RebornDevon
    on_map(631, 22, 10)
    [762, 763, 764, 765, 766, 769, 771, 773].each { |s| $game_switches[s] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [24, 10, :walk, 6, 25, 12], devon.recovery_move
    $game_player.x, $game_player.y = 27, 10
    assert_equal [26, 9, :act, 8, 26, 9], devon.recovery_move
    $game_switches[767] = true
    assert_equal [26, 9, :walk, 4, 25, 7], devon.recovery_move
    $game_player.x, $game_player.y = 25, 5
    assert_includes info_key, "{rbrj_devon_exit dir={dir_n} x=25 y=3}"
    $game_player.x, $game_player.y = 2, 2
    assert_nil devon.recovery_move
    assert_includes info_key, "{rbb_devon631_g}"
  end

  test "each Aventurine wood says its next log or web, with the way in and the Honey still needed" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(282, 30, 30)
    place(60, 12, 45, "EV060")
    place(94, 19, 44, "Heracross", 0, "pkmn_heracross", bug_list(372, "Pinsir crushed the log into bits!"))
    refute_includes info_key, "rbrj"
    PokeAccess::Config.puzzle_assist = true
    assert_equal 6, bugs.honey_left, "S300 is a ram of Route 1, no Honey"
    assert_equal [372, [:in, 17, 51, 272]], bugs.next_entry, "282's trees are reached on foot from Tanzan Mountain"
    assert_match(/\{rbrj4_aw_next_in ex=17 ey=51 honey=6 place=.* what=\{rbre_aw_/, info_key)
    [372, 373, 379, 374, 300, 375, 376].each { |s| $game_switches[s] = true }
    assert_nil bugs.next_entry
    assert_includes info_key, "{rbrj_aw_clear}"
  end

  test "Suicune's gate is ridden to through the westmost wood once it is clear, lost if its ram was ridden" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(282, 30, 30)
    $game_variables[572] = 2
    assert_nil bugs.gate_line
    bugs::WEST.each { |s| $game_switches[s] = true }
    assert_equal "{rbrj4_aw_gate_far bx=0 by=42 ex=55 ey=6 rx=72 ry=39 x=33 y=46}", bugs.gate_line
    $game_switches[310] = false
    $game_switches[311] = true
    assert_equal "{rbrj4_aw_gate_lost x=33 y=46}", bugs.gate_line, "S310's pair ridden: the way is gone"
    $game_switches[:Blindstep] = true
    $game_switches[375] = false
    assert_nil bugs.gate_line, "with Blindstep the gate wants S375 alone, and no lost way"
    $game_switches[375] = true
    assert_equal "{rbrj_aw_gate_suicune ex=12 ey=8 x=33 y=46}", bugs.gate_line
  end

  test "South Aventurine Woods' 283 rams S310, then says which Route 1 exit to ride in by and where to get off" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(283, 30, 30)
    place(84, 40, 20, "EV084")
    place(120, 39, 24, "Pinsir", 0, "pkmn_pinsir", bug_list(369, "Heracross tore down the spider web!"))
    PokeAccess::Config.puzzle_assist = true
    assert_equal [310, :walk], bugs.next_entry, "the ram first: it opens the way to S371"
    $game_switches[310] = true
    assert_equal [369, [:off, 34, 39, 26, 6, 31, 13]], bugs.next_entry
    assert_match(/\{rbrj_aw_next_dismount ex=26 ey=6 honey=5 rx=34 ry=39 what=\{rbre_aw_web_bug [^}]*\} x=31 y=13\}/,
                 info_key)
    [369, 368].each { |s| $game_switches[s] = true }
    assert_equal [367, [:off, 34, 39, 26, 6, 38, 26, :same]], bugs.next_entry, "on foot from the same getting off"
    [367, 370].each { |s| $game_switches[s] = true }
    assert_equal [371, [:ride, 72, 39, 55, 6]], bugs.next_entry, "S371 riding in by the east exit"
    $game_switches[371] = true
    assert_includes info_key, "{rbrj_aw_clear}"
  end

  test "283 says once what a ridden S310 pair loses, and skips it and S371" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(283, 30, 30)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[311] = true
    assert bugs.lost?(310)
    refute bugs.open?(371)
    assert_equal 369, bugs.next_entry[0]
    assert_includes info_key, "{rbrj4_aw_lost x=72 y=25}"
    assert_equal 4, bugs.honey_left, "S371's Honey is not counted any more"
  end

  test "with Blindstep a ridden S310 pair loses S310 alone: S371 is ridden to through the tall grass" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(283, 30, 30)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[311] = true
    $game_switches[:Blindstep] = true
    assert bugs.open?(371)
    assert_equal 5, bugs.honey_left
    [369, 368, 367, 370].each { |s| $game_switches[s] = true }
    assert_equal [371, [:ride, 34, 39, 26, 6]], bugs.next_entry, "in by the middle exit, no S310 on the way"
    assert_includes info_key, "{rbrj4_aw_lost x=72 y=25}"
    $game_switches[:Blindstep] = false
    assert_nil bugs.next_entry
  end

  test "with Blindstep 284's pair is ridden to from its own Route 1 exit, without the woods to the west" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(284, 30, 30)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[:Blindstep] = true
    $game_switches[311] = true
    [305, 377, 378].each { |s| $game_switches[s] = true }
    assert_equal [391, [:ride, 59, 43, 36, 8]], bugs.next_entry
    assert_includes info_key, "{rbrj_aw_next_ride ex=36 ey=8 honey=0 rx=59 ry=43 what={rbrj_aw_pair x=48 y=30}}"
    assert_equal 5, bugs.rides_left, "283's four, S371 still among them with Blindstep, and this pair"
  end

  test "North Aventurine Woods' 288 goes on without S309 and waits for S302 before S341" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(288, 30, 30)
    place(36, 52, 24, "EV036")
    place(120, 56, 29, "Pinsir", 0, "pkmn_pinsir", bug_list(341, "Heracross tore down the spider web!"))
    PokeAccess::Config.puzzle_assist = true
    $game_switches[308] = true
    assert_equal 4, bugs.honey_left
    assert_equal [342, [:in, 12, 19, 434]], bugs.next_entry, "S309 opens nothing: its pair gone, the order goes on"
    [342, 343, 344].each { |s| $game_switches[s] = true }
    assert_match(/\{rbrj4_aw_wait_bull what=\{rbre_aw_web_bug [^}]*\} x=66 y=16\}/, info_key)
    $game_switches[302] = true
    assert_match(/\{rbrj4_aw_next_east bx=69 by=30 honey=1 ox=0 oy=30 rx=66 ry=8 what=/, info_key)
    $game_switches[302] = false
    $game_switches[301] = true
    assert_nil bugs.next_entry
    assert_match(/\{rbrj4_aw_lost_behind what=\{rbre_aw_web_bug /, info_key)
    refute_includes info_key, "rbrj_aw_clear"
  end

  test "284's pair waits for the woods to the west, then is ridden to through them" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(284, 30, 30)
    PokeAccess::Config.puzzle_assist = true
    [305, 377, 378].each { |s| $game_switches[s] = true }
    assert_includes info_key, "{rbrj4_aw_wait what={rbrj_aw_pair x=48 y=30}}"
    (bugs::WEST + [300]).each { |s| $game_switches[s] = true }
    assert_includes info_key,
                    "{rbrj4_aw_next_far bx=0 by=48 ex=55 ey=6 honey=0 rx=72 ry=39 what={rbrj_aw_pair x=48 y=30} x=34 y=49}"
  end

  test "Raikou's gate is said once S328 and S339 are down, with the way in, and from the start with Blindstep" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(289, 30, 30)
    $game_variables[572] = 2
    assert_nil bugs.gate_line
    [328, 339].each { |s| $game_switches[s] = true }
    assert_equal "{rbrj_aw_gate_raikou ex=23 ey=51 x=57 y=9}", bugs.gate_line
    [328, 339].each { |s| $game_switches[s] = false }
    $game_switches[:Blindstep] = true
    assert_equal "{rbrj_aw_gate_raikou ex=80 ey=51 x=57 y=9}", bugs.gate_line
    $game_variables[572] = 1
    assert_nil bugs.gate_line
  end

  test "Route 1 counts the rides the woods still ask for against the free pairs, and says the ram that frees 290's" do
    bulls = PokeAccess::RebornRouteBulls
    on_map(286, 30, 30)
    tauros = place(65, 21, 26, "Tauros")
    assert_nil PokeAccess::Puzzles.piece_name(tauros)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbrj4_r1_free_tauros}", PokeAccess::Puzzles.piece_name(tauros)
    assert_equal 5, PokeAccess::RebornAventurineBugs.rides_left, "283's four and 284's far one, no gate yet"
    assert_equal 4, bulls.free_left, "290's three only get out once S314's log is aside"
    hint = bulls.hint
    assert_includes hint, "{rba_r1_hint}"
    assert_includes hint, "{rbrj4_r1_rides left=4 need=5}"
    assert_includes hint, "{rbrj4_r1_west_log more=3 x=2 y=15}", "first the ram that lets 290's three out"
    refute_includes hint, "rbrj4_r1_spare", "the seven free pairs are enough: no log pair is ridden"
    $game_switches[314] = true
    assert_equal 7, bulls.free_left
    refute_includes bulls.hint, "rbrj4_r1_west_log"
    refute_includes bulls.hint, "rbrj4_r1_spare"
    $game_variables[572] = 2
    assert_equal 7, PokeAccess::RebornAventurineBugs.rides_left, "both gates add a ride"
    $game_switches[1373] = true
    assert_equal 6, PokeAccess::RebornAventurineBugs.rides_left, "Raikou done"
  end

  test "Route 1 offers its spares only once the free pairs and the ram that frees 290's fall short" do
    bulls = PokeAccess::RebornRouteBulls
    on_map(290, 30, 30)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[315] = true
    assert_equal 0, bulls.free_behind_west, "S314's pair ridden: 290's three never get out"
    assert_includes bulls.hint, "{rbrj4_r1_rides left=4 need=5}"
    refute_includes bulls.hint, "rbrj4_r1_west_log"
    refute_includes bulls.hint, "rbrj4_r1_spare", "290's own spare is shut in as well"
    $game_map.map_id = 286
    assert_includes bulls.hint, "{rbrj4_r1_spare list=76, 26; 12, 26}"
    $game_switches[315] = false
    $game_switches[314] = true
    [321, 322, 303, 323, 318, 319].each { |s| $game_switches[s] = true }
    assert_equal 1, bulls.free_left
    assert_includes bulls.hint, "{rbrj4_r1_spare list=76, 26; 12, 26}"
    $game_map.map_id = 290
    assert_includes bulls.hint, "{rbrj4_r1_spare list=36, 52}", "out once S314's log is aside"
  end

  test "Rhodochrine's way round marks Beryl Ward's Cut tree before the house" do
    story = PokeAccess::RebornRhodochrineStory
    on_map(149, 9, 24)
    $game_variables[77] = 9
    $game_variables[655] = 4
    assert_equal [[40, 45], :rbre_rj_around_house], story.step(149)[2, 2]
  end

  # Swaps I18n.t for one that answers "{key name=value ...}", so the test reads keys and their values.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrj_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrj_kept_t)
    i18n.send(:remove_method, :rbrj_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::RebornAventurineBugs.forget
    PokeAccess::RebornRhodochrineStory.forget
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  # A bug's page: beating it has its partner break what the switch clears, and tell of it.
  def bug_list(switch, text)
    [TestCmd.new(111, [0, switch, 1], 0), TestCmd.new(121, [switch, switch, 0], 1), TestCmd.new(101, [text], 1),
     TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
  end

  def place(id, x, y, name, trigger = 0, sprite = "", list = nil)
    list ||= [TestCmd.new(101, ["text"]), TestCmd.new(0, [])]
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
