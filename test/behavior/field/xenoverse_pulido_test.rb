# Pokemon Xenoverse's puzzles of the second pass on the shipped profile: the Tide Gym's Unown letters and palm room, the
# Dielebi rooms, the bunker, the Altered Zodiac's mirrors, shadows and seal, the Regi tombs that ask for a Pokemon and the
# nests' baits, Abra, pads, doors, boulders and power box, and the legendaries that move away, each as heard with the
# puzzle assist and without it, and the blinking tiles' go. The name tables refuse a constant's symbol, as the game's own
# do on gen 6, and number the constants the puzzles name things by, so each name comes through its number.
class XenoversePulidoTest < PokeAccessTest
  include TileWorldHelpers
  include GuideHelpers

  NUMBERS = { PBSpecies => { :ABRA => 63, :MEW => 151, :EXEGGUTOR => 103, :TYRANITAR => 248, :BANDEON => 1001 },
              PBItems => { :PERLACQUA => 701, :PERLACQUA2 => 702, :PERLACQUA3 => 703 } }

  def setup
    super
    @tables = [PBSpecies, PBItems, PBMoves].map { |m| [m, m.method(:getName)] }
    @tables.each do |m, original|
      m.define_singleton_method(:getName) do |id|
        raise TypeError, "no implicit conversion of Symbol into Integer" if id.is_a?(Symbol)
        original.call(id)
      end
    end
    @numbered = []
    NUMBERS.each do |m, list|
      list.each do |sym, n|
        next if m.const_defined?(sym, false)
        m.const_set(sym, n)
        @numbered.push([m, sym])
      end
    end
  end

  def teardown
    @tables.each { |m, original| m.define_singleton_method(:getName, original) }
    @numbered.each { |m, sym| m.send(:remove_const, sym) }
    super
  end

  test "says the crossing of the blinking tiles once, then a go aimed at the safe window, never over the reader" do
    on_map(631)
    blink = PokeAccess::XenoBlink
    with_pace(3.8) do
      stand(60, 33)
      on = lambda { |f| f >= 41 && (f - 41) % 82 < 41 }
      aim = 41 + ((41 - 10 - blink::TURN) / 2) - (blink::LEAD * blink.frame_rate).round
      said = run_blink(blink, 0..130, on, false)
      assert_equal [t(:xv_blink_station, :way => t(:loc_leg, :n => 2, :dir => t(:dir_right)))], said[0]
      assert_equal [aim, aim + 82], (0..130).select { |f| said[f].include?(t(:xv_blink_go)) }
      assert_equal 3, said.flatten.length, "the crossing once and a go a cycle"
      late = run_blink(blink, 0..130, on, true)
      refute_includes late.flatten, t(:xv_blink_go), "never while the reader talks"
      clock = 0.0
      real = blink.method(:clock)
      blink.define_singleton_method(:clock) { clock }
      begin
        blink.reset
        heard = with_reader(nil) { (0..800).map { |f| clock = f / 40.0; frame(blink, f, on.call(f)) } }
      ensure
        blink.define_singleton_method(:clock, real)
      end
      first = (0..800).find { |f| heard[f].include?(t(:xv_blink_go)) }
      read = heard[0].first.length / blink::READ_CPS + blink::READ_GAP
      assert first && first / 40.0 >= read, "a reader that cannot tell waits for the line it was sent to be read"
    end
  end

  test "tells a blinking crossing with no room to react as very tight, and with the assist what other way there is" do
    on_map(631)
    blink = PokeAccess::XenoBlink
    with_pace(3.8) do
      stand(69, 32)
      on = lambda { |f| f >= 21 && (f - 21) % 42 < 21 }
      said = run_blink(blink, 0..130, on, false, 1202)
      assert_equal [t(:xv_blink_tight, :way => t(:loc_leg, :n => 2, :dir => t(:dir_right)))], said.flatten
      PokeAccess::Config.puzzle_assist = true
      assert_equal [t(:xv_blink_other_faster)], run_blink(blink, 0..0, on, false, 1202)[0].last(1)
      stand(64, 32)
      way = [t(:loc_leg, :n => 1, :dir => t(:dir_right)), t(:loc_leg, :n => 2, :dir => t(:dir_down))].join(", ")
      slow = lambda { |f| f >= 41 && (f - 41) % 82 < 41 }
      said = run_blink(blink, 0..130, slow, false)
      assert_equal [t(:xv_blink_tight_turn, :way => way), t(:xv_blink_no_other)], said.flatten,
                   "two blinking tiles and a turn on one leave no room in 41 frames, said as such"
      stand(62, 33)
      way = [t(:loc_leg, :n => 1, :dir => t(:dir_right)), t(:loc_leg, :n => 1, :dir => t(:dir_up))].join(", ")
      said = run_blink(blink, 0..130, slow, false)
      assert_equal t(:xv_blink_station, :way => way), said[0][0], "one blinking tile and a turn still fit"
      assert_includes said.flatten, t(:xv_blink_go)
    end
  end

  test "keeps the crossing and the go quiet while an event runs or a message is open, and says them once it ends" do
    on_map(631)
    blink = PokeAccess::XenoBlink
    with_pace(3.8) do
      stand(60, 33)
      on = lambda { |f| f >= 41 && (f - 41) % 82 < 41 }
      $game_temp.message_window_showing = true
      begin
        held = run_blink(blink, 0..130, on, false)
      ensure
        $game_temp.message_window_showing = false
      end
      assert_empty held.flatten, "nothing over a message"
      interp = $game_system.map_interpreter
      interp.define_singleton_method(:running?) { true }
      begin
        held = run_blink(blink, 0..130, on, false)
      ensure
        interp.define_singleton_method(:running?) { false }
      end
      assert_empty held.flatten, "nothing while an event runs"
      said = with_reader(false) { (131..260).map { |f| frame(blink, f, on.call(f)) } }
      assert_equal [t(:xv_blink_station, :way => t(:loc_leg, :n => 2, :dir => t(:dir_right)))], said[0]
      assert_includes said.flatten, t(:xv_blink_go)
    end
  end

  test "names each pad's Unown letter, with the assist where it leads, and a teleport says the letter reached" do
    on_map(145)
    place(13, 25, 10, [door(145, 24, 31)], "teleportblue", 1)
    place(42, 40, 37, [door(145, 24, 20)], "teleportblue", 1)
    k = t(:xv_unown_pad, :letter => "K")
    z = t(:xv_unown_pad, :letter => "Z")
    assert_equal [k, z].sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_unown_pad_leads, :pad => k, :to => t(:xv_unown_to_letter, :letter => "L")),
                  t(:xv_unown_pad_leads, :pad => z, :to => t(:xv_unown_to_exit))].sort, names.sort
    assert_equal t(:xv_unown_letter, :letter => "L"), PokeAccess::Locator.cause_line([25, 10, 145], [24, 31, 145])
    assert_nil PokeAccess::Locator.cause_line([25, 10, 145], [7, 11, 145]), "not off the letters"
  end

  test "names the palm room's Exeggutor, shells and sarcophagi, and with the assist the way to each pearl" do
    on_map(148)
    place(13, 27, 39, [TestCmd.new(355, ["fbText(\"Exegg...!\")"])])
    place(3, 22, 26, [TestCmd.new(111, [0, 229, 0])], "perla(rossa)")
    exegg = species(:EXEGGUTOR)
    assert_equal ["Especie103", "Item701"], [exegg, item(:PERLACQUA)], "named through their numbers"
    assert_equal [exegg, t(:xv_tide_shell)].sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_tide_palm_friendly, :pokemon => exegg, :item => item(:PERLACQUA)),
                  t(:xv_tide_shell_takes, :item => item(:PERLACQUA2))].sort, names.sort
    on_map(149)
    [[5, 9], [4, 11]].each { |id, x| place(id, x, 6, [TestCmd.new(101, ["?"])], "cofagrigus") }
    place(6, 7, 6, [], "sarcofago-vuoto")
    assert_equal [t(:xv_tide_sarcophagus)] * 2, names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_tide_sarcophagus), t(:xv_tide_sarcophagus_pearl)].sort, names.sort
  end

  test "names Dielebi's bells and holes, with the assist the way out, and says the room's version and the fall" do
    on_map(579)
    bell = [TestCmd.new(111, [12, "pbHasSpecies?(:DIELEBI)"]), door(580, 31, 26)]
    [[18, 30, 27], [19, 28, 25], [20, 20, 24]].each { |id, x, y| place(id, x, y, bell) }
    hole = place(22, 31, 25, [door(577, 9, 10)], "", 2)
    assert_equal ([t(:xv_dielebi_bell)] * 3 + [t(:xv_dielebi_hole)]).sort, names.sort
    assert_equal t(:xv_dielebi_hole), PokeAccess::Puzzles.piece_name(hole)
    assert_nil PokeAccess::Puzzles.info_line, "nothing before Dielebi"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_dielebi_bell_hole), t(:xv_dielebi_bell_way), t(:xv_dielebi_bell_way), t(:xv_dielebi_hole)].sort,
                 names.sort
    $game_switches[997] = true
    assert_equal t(:xv_dielebi_side_other), PokeAccess::Puzzles.info_line
    on_map(577)
    assert_equal t(:xv_dielebi_fell), PokeAccess::Puzzles.sent_back_line([31, 25, 579], [9, 10, 577], :map)
  end

  test "says the bunker's switches and flashes, and with the assist which platforms send the player back" do
    on_map(596)
    trap = place(3, 54, 23, [door(596, 31, 41)], "pedanebunker", 1)
    safe = place(7, 51, 30, [], "pedanebunker", 1)
    assert_equal t(:xv_bunker_platform), PokeAccess::Puzzles.piece_name(trap)
    tick
    $game_switches[1093] = true
    assert(tick.map(&:first).any? { |s| s.include?(t(:xv_bunker_switch_on)) })
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:xv_bunker_platform_trap), PokeAccess::Puzzles.piece_name(trap)
    assert_equal t(:xv_bunker_platform_safe), PokeAccess::Puzzles.piece_name(safe)
    on_map(602)
    button = place(22, 26, 6, [TestCmd.new(121, [1119, 1119, 0])])
    blind = place(58, 54, 23, [TestCmd.new(121, [1121, 1121, 0])])
    assert_equal [t(:xv_bunker_button)] * 2, names
    stand(26, 7)
    legs = [[4, :dir_right], [1, :dir_down], [2, :dir_right], [1, :dir_up], [3, :dir_right]]
    PokeAccess::World::Mechanics.used(button)
    assert_equal [[t(:xv_bunker_flash, :path => spoken(legs)), false]], tick
    PokeAccess::World::Mechanics.used(blind)
    assert_equal [[t(:xv_bunker_flash_none), false]], tick
    assert_equal t(:xv_bunker_trap_back), PokeAccess::Puzzles.sent_back_line([30, 6, 602], [9, 7, 602])
  end

  test "says the flash's way from the side of the button the player pressed it from, around the button and the traps" do
    Harness.load_puzzles("xenoverse")
    rows = ["#" * 37, "#" * 37, "#" * 37, "#" * 37, "#" * 37, "#" * 37,
            "#" * 24 + ".." + "#" + "@" + "." * 8 + "#", "#" * 24 + "." * 12 + "#", "#" * 24 + "." * 12 + "#", "#" * 37]
    with_tile_world(rows) do |world|
      world.map_id = 602
      traps = [[28, 6], [29, 6], [30, 6], [31, 6], [32, 6], [33, 6], [34, 6], [31, 7], [29, 8], [28, 8], [33, 8], [34, 8]]
      traps.each_with_index { |(x, y), i| world.events[100 + i] = TestGameEvent.new(:id => 100 + i, :x => x, :y => y,
                                                                                     :pages => [trap_page], :active_page => trap_page) }
      grid = [[3, :dir_right], [1, :dir_down], [2, :dir_right], [1, :dir_up], [3, :dir_right]]
      { [25, 6] => [[1, :dir_down], [5, :dir_right]], [27, 6] => [[1, :dir_down], [3, :dir_right]],
        [27, 8] => [[1, :dir_up], [3, :dir_right]], [26, 7] => [[4, :dir_right]] }.each do |(x, y), first|
        $game_player.x = x
        $game_player.y = y
        legs = first + grid[1..-1]
        line = PokeAccess::Puzzles.label_of(PokeAccess::XenoBunker.flash_line(22))
        assert_equal t(:xv_bunker_flash, :path => spoken(legs)), line, "pressed from #{x},#{y}"
      end
      $game_player.x = 30
      $game_player.y = 8
      legs = [[1, :dir_up], [3, :dir_left]] + grid
      line = PokeAccess::Puzzles.label_of(PokeAccess::XenoBunker.flash_line(22))
      assert_equal t(:xv_bunker_flash, :path => spoken(legs)), line, "up and round the traps of 29,8 and 28,8, not over them"
    end
  end

  test "says the reversed controls, names the mirrors as they show and the shadows, and why the player is sent back" do
    on_map(629)
    tick
    $game_switches[1500] = true
    assert(tick.map(&:first).any? { |s| s.include?(t(:xv_reverse_on)) })
    place(8, 40, 58, [], "mirrorkay", 4)
    place(5, 41, 45, [], "mirror", 4)
    assert_equal [t(:xv_mirror_altered), t(:xv_mirror_own)].sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_mirror_decoy), does(:xv_mirror_own, :xv_mirror_lets_by)].sort, names.sort
    assert_equal t(:xv_mirror_back), PokeAccess::Puzzles.sent_back_line([40, 58, 629], [40, 64, 629])
    on_map(631)
    place(5, 22, 23, [], "ombra", 3)
    assert_includes names, t(:xv_shadow)
    assert_equal t(:xv_shadow_back), PokeAccess::Puzzles.sent_back_line([31, 26, 631], [20, 27, 631])
    on_map(633)
    place(26, 34, 62, [TestCmd.new(355, ["pbPerseumN"])], "roccia")
    refute_includes names, t(:xv_seal_rock_trap)
    PokeAccess::Config.puzzle_assist = true
    assert_includes names, t(:xv_seal_rock_trap)
    assert_equal t(:xv_seal_back), PokeAccess::Puzzles.sent_back_line([32, 63, 633], [44, 64, 633])
  end

  test "with the assist, names each mirror by what it does in its zone, as it shows with the switch where it is" do
    on_map(629)
    place(11, 31, 44, [], "mirror", 4)
    place(12, 30, 41, [], "mirrorkay", 4)
    place(34, 10, 20, [], "mirror", 4)
    place(30, 10, 28, [], "mirroralteralice", 4)
    $game_switches[1189] = true
    assert_equal ([t(:xv_mirror_altered)] * 3 + [t(:xv_mirror_own)]).sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    want = [does(:xv_mirror_altered, :xv_mirror_lets_by), does(:xv_mirror_own, :xv_mirror_sends_back),
            does(:xv_mirror_altered, :xv_mirror_does_nothing), does(:xv_mirror_altered, :xv_mirror_sends_back)]
    assert_equal want.sort, names.sort,
                 "zone B lets the altered by; zone D the reflection, so with its switch on 30 sends back and 34 is idle"
  end

  test "with the assist, says the next press out of a mirror zone from where the player stands, slide by slide" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    walk = [[40, 64, false, step(walked(1, :dir_right))], [41, 64, false, step(walked(2, :dir_up))],
            [41, 62, false, step(slid(:dir_up))], [41, 58, false, step(slid(:dir_left))],
            [39, 58, true, step(slid(:dir_up))], [39, 55, false, step(slid(:dir_right))],
            [42, 55, true, step(slid(:dir_up))]]
    walk.each do |x, y, on, line|
      mirrors_at(1187, on)
      stand(x, y)
      assert_equal line, PokeAccess::XenoMirrors.step_line, "from #{x},#{y} with the switch #{on}"
    end
    stand(42, 53)
    assert_nil PokeAccess::XenoMirrors.step_line, "past the zone there is no next press"
    mirrors_at(1187, true)
    stand(40, 55)
    back = t(:xv_mirror_step_back, :way => slid(:dir_down))
    assert_equal back, PokeAccess::XenoMirrors.step_line, "boxed in, the way out is a send-back"
    $game_switches[1500] = true
    stand(12, 32)
    way = t(:xv_blink_way_reversed, :way => slid(:dir_up))
    assert_equal t(:xv_mirror_step, :way => way), PokeAccess::XenoMirrors.step_line,
                 "zone D's column of reflections is one slide, said with the keys reversed"
    info = PokeAccess::Puzzles.info_line.to_s
    assert_includes info, t(:xv_mirror_rule_own)
    assert_includes info, t(:xv_mirror_step, :way => way)
    PokeAccess::Config.puzzle_assist = false
    refute_includes PokeAccess::Puzzles.info_line.to_s, t(:xv_mirror_rule_own), "the rule is the assist's alone"
  end

  test "with the assist, a route through a mirror zone takes its own presses out and on; without it, what is seen" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    past = place(50, 40, 52, [], "trainer", 0)
    stand(40, 64)
    out = PokeAccess::XenoMirrors.way_out(PokeAccess::XenoMirrors::ZONES[0]).map { |d, _got| d }
    plan = route(past)
    assert_equal out + [4, 4], plan.route.to_a, "zone A's way out press by press, then along the floor past it"
    legs = [walked(1, :dir_right), walked(2, :dir_up), slid(:dir_up), slid(:dir_left), slid(:dir_up), slid(:dir_right),
            slid(:dir_up), walked(2, :dir_left)]
    assert_equal t(:loc_route, :steps => legs.join(", ")), said_route(plan, 40, 64)
    assert plan.stats[:puzzle_way], "marked for the guides to plan it again at each tile"
    mirrors_at(1187, true)
    stand(39, 58)
    assert_equal [8, 6, 8, 4, 4], route(past).route.to_a, "from partway, with the switch as the crossing left it"
    stand(40, 55)
    boxed = route(past)
    assert_equal [[2], [0]], [boxed.route.to_a, boxed.route.warps], "boxed in, the route ends on the send-back"
    assert_equal t(:loc_route, :steps => t(:loc_leg_transfer, :leg => slid(:dir_down))), said_route(boxed, 40, 55)
    mirrors_at(1187, false)
    stand(40, 64)
    assert_equal [6, 8, 8, 8], route($game_map.events[8]).route.to_a, "to a figure, the zone's way to beside it"
    PokeAccess::Config.puzzle_assist = false
    plain = route(past)
    assert_equal PokeAccess::Routes::Planner.plan(40, 52, false).route.to_a, plain.route.to_a, "the routes' own walk"
    refute_equal out, plain.route[0, out.length], "which crosses the figures as the floor they look like"
    assert_nil plain.stats && plain.stats[:puzzle_way]
  end

  test "the step guide plans a mirror zone's way again at each tile, with the zone's switch as it stands" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    past = place(50, 40, 52, [], "trainer", 0)
    stand(40, 64)
    with_guide_state do |loc|
      steps_aim(loc, past)
      assert_equal [walked(1, :dir_right)], walk_to(loc, 40, 64)
      assert_equal [walked(2, :dir_up)], walk_to(loc, 41, 64)
      assert_equal [slid(:dir_up)], walk_to(loc, 41, 62)
      mirrors_at(1187, true)
      assert_equal [t(:loc_leg_transfer, :leg => slid(:dir_left))], walk_to(loc, 41, 58),
                   "on the track, but with the switch turned the figure ahead sends back: the way from there"
    end
  end

  test "the next press of a mirror zone keeps quiet while a guide follows the mirrors' way to the target" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    past = place(50, 40, 52, [], "trainer", 0)
    stand(40, 64)
    with_guide_state do |loc|
      steps_aim(loc, past)
      assert_equal [[], []], [pulse, pulse], "the step guide says each press itself"
      PokeAccess::Guide.stop
      assert_equal [step(walked(1, :dir_right))], pulse, "with the guides off, said as before"
      guide_aim(loc, past)
      stand(41, 64)
      assert_equal [[], [step(walked(2, :dir_up))]], [pulse, pulse], "the cane alone only sounds the way: the press is said"
    end
  end

  test "a way the mirrors find none for is left to the routes, unmarked, and the next press is still said" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    far = place(60, 11, 32, [], "trainer", 0)
    stand(40, 64)
    assert_nil PokeAccess::XenoMirrors.plan(far, false), "no walk leads from zone A to zone C"
    plan = route(far)
    assert_equal PokeAccess::Routes::Planner.plan(11, 32, false).kind, plan.kind, "the routes' own answer"
    assert_nil plan.stats && plan.stats[:puzzle_way], "not marked as the mirrors' way"
    with_guide_state do |loc|
      steps_aim(loc, far)
      assert_equal [[], [step(walked(1, :dir_right))]], [pulse, pulse], "no mirrors' way to follow: the press is said"
    end
  end

  test "with a target the zone holds, the hint key and the pulse say the press toward it, as the routes take it" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    corner = place(60, 38, 63, [], "trainer", 0)
    stand(40, 64)
    with_guide_state do |loc|
      assert_equal step(walked(1, :dir_right)), PokeAccess::XenoMirrors.step_line, "with no target, the way out"
      guide_aim(loc, corner)
      way = route(corner).route.to_a
      assert_equal [4, 8], way, "beside the target by the floor's left"
      assert_equal step(walked(1, :dir_left)), PokeAccess::XenoMirrors.step_line, "the hint key, toward the target"
      assert_equal [[], [step(walked(1, :dir_left))]], [pulse, pulse], "and the pulse, with the cane alone on"
    end
  end

  test "whether the step guide takes the mirrors' way is asked once for each tile, switches and target" do
    mirror_fields
    PokeAccess::Config.puzzle_assist = true
    past = place(50, 40, 52, [], "trainer", 0)
    stand(40, 64)
    with_guide_state do |loc|
      steps_aim(loc, past)
      asked = 0
      real = loc.method(:route_plan)
      loc.define_singleton_method(:route_plan) { |t| asked += 1; real.call(t) }
      begin
        4.times { pulse }
        assert_equal 1, asked, "standing still"
        mirrors_at(1187, true)
        2.times { pulse }
        assert_equal 2, asked, "the switch turned"
      ensure
        loc.define_singleton_method(:route_plan, real)
      end
    end
  end

  test "says the figures swapping as a figure is crossed, and with the assist the next press once the player stands" do
    mirror_fields
    stand(39, 58)
    pulse
    $game_switches[1187] = true
    assert_equal [t(:xv_mirror_swap)], pulse
    stand(40, 64)
    $game_switches[1187] = false
    assert_equal [], pulse, "the switch put back by a send-back, with the player at the start, is no swap"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[], [step(walked(1, :dir_right))]], [pulse, pulse], "said once the player has stood still two pulses"
    assert_equal [], pulse
    stand(41, 64)
    assert_equal [[], [step(walked(2, :dir_up))]], [pulse, pulse]
    stand(41, 63)
    assert_equal [[], []], [pulse, pulse], "quiet along a walk already said"
    stand(41, 62)
    assert_equal [[], [step(slid(:dir_up))]], [pulse, pulse]
  end

  test "lists the Regi tomb's spot with the Pokemon the game asks for" do
    on_map(686)
    assert_equal [], names
    PokeAccess::Config.puzzle_assist = true
    line = t(:xv_regi_spot_with, :move => PokeAccess::FieldMoves.name(:CUT), :pokemon => species(:BANDEON))
    assert_equal [line], names
  end

  test "names the forest nest's baits and trees, tells the bait carried, and with the assist each tree's bait" do
    on_map(503)
    place(1, 28, 41, [TestCmd.new(121, [640, 640, 0])], "miele")
    [[7, 41], [8, 42]].each { |id, x| place(id, x, 42, [TestCmd.new(111, [0, 640, 0])]) }
    seen = place(9, 15, 42, [door(18, 42, 27)], "", 1)
    assert_equal [t(:xv_bait_honey), t(:xv_bait_tree)].sort, names.sort
    assert PokeAccess::Puzzles.hidden_event?(seen)
    $game_switches[640] = true
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:xv_bait_carried, :bait => t(:xv_bait_honey))
    PokeAccess::Config.puzzle_assist = true
    assert_includes names, t(:xv_bait_tree_honey)
    assert_includes names, t(:xv_nest_watched)
    $game_switches[643] = true
    refute_includes names, t(:xv_bait_tree_honey)
  end

  test "tells apart the nests' Abra, pads and doors with the assist alone, and the boulder's way to pick" do
    on_map(495)
    place(4, 18, 31, [door(495, 47, 36)], "abra")
    place(11, 48, 30, [door(68, 57, 13)], "abra")
    refute_includes names, t(:xv_nest_abra_on, :pokemon => species(:ABRA))
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_nest_abra_on, :pokemon => species(:ABRA)), t(:xv_nest_abra_out, :pokemon => species(:ABRA))].sort,
                 names.sort
    on_map(510)
    [[2, 12], [3, 16], [4, 20]].each { |id, x| place(id, x, 12, [door(514, 13, 17)], "portaroccia", 1) }
    assert_equal [t(:xv_root_door_left), t(:xv_root_door_middle), t(:xv_root_door_right)].sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    assert_includes names, t(:xv_nest_door_on, :door => t(:xv_root_door_left))
    assert_includes names, t(:xv_nest_door_out, :door => t(:xv_root_door_middle), :pokemon => species(:TYRANITAR))
    on_map(497)
    place(2, 22, 9, [door(497, 48, 10)], "pedanenido", 1)
    place(7, 50, 20, [door(498, 15, 17)], "pedanenido", 1)
    assert_equal [t(:xv_nest_pad)] * 2, names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_nest_pad_on), t(:xv_nest_pad_out)].sort, names.sort
    on_map(499)
    place(12, 20, 9, [door(496, 9, 13)], "pedanenido", 1)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_nest_pad_back)], names
    on_map(507)
    place(2, 24, 23, [TestCmd.new(101, ["?"])], "Boulder", 0, "Boulder2")
    assert_equal [t(:xv_gravity_rock)], names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:xv_gravity_rock_pick, :dir => t(:dir_up))], names
  end

  test "names Sabolt's power box until the current is back, and says as Mew and the triangle move away" do
    on_map(249)
    place(2, 32, 16, [TestCmd.new(101, ["La corrente è staccata..."])])
    assert_equal [t(:xv_power_switch)], names
    $game_switches[497] = true
    assert_equal [], names
    on_map(428)
    tick
    $game_switches[469] = true
    assert_equal [[t(:xv_legend_gone, :pokemon => species(:MEW)), false]], tick
    on_map(434)
    place(3, 13, 24, [TestCmd.new(121, [476, 476, 0])], "Triangle_B")
    assert_equal [t(:xv_triangle)], names
    tick
    $game_switches[475] = true
    assert_equal [[t(:xv_triangle_moved), false]], tick
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A species' name as the data provider gives it.
  def species(id); PokeAccess::Data.species_name(id); end

  # An item's name as the data provider gives it.
  def item(id); PokeAccess::Data.item_name(id); end

  # Declares the shipped puzzles and puts the player on map with every flag off.
  def on_map(map)
    Harness.load_puzzles("xenoverse")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    [227, 469, 475, 497, 640, 643, 997, 1093, 1095, 1130, 1187, 1188, 1189, 1193, 1198, 1422, 1500].each do |s|
      $game_switches[s] = false
    end
    World.next_frame
  end

  # Mirror zones A and D of map 629 as the game lays them, by their top left tile: '#' shut, '.' floor, 'i' ice.
  MIRROR_FIELDS = { [37, 52] => %w[#.....# #.....# #####i# #iiiii# #iiii## ##ii#i# ##iii## #i#ii## #iiiii# #iiiii#
                                   #.....# #.....# ##...## #######],
                    [8, 16] => %w[#.....i #.....i ##iii#i #iiiii# #iiiii# #iiiii# #iiiii# #iiiii# #iiiii# #iiiii#
                                  #iiiii# #iiiii# #iiiii# #iiiii# #iiiii# #iiiii# #.....# ##...## #.....# #.....#
                                  ###.###] }
  # The figures of zones A and D with their switch off: id => [x, y, graphic].
  MIRROR_FIGURES = { 1 => [38, 59, "mirror"], 8 => [40, 58, "mirrorkay"], 9 => [41, 55, "mirrorkay"],
                     10 => [39, 57, "mirror"], 30 => [10, 28, "mirrorkay"], 31 => [12, 24, "mirror"],
                     32 => [11, 20, "mirrorkay"], 33 => [12, 20, "mirrorkay"], 34 => [10, 20, "mirrorkay"],
                     35 => [11, 28, "mirrorkay"], 36 => [10, 24, "mirrorkay"], 37 => [11, 24, "mirrorkay"],
                     38 => [12, 28, "mirrorkay"], 39 => [13, 26, "mirror"], 40 => [9, 22, "mirror"] }

  # Map 629 with mirror zones A and D laid out, their figures as with every switch off.
  def mirror_fields
    on_map(629)
    rows = Array.new(66) { "#" * 44 }
    ice = []
    MIRROR_FIELDS.each do |(x0, y0), field|
      field.each_with_index do |row, dy|
        row.chars.each_with_index do |c, dx|
          rows[y0 + dy][x0 + dx] = c == "#" ? "#" : "."
          ice.push([x0 + dx, y0 + dy]) if c == "i"
        end
      end
    end
    $game_map.load_grid(rows)
    ice.each { |x, y| $game_map.set_terrain(x, y, 12) }
    MIRROR_FIGURES.each { |id, (x, y, sprite)| place(id, x, y, [], sprite, 4) }
    PokeAccess::XenoMirrors.reset
  end

  # Puts the switch of a mirror zone at on, its figures showing what they show then: each swaps its reflection.
  def mirrors_at(switch, on)
    $game_switches[switch] = on
    zone = PokeAccess::XenoMirrors::ZONES.find { |z| z.switch == switch }
    zone.figures.each do |id|
      ev = $game_map.events[id]
      next unless ev
      off = MIRROR_FIGURES[id][2]
      ev.character_name = on ? (off == "mirror" ? "mirrorkay" : "mirror") : off
    end
    World.next_frame
  end

  # A figure's name with what it does, as the assist says it.
  def does(look, effect)
    t(:xv_mirror_effect, :figure => t(look), :effect => t(effect))
  end

  # The assist's next press out of a mirror zone.
  def step(way); t(:xv_mirror_step, :way => way); end

  # A walk of n tiles toward dir, as a route says it.
  def walked(n, dir); t(:loc_leg, :n => n, :dir => t(dir)); end

  # A slide toward dir, as a route says it.
  def slid(dir); t(:loc_slide_leg, :dir => t(dir)); end

  # The route the locator plans to a target.
  def route(target); PokeAccess::Locator.route_plan(target); end

  # The route key's line for plan from (x, y).
  def said_route(plan, x, y)
    PokeAccess::Routes::Text.line(plan, [x, y], PokeAccess::Routes::Moves.one_way(x, y, 0, plan.route))
  end

  # One pulse of the mirrors: what they said.
  def pulse
    SpeakCapture.clear
    PokeAccess::XenoMirrors.tick
    SpeakCapture.log.map(&:first)
  end

  # A Transfer Player command to (x, y) of map.
  def door(map, x, y)
    TestCmd.new(201, [0, map, x, y, 0, 0])
  end

  # An event at (x, y) whose live page runs list, drawn with sprite and fired by trigger, placed on the map.
  def place(id, x, y, list, sprite = "", trigger = 0, name = nil)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    opts = { :id => id, :x => x, :y => y, :pages => [page], :active_page => page }
    opts[:name] = name if name
    ev = TestGameEvent.new(opts)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # Legs as [tiles, direction key], said as a route says them.
  def spoken(legs)
    legs.map { |n, d| t(:loc_leg, :n => n, :dir => t(d)) }.join(", ")
  end

  # A trap's page: a touch with no sprite that sends the player back to the Sound Room's start.
  def trap_page
    TestPage.new(:trigger => 1, :sprite => "", :list => [door(602, 9, 7)])
  end

  # Puts the player on (x, y).
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # One frame f of the blinking with the switch as on: the lines said.
  def frame(blink, f, on, switch = 1198)
    $game_switches[switch] = on
    SpeakCapture.clear
    blink.tick(f)
    SpeakCapture.log.map(&:first)
  end

  # The lines said each frame of frames, from a fresh start, with the switch on as on tells and a reader whose speaking?
  # answers talking.
  def run_blink(blink, frames, on, talking, switch = 1198)
    blink.reset
    with_reader(talking) { frames.map { |f| frame(blink, f, on.call(f), switch) } }
  end

  # Runs the block with the player walking at speed.
  def with_pace(speed)
    $game_player.define_singleton_method(:move_speed) { speed }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :move_speed)
  end

  # Runs the block with a reader whose speaking? answers talking.
  def with_reader(talking)
    real = PokeAccess.method(:speaking?)
    PokeAccess.define_singleton_method(:speaking?) { talking }
    yield
  ensure
    PokeAccess.define_singleton_method(:speaking?, real)
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map(&:name)
  end

  # One frame of the puzzle: what it said.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end
end
