# Soulstones 2's puzzles (games/soulstones2/puzzles/) on the shipped profile over events shaped like the game's: the Academy's
# books and acolytes, the Facility Lab's enclosures, the Forgotten Tombs, Casper's rooms, the Indus statues, the crystals of
# Rhea and the wards of Route 23C, the Power Plant's single-step tiles, the turnstiles and Mt. Oberon's boulders. Without the
# puzzle assist what is heard is what the screen shows; the answers come with it. Gamedata pass.
class Soulstones2PuzzlesGdTest < PokeAccessTest
  MAPS = [24, 151, 173, 187, 192, 276, 337, 350, 362, 395, 442, 481, 484]
  SWITCHES = [65, 75, 92, 93, 101, 270]
  VARS = [31, 32, 33, 37, 86, 113, 114, 142, 143, 144, 145, 146, 182, 218, 264, 405]
  RESET = "Hay baldosas pisadas fuera del orden de la pista: para empezar de cero, sal de la planta y vuelve a entrar."

  class FakeBag
    def initialize(items); @items = items; end

    def quantity(item); @items.include?(item) ? 1 : 0; end
  end

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $bag
    @x = $game_player.x
    @y = $game_player.y
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    VARS.each { |i| $game_variables[i] = 0 }
    $game_self_switches = @selfs
    $bag = @bag
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the Academy calls every book a shelf, and the assist lists the key books unread and says what the floor still wants" do
    on_map(151)
    $game_variables[31] = 3
    event(28, 15, 31, :name => "Intelligence Gathering Book 1")
    event(11, 19, 26, :name => "Intelligence Gathering Book 2")
    shelf = event(12, 21, 26, :name => "Unimportant Book")
    assert_equal [], listed
    assert_equal "Estantería", PokeAccess::Locator.target_name(shelf)
    assert_includes info_key, "Libros importantes leídos en esta planta: 0 de 2"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[15, 31, "Estantería con un libro importante"], [19, 26, "Estantería con un libro importante"]], listed
    $game_self_switches[[151, 28, "A"]] = true
    assert_equal [[19, 26, "Estantería con un libro importante"]], listed
    assert_equal "Por hacer en esta planta: libros importantes, 1; antiguos miembros del Gremio, 0. Salen en la lista de puzles.", hint_text
    $game_self_switches[[151, 11, "A"]] = true
    assert_equal "Esta planta está hecha: Artie deja subir a la siguiente.", hint_text
    $game_variables[31] = 5
    refute_includes info_key.to_s, "Libros importantes"
  end

  test "the Lab names each enclosure by the Pokémon it shows, says the new one as it changes, and the assist counts the presses" do
    on_map(362)
    $game_switches[92] = true
    event(17, 9, 49, :sprite => "ARON")
    event(19, 13, 49, :sprite => "AZURILL")
    aron = PokeAccess::SS2FacilityLab.species(:ARON)
    assert_includes listed, [9, 49, "Recinto 1: #{aron}"]
    baltoy = PokeAccess::SS2FacilityLab.species(:BALTOY)
    assert_includes frame { $game_variables[142] = 1 }.join(" "), "Recinto 1: #{baltoy}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes hint_text, "recinto 1, pulsaciones que faltan: 3"
    assert_includes hint_text, "recinto 2, pulsaciones que faltan: 2"
    [[142, 4], [143, 2], [144, 3], [145, 4], [146, 1]].each { |v, n| $game_variables[v] = n }
    assert_equal "Los cinco recintos tienen un Raticate: queda pisar el panel delante de Caitlin y confirmar.", hint_text
    $game_switches[93] = true
    assert_equal [], listed
  end

  test "the Tombs list the tablets and inscriptions unread, say how many have been read and the assist says what is left" do
    on_map(192)
    $game_variables[37] = 17
    event(15, 47, 59)
    event(17, 28, 63)
    event(14, 44, 63)
    assert_equal [[28, 63, "Inscripción de una tumba"], [44, 63, "Inscripción de una tumba"], [47, 59, "Lápida de pared"]], listed
    assert_includes frame { $game_variables[114] = 1 }.join(" "), "Lápidas de pared leídas: 1"
    $game_self_switches[[192, 15, "A"]] = true
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[28, 63, "Inscripción de una tumba"]], listed
    assert_includes hint_text, "Lápidas de pared por leer: 5. Inscripciones por revisar: 7."
    $game_variables[37] = 19
    refute_includes info_key.to_s, "Lápidas de pared leídas"
    assert_equal [], listed
  end

  test "Casper's room is described as its timer starts, and his anchor is listed until his fight is done" do
    on_map(481)
    event(19, 17, 9)
    assert_equal [], frame
    lines = frame { $game_self_switches[[481, 19, "A"]] = true }
    assert lines.any? { |l| l.start_with?("Primera sala. En el foso, 5 rocas") }, lines.inspect
    $game_self_switches[[481, 19, "B"]] = true
    assert_equal [], frame { $game_self_switches[[481, 19, "A"]] = true }
    event(30, 19, 67)
    $game_variables[182] = 17
    assert_equal [[19, 67, "Ancla de Casper, con una tablilla delante"]], listed
    $game_variables[182] = 18
    assert_equal [], listed
  end

  test "the Indus statues are named by their place, and the assist adds the berry each takes and whether the bag holds it" do
    on_map(24)
    $game_variables[86] = 13
    $bag = FakeBag.new([:CHOPLEBERRY])
    event(7, 22, 23, :sprite => "GLISCOR")
    event(8, 24, 23, :sprite => "GLISCOR")
    assert_equal [[22, 23, "Estatua de Gliscor de la izquierda"], [24, 23, "Estatua de Gliscor del centro"]], listed
    PokeAccess::Config.puzzle_assist = true
    names = listed.map { |_x, _y, n| n }
    assert_match(/\AEstatua de Gliscor de la izquierda\. Pide una .+, y no hay ninguna en la mochila\z/, names[0])
    assert_match(/\AEstatua de Gliscor del centro\. Pide una .+, y hay una en la mochila\z/, names[1])
    $game_switches[233] = true
    assert_equal 1, listed.length
    $game_switches[233] = false
  end

  test "Rhea's crystals hide their button without the assist, Route 23C counts its four wards and Norma lists its faulty lights" do
    on_map(337)
    event(54, 18, 11)
    assert_equal [[18, 11, "Cristales blancos"]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[18, 11, "Botón escondido junto a unos cristales blancos"]], listed
    on_map(276)
    event(48, 15, 17)
    assert_equal [], listed
    $game_variables[218] = 14
    assert_equal [[15, 17, "Protección dañada"]], listed
    assert_includes info_key, "Protecciones restauradas: 1 de 4"
    on_map(350)
    event(39, 29, 36)
    assert_equal [], listed
    $game_variables[264] = 2
    assert_equal [[29, 36, "Farola averiada"]], listed
  end

  test "the Power Plant counts the tiles stepped on, and the assist leads tile by tile, asks to start over and says when it holds" do
    on_map(484)
    [[1, 65, 36], [2, 64, 36], [3, 64, 35]].each { |id, x, y| event(id, x, y, :name => "Stepped on", :trigger => 1) }
    event(14, 59, 37, :name => "Ladder Out")
    at(66, 36)
    assert info_key.start_with?("Baldosas pisadas: 0 de 13. Suelo de baldosas que aguantan un solo paso"), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "Se empieza por la baldosa de la entrada: 1 izquierda.", hint_text
    step(1, 65, 36)
    assert_equal "Siguiente baldosa: 1 izquierda. Faltan: 12.", hint_text
    assert_equal ["Siguiente baldosa: 1 arriba. Faltan: 11."], frame { step(2, 64, 36) }
    at(66, 36)
    assert_equal RESET, hint_text
    at(64, 36)
    $game_self_switches[[484, 2, "A"]] = false
    $game_variables[405] = 0
    assert_equal RESET, hint_text
    $game_self_switches[[484, 1, "A"]] = false
    $game_self_switches[[484, 2, "A"]] = true
    $game_variables[405] = 1
    assert_equal RESET, hint_text
    lines = frame { $game_variables[405] = 13 }
    assert_equal ["Todas las baldosas están pisadas y el suelo aguanta. La escalera de salida está 5 izquierda, 1 abajo."], lines
    refute_includes info_key.to_s, "Baldosas pisadas"
  end

  test "the free camera says of each Power Plant tile whether it is stepped on, as its tile shows, on the plant alone" do
    on_map(484)
    fresh = event(1, 65, 36, :name => "Stepped on", :trigger => 1)
    marked = event(2, 64, 36, :name => "Stepped on", :trigger => 1)
    fresh.tile_id = 4155
    marked.tile_id = 4136
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y) }
    assert_equal [["Baldosa sin pisar"], ["Baldosa pisada"], []], [lines[65, 36], lines[64, 36], lines[63, 36]]
    on_map(350)
    $game_map.events[2] = marked
    assert_equal [], lines[64, 36], "another map"
  end

  test "a turnstile's arm says where it leads now, which turns with the ring's switch" do
    on_map(395)
    event(3, 33, 46, :name => "Escalator", :trigger => 1)
    centre = event(6, 34, 46, :name => "Escalator")
    assert_equal [[33, 46, "Puerta giratoria: sale por el sur"]], listed
    $game_switches[270] = true
    assert_equal [[33, 46, "Puerta giratoria: sale por el norte"]], listed
    refute_includes PokeAccess::Locator.target_name(centre).to_s, "Puerta giratoria"
  end

  test "a sand pit is named and told on arriving, and an Oberon hole stays named after its boulder falls" do
    on_map(187)
    event(20, 47, 63, :name => "Sand Trap", :trigger => 1)
    assert_equal [[47, 63, "Arena movediza"]], listed
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    assert_includes SpeakCapture.lines, "En esta zona hay arena movediza: pisarla arrastra a una cueva de abajo."
    on_map(173)
    event(15, 39, 14, :name => "Hole", :trigger => 1)
    event(16, 35, 16, :name => "StrengthBoulder", :sprite => "boulder")
    assert_includes frame { $game_switches[65] = true }.join(" "), "La roca ha caído por el agujero"
    assert_includes listed, [39, 14, "Agujero en el suelo"]
  end

  test "the assist gives the right option of a statuette's riddle and of Casper's count, read from what each branch does" do
    on_map(442)
    statuette = [TestCmd.new(101, ["What Pokemon am I? \\ch[192,0,Butterfree, Lilligant, Clefairy, T.Seadra]"], 0),
                 TestCmd.new(111, [1, 192, 0, 2, 0], 0), TestCmd.new(122, [182, 182, 1, 0, 1], 1), TestCmd.new(412, [], 0),
                 TestCmd.new(411, [], 0), TestCmd.new(355, ["WildBattle.dx_start([:SIMIPOUR, 78])"], 1),
                 TestCmd.new(122, [182, 182, 1, 0, 1], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
    place(46, 12, 44, "Simipour Statuette Riddle", statuette)
    assert_equal "Clefairy", right_option(46, statuette, 0)
    on_map(481)
    room = [TestCmd.new(111, [1, 1, 0, 0, 0], 0), TestCmd.new(101, ["How many rocks? \\ch[192, 0, 3, 5, 13, 19]"], 1),
            TestCmd.new(111, [1, 192, 0, 1, 0], 1), TestCmd.new(119, ["Correct"], 2), TestCmd.new(412, [], 1),
            TestCmd.new(411, [], 1), TestCmd.new(119, ["Incorrect"], 2), TestCmd.new(412, [], 1), TestCmd.new(412, [], 0),
            TestCmd.new(118, ["Correct"], 0), TestCmd.new(122, [182, 182, 1, 0, 1], 0), TestCmd.new(115, [], 0),
            TestCmd.new(118, ["Incorrect"], 0), TestCmd.new(123, ["A", 1], 0), TestCmd.new(0, [], 0)]
    place(19, 17, 9, "Room 1 Timer", room)
    assert_equal "5", right_option(19, room, 1)
    PokeAccess::Config.puzzle_assist = false
  end

  private

  def mechanics; PokeAccess::World::Mechanics; end

  def at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def step(id, x, y)
    at(x, y)
    $game_self_switches[[484, id, "A"]] = true
    $game_variables[405] += 1
  end

  def place(id, x, y, name, list)
    page = TestPage.new(:trigger => 0, :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    World.next_frame
  end

  def right_option(id, list, i)
    PokeAccess::Config.puzzle_assist = true
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, i)
  end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("soulstones2")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |i| $game_switches[i] = false }
    VARS.each { |i| $game_variables[i] = 0 }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def event(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def hint_text; PokeAccess::Puzzles.label_of(mechanics.instances.first.spec[:hint]); end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    PokeAccess::Puzzles.tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
