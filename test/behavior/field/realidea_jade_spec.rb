# Realidea's Jade screens (games/realidea/jade_screens.rb): the theatre's choreography sheet and the dance it is
# checked against, the gym's cry helper, and the rhythm game two of the gym's battles open. The dance and the rhythm
# game are entered through the game's own methods on stand-ins that exist before the profile loads, so its hooks
# bind to them as they do in the game.

# The event interpreter, down to Set Move Route (command 209): it forces the route @parameters[1] on the character
# @parameters[0] names, and goes on.
class Interpreter
  def command_209; true; end
end

# A sprite and its bitmap, as far as the rhythm game's reader measures the selector.
ReaIdolBitmap = Struct.new(:width)
ReaIdolSprite = Struct.new(:bitmap)

# A note of the song, as SongNote keeps it: every frame it steps 8 px left, toward the selector.
class ReaIdolNote
  attr_accessor :note, :x, :hit, :range
  def initialize(note, x); @note = note; @x = x; @hit = false; @range = 30; end
  def doStep; @x -= 8; end
end

# The rhythm game (SuperIdols' Idol): pbStartScene lays the song's notes out to the right of the selector, 40 px
# apart, and paints its title; pbUpdate's loop steps every note each frame until the last one has passed the
# selector.
class Idol
  attr_accessor :song

  def pbStartScene
    @sprites = { "selector" => ReaIdolSprite.new(ReaIdolBitmap.new(64)) }
    @notes = []
    (@song || []).each_with_index { |note, i| @notes.push(ReaIdolNote.new(note, Graphics.width / 2 + 64 + 40 * i)) }
    pbDrawTextPositions(nil, [["¡Dale caña!", 192, 30]])
  end

  def pbUpdate
    loop do
      Graphics.update
      Input.update
      @notes.each { |n| n.doStep }
      break if @notes.last.x < Graphics.width / 2 - 150
    end
  end
end

require File.expand_path("../../../games/realidea/jade_screens", File.dirname(__FILE__))

# The theatre's puzzle as the profile registered it on its map, 113; each suite starts with the definitions cleared.
REA_JADE_DANCE = PokeAccess::Puzzles.instance_variable_get(:@defs)[113]

# A Set Move Route of the theatre's supervisor, run as the interpreter runs it.
def rea_set_route(character, route)
  interp = Interpreter.allocate
  interp.instance_variable_set(:@parameters, [character, route])
  interp.command_209
end

Suite.define("realidea: the choreography sheet reads as one line per Oricorio, and the cry helper names its species") do
  rj = PokeAccess::ReaJade

  eq "each column becomes its header and its steps in order",
     rj.sheet_text(["Oricorio 1\nArriba\nSalto\nDerecha", "Oricorio 2\nAbajo\nIzquierda"]),
     "Oricorio 1: Arriba, Salto, Derecha. Oricorio 2: Abajo, Izquierda"
  eq "a blank capture says nothing", rj.sheet_text([]), ""
  eq "a column of one line is said as it is", rj.sheet_text(["Sin pasos"]), "Sin pasos"

  eq "the cursor's species and its position among the three",
     rj.cry_text(1, 1), "#{PokeAccess::Data.species_name(209)}, 1 de 3"
  eq "the first trio's second sprite is the species its octal 035 names, 29",
     rj.cry_text(2, 1), "#{PokeAccess::Data.species_name(29)}, 2 de 3"
  eq "the third group's last member", rj.cry_text(3, 3), "#{PokeAccess::Data.species_name(755)}, 3 de 3"
  eq "off the table there is nothing to say", rj.cry_text(0, 1), nil
  eq "and an unknown group neither", rj.cry_text(1, 9), nil
end

# The dance through command 209 as event 10 sets each dancer's route, and through the theatre's registered puzzle,
# which the info key reads while the supervisor's page runs.
Suite.define("realidea theatre: the dance is told once its four routes are set, and stays for the info key") do
  t = PokeAccess::I18n
  pz = PokeAccess::Puzzles
  step = lambda { |*codes| TestMoveRoute.new(codes.map { |c| TestMoveCmd.new(c) } + [TestMoveCmd.new(0)]) }
  routes = { 2 => step.call(4, 15, 14, 15, 3, 15, 2, 15, 1, 15), 3 => step.call(1, 15, 2, 15, 3, 15, 14, 15, 4, 16, 15),
             4 => step.call(2, 15, 14, 15, 3, 15, 14, 15, 14, 16, 15), 5 => step.call(14, 15, 3, 15, 4, 15, 2, 15, 1, 15) }
  up = t.t(:dir_up); down = t.t(:dir_down); left = t.t(:dir_left); right = t.t(:dir_right); jump = t.t(:rea_ori_jump)
  steps = [[up, jump, right, left, down], [down, left, right, jump, up], [left, jump, right, jump, jump],
           [jump, right, up, left, down]]
  dance = t.t(:rea_ori_dance, :list => (0...4).map { |i| t.t(:rea_ori_dancer, :n => i + 1, :steps => steps[i].join(", ")) }.join("; "))
  $game_map.map_id = 113
  was_switches = $game_self_switches
  begin
    rea_set_route(0, step.call(4))
    rea_set_route(-1, step.call(8))
    [2, 3, 4].each { |id| rea_set_route(id, routes[id]) }
    silent "the supervisor's own turn, the player's, and three of four dancers say nothing"
    rea_set_route(5, routes[5])
    eq "the fourth route tells the whole dance, each dancer as it really moves, led by the key that opens the sheet " \
       "while the sheet can still be opened", SpeakCapture.lines,
       [PokeAccess.sentences([PokeAccess::KeyHints.localize(t.t(:rea_ori_sheet_key)), dance])]

    truthy "the theatre is declared as a staged puzzle", REA_JADE_DANCE.is_a?(Hash) && REA_JADE_DANCE[:kind] == :stages
    pz.register(113, REA_JADE_DANCE)
    falsy "the info key has it only while the supervisor's page runs", pz.active?
    $game_self_switches = { [113, 10, "A"] => true }
    truthy "and then it does", pz.active?
    SpeakCapture.clear
    pz.read
    eq "the text the info key reads", SpeakCapture.lines, [dance]
    $game_self_switches = { [113, 10, "A"] => true, [113, 10, "B"] => true }
    falsy "the right answer turns B on and leaves A, and the info key is its own again", pz.active?

    SpeakCapture.clear
    $game_map.map_id = 114
    rea_set_route(2, routes[2])
    silent "routes on another map are not the dance"
  ensure
    $game_self_switches = was_switches
  end
end

Suite.define("realidea rhythm game: each note's arrow as it comes within reach of the selector, once") do
  rj = PokeAccess::ReaJade
  t = PokeAccess::I18n
  sx = Graphics.width / 2 - 32
  notes = [ReaIdolNote.new("up", sx + 100), ReaIdolNote.new("", sx + 120), ReaIdolNote.new("down", sx + 140)]
  scene = Object.new
  scene.instance_variable_set(:@notes, notes)
  scene.instance_variable_set(:@sprites, { "selector" => ReaIdolSprite.new(ReaIdolBitmap.new(64)) })
  rj.hold_idol(scene)
  begin
    rj.idol_poll
    silent "no note within reach yet"
    notes.each { |n| n.x -= 80 }
    rj.idol_poll
    eq "the first note as it comes within 30 px", SpeakCapture.lines, [t.t(:dir_up)]
    notes.each { |n| n.x -= 40 }
    rj.idol_poll
    eq "an empty slot says nothing, the next arrow its direction", SpeakCapture.lines, [t.t(:dir_up), t.t(:dir_down)]
    rj.idol_poll
    eq "each note once", SpeakCapture.lines.length, 2
  ensure
    rj.release_idol
  end
end

# The rhythm game through pbStartScene and pbUpdate: the title it paints as it opens, then each note's arrow while
# the loop runs; nothing once the loop is over.
Suite.define("realidea rhythm game loop: its title, then the notes' arrows while it runs, and nothing once it is over") do
  t = PokeAccess::I18n
  idol = Idol.new
  idol.song = ["up", "", "down"]
  idol.pbStartScene
  idol.pbUpdate
  eq "the title queued, then the arrows in the song's order, an empty slot saying nothing", SpeakCapture.log,
     [["¡Dale caña!", false], [t.t(:dir_up), true], [t.t(:dir_down), true]]
  SpeakCapture.clear
  idol.instance_variable_get(:@notes).push(ReaIdolNote.new("left", Graphics.width / 2 - 32))
  Input.update
  silent "and nothing once the game is over"
end
