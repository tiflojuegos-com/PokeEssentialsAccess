# Realidea's beam rooms (games/realidea/lasers.rb), on boards transcribed from Map020 and Map191-193: the beam model
# matches launchLaser, the solution table solves every room, and what a turn, a shot, the info key and Bronzor say.
load File.expand_path("../../../games/realidea/lasers.rb", File.dirname(__FILE__)) unless defined?(PokeAccess::RealideaLasers)

module LaserBoards
  # map => :from emitter [x, y, facing], :to receiver [x, y], :steps given to launchLaser, :gap Bronzor's gap, and
  # :mirrors id => [x, y, facing] as the room starts (Bronzor, event 14, where it wanders before its battle).
  ROOMS = {
    20  => { :from => [8, 7, 6], :to => [17, 8], :steps => 20,
             :mirrors => { 4 => [11, 7, 4], 5 => [11, 11, 2], 6 => [17, 11, 8] } },
    191 => { :from => [8, 7, 8], :to => [17, 7], :steps => 38,
             :mirrors => { 18 => [13, 5, 4], 4 => [8, 5, 4], 15 => [10, 7, 4], 16 => [10, 10, 2], 5 => [13, 10, 2],
                           14 => [14, 5, 4], 19 => [15, 5, 2], 17 => [15, 7, 2], 20 => [17, 11, 2], 13 => [14, 11, 4] } },
    192 => { :from => [8, 7, 6], :to => [17, 8], :steps => 40, :gap => [11, 7],
             :mirrors => { 14 => [20, 16, 2], 5 => [11, 11, 2], 6 => [14, 11, 2], 15 => [14, 5, 2], 18 => [17, 12, 2],
                           16 => [9, 5, 2], 17 => [9, 12, 2] } },
    193 => { :from => [8, 7, 6], :to => [10, 4], :steps => 46, :gap => [10, 10],
             :mirrors => { 14 => [5, 16, 2], 5 => [18, 7, 2], 6 => [14, 12, 2], 15 => [14, 5, 2], 18 => [18, 12, 2],
                           16 => [17, 10, 2], 17 => [17, 5, 2] } }
  }

  # A board for RealideaLasers.trace in the game's mirror order; :solved turns each mirror as the solution wants, and
  # :bronzor puts Bronzor in its gap with that facing.
  def self.board(mid, opts = {})
    b = ROOMS[mid]
    room = PokeAccess::RealideaLasers::ROOMS[mid]
    mirrors = room[:mirrors].map do |id|
      x, y, d = b[:mirrors][id]
      placed = b[:gap] && id == room[:bronzor] && opts[:bronzor]
      x, y = b[:gap] if placed
      s = PokeAccess::RealideaLasers.shape(placed ? opts[:bronzor] : d)
      s = room[:goal][[x, y]] if opts[:solved] && room[:goal][[x, y]]
      [id, x, y, s]
    end
    { :w => 28, :h => 24, :from => b[:from][0, 2], :dir => b[:from][2], :to => b[:to],
      :steps => opts[:steps] || b[:steps], :mirrors => mirrors }
  end

  # Lays a room out on the stub map as events: the crystals, the prisms and Bronzor (sprite 436).
  def self.lay(mid)
    b = ROOMS[mid]
    $game_map.map_id = mid; $game_map.width = 28; $game_map.height = 24
    $game_map.events.clear
    put = lambda do |id, x, y, d, sprite|
      e = TestEvent.new(id, "EV#{id}", x, y)
      e.direction = d; e.character_name = sprite
      $game_map.events[id] = e
    end
    put.call(3, b[:from][0], b[:from][1], b[:from][2], "Cristal PequeA")
    put.call(1, b[:to][0], b[:to][1], 2, "Cristal Grande")
    put.call(10, 0, 0, 2, "laser")
    b[:mirrors].each { |id, (x, y, d)| put.call(id, x, y, d, id == 14 ? "436" : "Prismas2") }
    PokeAccess::RealideaLasers.reset
  end

  # Stands the player on (x,y) facing d.
  def self.stand(x, y, d)
    $game_player.x = x; $game_player.y = y; $game_player.direction = d
  end
end

Suite.define("realidea beam rooms: the model moves the beam as launchLaser does") do
  l = PokeAccess::RealideaLasers
  eq "2 and 8 draw the falling diagonal, 4 and 6 the rising one", [2, 8, 4, 6].map { |d| l.shape(d) }, [:desc, :desc, :asc, :asc]
  eq "each turn of rotateEvent (2, 4, 8, 6, 2) flips the shape", [2, 4, 8, 6, 2].map { |d| l.shape(d) },
     [:desc, :asc, :desc, :asc, :desc]

  eq "room 20 as it starts: prism 1 sends the beam up and it is lost at the top",
     l.trace(LaserBoards.board(20)), [:lost, [[4, 8]], 8]
  eq "room 191 as it starts: prism 1 right, prism 2 up, lost at the top",
     l.trace(LaserBoards.board(191)), [:lost, [[4, 6], [18, 8]], 8]
  eq "room 192 with Bronzor in its gap: down, right, down, lost at the bottom",
     l.trace(LaserBoards.board(192, :bronzor => 8)), [:lost, [[14, 2], [5, 6], [6, 2]], 2]
  eq "room 193 as it starts: prism 3 down, prism 6 right, lost at the right after the map wraps",
     l.trace(LaserBoards.board(193)), [:lost, [[5, 2], [18, 6]], 6]

  [20, 191, 192, 193].each do |mid|
    t = l.trace(LaserBoards.board(mid, :solved => true, :bronzor => 2))
    eq "the solution table solves room #{mid}, through every mirror", [t[0], t[1].length],
       [:hit, PokeAccess::RealideaLasers::ROOMS[mid][:mirrors].length]
  end
  eq "191 is solved on the last move allowed: one step less and the beam stops short",
     l.trace(LaserBoards.board(191, :solved => true, :steps => 37))[0], :stop
  eq "and so is 193", l.trace(LaserBoards.board(193, :solved => true, :bronzor => 2, :steps => 45))[0], :stop
  near = LaserBoards.board(20)
  near[:mirrors][0][3] = :desc
  eq "room 20 with only prism 1 turned: the beam runs out of steps before the crystal",
     l.trace(near), [:stop, [[4, 2], [5, 6], [6, 2]], 2]
end

Suite.define("realidea beam rooms: a turn, a shot and the info key are said as the room stands") do
  t = PokeAccess::I18n
  l = PokeAccess::RealideaLasers
  was_assist = PokeAccess::Config.puzzle_assist
  was_switches = $game_self_switches
  $game_self_switches = {}
  PokeAccess::Config.puzzle_assist = false
  LaserBoards.lay(20)
  LaserBoards.stand(13, 21, 8)
  prism = lambda { |n, shape| t.t(:rea_laser_shape, :name => t.t(:rea_laser_prism, :n => n), :shape => t.t(shape)) }
  heading = lambda { |k| t.t(k) }

  $game_map.events[4].direction = 2
  SpeakCapture.clear
  l.rotated(4)
  eq "turning prism 1 says its new shape", SpeakCapture.last, prism.call(1, :rea_laser_desc)
  PokeAccess::Config.puzzle_assist = true
  SpeakCapture.clear
  l.rotated(4)
  eq "with the assist, and that it is right", SpeakCapture.last, "#{prism.call(1, :rea_laser_desc)}, #{t.t(:rea_laser_ok)}"
  SpeakCapture.clear
  l.rotated(99)
  silent "an event that is no mirror of the room says nothing"

  $game_map.events[4].direction = 4
  PokeAccess::Config.puzzle_assist = false
  SpeakCapture.clear
  l.firing([3, 10, 1, [4, 5, 6], 20])
  shot = [t.t(:rea_laser_start, :dir => heading.call(:rea_laser_to_right)),
          t.t(:rea_laser_hop, :name => t.t(:rea_laser_prism, :n => 1), :dir => heading.call(:rea_laser_to_up)),
          t.t(:rea_laser_lost, :side => t.t(:rea_laser_by_up))].join("; ")
  eq "firing says the path the beam is about to take", SpeakCapture.last, shot
  SpeakCapture.clear
  l.fired(false)
  silent "and the game's own answer, the same, adds nothing"
  l.fired(true)
  eq "an answer that differs is said", SpeakCapture.last, t.t(:rea_laser_real_hit)

  PokeAccess::Config.puzzle_assist = true
  SpeakCapture.clear
  l.firing([3, 10, 1, [4, 5, 6], 20])
  eq "with the assist, the shot names the first prism to turn",
     SpeakCapture.last, "#{shot}. #{t.t(:rea_laser_todo, :list => t.t(:rea_laser_prism, :n => 1))}"

  board = t.t(:rea_laser_board, :n => 3, :dir => heading.call(:rea_laser_to_right))
  eq "the info key reads the room and the last shot", l.info_line, "#{board}. #{t.t(:rea_laser_last, :shot => shot)}"
  eq "and with the assist what to turn", l.assist_line, t.t(:rea_laser_todo, :list => t.t(:rea_laser_prism, :n => 1))

  LaserBoards.stand(16, 11, 6)
  eq "facing a prism, the info key says its shape", l.info_line, prism.call(3, :rea_laser_desc)
  eq "and the assist whether it is right",
     l.assist_line, t.t(:rea_laser_goal, :shape => t.t(:rea_laser_asc))
  LaserBoards.stand(9, 7, 4)
  eq "facing the small crystal, the way it fires", l.info_line,
     t.t(:rea_laser_emitter_dir, :dir => heading.call(:rea_laser_to_right))

  $game_map.events[4].direction = 2
  $game_map.events[6].direction = 4
  SpeakCapture.clear
  l.firing([3, 10, 1, [4, 5, 6], 20])
  eq "a shot that reaches the crystal says just that", SpeakCapture.last, t.t(:rea_laser_hit)
  LaserBoards.stand(13, 21, 8)
  eq "and the assist has nothing left to turn", l.assist_line, t.t(:rea_laser_ready)

  eq "the locator names the prisms by number and shape",
     PokeAccess::Locator.target_name($game_map.events[6]), "#{prism.call(3, :rea_laser_asc)}, #{t.t(:rea_laser_ok)}"
  eq "the crystals by what they are, and the parked beam as the beam",
     [PokeAccess::Locator.target_name($game_map.events[3]), PokeAccess::Locator.target_name($game_map.events[1]),
      PokeAccess::Locator.target_name($game_map.events[10])],
     [t.t(:rea_laser_emitter), t.t(:rea_laser_receiver), t.t(:rea_laser_beam)]
  begin
    PokeAccess::Tags.set($game_map.map_id, 3, "cristal rojo")
    eq "a name the player gave a piece wins, as anywhere else", PokeAccess::Locator.target_name($game_map.events[3]),
       "cristal rojo"
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 3)
  end
  names = PokeAccess::Puzzles.spot_targets(l.spots(20)).map { |s| s.name }
  truthy "the puzzle category lists both crystals and every prism, each as it stands",
         names.length == 5 && names.include?("#{prism.call(1, :rea_laser_desc)}, #{t.t(:rea_laser_ok)}")
  eq "a puzzle label may be a lambda, read when it is asked", PokeAccess::Puzzles.label_of(lambda { :rea_laser_beam }),
     t.t(:rea_laser_beam)

  falsy "the room is not solved while the crystal has not turned", l.solved?
  $game_self_switches[[20, 3, "A"]] = true
  truthy "and is once it has", l.solved?
ensure
  PokeAccess::Config.puzzle_assist = was_assist
  $game_self_switches = was_switches
  $game_map.map_id = 1; $game_map.width = 20; $game_map.height = 20
  $game_map.events.clear
end

Suite.define("realidea beam rooms: Bronzor fills its gap after its battle, in either shape") do
  t = PokeAccess::I18n
  l = PokeAccess::RealideaLasers
  was_assist = PokeAccess::Config.puzzle_assist
  was_switches = $game_self_switches
  $game_self_switches = {}
  PokeAccess::Config.puzzle_assist = true
  LaserBoards.lay(192)
  LaserBoards.stand(13, 21, 8)
  bronzor = PBSpecies.getName(436)

  SpeakCapture.clear
  l.rotated(14)
  silent "while Bronzor wanders, it is no mirror to speak of"
  eq "the locator calls it by its species", PokeAccess::Locator.target_name($game_map.events[14]), bronzor
  eq "and the assist says to beat it first", l.assist_line, t.t(:rea_laser_missing, :name => bronzor)

  l.poll
  silent "arriving on the map only takes note of where Bronzor stands"
  $game_self_switches[[192, 14, "A"]] = true
  $game_map.events[14].x = 11; $game_map.events[14].y = 7; $game_map.events[14].direction = 4
  l.poll
  shape = t.t(:rea_laser_shape, :name => bronzor, :shape => t.t(:rea_laser_asc))
  eq "once it settles, where it went and the shape it came in with",
     SpeakCapture.last, [t.t(:rea_laser_placed, :name => bronzor), shape, t.t(:rea_laser_placed_hint)].join(". ")
  SpeakCapture.clear
  l.poll
  silent "and only once"
  l.rotated(14)
  eq "then it turns like a prism", SpeakCapture.last,
     "#{t.t(:rea_laser_shape, :name => bronzor, :shape => t.t(:rea_laser_asc))}, #{t.t(:rea_laser_goal, :shape => t.t(:rea_laser_desc))}"
ensure
  PokeAccess::Config.puzzle_assist = was_assist
  $game_self_switches = was_switches
  $game_map.map_id = 1; $game_map.width = 20; $game_map.height = 20
  $game_map.events.clear
end
