# The sunken ship's puzzles (games/realidea/shipwreck.rb): the telegraph and the wheel through their per-frame
# readers and their loops, the sea chart's route, and the Chinchou puzzle's fish on a stub map 278. The loops, the
# bag's examination and the puzzle's arrows are entered through the game's own methods and functions on stand-ins
# that exist before the profile loads, so its hooks bind to them as they do in the game.

# Runs the frames a stand-in's loop is handed: each one's ivar changes are left on the scene, as the game's own
# frame work leaves them, then the frame is drawn and the input read.
def rea_ship_frames(scene, steps)
  (steps || []).each do |changes|
    changes.each { |k, v| scene.instance_variable_set(k, v) }
    Graphics.update
    Input.update
  end
end

# The telegraph (Morse) and the wheel (Timon), down to the blocking loop each runs until it ends; @steps holds its
# frames.
class Morse
  def actu; rea_ship_frames(self, @steps); end
end

class Timon
  def actu; rea_ship_frames(self, @steps); end
end

# What Jeremiah says over the sea chart, and over an object he has nothing to say about.
REA_SHIP_CHART_LINE = "Parece el recorrido que tomó el barco antes de hundirse."
REA_SHIP_OTHER_LINE = "No tengo mucho que decir sobre ese objeto..."

# Examining an object in the bag (Fusion objetos): over the sea chart's picture, or with none, Jeremiah's comment,
# shown as Kernel.pbMessage shows it (through pbMessageDisplay).
def examinarobj(item)
  Kernel.pbMessageDisplay(nil, item == PBItems::MAPAMAR ? REA_SHIP_CHART_LINE : REA_SHIP_OTHER_LINE)
end

# The Chinchou puzzle's arrows (Minijuego gambas): each moves every fish, events 3 to 5, that can go its way (the
# move route it sets, done at once here).
def gambaizda
  (3...6).each { |i| ev = $game_map.events[i]; ev.x -= 1 if ev.passable?(ev.x, ev.y, 4) }
end

def gambadcha
  (3...6).each { |i| ev = $game_map.events[i]; ev.x += 1 if ev.passable?(ev.x, ev.y, 6) }
end

def gambabajo
  (3...6).each { |i| ev = $game_map.events[i]; ev.y += 1 if ev.passable?(ev.x, ev.y, 2) }
end

def gambarriba
  (3...6).each { |i| ev = $game_map.events[i]; ev.y -= 1 if ev.passable?(ev.x, ev.y, 8) }
end

require File.expand_path("../../../games/realidea/shipwreck", File.dirname(__FILE__))

# The Chinchou puzzle as the profile registered it on its map, 278; each suite starts with the definitions cleared.
REA_SHIP_FISH = PokeAccess::Puzzles.instance_variable_get(:@defs)[278]

# A sprite as the readers see it: shown or not.
class ReaShipSprite
  attr_accessor :visible
  def initialize(visible = true); @visible = visible; end
end

# A fish event: where it is, its charset, whether it is still moving and whether something blocks its way.
class ReaShipFish
  attr_accessor :id, :x, :y, :character_name, :name, :moving, :blocked
  def initialize(id, x, y, graphic)
    @id = id; @x = x; @y = y; @character_name = graphic; @name = "GAMBA"; @moving = false; @blocked = false
  end
  def moving?; @moving; end
  def passable?(_x, _y, _dir); !@blocked; end
end

def rea_ship_scene(ivars)
  s = Object.new
  ivars.each { |k, v| s.instance_variable_set(k, v) }
  s
end

# The telegraph or the wheel with the given ivars, built without its initializer (which runs the whole loop).
def rea_ship_game(klass, ivars)
  s = klass.allocate
  ivars.each { |k, v| s.instance_variable_set(k, v) }
  s
end

def rea_st(key, vars = nil); PokeAccess::I18n.t(key, vars); end

REA_SHIP_ANSWER = %w[punto raya raya punto punto punto punto punto raya punto raya raya]

Suite.define("realidea telegraph: the painted keys, each symbol where it is painted, the guide, no answer length") do
  sw = PokeAccess::RealideaShipwreck
  sprites = { "help" => ReaShipSprite.new(false), "help1" => ReaShipSprite.new(true) }
  scene = rea_ship_scene(:@secuencia => [], :@secuenciacorrecta => REA_SHIP_ANSWER, :@numero => 0, :@sprites => sprites)
  sw.morse(scene)
  eq "the keys the panel paints, with the guide's once it is owned, queued", SpeakCapture.log,
     [["#{rea_st(:rea_morse_keys)}. #{rea_st(:rea_morse_guide_key)}", false]]
  not_spoke "and never how long the answer is", /12/

  SpeakCapture.clear
  scene.instance_variable_get(:@secuencia).push("raya")
  scene.instance_variable_set(:@numero, 1)
  sw.morse(scene)
  eq "a dash with the row and place it is painted in", SpeakCapture.lines,
     [rea_st(:rea_morse_slot, :sym => rea_st(:rea_dash), :row => 1, :col => 1)]

  SpeakCapture.clear
  scene.instance_variable_set(:@numero, 5)
  scene.instance_variable_get(:@secuencia).push("punto")
  sw.morse(scene)
  eq "after V jumps a row, the next symbol opens the second one", SpeakCapture.lines,
     [rea_st(:rea_morse_slot, :sym => rea_st(:rea_dot), :row => 2, :col => 1)]

  SpeakCapture.clear
  scene.instance_variable_set(:@secuencia, [])
  sw.morse(scene)
  eq "the symbols cleared", SpeakCapture.lines, [rea_st(:rea_morse_clear)]

  SpeakCapture.clear
  sprites["help"].visible = true
  sw.morse(scene)
  dot = rea_st(:rea_dot)
  dash = rea_st(:rea_dash)
  match "M shows the alphabet as the guide paints it", SpeakCapture.last, /\AA: #{dot} #{dash}\. B: #{dash} #{dot} #{dot} #{dot}\./
  match "P, H and Y among it", SpeakCapture.last,
        /P: #{dot} #{dash} #{dash} #{dot}\. .*Y: #{dash} #{dot} #{dash} #{dash}\./
  match "with the key that closes it", SpeakCapture.last, /#{Regexp.escape(rea_st(:rea_morse_guide_close))}\z/

  PokeAccess::Config.puzzle_assist = true
  SpeakCapture.clear
  helped = rea_ship_scene(:@secuencia => [], :@secuenciacorrecta => REA_SHIP_ANSWER, :@numero => 0,
                          :@sprites => { "help" => ReaShipSprite.new(false), "help1" => ReaShipSprite.new(false) })
  sw.morse(helped)
  spoke "the puzzle assist gives the answer's length", /#{Regexp.escape(rea_st(:rea_morse_goal, :n => 12))}/
  helped.instance_variable_get(:@secuencia).push("punto")
  sw.morse(helped)
  eq "and each symbol's place in it", SpeakCapture.last, rea_st(:rea_morse, :sym => dot, :n => 1, :tot => 12)
end

# Morse#actu and Timon#actu: each holds its scene for the per-frame reader while its loop runs, and lets it go as it
# ends.
Suite.define("realidea telegraph and wheel loops: the reader follows each while its loop runs, and lets go as it ends") do
  sprites = { "help" => ReaShipSprite.new(false), "help1" => ReaShipSprite.new(false) }
  telegraph = rea_ship_game(Morse, :@steps => [{ :@secuencia => [], :@secuenciacorrecta => REA_SHIP_ANSWER, :@numero => 0,
                                                  :@sprites => sprites }, { :@secuencia => ["raya"], :@numero => 1 }])
  telegraph.actu
  eq "the telegraph: its keys as it opens, then the dash entered where it is painted", SpeakCapture.lines,
     [rea_st(:rea_morse_keys), rea_st(:rea_morse_slot, :sym => rea_st(:rea_dash), :row => 1, :col => 1)]
  SpeakCapture.clear
  telegraph.instance_variable_set(:@secuencia, [])
  Input.update
  silent "and nothing once its loop is over"

  SpeakCapture.clear
  wheel = rea_ship_game(Timon, :@steps => [{ :@posiciones => %w[SE E NE N NO O SO S], :@combinaciontimon => [],
                                             :@sprites => {} }, { :@posiciones => %w[E NE N NO O SO S SE] }])
  wheel.actu
  eq "the wheel: its heading, then the next one as it turns", SpeakCapture.lines, [rea_st(:dir_se), rea_st(:dir_e)]
  SpeakCapture.clear
  wheel.instance_variable_set(:@posiciones, %w[NE N NO O SO S SE E])
  Input.update
  silent "and nothing once its loop is over"
end

# The wheel's reader, and the sea chart examined in the bag through examinarobj: its route as the chart shows,
# before Jeremiah speaks over it.
Suite.define("realidea wheel: headings as words, entries without the answer's length, its keys and the chart") do
  sw = PokeAccess::RealideaShipwreck
  sprites = { "extra" => ReaShipSprite.new(true), "extra1" => ReaShipSprite.new(true), "mapa" => ReaShipSprite.new(false) }
  answer = ["[O]", "[NO]", "[NE]", "[E]", "[S]", "[E]"]
  scene = rea_ship_scene(:@posiciones => %w[SE E NE N NO O SO S], :@combinaciontimon => [], :@combinacion => answer,
                         :@sprites => sprites)
  sw.timon(scene)
  keys = "#{rea_st(:rea_timon_key_enter)}. #{rea_st(:rea_timon_key_chart)}"
  eq "the heading as a word, the empty log and the painted keys", SpeakCapture.log,
     [[rea_st(:dir_se), true], [rea_st(:rea_timon_empty), false], [keys, false]]

  SpeakCapture.clear
  scene.instance_variable_set(:@posiciones, %w[NO O SO S SE E NE N])
  scene.instance_variable_get(:@combinaciontimon).push("[NO]")
  sw.timon(scene)
  eq "a turn and an entry, which says its place but not how many the answer has", SpeakCapture.lines,
     [rea_st(:dir_no), rea_st(:rea_timon_entry, :dir => rea_st(:dir_no), :n => 1)]

  SpeakCapture.clear
  sprites["mapa"].visible = true
  sw.timon(scene)
  words = %w[dir_o dir_no dir_ne dir_e dir_s dir_e].map { |k| rea_st(k.to_sym) }.join(", ")
  eq "F opens the chart: its red line leg by leg, and the key that closes it", SpeakCapture.lines,
     ["#{rea_st(:rea_chart_route, :list => words)}. #{rea_st(:rea_chart_back)}"]

  SpeakCapture.clear
  bare = rea_ship_scene(:@posiciones => %w[SE E], :@combinaciontimon => [], :@combinacion => answer,
                        :@sprites => { "extra" => ReaShipSprite.new(false), "extra1" => ReaShipSprite.new(false) })
  sw.timon(bare)
  eq "without the compass only the heading: no log, no keys", SpeakCapture.lines, [rea_st(:dir_se)]

  PBItems.const_set(:MAPAMAR, 7777) unless PBItems.const_defined?(:MAPAMAR)
  begin
    SpeakCapture.clear
    examinarobj(7777)
    eq "examining the chart in the bag says its route as the chart shows, before Jeremiah speaks", SpeakCapture.lines,
       [rea_st(:rea_chart_route, :list => words), REA_SHIP_CHART_LINE]
    SpeakCapture.clear
    examinarobj(7776)
    eq "and any other item only what the game says", SpeakCapture.lines, [REA_SHIP_OTHER_LINE]
  ensure
    PBItems.send(:remove_const, :MAPAMAR)
  end
end

# The fish through their per-frame reader, and each of the four arrows through its own function: one that moves no
# fish is said once they settle, one that moves a fish gives their places.
Suite.define("realidea Chinchou puzzle: the board and the fish, their places after each move, and the currents") do
  sw = PokeAccess::RealideaShipwreck
  chinchou = ReaShipFish.new(3, 18, 6, "170")
  carvanha = ReaShipFish.new(4, 17, 7, "318")
  other = ReaShipFish.new(5, 18, 9, "318")
  fish = [chinchou, carvanha, other]
  $game_map.map_id = 278
  fish.each { |f| $game_map.events[f.id] = f }
  sw.fish_reset
  begin
    sw.fish_poll
    silent "off the switch the puzzle is asleep"
    falsy "and not active", sw.fish_active?

    $game_switches[366] = true
    truthy "switch 366 runs it", sw.fish_active?
    c_name = PokeAccess::Locator.sprite_species("170") || "GAMBA"
    v_name = PokeAccess::Locator.sprite_species("318") || "GAMBA"
    title = sw.fish_title
    match "its line: what the arrows move, the painted grid", title,
          /\A#{Regexp.escape(rea_st(:rea_fish_intro))}\. .*#{Regexp.escape(rea_st(:rea_fish_board))}/
    match "and where each fish stands on it", title,
          /#{Regexp.escape(rea_st(:rea_fish_at, :name => c_name, :row => 1, :col => 6))}\. #{Regexp.escape(rea_st(:rea_fish_at, :name => v_name, :row => 2, :col => 5))}/

    sw.fish_poll
    silent "the first frame only takes the places"
    chinchou.x = 17
    carvanha.x = 16
    carvanha.moving = true
    sw.fish_poll
    carvanha.moving = false
    5.times { sw.fish_poll }
    silent "nothing while they settle"
    sw.fish_poll
    spoke_once "then where the three are", /#{Regexp.escape(rea_st(:rea_fish_at, :name => c_name, :row => 1, :col => 5))}/
    SpeakCapture.clear
    8.times { sw.fish_poll }
    silent "and nothing more while they stay"

    $game_map.set_terrain(13, 9, 38)
    other.x = 13
    sw.fish_poll
    other.y = 11
    8.times { sw.fish_poll }
    spoke_once "a fish a current carried says so", /#{Regexp.escape(rea_st(:rea_fish_drift, :name => v_name, :row => 6, :col => 1))}/

    fish.each { |f| f.blocked = true }
    %w[gambaizda gambadcha gambabajo gambarriba].each do |arrow|
      SpeakCapture.clear
      send(arrow)
      5.times { sw.fish_poll }
      silent "#{arrow}, moving no fish, waits for them to settle"
      sw.fish_poll
      eq "then says none moved", SpeakCapture.lines, [rea_st(:rea_fish_stuck)]
    end
    SpeakCapture.clear
    8.times { sw.fish_poll }
    silent "once"

    chinchou.blocked = false
    gambabajo
    10.times { sw.fish_poll }
    eq "an arrow that moves one says where the three are, not that none moved", SpeakCapture.lines.length, 1
    match "starting with the Chinchou", SpeakCapture.last, /\A#{Regexp.escape(rea_st(:rea_fish_at, :name => c_name, :row => 2, :col => 5))}/
  ensure
    $game_switches[366] = false
    sw.fish_reset
  end
end

# The puzzle the profile registered on map 278: its green circle is a locator spot and its line the info key's only
# while switch 366 runs it.
Suite.define("realidea Chinchou puzzle: the green circle is a locator spot only while the puzzle runs") do
  pz = PokeAccess::Puzzles
  truthy "map 278 is declared as a staged puzzle", REA_SHIP_FISH.is_a?(Hash) && REA_SHIP_FISH[:kind] == :stages
  pz.register(278, REA_SHIP_FISH)
  $game_map.map_id = 278
  begin
    eq "before the puzzle starts nothing is listed", pz.stages_targets(pz.current), []
    falsy "nor read", pz.active?
    $game_switches[366] = true
    names = pz.stages_targets(pz.current).map { |t| t.name }
    eq "while it runs, the circle", names, [rea_st(:rea_fish_circle)]
    SpeakCapture.clear
    pz.read
    match "and the info key reads what the arrows move", SpeakCapture.last, /\A#{Regexp.escape(rea_st(:rea_fish_intro))}/
    $game_switches[366] = false
    eq "and once it is over, nothing again", pz.stages_targets(pz.current), []
  ensure
    $game_switches[366] = false
  end
  match "the board names the two corals the picture leaves uncrossed", rea_st(:rea_fish_board),
        /fila 1, columna 1, y fila 2, columna 4/
end
