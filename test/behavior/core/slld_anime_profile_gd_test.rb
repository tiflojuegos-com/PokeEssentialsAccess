# The Pokemon SL & LD - Anime Chronicles profile loaded whole, over doubles with the shape of its scripts and maps: the
# episodes' title cards, Dullfern Forest's spider webs, the gyms' battle tiles, the thorns, Chirp Perfect's bar, the
# puzzles it declares, Budcheep's flight over the roofs, and the plugin readers it brings along (Multiple Protagonists' switch, FL's Game Over, Roei's badge
# case). In a process of its own, since its overrides would reach every other test here.
class SlldAnimeProfileGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "world_builder")

    # Multiple Protagonists 5.0.0's switch, on a player with its protagonist's key.
    $hero = Struct.new(:name, :character_ID).new("Ash", 1)
    def pbSwitchCharacter(id, _name = nil, _outfit = 0)
      return if id == $hero.character_ID
      $hero.character_ID = id
      $hero.name = "Keira"
    end

    # FL's Game Over: its scene and the function that gives it away.
    class Scene_Gameover; def main; :over; end; end
    def go_to_title; nil; end

    # Roei's Badgecase UI, down to what its reader hooks and reads: the grid's cursor, the page and its paint.
    class BadgeCase_Scene
      def initialize(badges)
        @badges = badges
        @badgeindex = 0
        @badgepage = false
        @badges_showed = badges.length
      end

      def pbUpdate; nil; end
      def pbEndScene; nil; end
      def move(i); @badgeindex = i; end

      def turn
        @badgepage = !@badgepage
        drawBadgePage if @badgepage
      end

      def drawBadgePage
        b = @badges[@badgeindex]
        pbDrawTextPositions(nil, [["BADGE INFO", 26, 22, :left], ["Obtained At", 238, 86, :left],
                                  ["Main Type", 238, 118, :left], ["Location", 238, 150, :left], ["Leader", 238, 182, :left],
                                  ["ACE", 78, 304, :left], ["POKEMON", 78, 324, :left], [b.name, 26, 68, :left],
                                  [b.location, 425, 150, :center], [b.leader, 425, 182, :center], ["Thornox", 16, 358, :left],
                                  ["12 November 2026", 425, 86, :center]])
      end
    end
    Badge = Struct.new(:id, :name, :location, :leader, :type)
    Holder = Struct.new(:held) do
      def has?(id); held.include?(id); end
    end
  RUBY

  PLAY = <<-'RUBY'
    probe(:profile_name) { PokeAccess::Game.profile_name }
    probe(:plain) { PokeAccess::World::Probe.plain? }
    probe(:maps) { PokeAccess::World::Mechanics.instance_variable_get(:@defs).keys.sort }

    probe(:episodes) do
      cues = PokeAccess::PictureCues
      [said { cues.on_picture("EpisodeTitel6", []) }, said { cues.on_picture("start", []) },
       said { cues.on_picture("Heart_full", []) }, said { cues.on_picture("EpisodeTitel99", []) }]
    end

    probe(:webs) do
      web_page = TestPage.new(:list => [TestCmd.new(355, ["$game_variables[31] = $player.character_ID"]),
                                        TestCmd.new(111, [12, "$player.character_ID = 1"]), TestCmd.new(0, [])])
      web = TestGameEvent.new(:id => 3, :name => "CutTree", :tile_id => 1177, :pages => [web_page, TestPage.new])
      cut = TestGameEvent.new(:id => 4, :name => "CutTree", :pages => [web_page, TestPage.new], :active_page => TestPage.new)
      tree = TestGameEvent.new(:id => 84, :name => "CutTree",
                               :pages => [TestPage.new(:sprite => "Object", :list => [TestCmd.new(355, ["pbCut"]),
                                                                                      TestCmd.new(0, [])])])
      field = PokeAccess::SlldField
      [PokeAccess::Locator.fieldmove_label(web), PokeAccess::Locator.fieldmove_label(tree),
       field.standing_web?(web), field.standing_web?(cut)]
    end

    probe(:battle_tile) do
      waiting = TestGameEvent.new(:id => 18, :pages => [TestPage.new(:trigger => 1, :list => [TestCmd.new(111, [6, -1, 4]),
                                                                                             TestCmd.new(0, [])])])
      $game_map.events[18] = waiting
      before = PokeAccess::SlldField.battle_tile?(18)
      $game_map.events[18] = TestGameEvent.new(:id => 18, :pages => [TestPage.new(:trigger => 3)])
      after = PokeAccess::SlldField.battle_tile?(18)
      $game_map.events.delete(18)
      [before, after]
    end

    probe(:thorns) do
      ev = TestGameEvent.new(:id => 6, :name => "Thorns 1-3")
      ev.direction = 2
      up = PokeAccess::SlldThorns.label(ev)
      ev.direction = 8
      [up, PokeAccess::SlldThorns.label(ev)]
    end

    probe(:chirp) do
      chirp = PokeAccess::SlldChirp
      $game_variables[429] = 12
      hits = chirp.hits
      $game_variables[429] = 0
      [chirp.ahead(450, 9, true, 4), chirp.ahead(60, 3, false, 4), hits]
    end

    probe(:switched) do
      was = $player
      $player = $hero
      same = said { pbSwitchCharacter(1) }
      other = said { pbSwitchCharacter(2) }
      $player = was
      [same, other]
    end

    probe(:gameover) { said { Scene_Gameover.new.main } }

    probe(:badge_case) do
      was = $PokemonGlobal
      $PokemonGlobal = Struct.new(:badges).new(Holder.new([:THORN]))
      scene = BadgeCase_Scene.new([Badge.new(:THORN, "Thorn Badge", "Serpentine City", "Ellen", :GRASS),
                                   Badge.new(:DARK, "Darkness Badge", "Crestlight City", "Damon", :DARK)])
      first = said { scene.pbUpdate }
      scene.move(1)
      second = said { scene.pbUpdate }
      scene.move(0)
      scene.turn
      page = said { scene.pbUpdate }
      again = said { scene.pbUpdate }
      $PokemonGlobal = was
      [first, second, page, again]
    end

    def slld_on_map(map)
      World.clear_events
      $game_self_switches = {}
      $game_map.map_id = map
      PokeAccess::Caches.reset_all
      PokeAccess::World::Mechanics.forget
    end

    def slld_listed
      PokeAccess::Puzzles.category_targets.map do |tg|
        name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
        [tg.x, tg.y, name]
      end.sort_by { |x, y, _n| [x, y] }
    end

    def slld_silent(id, x, y, name = "EV#{id}")
      page = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
      ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
      $game_map.events[id] = ev
      World.next_frame
      ev
    end

    # Makes I18n.t answer each key and its values as "{key name=value ...}" for the block, so what it says is compared
    # by its keys and values rather than by the text of a language.
    def slld_keyed
      i18n = PokeAccess::I18n.singleton_class
      i18n.send(:alias_method, :slld_kept_t, :t)
      i18n.send(:define_method, :t) do |key, vars = nil|
        parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
        "{#{parts.join(' ')}}"
      end
      yield
    ensure
      i18n.send(:alias_method, :t, :slld_kept_t)
      i18n.send(:remove_method, :slld_kept_t)
    end

    probe(:hamstar) do
      slld_on_map(8)
      slld_silent(44, 43, 13)
      slld_silent(41, 26, 20)
      $game_switches[185] = true
      $game_variables[52] = 2
      early = slld_listed
      $game_variables[52] = 6
      PokeAccess::Caches.reset_all
      late = slld_listed
      $game_variables[52] = 7
      PokeAccess::Caches.reset_all
      done = slld_listed
      $game_switches[185] = false
      $game_variables[52] = 0
      [early, late, done]
    end

    probe(:paracaw) do
      slld_on_map(15)
      $game_switches[445] = true
      perched = slld_silent(88, 23, 26, "Paracaw 1")
      PokeAccess::Config.puzzle_assist = false
      plain = PokeAccess::SlldParacaw.label(perched)
      PokeAccess::Config.puzzle_assist = true
      named = PokeAccess::SlldParacaw.label(perched)
      $game_self_switches[[15, 88, "A"]] = true
      gone = PokeAccess::SlldParacaw.perched?(88)
      PokeAccess::Config.puzzle_assist = false
      $game_switches[445] = false
      [plain, named, PokeAccess::SlldParacaw.pushes(94, 44, 12), PokeAccess::SlldParacaw.pushes(89, 18, 20), gone]
    end

    probe(:paracaw_side) do
      slld_on_map(15)
      $game_map.width = 63
      $game_map.height = 42
      $game_switches[445] = true
      bird = slld_silent(94, 44, 12, "Paracaw 7")
      bird.character_name = "PARACAW"
      bird.blocking = true
      was = [$game_player.x, $game_player.y]
      ends = [false, true].map do |assist|
        PokeAccess::Config.puzzle_assist = assist
        $game_player.x, $game_player.y = 47, 12
        PokeAccess::Caches.reset_all
        made = PokeAccess::Routes::Planner.plan(44, 12)
        x, y = 47, 12
        (made.route || []).each { |d| x += PokeAccess::DIR_DELTA[d][0]; y += PokeAccess::DIR_DELTA[d][1] }
        [made.kind, x, y]
      end
      PokeAccess::Config.puzzle_assist = false
      $game_switches[445] = false
      $game_player.x, $game_player.y = was
      $game_map.width = $game_map.height = 20
      ends
    end

    probe(:flight) do
      slld_on_map(15)
      $game_map.width = 63
      $game_map.height = 42
      def $game_map.passable?(x, y, d)
        dd = PokeAccess::DIR_DELTA[d]
        !(x + dd[0]).between?(22, 26) || !(y + dd[1]).between?(25, 28)
      end
      slld_silent(88, 23, 26, "Paracaw 1")
      was = [$game_player.x, $game_player.y]
      $game_player.x, $game_player.y = 21, 24
      PokeAccess::Caches.reset_all
      plan = lambda do |x, y|
        made = PokeAccess::Routes::Planner.plan(x, y)
        [made.kind, made.route && made.route.length]
      end
      steps = lambda do
        [[23, 24, 2], [16, 20, 4], [15, 20, 4], [20, 5, 8]].map { |x, y, d| PokeAccess::World::Probe.step?(x, y, d) }
      end
      walking = [plan.call(23, 26), steps.call]
      $game_switches[445] = true
      flying = [plan.call(23, 26), plan.call(12, 16)[0], steps.call, $game_player.passable?(23, 24, 2)]
      $game_switches[445] = false
      landed = plan.call(23, 26)[0]
      $game_player.x, $game_player.y = was
      $game_map.width = $game_map.height = 20
      class << $game_map; remove_method :passable?; end
      PokeAccess::Caches.reset_all
      [walking, flying, landed]
    end

    probe(:fire) do
      slld_on_map(41)
      [452, 453, 454].each { |s| $game_switches[s] = true }
      plain = slld_listed
      PokeAccess::Config.puzzle_assist = true
      PokeAccess::Caches.reset_all
      all = slld_listed
      [11, 12, 13, 14, 15, 16].each { |id| $game_self_switches[[41, id, "A"]] = true }
      PokeAccess::Caches.reset_all
      last = slld_listed
      PokeAccess::Config.puzzle_assist = false
      [452, 453, 454].each { |s| $game_switches[s] = false }
      [plain, all, last, PokeAccess::SlldFire::SHOTS]
    end

    probe(:pupool) do
      slld_on_map(15)
      PokeAccess::Config.puzzle_assist = true
      [436, 440].each { |s| $game_switches[s] = true }
      $game_variables[365] = 4
      PokeAccess::Puzzles.tick
      fifth = said { $game_variables[365] = 5; PokeAccess::Puzzles.tick }
      tired = PokeAccess::Puzzles.info_line
      sixth = said { $game_switches[441] = true; PokeAccess::Puzzles.tick }
      done = PokeAccess::Puzzles.info_line
      PokeAccess::Config.puzzle_assist = false
      [436, 440, 441].each { |s| $game_switches[s] = false }
      $game_variables[365] = 0
      [fifth, tired, sixth, done]
    end

    probe(:pupool_press) do
      slld_on_map(15)
      [436, 440].each { |s| $game_switches[s] = true }
      $game_variables[365] = 5
      tired = TestPage.new(:sprite => "PUPOOL", :list => [TestCmd.new(355, ["Followers.add(@event_id, \"Pupool\", 6)"]),
                                                          TestCmd.new(121, [441, 441, 0]), TestCmd.new(0, [])])
      pupool = TestGameEvent.new(:id => 65, :x => 38, :y => 21, :name => "Pupool Run Away", :pages => [tired])
      lever = TestGameEvent.new(:id => 70, :x => 30, :y => 20, :name => "EV070",
                                :pages => [TestPage.new(:sprite => "Object", :list => [TestCmd.new(121, [900, 900, 0]),
                                                                                       TestCmd.new(0, [])])])
      readers = [[71, 441], [72, 900]].map do |id, sw|
        page = TestPage.new(:condition => { :switch1_valid => true, :switch1_id => sw }, :list => [TestCmd.new(0, [])])
        TestGameEvent.new(:id => id, :x => id, :y => 5, :pages => [page])
      end
      [pupool, lever].concat(readers).each { |ev| $game_map.events[ev.id] = ev }
      World.next_frame
      press = lambda do |ev|
        said do
          PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
          8.times { World.next_frame; PokeAccess::Puzzles.tick }
        end
      end
      on_here = PokeAccess::Puzzles::Auto.on_here?
      sixth, worked = slld_keyed { [press.call(pupool), press.call(lever)] }
      [436, 440, 441, 900].each { |s| $game_switches[s] = false }
      $game_variables[365] = 0
      [on_here, sixth, worked]
    end

    probe(:chirp_count) do
      slld_on_map(25)
      webs = PokeAccess::SlldChirp::WEBS
      webs.each { |v| $game_variables[v] = 1 }
      $game_switches[266] = true
      $game_variables[429] = 9
      plain, helped = slld_keyed do
        off = PokeAccess::Puzzles.info_line
        PokeAccess::Config.puzzle_assist = true
        [off, PokeAccess::Puzzles.info_line]
      end
      PokeAccess::Config.puzzle_assist = false
      $game_switches[266] = false
      ([429] + webs).each { |v| $game_variables[v] = 0 }
      [plain, helped]
    end

    probe(:thorn_ahead) do
      slld_on_map(362)
      was = [$game_player.x, $game_player.y, $game_player.direction]
      slld_silent(6, 23, 34, "Thorns 1-3")
      $game_player.x = 23
      $game_player.y = 35
      $game_player.direction = 8
      faced = PokeAccess::SlldThorns.ahead
      $game_map.events.delete(6)
      kept = PokeAccess::SlldThorns.ahead
      [16, 362].each do |map|
        $game_map.map_id = map
        World.next_frame
        PokeAccess::World::Epoch.settle
      end
      gone = PokeAccess::SlldThorns.ahead
      $game_player.x, $game_player.y, $game_player.direction = was
      [faced && faced.id, kept && kept.id, gone]
    end

    probe(:contest) do
      slld_on_map(370)
      red = slld_silent(84, 16, 20, "Box Red 1")
      yellow = slld_silent(96, 22, 21, "Box Yellow 1")
      red.direction = 2
      yellow.direction = 8
      $game_self_switches[[370, 96, "B"]] = true
      names = [PokeAccess::SlldContest.label(red), PokeAccess::SlldContest.label(yellow)]
      $game_self_switches = {}
      names
    end
  RUBY

  profile "slld_anime", WORLD, PLAY, "gamedata"

  # Map 41's fires as its data has them: where each burns, and the one whose page runs on the action key.
  FIRE_AT = { 7 => [28, 13], 10 => [28, 11], 11 => [26, 12], 12 => [23, 10], 13 => [24, 13], 14 => [21, 13],
              15 => [27, 7], 16 => [21, 7] }.freeze
  PRESSED_FIRE = 14
  STEP = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }.freeze

  test "loads whole and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    assert_equal "slld_anime", played(:profile_name)
    assert played(:plain)
  end

  test "declares the puzzles of the maps where the story stops on one" do
    assert_equal [8, 9, 10, 12, 15, 16, 25, 29, 37, 39, 41, 232, 361, 362, 366, 368, 370], played(:maps)
  end

  test "a title card says its episode as it paints it, cutting in, and its prompt queued; other pictures say nothing" do
    title, prompt, heart, unknown = played(:episodes)
    assert_equal [["Episode 6: Serpentine Gym - A Storm of Thorns!", true]], title
    assert_equal [["Press Enter", false]], prompt
    assert_equal [[], []], [heart, unknown]
  end

  test "a Dullfern web asks for no field move while a real Cut tree still does, and is a web only while it stands" do
    assert_equal [nil, :loc_cut_tree, true, false], played(:webs)
  end

  test "a gym's battle tile counts only while its page waits for a player facing west" do
    assert_equal [true, false], played(:battle_tile)
  end

  test "a thorn is up while it faces down" do
    assert_equal [:slld_thorns_up, :slld_thorns_down], played(:thorns)
  end

  test "Chirp Perfect's pointer is foreseen bouncing off the bar's ends, and the hits come from its speed" do
    assert_equal [450, 60, 3], played(:chirp)
  end

  test "a switch of protagonist is said, queued, and a call on the one in play is not" do
    same, other = played(:switched)
    assert_equal [], same
    assert_equal [["Ahora juegas con Keira.", false]], other
  end

  test "FL's game over says itself and the key that goes on" do
    assert_equal [["#{t(:fl_gameover)}. #{t(:title_press, :key => t(:key_enter))}", false]], played(:gameover)
  end

  test "the badge case says the badge under the cursor, held or not, named only where its page names it, and its page as painted" do
    first, second, page, again = played(:badge_case)
    assert_equal [["Thorn Badge, #{t(:case_held)}, #{t(:loc_count, :n => 1, :total => 2)}", false]], first
    assert_equal [["#{t(:case_missing)}, #{t(:loc_count, :n => 2, :total => 2)}", true]], second
    assert_equal [["BADGE INFO. Thorn Badge. Obtained At 12 November 2026. Main Type TypeGRASS. Location Serpentine City. " \
                   "Leader Ellen. ACE POKEMON Thornox", true]], page
    assert_equal [], again
  end

  test "Mossy Town names the shore while the chase runs and the wall from the sixth Hamstar, and neither once all are found" do
    early, late, done = played(:hamstar)
    assert_equal [[43, 13, t(:slld_hamstar_shore)]], early
    assert_equal [[26, 20, t(:slld_hamstar_wall)], [43, 13, t(:slld_hamstar_shore)]], late
    assert_equal [], done
  end

  test "with the assist alone, a Paracaw is named by its fewest pushes to its roof's edge, and leaves once it flew off" do
    plain, named, one, two, gone = played(:paracaw)
    assert_nil plain
    assert_equal [:fx_slld_paracaw_push, { :n => 2, :dirs => t(:fx_slld_paracaw_or, :a => t(:dir_up), :b => t(:dir_down)) }],
                 named
    assert_equal [1, [2]], one
    assert_equal [2, [6, 8, 2]], two
    assert_equal false, gone
  end

  test "with the assist alone, the route to a Paracaw ends on the side a press pushes it toward its roof's edge from" do
    assert_equal [[:walk, 45, 12], [:walk, 44, 11]], played(:paracaw_side), "Paracaw 7 one push down from its edge"
  end

  test "flying as Budcheep, the routes cross the roofs and stay inside the box event 87 keeps the player in" do
    walking, flying, landed = played(:flight)
    assert_equal [[:none, nil], [false, true, true, true]], walking
    roof, outside, steps, game_own = flying
    assert_equal [[:walk, 3], :none], [roof, outside]
    assert_equal [true, true, false, false], steps
    assert_equal false, game_own
    assert_equal :none, landed
  end

  test "with the assist alone, the fire's spots are listed while their fires burn, the trash can's once the rest are out" do
    plain, all, last, = played(:fire)
    down = "Sitio para lanzar Rayo Burbuja mirando abajo"
    right = "Sitio para lanzar Rayo Burbuja mirando a la derecha"
    assert_equal [], plain
    assert_equal [[21, 8, "Sitio para lanzar Rayo Burbuja mirando arriba"], [21, 12, down], [23, 9, down], [24, 12, down],
                  [25, 12, right], [26, 7, right]], all
    assert_equal [[28, 12, down]], last
  end

  test "each fire shot faces one of its fires, so the bubble stays on the player's tile, and names just what burns beside it" do
    shots = played(:fire)[3]
    shots.each do |at, dir, ids|
      front = [at[0] + STEP[dir][0], at[1] + STEP[dir][1]]
      beside = FIRE_AT.select { |id, (x, y)| (x - at[0]).abs + (y - at[1]).abs == 1 && (id != PRESSED_FIRE || [x, y] == front) }
      assert_includes ids.map { |id| FIRE_AT[id] }, front, "the shot at #{at.inspect} faces one of its fires"
      assert_equal beside.keys.sort, ids.sort, "the shot at #{at.inspect} names what goes out from there"
    end
    assert_equal FIRE_AT.keys.sort, shots.map { |s| s[2] }.flatten.sort
  end

  test "fire 14, whose page runs on the action key alone, has its shot beside it and facing it" do
    at, dir, = played(:fire)[3].find { |s| s[2].include?(PRESSED_FIRE) }
    assert_equal FIRE_AT[PRESSED_FIRE], [at[0] + STEP[dir][0], at[1] + STEP[dir][1]]
  end

  test "with the assist, the Pupool's count stands at five of six once it tires, and the sixth press ends it" do
    fifth, tired, sixth, done = played(:pupool)
    assert_equal [["Pulsaciones frente al Pupool: 5 de 6", false]], fifth
    assert_equal "Pulsaciones frente al Pupool: 5 de 6. Alcanza al Pupool que corre por la ciudad y pulsa Enter frente a él " \
                 "seis veces: tras cinco absorciones se cansa y deja de correr, y a la sexta se deja llevar. Después, habla con Keira.",
                 tired
    assert_equal [["Pulsaciones frente al Pupool: 6 de 6", false]], sixth
    assert_nil done
  end

  test "Serpentine City keeps the core's own lines, but the tired Pupool's sixth press is no mechanism worked" do
    on_here, sixth, worked = played(:pupool_press)
    assert on_here, "both of the map's mechanics keep auto"
    assert_equal [], sixth
    assert_equal [["{chg_used}", false]], worked
  end

  test "Chirp Perfect's hits are counted with the assist alone" do
    plain, helped = played(:chirp_count)
    assert_equal "", plain.to_s
    assert_equal "{puzzle_progress label={slld_chirp_hits} n=2 of=7}", helped
  end

  test "the thorns ahead are read once a map, and read again on coming back from another map" do
    assert_equal [6, 6, nil], played(:thorn_ahead)
  end

  test "a contest box is named by its colour, and once on its field as in place" do
    red, yellow = played(:contest)
    assert_equal [:slld_box, { :colour => t(:slld_red) }], red
    assert_equal [:slld_box_placed, { :colour => t(:slld_yellow) }], yellow
  end
end
