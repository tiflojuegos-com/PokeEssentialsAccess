# Infinite Fusion (Kanto)'s minigames: the Art Gallery's frames (games/infinitefusion_common/art_gallery.rb), the
# S.S. Anne's waiter quest (ss_anne_waiter.rb), Route 19's surf race (surf_race.rb), Mt. Moon Summit's cloud path
# (cloud_path.rb) and Moonlit Forest's Magikarp ride (magikarp_ride.rb), each on the data shapes its scripts and map
# events give.

# The game's sprite-to-species lookup, as the Credits code defines it.
def getPokemonSpeciesFromPifSprite(sprite)
  part = Struct.new(:name)
  Struct.new(:head_pokemon, :body_pokemon).new(part.new("Bulbasaur#{sprite.head_id}"), part.new("Charmander"))
end

%w[infinitefusion_common/art_gallery infinitefusion/ss_anne_waiter infinitefusion/surf_race
   infinitefusion/cloud_path infinitefusion/magikarp_ride].each do |f|
  path = File.join(Harness::ROOT, "games", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

# A player on a set of free tiles, facing a direction; a step is passable onto a free tile.
class IfMiniPlayer
  attr_accessor :x, :y, :direction, :free
  def initialize(x, y, free); @x = x; @y = y; @direction = 2; @free = free; end
  def passable?(x, y, d)
    nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
    ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
    @free.include?([nx, ny])
  end
end

class InfinitefusionMiniGdTest < PokeAccessTest
  T = PokeAccess::I18n
  PifSprite = Struct.new(:head_id, :body_id, :type)
  Route = Struct.new(:list)
  Move = Struct.new(:code, :parameters)
  RpgEvent = Struct.new(:x, :y, :pages)

  def setup
    super
    assist = (PokeAccess::Config.puzzle_assist rescue false)
    @saved = [$game_player, $game_map.events.dup, $game_map.map_id, $game_self_switches, assist]
    $game_self_switches = {}
    [PokeAccess::IFSurfRace, PokeAccess::IFCloudPath, PokeAccess::IFMagikarpRide].each do |m|
      m.instance_variable_set(:@state, nil)
    end
    PokeAccess::IFMagikarpRide.instance_variable_set(:@told, false)
    $game_map.events.clear
  end

  def teardown
    $game_player, events, $game_map.map_id, $game_self_switches, assist = @saved
    $game_map.events.clear
    $game_map.events.merge!(events)
    PokeAccess::Config.puzzle_assist = assist
    [619, 806, 807, 1017, 1018, 1091].each { |s| $game_switches[s] = false }
    [26, 260, 313].each { |v| $game_variables[v] = 0 }
    super
  end

  def event(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, []))
    pages = opts.fetch(:pages, [page])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => opts.fetch(:tile, 0), :pages => pages,
                           :active_page => opts.fetch(:active, pages[-1]))
    ev.through = opts.fetch(:through, false)
    $game_map.events[id] = ev
    ev
  end

  test "a gallery frame names its fusion's head and body after its message, and the locator names the frame" do
    $game_variables[260] = [PifSprite.new(1, 1, :BASE), PifSprite.new(7, 4, :CUSTOM)]
    $game_map.map_id = 788
    PokeAccess::IFGallery.frame_shown(1)
    SpeakCapture.clear
    PokeAccess.say_dialogue("\"Squirtmander\"\nBy someone")
    assert_equal T.t(:if_gal_parts, :head => "Bulbasaur7", :body => "Charmander"), SpeakCapture.last
    PokeAccess::IFGallery.frame_shown(0)
    assert_nil PokeAccess.take_tail, "a sprite of one Pokemon has nothing to add"
    frame = event(301, 21, 6, :list => [TestCmd.new(355, ["frame=3"]),
                                        TestCmd.new(655, ["displayGalleryFrame(frame)"])])
    assert_equal T.t(:if_gal_frame, :n => 4), PokeAccess::IFGallery.frame_name(frame)
    assert_nil PokeAccess::IFGallery.frame_name(event(302, 2, 2, :list => [TestCmd.new(101, ["Hi"])]))
  end

  test "a customer says whether it waits, what it ordered or that it was served, and a kitchen dish its name" do
    $game_switches[1091] = true
    $game_variables[313] = ["Confit", "Savoury Cinnabar", "Bellossom Garden Salad"]
    $game_map.map_id = 17
    order = [TestCmd.new(122, [314, 314, 0, 0, 1]), TestCmd.new(122, [315, 315, 1, 0, 1])]
    guest = event(3, 18, 6, :pages => [TestPage.new(:list => []), TestPage.new(:list => order)])
    assert_equal T.t(:if_ssa_waiting), PokeAccess::IFWaiter.mark(guest)
    $game_self_switches[[17, 3, "D"]] = true
    assert_equal T.t(:if_ssa_wants, :dish => "Savoury Cinnabar"), PokeAccess::IFWaiter.mark(guest)
    $game_self_switches[[17, 3, "C"]] = true
    assert_equal T.t(:if_ssa_served), PokeAccess::IFWaiter.mark(guest)
    assert_nil PokeAccess::IFWaiter.mark(event(9, 2, 2, :sprite => "npc")), "someone who takes no order"
    $game_map.map_id = 29
    dish = event(15, 5, 13, :sprite => "food", :list => [TestCmd.new(122, [314, 314, 0, 0, 2])])
    assert_equal "Bellossom Garden Salad", PokeAccess::IFWaiter.mark(dish)
    $game_switches[1091] = false
    assert_nil PokeAccess::IFWaiter.mark(dish), "nothing out of the quest"
  end

  test "the surf race says the next turns first, each lap, who leads and a crossing the wrong way" do
    $game_map.map_id = 56
    rival = event(19, 11, 18, :sprite => "cooltrainer_surf")
    rival.instance_variable_set(:@event, RpgEvent.new(11, 18, []))
    rival.instance_variable_set(:@move_type, 3)
    rival.instance_variable_set(:@move_route, Route.new([1, 1, 1, 1, 29, 3, 3, 4, 4, 4].map { |c| Move.new(c, []) }))
    rival.instance_variable_set(:@move_route_index, 0)
    $game_player = IfMiniPlayer.new(11, 18, [])
    $game_switches[619] = true
    PokeAccess::IFSurfRace.poll
    SpeakCapture.clear
    $game_variables[26] = 1
    $game_player.y = 20
    PokeAccess::IFSurfRace.poll
    turns = T.t(:if_sr_then, :first => T.t(:if_sr_turn, :dir => T.t(:dir_right), :n => 2),
                             :second => T.t(:if_sr_turn, :dir => T.t(:dir_up), :n => 2))
    assert_equal [turns, T.t(:if_sr_lap, :n => 1, :total => 2), T.t(:if_sr_ahead)], SpeakCapture.lines,
                 "the two close turns as one line, before the lap and the lead"
    assert_equal 6, PokeAccess::IFSurfRace.instance_variable_get(:@state)[:turned], "the second turn of the pair"
    SpeakCapture.clear
    $game_player.y = 22
    PokeAccess::IFSurfRace.poll
    assert_empty SpeakCapture.lines, "a turn said within a pair is not said again"
    rival.instance_variable_set(:@move_route_index, 9)
    PokeAccess::IFSurfRace.poll
    assert_equal T.t(:if_sr_behind), SpeakCapture.last
    $game_variables[26] = 0
    PokeAccess::IFSurfRace.poll
    assert_equal T.t(:if_sr_back), SpeakCapture.last
    $game_switches[619] = false
    PokeAccess::IFSurfRace.poll
    assert_nil PokeAccess::IFSurfRace.instance_variable_get(:@state)
  end

  # The way up in small: two clouds above the start, a spring to their left, then a corridor to the harpist's ledge.
  def cloud_world
    $game_map.map_id = 827
    $game_switches[1018] = true
    free = [[38, 30], [38, 29], [38, 28]] + (27..36).map { |x| [x, 28] } + (17..27).map { |y| [27, y] }
    $game_player = IfMiniPlayer.new(38, 30, free)
    event(13, 38, 29, :tile => 8623, :through => true)
    event(17, 38, 28, :tile => 8615, :through => true)
    event(18, 37, 28, :tile => 391, :trigger => 2, :list => [TestCmd.new(117, [90])])
  end

  test "each step of the cloud path says what lies on each side, and nothing during a fall" do
    cloud_world
    PokeAccess::IFCloudPath.poll
    assert_equal PokeAccess.sentences([T.t(:if_cloud_rule)]), SpeakCapture.last
    $game_player.y = 29
    PokeAccess::IFCloudPath.poll
    side = lambda { |dir, what| T.t(:if_cloud_side, :dir => T.t(dir), :what => T.t(what)) }
    assert_equal [side.call(:dir_up, :if_cloud_cloud), side.call(:dir_down, :if_cloud_floor)].join(", "),
                 SpeakCapture.last
    $game_player.y = 28
    PokeAccess::IFCloudPath.poll
    assert_equal [side.call(:dir_down, :if_cloud_cloud), side.call(:dir_left, :if_cloud_spring)].join(", "),
                 SpeakCapture.last
    SpeakCapture.clear
    $game_switches[1017] = true
    $game_player.y = 29
    PokeAccess::IFCloudPath.poll
    $game_player.y = 30
    PokeAccess::IFCloudPath.poll
    assert_empty SpeakCapture.lines, "nothing while the player falls"
    $game_switches[1017] = false
    $game_player.x = 27
    $game_player.y = 17
    PokeAccess::IFCloudPath.poll
    assert_equal T.t(:if_cloud_top), SpeakCapture.last, "the ledge without the assist too"
  end

  test "with the assist the cloud path gives the whole way at the start and the next move on each step" do
    cloud_world
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::IFCloudPath.poll
    jump = T.t(:if_cloud_jump, :dir => T.t(:dir_left))
    walk = lambda { |dir, n| T.t(:if_cloud_walk, :dir => T.t(dir), :n => n) }
    steps = [walk.call(:dir_up, 2), jump, walk.call(:dir_left, 9), walk.call(:dir_up, 11)].join(", ")
    assert_equal PokeAccess.sentences([T.t(:if_cloud_rule), T.t(:if_cloud_route, :steps => steps)]), SpeakCapture.last
    $game_player.y = 28
    PokeAccess::IFCloudPath.poll
    assert_equal jump, SpeakCapture.last
    $game_player.x = 27
    $game_player.y = 18
    PokeAccess::IFCloudPath.poll
    assert_equal T.t(:dir_up), SpeakCapture.last, "the last move, on ground away from the clouds"
    $game_player.y = 17
    PokeAccess::IFCloudPath.poll
    assert_equal T.t(:if_cloud_top), SpeakCapture.last
  end

  test "a fall from the clouds is said in place of the teleport back to the start" do
    $game_switches[1017] = true
    assert_equal T.t(:if_cloud_fell), PokeAccess::IFCloudPath.fall_line([30, 29, 827], [38, 30, 827])
    assert_nil PokeAccess::IFCloudPath.fall_line([30, 29, 827], [12, 8, 827])
    $game_switches[1017] = false
    assert_nil PokeAccess::IFCloudPath.fall_line([30, 29, 827], [38, 30, 827])
  end

  test "the Magikarp ride says its controls, what lies ahead, the charge, the next press and the nightmares" do
    $game_map.map_id = 824
    $game_switches[806] = true
    karp = event(4, 12, 11, :sprite => "129")
    free = [[13, 11], [15, 11]]
    karp.define_singleton_method(:passable?) { |x, y, _d| free.include?([x, y]) }
    event(42, 16, 11, :sprite => "silhouette")
    $game_player = IfMiniPlayer.new(12, 11, [])
    $game_player.direction = 6
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::IFMagikarpRide.poll
    ahead = T.t(:if_karp_ahead, :one => T.t(:if_karp_free), :two => T.t(:if_karp_blocked))
    right = T.t(:dir_right)
    hop = T.t(:if_karp_next, :hop => T.t(:if_karp_hold, :hop => T.t(:if_karp_short, :dir => right)))
    assert_equal [[PokeAccess.sentences([T.t(:if_karp_rule), ahead, hop]), false]], said,
                 "the controls and the first hop as one line that cuts nothing; no long hop before the charge"
    karp.x = 13
    PokeAccess::IFMagikarpRide.poll
    blocked = T.t(:if_karp_ahead, :one => T.t(:if_karp_blocked), :two => T.t(:if_karp_free))
    here = T.t(:if_karp_next, :hop => T.t(:if_karp_charge_here, :dir => right))
    assert_equal [PokeAccess.sentences([blocked, here]), true], said.last, "a hop cuts what came before"
    $game_switches[807] = true
    PokeAccess::IFMagikarpRide.poll
    long = T.t(:if_karp_next, :hop => T.t(:if_karp_long, :dir => right))
    assert_equal [PokeAccess.sentences([T.t(:if_karp_charged), long]), false], said.last, "the charge waits its turn"
    SpeakCapture.clear
    beast = event(7, 10, 11, :sprite => "nightmare", :through => true)
    PokeAccess::IFMagikarpRide.poll
    appears = T.t(:if_karp_nightmare, :where => PokeAccess::Locator.dir_phrase(-3, 0))
    assert_equal [[PokeAccess.sentences([appears, T.t(:if_karp_close, :n => 3)]), false]], said
    beast.x = 11
    PokeAccess::IFMagikarpRide.poll
    assert_equal [T.t(:if_karp_close, :n => 2), false], said.last
    $game_player.direction = 2
    beast.x = 12
    PokeAccess::IFMagikarpRide.poll
    down = T.t(:if_karp_ahead, :one => T.t(:if_karp_blocked), :two => T.t(:if_karp_blocked))
    assert_equal [PokeAccess.sentences([down, long, T.t(:if_karp_close, :n => 1)]), false], said.last,
                 "a turn and the closing nightmare in one line, not cutting the nightmare that just appeared"
    120.times { PokeAccess::IFMagikarpRide.poll }
    $game_player.direction = 4
    PokeAccess::IFMagikarpRide.poll
    assert_equal true, said.last[1], "later turns cut again"
  end

  # What was voiced, each line with whether it cut what came before.
  def said
    SpeakCapture.log.map { |text, cut| [text, cut] }
  end

  test "with the long hop charged where only a short hop reaches, the next press is a quick one that spends it" do
    $game_map.map_id = 824
    $game_switches[806] = true
    $game_switches[807] = true
    karp = event(4, 20, 20, :sprite => "129")
    karp.define_singleton_method(:passable?) { |x, y, _d| x == 21 && y == 20 }
    event(42, 22, 20, :sprite => "silhouette")
    $game_player = IfMiniPlayer.new(20, 20, [])
    $game_player.direction = 6
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::IFMagikarpRide.poll
    ahead = T.t(:if_karp_ahead, :one => T.t(:if_karp_free), :two => T.t(:if_karp_blocked))
    spend = T.t(:if_karp_next, :hop => T.t(:if_karp_spend, :dir => T.t(:dir_right)))
    assert_equal PokeAccess.sentences([T.t(:if_karp_rule), ahead, spend]), SpeakCapture.last
    SpeakCapture.clear
    $game_switches[807] = false
    6.times { PokeAccess::IFMagikarpRide.poll }
    assert_empty SpeakCapture.lines, "a spent charge waits a few frames for a hop"
    PokeAccess::IFMagikarpRide.poll
    short = T.t(:if_karp_next, :hop => T.t(:if_karp_short, :dir => T.t(:dir_right)))
    assert_equal [[PokeAccess.sentences([short]), false]], said, "the charge spent in place: the next press"
    3.times { PokeAccess::IFMagikarpRide.poll }
    assert_equal 1, SpeakCapture.lines.length, "said once"
  end
end
