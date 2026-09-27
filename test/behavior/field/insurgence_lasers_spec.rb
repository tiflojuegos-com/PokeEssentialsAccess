# The Erebus Gym mirror rooms (games/insurgence/lasers.rb): each mirror by its number in reading order, the sides its
# turn joins (variable 144) and whether the beam passes it (variable 145), the room's count after a turn, and the beam's
# tiles kept out of the lists. Map 543's layout in part: mirrors 1 (6,18), 2 (12,18) and 6 (12,24), receiver 211.
unless defined?(PokeAccess::InsurgenceLasers)
  path = File.join(Harness::ROOT, "games", "insurgence", "lasers.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

module InsurgenceLaserSpec
  # Lays part of map 543 out: three mirrors, a lit track tile, the receiver and a trainer, with the turns and lit flags
  # the game keeps.
  def self.room
    $game_map.map_id = 543
    $game_map.events.clear
    [[1, "c", 6, 18, "mirror_1"], [2, "c", 12, 18, "mirror_0_active"], [6, "c", 12, 24, "mirror_2_active"],
     [40, "laser", 12, 20, "laser_0"], [211, "laser", 24, 15, ""], [229, "Trainer(3)", 3, 3, "trchar010"]].each do |id, name, x, y, sprite|
      World.event(:id => id, :name => name, :x => x, :y => y, :sprite => sprite)
    end
    turns = Array.new(221, 0)
    turns[1] = 1; turns[2] = 0; turns[6] = 2
    lit = Array.new(221, false)
    lit[2] = true; lit[6] = true; lit[40] = true
    $game_variables[144] = turns
    $game_variables[145] = lit
  end

  def self.ev(id); $game_map.events[id]; end
end

Suite.define("insurgence lasers: a mirror by its number, the sides its turn joins and whether the beam passes it") do
  InsurgenceLaserSpec.room
  l = PokeAccess::InsurgenceLasers
  t = PokeAccess::I18n
  eq "mirrors in reading order", l.mirrors.map { |e| e.id }, [1, 2, 6]
  eq "turn 1 joins top and right, off the beam", l.mirror_line(InsurgenceLaserSpec.ev(1)),
     t.t(:ins_mirror, :n => 1, :sides => t.t(:ins_mirror_tr))
  eq "turn 0 joins top and left, on the beam", l.mirror_line(InsurgenceLaserSpec.ev(2)),
     "#{t.t(:ins_mirror, :n => 2, :sides => t.t(:ins_mirror_tl))}, #{t.t(:ins_mirror_lit)}"
  eq "turn 2 joins bottom and right", l.mirror_line(InsurgenceLaserSpec.ev(6)),
     "#{t.t(:ins_mirror, :n => 3, :sides => t.t(:ins_mirror_br))}, #{t.t(:ins_mirror_lit)}"
end

Suite.define("insurgence lasers: a turned mirror is said with the room, and the info key says what is in front") do
  InsurgenceLaserSpec.room
  l = PokeAccess::InsurgenceLasers
  t = PokeAccess::I18n
  room = PokeAccess.sentences([t.t(:ins_laser_mirrors, :n => 3, :lit => 2), t.t(:ins_laser_receivers, :n => 1, :lit => 0)])
  eq "the room: mirrors on the beam and receivers reached", l.status_line(l.room), room
  l.rotated(6)
  eq "a turn says the mirror, then the room, interrupting", SpeakCapture.log,
     [[PokeAccess.sentences([l.mirror_line(InsurgenceLaserSpec.ev(6)), room]), true]]
  SpeakCapture.clear
  l.rotated(40)
  silent "an event that is no mirror says nothing"
  $game_player.x = 12; $game_player.y = 23; $game_player.direction = 2
  eq "facing a mirror, the info key says that mirror", l.info_line, l.mirror_line(InsurgenceLaserSpec.ev(6))
  $game_player.direction = 8
  eq "facing none, the room", l.info_line, room
end

Suite.define("insurgence lasers: the beam's tiles stay out of the lists, and a room is solved by its receivers' switches") do
  InsurgenceLaserSpec.room
  l = PokeAccess::InsurgenceLasers
  truthy "a lit track tile is the beam's", l.track?(InsurgenceLaserSpec.ev(40))
  falsy "the receiver is not", l.track?(InsurgenceLaserSpec.ev(211))
  falsy "nor a mirror", l.track?(InsurgenceLaserSpec.ev(1))
  falsy "nor anything off the mirror rooms", ($game_map.map_id = 5; l.track?(InsurgenceLaserSpec.ev(40)))
  $game_map.map_id = 543
  falsy "unsolved while the door switch is off", l.solved?
  $game_switches[515] = true
  truthy "solved once the receiver opened its door", l.solved?
  $game_map.map_id = 542
  $game_switches[517] = true
  falsy "map 542 needs both of its receivers", l.solved?
  $game_switches[516] = true
  truthy "and is solved with both", l.solved?
end
