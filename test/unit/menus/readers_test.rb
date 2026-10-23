# Three menu readers: the Purify Chamber's set list and ring, the encounter list's summary of a type, and the generic
# read of a window's focused entry from its own lists.

# The Purify Chamber's set list, as the game names it: the chamber it lists and the set being moved (-1 for none).
class Window_PurifyChamberSets < Window_DrawableCommand
  attr_accessor :switching
  def initialize(chamber); super([]); @chamber = chamber; @switching = -1; end
end

class ReadersTest < PokeAccessTest
  Purify = PokeAccess::PurifyChamber
  Encounters = PokeAccess::EncounterList
  Menus = PokeAccess::Menus

  # A shadow Pokemon as gen-6 keeps its heart (heartgauge), as v19 and v20 keep it (heart_gauge), and as v21 does,
  # with a gauge size of its own.
  Gen6Shadow = Struct.new(:name, :level, :heartgauge)
  ModernShadow = Struct.new(:name, :level, :heart_gauge)
  V21Shadow = Struct.new(:name, :level, :heart_gauge, :max_gauge_size)

  # A list entry that has a name, a text, or both.
  Named = Struct.new(:name)
  Texted = Struct.new(:text)
  NamedTexted = Struct.new(:name, :text)

  # The Purify Chamber's ring view (PurifyChamberSetView): its cursor (0 the centre) over one set.
  RingView = Struct.new(:cursor, :set)

  # A stand-in of the game's PurifyChamberSet: its regular members and its tempo.
  class ChamberSet
    attr_reader :list, :tempo
    def initialize(list, tempo); @list = list; @tempo = tempo; end
    def length; @list.length; end
  end

  # A set that keeps a tempo and no count of its members.
  class TempoOnlySet
    attr_reader :tempo
    def initialize(tempo); @tempo = tempo; end
  end

  # A stand-in of the game's PurifyChamber: its sets, and per set the shadow Pokemon at its centre, whether it can be
  # purified and its flow.
  class Chamber
    def self.maximumTempo; 30; end
    def initialize(sets, shadows, purifiable = [], flows = [])
      @sets = sets
      @shadows = shadows
      @purifiable = purifiable
      @flows = flows
    end
    def setCount(i); @sets[i].length; end
    def setList(i); @sets[i].list; end
    def [](i); @sets[i]; end
    def getShadow(i); @shadows[i]; end
    def chamberFlow(i); @flows[i]; end
    def isPurifiable?(i); @purifiable[i] ? true : false; end
  end

  # A chamber that cannot count a set's members.
  class UncountedChamber < Chamber
    undef_method :setCount
  end

  # A chamber that keeps no maximum tempo.
  class UntimedChamber < Chamber
    class << self
      undef_method :maximumTempo
    end
  end

  # A chamber that cannot list a set's members.
  class UnlistedChamber < Chamber
    undef_method :setList
  end

  # A chamber that cannot tell whether a set can be purified.
  class UndecidedChamber < Chamber
    undef_method :isPurifiable?
  end

  test "a chamber set says its number, shadow Pokemon and that it is purifiable, how many from medium, tempo at full" do
    ok = t(:pchm_purifiable)
    assert_equal [line(set_no(1), shadow("Larvitar"), ok),
                  line(set_no(1), count(3), shadow("Larvitar"), ok),
                  line(set_no(1), count(3), shadow("Larvitar"), tempo(20), ok)],
                 vb_levels { Purify.set_text(chamber, 0) }
  end

  test "the info key and Ctrl+T keep the whole chamber set at any verbosity" do
    PokeAccess::Config.verbosity = :brief
    Purify.set_text(chamber, 0)
    whole = line(set_no(1), count(3), shadow("Larvitar"), tempo(20), t(:pchm_purifiable))
    assert_equal whole, PokeAccess::Info.info_text, "the info key"
    assert_equal whole, PokeAccess::Info.row_text, "Ctrl+T"
  end

  test "an empty chamber set says it is empty, at any verbosity" do
    empty = line(set_no(2), t(:pchm_empty))
    assert_equal [empty, empty, empty], vb_levels { Purify.set_text(chamber, 1) }
  end

  test "a part the chamber does not answer is left out of the set" do
    ok = t(:pchm_purifiable)
    named = shadow("Larvitar")
    no_tempo = Chamber.new([ChamberSet.new(members("Pidgey", "Rattata"), nil)], [larvitar], [true])
    rows = {
      "no shadow Pokemon" => [chamber_of(nil), line(set_no(1), count(2), tempo(5), ok)],
      "a nameless shadow Pokemon" => [chamber_of(Gen6Shadow.new("", 20, nil)), line(set_no(1), count(2), tempo(5), ok)],
      "a set it cannot purify" => [chamber_of(larvitar, Chamber, false), line(set_no(1), count(2), named, tempo(5))],
      "no answer on purifying" => [chamber_of(larvitar, UndecidedChamber), line(set_no(1), count(2), named, tempo(5))],
      "no maximum tempo" => [chamber_of(larvitar, UntimedChamber), line(set_no(1), count(2), named, ok)],
      "a set without its tempo" => [no_tempo, line(set_no(1), count(2), named, ok)]
    }
    rows.each { |what, (ch, want)| assert_equal want, Purify.set_text(ch, 0), what }
  end

  test "a chamber that cannot count a set counts the set's members, and one that has neither says no count" do
    ok = t(:pchm_purifiable)
    counted = UncountedChamber.new([ChamberSet.new(members("Pidgey", "Rattata", "Zubat"), 5)], [larvitar], [true])
    uncounted = UncountedChamber.new([TempoOnlySet.new(5)], [larvitar], [true])
    assert_equal line(set_no(1), count(3), shadow("Larvitar"), tempo(5), ok), Purify.set_text(counted, 0),
                 "the set's own length"
    assert_equal line(set_no(1), shadow("Larvitar"), tempo(5), ok), Purify.set_text(uncounted, 0), "no count at all"
  end

  test "the chamber set being moved says so" do
    moving = t(:pchm_switching)
    assert_equal line(set_no(1), count(3), shadow("Larvitar"), tempo(20), t(:pchm_purifiable), moving),
                 Purify.set_text(chamber, 0, true),
                 "a set with Pokemon"
    assert_equal line(set_no(2), t(:pchm_empty), moving), Purify.set_text(chamber, 1, true), "an empty set"
  end

  test "no chamber gives no set line" do
    assert_nil Purify.set_text(nil, 0)
  end

  test "the chamber's set list says the focused set, marking it while it is the one being moved" do
    win = Window_PurifyChamberSets.new(chamber)
    win.index = 1
    empty = line(set_no(2), t(:pchm_empty))
    { -1 => empty, 1 => line(empty, t(:pchm_switching)), 0 => empty }.each do |moving, want|
      win.switching = moving
      assert_equal want, Menus.focused_text(win), "set #{moving} being moved"
    end
  end

  test "a shadow Pokemon's heart is said from medium, out of the engine's gauge size" do
    shapes = [[:PokeBattle_Pokemon, :HEARTGAUGESIZE, Gen6Shadow], [:Pokemon, :HEART_GAUGE_SIZE, ModernShadow]]
    shapes.each do |owner, size, kind|
      with_constant(owner, size, 3840) do
        ch = chamber_of(kind.new("Larvitar", 20, 1200), Chamber, false)
        heart = t(:pchm_heart, :n => 1200, :max => 3840)
        assert_equal [line(set_no(1), shadow("Larvitar")),
                      line(set_no(1), count(2), shadow("Larvitar"), heart),
                      line(set_no(1), count(2), shadow("Larvitar"), tempo(5), heart)],
                     vb_levels { Purify.set_text(ch, 0) },
                     "#{owner}::#{size}"
      end
    end
  end

  test "a v21 shadow Pokemon's heart is said out of its own gauge size" do
    ch = chamber_of(V21Shadow.new("Larvitar", 20, 1200, 4000), Chamber, false)
    PokeAccess::Config.verbosity = :medium
    assert_equal line(set_no(1), count(2), shadow("Larvitar"), t(:pchm_heart, :n => 1200, :max => 4000)),
                 Purify.set_text(ch, 0)
  end

  test "the ring's centre names its shadow Pokemon and level, its heart from medium, its flow and tempo at full" do
    with_constant(:PokeBattle_Pokemon, :HEARTGAUGESIZE, 3840) do
      ch = Chamber.new([ChamberSet.new(members("Pidgey", "Rattata"), 12)], [Gen6Shadow.new("Larvitar", 20, 1200)],
                       [], [2])
      centre = t(:pc_slot, :name => "Larvitar", :level => 20)
      heart = t(:pchm_heart, :n => 1200, :max => 3840)
      assert_equal [centre, line(centre, heart), line(centre, heart, t(:pchm_flow, :n => 2), tempo(12))],
                   vb_levels { Purify.ring_text(ring(ch, 0)) }
    end
  end

  test "a ring position says where it stands out of the ring's points and who is there, the name alone at brief" do
    ch = chamber_of(larvitar)
    uncounted = chamber_of(larvitar, UncountedChamber)
    {
      "the first member" => [ch, 1, 4, "Pidgey"],
      "the second member" => [ch, 3, 4, "Rattata"],
      "a chamber that cannot count the set, out of a single point" => [uncounted, 1, 1, "Pidgey"]
    }.each do |what, (source, cur, tot, who)|
      whole = t(:pchm_pos, :n => cur, :tot => tot, :name => who)
      assert_equal [who, whole, whole], vb_levels { Purify.ring_text(ring(source, cur)) }, what
    end
  end

  test "a ring position with no member is a gap, the empty word alone at brief" do
    ch = chamber_of(larvitar)
    unlisted = chamber_of(larvitar, UnlistedChamber)
    [[ch, 2, "between two members"], [ch, 4, "after the last"],
     [unlisted, 1, "of a chamber that cannot list its members"]].each do |source, cur, what|
      whole = t(:pchm_pos_empty, :n => cur, :tot => 4)
      assert_equal [t(:pc_empty), whole, whole], vb_levels { Purify.ring_text(ring(source, cur)) }, what
    end
  end

  test "a part the chamber does not answer is left out of the ring's centre" do
    centre = t(:pc_slot, :name => "Larvitar", :level => 20)
    flow = t(:pchm_flow, :n => 1)
    rows = {
      "no heart gauge" => [chamber_of(larvitar), line(centre, flow, tempo(5))],
      "no flow" => [Chamber.new([ChamberSet.new(members("Pidgey"), 5)], [larvitar]), line(centre, tempo(5))],
      "no maximum tempo" => [chamber_of(larvitar, UntimedChamber), line(centre, flow)]
    }
    rows.each { |what, (ch, want)| assert_equal want, Purify.ring_text(ring(ch, 0)), what }
  end

  test "an empty set's ring has a single point, a gap" do
    whole = t(:pchm_pos_empty, :n => 1, :tot => 1)
    assert_equal whole, Purify.ring_text(ring(chamber, 1, 1))
  end

  test "the info key keeps the whole ring position at any verbosity" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "Pidgey", Purify.ring_text(ring(chamber_of(larvitar), 1)), "said at brief"
    assert_equal t(:pchm_pos, :n => 1, :tot => 4, :name => "Pidgey"), PokeAccess::Info.info_text, "the info key"
  end

  test "the ring says nothing with no cursor, one before the centre, no chamber, no set, or no shadow at its centre" do
    ch = chamber_of(larvitar)
    {
      "no cursor" => ring(ch, nil),
      "a cursor before the centre" => ring(ch, -1),
      "no chamber" => ring(nil, 1),
      "no set" => ring(ch, 1, nil),
      "a centre with no shadow Pokemon" => ring(chamber_of(nil), 0)
    }.each { |what, view| assert_nil Purify.ring_text(view), what }
  end

  test "an encounter type says its header and species, their states from medium and the count at full" do
    unknown = t(:dex_unknown)
    assert_equal ["Hierba alta: Pidgey, Rattata, #{unknown}",
                  "Hierba alta: Pidgey #{t(:dex_caught)}, Rattata #{t(:dex_seen)}, #{unknown}",
                  "#{head('Hierba alta', 3)}: Pidgey #{t(:dex_caught)}, Rattata #{t(:dex_seen)}, #{unknown}"],
                 vb_levels { Encounters.summary("Hierba alta", grass) }
  end

  test "the info key's encounter summary is whole at any verbosity" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "#{head('Hierba alta', 3)}: Pidgey #{t(:dex_caught)}, Rattata #{t(:dex_seen)}, #{t(:dex_unknown)}",
                 Encounters.summary("Hierba alta", grass, true)
  end

  test "an empty encounter type says its header with the count at any verbosity" do
    assert_equal [head("Agua", 0)] * 3, vb_levels { Encounters.summary("Agua", []) }
  end

  test "an encounter list that marks no state says the names alone" do
    unmarked = [["Pidgey", nil], ["Rattata", nil]]
    assert_equal "#{head('Hierba alta', 2)}: Pidgey, Rattata", Encounters.summary("Hierba alta", unmarked)
  end

  test "no encounter list gives no summary" do
    assert_nil Encounters.summary("Cueva", nil)
  end

  test "an encounter summary stops at fifteen species and says how many more there are" do
    shown = (1..15).map { |k| "Sp#{k} #{t(:dex_seen)}" }.join(", ")
    assert_equal "#{head('Cueva', 17)}: #{shown}, #{t(:enc_more, :n => 2)}",
                 Encounters.summary("Cueva", seen_species(17))
  end

  test "the info key's encounter summary says every species, past fifteen too" do
    shown = (1..17).map { |k| "Sp#{k} #{t(:dex_seen)}" }.join(", ")
    assert_equal "#{head('Cueva', 17)}: #{shown}", Encounters.summary("Cueva", seen_species(17), true)
  end

  test "an encounter summary of fifteen species says them all, with none more" do
    shown = (1..15).map { |k| "Sp#{k} #{t(:dex_seen)}" }.join(", ")
    assert_equal "#{head('Cueva', 15)}: #{shown}", Encounters.summary("Cueva", seen_species(15))
  end

  test "a list entry is read as its string, its symbol, its name, or else its text" do
    {
      "Bolsa" => "Bolsa",
      :Pokedex => "Pokedex",
      Named.new("Curar") => "Curar",
      Texted.new("Hola") => "Hola",
      NamedTexted.new("", "Adios") => "Adios"
    }.each { |entry, want| assert_equal want, Menus.entry_text(entry), entry.inspect }
  end

  test "a list entry with no text of its own reads nothing" do
    [[5, 3], 7, nil, Named.new(""), Named.new(5)].each { |entry| assert_nil Menus.entry_text(entry), entry.inspect }
  end

  test "a window's focused entry is read from whichever of its lists holds it" do
    [:@commands, :@items, :@list, :@data, :@choices, :@names, :@entries, :@stock].each do |ivar|
      win = window_with(ivar => ["Uno", Named.new("Dos")])
      assert_equal ["Uno", "Dos"], [0, 1].map { |i| Menus.generic_focus(win, i) }, ivar.to_s
    end
  end

  test "a list whose focused entry has no text gives way to the next list" do
    assert_equal "X", Menus.generic_focus(window_with(:@commands => [[1, 2]], :@items => ["X"]), 0), "a pair"
    assert_equal "Y", Menus.generic_focus(window_with(:@commands => [""], :@list => ["Y"]), 0), "a blank entry"
  end

  test "an index outside every list, or a list of pairs, reads nothing" do
    win = window_with(:@commands => ["X"], :@list => [[1, 2], [3, 4]])
    { 1 => "past the end", -1 => "before the start" }.each { |i, what| assert_nil Menus.generic_focus(win, i), what }
    assert_nil Menus.generic_focus(window_with(:@list => [[1, 2], [3, 4]]), 0), "a pair"
  end

  private

  # A chamber of two sets: the first holds Pidgey, Rattata and Zubat around Larvitar, at tempo 20, and can be
  # purified; the second is empty.
  def chamber
    Chamber.new([ChamberSet.new(members("Pidgey", "Rattata", "Zubat"), 20), ChamberSet.new([], 0)],
                [larvitar, nil], [true, false], [2, 0])
  end

  # A one-set chamber of kind holding Pidgey and Rattata at tempo 5 around shadow, purifiable or not.
  def chamber_of(shadow, kind = Chamber, purifiable = true)
    kind.new([ChamberSet.new(members("Pidgey", "Rattata"), 5)], [shadow], [purifiable], [1])
  end

  def larvitar
    Gen6Shadow.new("Larvitar", 20, nil)
  end

  def members(*names)
    names.map { |n| Named.new(n) }
  end

  # The ring view over chamber's set, its cursor at cur.
  def ring(chamber, cur, set = 0)
    view = RingView.new(cur, set)
    view.instance_variable_set(:@chamber, chamber)
    view
  end

  # Runs the block with owner::name set to value, owner made for it when the engine has none, both put back after.
  def with_constant(owner, name, value)
    made = !Object.const_defined?(owner)
    Object.const_set(owner, Class.new) if made
    klass = Object.const_get(owner)
    was = klass.const_defined?(name, false) ? [klass.const_get(name)] : nil
    klass.send(:remove_const, name) if was
    klass.const_set(name, value)
    yield
  ensure
    klass.send(:remove_const, name) if klass && klass.const_defined?(name, false)
    klass.const_set(name, was[0]) if klass && was
    Object.send(:remove_const, owner) if made
  end

  # A window keeping lists in its ivars ({ivar => list}).
  def window_with(lists)
    win = Object.new
    lists.each { |ivar, list| win.instance_variable_set(ivar, list) }
    win
  end

  # The grass type's species: Pidgey caught, Rattata seen, Caterpie never seen.
  def grass
    [["Pidgey", :dex_caught], ["Rattata", :dex_seen], ["Caterpie", :dex_unknown]]
  end

  def seen_species(n)
    (1..n).map { |k| ["Sp#{k}", :dex_seen] }
  end

  def head(type, n)
    t(:enc_type, :type => type, :n => n)
  end

  def set_no(n)
    t(:pchm_set, :n => n)
  end

  def count(n)
    t(:pchm_count, :n => n)
  end

  def shadow(name)
    t(:pchm_shadow, :name => name)
  end

  def tempo(n)
    t(:pchm_tempo, :n => n, :max => 30)
  end

  def line(*parts)
    parts.join(", ")
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
