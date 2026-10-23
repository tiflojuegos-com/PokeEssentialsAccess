# Realidea's Jade screens (games/realidea/jade_screens.rb), through the game's own methods: the theatre's choreography
# sheet and the dance it is checked against, the gym's cry helper, and the rhythm game two of the gym's battles open.

# The event interpreter, down to Set Move Route (command 209): it forces the route @parameters[1] on the character
# @parameters[0] names, and goes on.
class Interpreter
  def command_209; true; end
end

# The theatre's choreography sheet (Baileoricorios): its constructor paints each Oricorio's column with drawTextEx, then
# runs actu, the loop the sheet stays open in.
class Baileoricorios
  def initialize
    (@columns || []).each_with_index { |text, i| drawTextEx(nil, 16 + 120 * i, 40, 120, 6, text) }
    actu
  end

  def actu; end
end

# The gym's cry helper (Pokemonysusgritos): its input reads the keys and leaves @seleccion on one of its three sprites.
class Pokemonysusgritos
  def initialize; @seleccion = 1; end
  def input; end
end

# The rhythm game (SuperIdols' Idol): pbStartScene lays the song's notes out to the right of the selector, 40 px apart,
# and paints its title; pbUpdate's loop steps every note each frame until the last one has passed the selector.
class Idol
  # A note of the song, as SongNote keeps it: every frame it steps its step_distance, 8 px, left toward the selector.
  class SongNote
    attr_accessor :note, :x, :hit, :range, :step_distance
    def initialize(note, x); @note = note; @x = x; @hit = false; @range = 30; @step_distance = 8; end
    def doStep; @x -= @step_distance; end
  end

  # The selector's sprite and its bitmap, as far as the reader measures them.
  Selector = Struct.new(:bitmap)
  SelectorBitmap = Struct.new(:width)

  attr_accessor :song

  def pbStartScene
    @sprites = { "selector" => Selector.new(SelectorBitmap.new(64)) }
    @notes = []
    (@song || []).each_with_index { |note, i| @notes.push(SongNote.new(note, Graphics.width / 2 + 64 + 40 * i)) }
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

jade = File.join(Harness::ROOT, "games", "realidea", "jade_screens.rb")
eval(Harness.source(jade), TOPLEVEL_BINDING, jade)

class RealideaJadeTest < PokeAccessTest
  # The theatre's puzzle as the profile declared it on its map, kept before the first test clears the declarations.
  DANCE = PokeAccess::World::Mechanics.declared(113)
  # The species the cry helper's three sprites show for each value of $game_variables[91], as its constructor sets them
  # (the 035 there is octal: species 29).
  TRIOS = { 1 => [209, 29, 742], 2 => [175, 546, 281], 3 => [703, 183, 755] }
  # The Set Move Route the supervisor (event 10) gives each dancer, by event: codes 1 to 4 step down, left, right and
  # up, 14 jumps, 15 waits and 16 turns.
  ROUTES = { 2 => [4, 15, 14, 15, 3, 15, 2, 15, 1, 15], 3 => [1, 15, 2, 15, 3, 15, 14, 15, 4, 16, 15],
             4 => [2, 15, 14, 15, 3, 15, 14, 15, 14, 16, 15], 5 => [14, 15, 3, 15, 4, 15, 2, 15, 1, 15] }
  # The steps each of those routes dances, as the words that say them.
  STEPS = { 2 => [:dir_up, :rea_ori_jump, :dir_right, :dir_left, :dir_down],
            3 => [:dir_down, :dir_left, :dir_right, :rea_ori_jump, :dir_up],
            4 => [:dir_left, :rea_ori_jump, :dir_right, :rea_ori_jump, :rea_ori_jump],
            5 => [:rea_ori_jump, :dir_right, :dir_up, :dir_left, :dir_down] }

  test "reads the choreography sheet as one line per Oricorio" do
    { ["Oricorio 1\nArriba\nSalto\nDerecha", "Oricorio 2\nAbajo\nIzquierda"] =>
        "Oricorio 1: Arriba, Salto, Derecha. Oricorio 2: Abajo, Izquierda",
      ["Sin pasos"] => "Sin pasos",
      [" Oricorio 1 \n\n  Arriba ", " \n "] => "Oricorio 1: Arriba",
      [] => "",
      nil => "" }.each do |columns, line|
      assert_equal line, PokeAccess::ReaJade.sheet_text(columns), "for #{columns.inspect}"
    end
  end

  test "reads the sheet its screen paints as it opens" do
    open_sheet(["Oricorio 1\nArriba\nSalto", "Oricorio 2\nAbajo"])
    assert_equal [["Oricorio 1: Arriba, Salto. Oricorio 2: Abajo", true]], SpeakCapture.log
  end

  test "names each species the cry helper shows and its place among the three" do
    TRIOS.each do |group, ids|
      ids.each_with_index do |id, i|
        want = t(:list_entry, :name => PokeAccess::Data.species_name(id), :n => i + 1, :tot => 3)
        assert_equal want, PokeAccess::ReaJade.cry_text(i + 1, group), "sprite #{i + 1} of group #{group}"
      end
    end
  end

  test "finds the helper's group from a variable that holds it as text" do
    assert_equal t(:list_entry, :name => PokeAccess::Data.species_name(703), :n => 1, :tot => 3),
                 PokeAccess::ReaJade.cry_text(1, "3")
  end

  test "names nothing off the cry helper's table" do
    [[0, 1], [4, 1], [1, 9], [1, nil], ["1", 1]].each do |sel, group|
      assert_nil PokeAccess::ReaJade.cry_text(sel, group), "sprite #{sel.inspect} of group #{group.inspect}"
    end
  end

  test "names only the species while positions are left out" do
    name = PokeAccess::Data.species_name(209)
    assert_equal [name, t(:list_entry, :name => name, :n => 1, :tot => 3), t(:list_entry, :name => name, :n => 1, :tot => 3)],
                 vb_levels { PokeAccess::ReaJade.cry_text(1, 1) },
                 "brief, medium and full"
  end

  test "calls a species the data cannot name by its place" do
    unnamed = Object.new
    def unnamed.species_name(_id); ""; end
    Harness.with_provider(unnamed, 30) do
      assert_equal t(:list_entry, :name => "Pokémon 2", :n => 2, :tot => 3), PokeAccess::ReaJade.cry_text(2, 1)
    end
  end

  test "reads the cry helper's cursor each time its input moves it" do
    $game_variables[91] = 1
    helper = Pokemonysusgritos.new
    helper.input
    helper.input
    helper.instance_variable_set(:@seleccion, 3)
    helper.input
    helper.instance_variable_set(:@seleccion, 0)
    helper.input
    assert_equal [[t(:list_entry, :name => PokeAccess::Data.species_name(209), :n => 1, :tot => 3), true],
                  [t(:list_entry, :name => PokeAccess::Data.species_name(742), :n => 3, :tot => 3), true]],
                 SpeakCapture.log,
                 "once per move, and nothing off the three sprites"
  end

  test "tells the whole dance once the fourth dancer's route is set, led by the key that opens the sheet" do
    on_map(113) do
      set_route(0, route(4))
      set_route(-1, route(8))
      [2, 3, 4].each { |ev| set_route(ev, route(*ROUTES[ev])) }
      assert_nothing_spoken "the supervisor's turn, the player's and three of the four dancers"
      set_route(5, route(*ROUTES[5]))
    end
    assert_equal [[hinted_dance, true]], SpeakCapture.log
  end

  test "tells the dance without the key while key hints are left out" do
    told = vb_levels do
      SpeakCapture.clear
      on_map(113) { perform }
      SpeakCapture.log.dup
    end
    assert_equal [[[dance_line, true]], [[hinted_dance, true]], [[hinted_dance, true]]], told, "brief, medium and full"
  end

  test "takes no route but a dancer's for a step of the dance" do
    on_map(113) do
      perform
      SpeakCapture.clear
      set_route(0, route(4))
      set_route(10, route(1))
    end
    assert_nothing_spoken
  end

  test "tells a second performance again, once its four routes are set again" do
    on_map(113) do
      perform
      SpeakCapture.clear
      [2, 3, 4].each { |ev| set_route(ev, route(*ROUTES[ev])) }
      assert_nothing_spoken "the first dancer starts the dance anew"
      set_route(5, route(*ROUTES[5]))
    end
    assert_equal [[hinted_dance, true]], SpeakCapture.log, "the dance once more"
  end

  test "takes routes set on another map for no dance" do
    on_map(114) { perform }
    assert_nothing_spoken
  end

  test "passes a Set Move Route that carries no parameters on to the game untouched" do
    on_map(113) do
      assert_equal true, Interpreter.allocate.command_209, "the interpreter goes on"
    end
    assert_nothing_spoken
  end

  test "tells nothing of a dancer's route it cannot read, and the game's command still runs" do
    on_map(113) do
      [2, 3, 4].each { |ev| set_route(ev, route(*ROUTES[ev])) }
      assert_equal true, set_route(5, TestMoveRoute.new(Object.new)), "the interpreter goes on"
    end
    assert_nothing_spoken
  end

  test "lets the info key read the dance only while the supervisor's page runs" do
    on_map(113) do
      perform
      PokeAccess::World::Mechanics.declare(113, DANCE)
      [[[], nil], [["A"], dance_line], [["A", "B"], nil]].each do |on, line|
        with_self_switches(supervisor(on)) do
          assert_equal !line.nil?, PokeAccess::Puzzles.active?, "self switches #{on.inspect}: the info key is the dance's"
          line ? assert_equal(line, PokeAccess::Puzzles.info_line) : assert_nil(PokeAccess::Puzzles.info_line)
        end
      end
    end
  end

  test "leaves the info key its own while no dance has been told, as in a game loaded mid-question" do
    on_map(113) do
      PokeAccess::World::Mechanics.declare(113, DANCE)
      untold do
        with_self_switches(supervisor(["A"])) do
          assert_equal [false, nil], [PokeAccess::Puzzles.active?, PokeAccess::Puzzles.info_line]
        end
      end
    end
  end

  test "holds the dance live only on the theatre's map" do
    on_map(113) { perform }
    with_self_switches(supervisor(["A"])) do
      assert_equal [true, false], [113, 114].map { |id| on_map(id) { PokeAccess::ReaJade.dance_live? } }
    end
  end

  test "holds no dance live while the game keeps no self switches" do
    on_map(113) do
      perform
      assert_equal false, with_self_switches(nil) { PokeAccess::ReaJade.dance_live? }
    end
  end

  test "chimes each note's arrow once, with the guide's flat chime toward it, CUE_LEAD seconds before it is in reach" do
    notes = [note("up", 324), note("", 344), note("down", 364)]
    log = idol_chimes do
      poll_idol(notes) do
        PokeAccess::ReaJade.idol_poll
        shift(notes, -10)
        PokeAccess::ReaJade.idol_poll
        shift(notes, -40)
        PokeAccess::ReaJade.idol_poll
        PokeAccess::ReaJade.idol_poll
      end
    end
    assert_equal [chime(8), chime(2)], log, "nothing 100 px out, the lead 64 px at 8 px a frame; a rest is silent"
    assert_nothing_spoken
  end

  test "counts a note due from its reach plus the lead before the selector until it leaves its reach" do
    { [318, 30] => [], [317, 30] => [chime(8)], [194, 30] => [], [195, 30] => [chime(8)], [298, 10] => [],
      [297, 10] => [chime(8)], [214, 10] => [], [215, 10] => [chime(8)], [318, nil] => [],
      [317, nil] => [chime(8)] }.each do |(x, range), chimed|
      n = note("up", x)
      n.range = range
      log = idol_chimes { poll_idol([n]) { PokeAccess::ReaJade.idol_poll } }
      assert_equal chimed, log, "a note at x #{x} with range #{range.inspect}, the selector at 224"
    end
  end

  test "measures a note that keeps no range by the 30 px a press counts in, and one with no step by its reach alone" do
    bare = Struct.new(:note, :x, :hit)
    log = idol_chimes { poll_idol([bare.new("left", 254), bare.new("right", 253)]) { PokeAccess::ReaJade.idol_poll } }
    assert_equal [chime(6)], log
  end

  test "passes over a note already hit, one that keeps no hit flag, and one no arrow names" do
    hit = note("up", 230)
    hit.hit = true
    unflagged = Struct.new(:note, :x, :range).new("down", 231, 30)
    log = idol_chimes do
      poll_idol([hit, unflagged, note("spin", 232), note("left", 234)]) { PokeAccess::ReaJade.idol_poll }
    end
    assert_equal [chime(4)], log
  end

  test "says the arrow instead, cutting in, while the minigames' sounds are off" do
    was = PokeAccess::Config.sound_minigame
    PokeAccess::Config.sound_minigame = false
    log = idol_chimes { poll_idol([note("left", 300)]) { PokeAccess::ReaJade.idol_poll } }
    assert_equal [[], [[t(:dir_left), true]]], [log, SpeakCapture.log]
  ensure
    PokeAccess::Config.sound_minigame = was
  end

  test "the minigames' volume help says in every language that it also sets the rhythm game's arrows" do
    silent = (PokeAccess::I18n.language_choices - [:auto]).reject do |lang|
      PokeAccess::Config.language = lang
      t(:help_minigame_vol).include?("Realidea")
    end
    assert_equal [], silent
  end

  test "sounds nothing without a held game, a selector, its picture or a list of notes" do
    log = idol_chimes do
      PokeAccess::ReaJade.idol_poll
      poll_idol([note("up", 224)], {}) { PokeAccess::ReaJade.idol_poll }
      poll_idol([note("up", 224)], { "selector" => Idol::Selector.new(nil) }) { PokeAccess::ReaJade.idol_poll }
      poll_idol(nil) { PokeAccess::ReaJade.idol_poll }
    end
    assert_equal [], log
    assert_nothing_spoken
  end

  test "reads the rhythm game's title, then chimes the notes' arrows while its loop runs, and nothing once it is over" do
    idol = Idol.new
    idol.song = ["up", "", "down"]
    log = idol_chimes do
      idol.pbStartScene
      idol.pbUpdate
    end
    assert_equal [[["¡Dale caña!", false]], [chime(8), chime(2)]], [SpeakCapture.log, log],
                 "the title queued, then the arrows in the song's order"
    SpeakCapture.clear
    idol.instance_variable_get(:@notes).push(note("left", 224))
    assert_equal [], idol_chimes { Input.update }, "a note in reach once the game is over"
  end

  private

  # The text of key in the running language.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The dance the four routes make, as it is told.
  def dance_line
    dancers = [2, 3, 4, 5].each_with_index.map do |ev, i|
      t(:rea_ori_dancer, :n => i + 1, :steps => STEPS[ev].map { |k| t(k) }.join(", "))
    end
    t(:rea_ori_dance, :list => dancers.join("; "))
  end

  # The dance as it is told while key hints are said: led by the key that opens the sheet.
  def hinted_dance
    PokeAccess.sentences([PokeAccess::KeyHints.localize(t(:rea_ori_sheet_key)), dance_line])
  end

  # A Set Move Route's route of these move codes, closed by the end of the list.
  def route(*codes)
    TestMoveRoute.new((codes + [0]).map { |c| TestMoveCmd.new(c) })
  end

  # A Set Move Route on character, run as the interpreter runs it.
  def set_route(character, rte)
    interp = Interpreter.allocate
    interp.instance_variable_set(:@parameters, [character, rte])
    interp.command_209
  end

  # The supervisor's four routes, one per dancer from left to right.
  def perform
    [2, 3, 4, 5].each { |ev| set_route(ev, route(*ROUTES[ev])) }
  end

  # Runs the block on map id, the test map put back afterwards.
  def on_map(id)
    was = $game_map.map_id
    $game_map.map_id = id
    yield
  ensure
    $game_map.map_id = was
  end

  # Runs the block with these self switches, the game's put back afterwards.
  def with_self_switches(switches)
    was = $game_self_switches
    $game_self_switches = switches
    yield
  ensure
    $game_self_switches = was
  end

  # Runs the block with no dance told yet, as a game loaded mid-question has it; the dance told before put back.
  def untold
    was = PokeAccess::ReaJade.dance
    PokeAccess::ReaJade.instance_variable_set(:@dance, nil)
    yield
  ensure
    PokeAccess::ReaJade.instance_variable_set(:@dance, was)
  end

  # The theatre's self switches with these letters of the supervisor's (event 10) on.
  def supervisor(letters)
    switches = {}
    letters.each { |l| switches[[113, 10, l]] = true }
    switches
  end

  # Opens the choreography sheet on these painted columns, through its constructor.
  def open_sheet(columns)
    sheet = Baileoricorios.allocate
    sheet.instance_variable_set(:@columns, columns)
    sheet.send(:initialize)
  end

  # A note of the song at x.
  def note(name, x)
    Idol::SongNote.new(name, x)
  end

  # The rhythm game's selector, 64 px wide: centred, it stands at x 224.
  def selector
    Idol::Selector.new(Idol::SelectorBitmap.new(64))
  end

  # The flat sounds the block plays, as [file, volume, pitch].
  def idol_chimes
    out = nil
    with_cue_log { |log| yield; out = log.map { |e| [cue_name(e), e[1], e[2]] } }
    out
  end

  # The guide's flat chime toward d at the minigames' volume, as idol_chimes logs it.
  def chime(d)
    file, pitch = PokeAccess::Sound::Catalog::GUIDE_FLAT[d]
    [file, PokeAccess::Sound::Mixer.volume(:minigame), (pitch * PokeAccess::Sound::Mixer.flat_factor(:guide)).round]
  end

  # Moves every note by dx.
  def shift(notes, dx)
    notes.each { |n| n.x += dx }
  end

  # Runs the block with a rhythm game carrying these notes and sprites (the selector by default) held for the per-frame
  # reader, released afterwards.
  def poll_idol(notes, sprites = { "selector" => selector })
    scene = Object.new
    scene.instance_variable_set(:@notes, notes)
    scene.instance_variable_set(:@sprites, sprites)
    PokeAccess::ReaJade.hold_idol(scene)
    yield
  ensure
    PokeAccess::ReaJade.release_idol
  end
end
