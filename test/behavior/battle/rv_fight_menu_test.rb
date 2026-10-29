# The fight menu of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/fight_menu_rv.rb), bound with
# core's gen-6 battle hooks over a FightMenuDisplay made here and opened as Rejuvenation's pbFightMenu opens it: the
# Z-Move and Terastallization buttons said as they come up, queued, and as they toggle, cutting in; while the Z-Move
# button is on, the Z-move in its move's place in the move line, as the buttons then paint it, and the move itself
# again once it is off or the menu opens anew; each line with the type its button paints, at the fight line's levels.
Harness.load_common("rv_common")

class RvFightMenuTest < PokeAccessTest
  T = PokeAccess::I18n

  # Rejuvenation's FightMenuDisplay as far as the hooks go: the battler it is set up for, a cursor that moves only onto
  # a move, and its four buttons (0 hidden, 1 shown, 2 pressed).
  Display = Class.new do
    attr_accessor :megaButton, :ultraButton, :teraButton, :zButton
    def initialize; @index = 0; @battler = nil; end
    def battler=(b); @battler = b; end
    def setIndex(v)
      return false unless @battler && @battler.moves[v]
      @index = v
      true
    end
  end

  # The methods of core's fight line rv_common overrides.
  SWAPPED = [:read_fight_move, :fight_type, :fight_line, :fight_row]

  # A battle move as the engine builds it: the symbol in move, and no id.
  Move = Struct.new(:move, :name, :type, :category, :pp, :totalpp)
  HYPER_VOICE = Move.new(:HYPERVOICE, "Hyper Voice", :NORMAL, :special, 10, 15)
  EMBER = Move.new(:EMBER, "Ember", :FIRE, :special, 25, 25)
  BLITZ = Move.new(:BREAKNECKBLITZ, "Breakneck Blitz", :NORMAL, :special, 0, 0)

  # A battler with its moves and the Z-moves they turn into (nil where none); its Z-move check takes a slot when its
  # flag says so, as the engine's does.
  class Fighter
    attr_reader :moves, :zmoves
    def initialize(moves, zmoves); @moves = moves; @zmoves = zmoves; end
    def pbCompatibleZMoveFromMove?(move, moveindex = false)
      !@zmoves[moveindex ? move : @moves.index(move)].nil?
    end
  end

  # Desolation's battler: a Z-crystal that suits every move, and no Z-moves to paint in their place.
  class PlainFighter
    attr_reader :moves
    def initialize(moves); @moves = moves; end
    def pbCompatibleZMoveFromMove?(_move, _moveindex = false); true; end
  end

  test "the Z-Move button coming up is said behind the move the menu opens on, queued" do
    with_menu { |menu| open(menu, fighter, 0, :zButton => [1]) }
    assert_equal [[line(HYPER_VOICE), true], [ready(:bt_m_zmove), false]], SpeakCapture.log
  end

  test "pressing Z-Move says it on, then the Z-move in the move's place with no PP of its own, queued" do
    with_menu do |menu|
      open(menu, fighter, 0, :zButton => [1])
      SpeakCapture.clear
      menu.zButton = 2
    end
    assert_equal [[toggled(:bt_special_on, :bt_m_zmove), true], [z_line(BLITZ), false]], SpeakCapture.log
  end

  test "while Z-Move is on, the cursor says the Z-move where a move has one and the move itself elsewhere" do
    with_menu do |menu|
      open(menu, fighter, 0, :zButton => [1, 2])
      SpeakCapture.clear
      menu.setIndex(1)
      menu.setIndex(0)
    end
    assert_equal [[line(EMBER), true], [z_line(BLITZ), true]], SpeakCapture.log
  end

  test "while Z-Move is on, the info key tells of the Z-move" do
    with_menu { |menu| open(menu, fighter, 0, :zButton => [1, 2]) }
    assert_match(/\ABreakneck Blitz\b/, PokeAccess::Info.info_text.to_s)
  end

  test "the info key tells of the Z-move with no PP, as its button paints none" do
    with_menu { |menu| open(menu, fighter, 0, :zButton => [1, 2]) }
    sheet = PokeAccess::Info.info_text.to_s
    assert_match(/\ABreakneck Blitz\. /, sheet)
    refute_match(/PP/, sheet)
  end

  test "the Z-move's line says its name at brief, its type from medium and its category in full" do
    lines = vb_levels do
      with_menu do |menu|
        open(menu, fighter, 0, :zButton => [1])
        menu.zButton = 2
      end
      SpeakCapture.last
    end
    assert_equal ["Breakneck Blitz", "Breakneck Blitz. #{type(BLITZ)}", z_line(BLITZ)], lines
  end

  test "the move and the Z-move in its place say the type Rejuvenation's buttons paint (pbMoveBattleSceneType)" do
    painted = lambda { |m, _b| [:HYPERVOICE, :BREAKNECKBLITZ].include?(m.move) ? :FAIRY : m.type }
    GameFunctions.with(:pbMoveBattleSceneType => painted) do
      with_menu do |menu|
        open(menu, fighter, 0, :zButton => [1])
        menu.zButton = 2
      end
    end
    fairy = T.t(:mv_type, :t => PBTypes.getName(:FAIRY))
    assert_equal [[["Hyper Voice", fairy, T.t(:cat_special), T.t(:mv_pp, :pp => 10, :tot => 15)].join(". "), true],
                  [ready(:bt_m_zmove), false], [toggled(:bt_special_on, :bt_m_zmove), true],
                  [["Breakneck Blitz", fairy, T.t(:cat_special)].join(". "), false]], SpeakCapture.log
  end

  test "without that function, the line says the type the engine's pbType gives, as Reborn and Desolation paint it" do
    pixilated = Class.new(Move) { def pbType(_attacker); :FAIRY; end }
    voice = pixilated.new(:HYPERVOICE, "Hyper Voice", :NORMAL, :special, 10, 15)
    with_menu { |menu| open(menu, Fighter.new([voice], [nil]), 0) }
    fairy = T.t(:mv_type, :t => PBTypes.getName(:FAIRY))
    assert_equal [[["Hyper Voice", fairy, T.t(:cat_special), T.t(:mv_pp, :pp => 10, :tot => 15)].join(". "), true]],
                 SpeakCapture.log
  end

  test "Rejuvenation's line says the types the field adds after the move's own and its boost last, from medium" do
    added = Class.new(Move) { def getSecondaryType(_attacker, _type, _opts = {}); [:FLYING]; end }
    press = added.new(:FLYINGPRESS, "Flying Press", :FIGHTING, :special, 10, 10)
    lines = vb_levels do
      GameFunctions.with(:pbFieldMoveHighlights => lambda { |_m, _b| :buff }) do
        with_menu { |menu| open(menu, Fighter.new([press], [nil]), 0) }
      end
      SpeakCapture.last
    end
    also = T.t(:reb_move_also_type, :t => PBTypes.getName(:FLYING))
    pp = T.t(:mv_pp, :pp => 10, :tot => 10)
    assert_equal ["Flying Press. #{pp}",
                  ["Flying Press", type(press), also, pp, T.t(:reb_move_boosted)].join(". "),
                  ["Flying Press", type(press), also, T.t(:cat_special), pp, T.t(:reb_move_boosted)].join(". ")], lines
  end

  test "Ctrl+T keeps the whole line at brief, the field's added types and mark among it, the Z-move's too" do
    added = Class.new(Move) { def getSecondaryType(_attacker, _type, _opts = {}); [:FLYING]; end }
    press = added.new(:FLYINGPRESS, "Flying Press", :FIGHTING, :special, 10, 10)
    PokeAccess::Config.verbosity = :brief
    rows = []
    GameFunctions.with(:pbFieldMoveHighlights => lambda { |_m, _b| :nerf }) do
      with_menu do |menu|
        open(menu, Fighter.new([press], [BLITZ]), 0, :zButton => [1])
        rows.push(PokeAccess::Info.row_text)
        menu.zButton = 2
        rows.push(PokeAccess::Info.row_text)
      end
    end
    weak = T.t(:reb_move_weakened)
    assert_equal [["Flying Press", type(press), T.t(:reb_move_also_type, :t => PBTypes.getName(:FLYING)),
                   T.t(:cat_special), T.t(:mv_pp, :pp => 10, :tot => 10), weak].join(". "),
                  [z_line(BLITZ), weak].join(". ")], rows
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "a rolled type is said as one, and added types are left unsaid where the move's own is among them" do
    rolled = Class.new(Move) { def getSecondaryType(_attacker, _type, _opts = {}); [:RAINBOW]; end }
    own = Class.new(Move) { def getSecondaryType(_attacker, _type, _opts = {}); [:FIRE, :WATER]; end }
    lines = [rolled.new(:WATERGUN, "Water Gun", :WATER, :special, 25, 25),
             own.new(:EMBER, "Ember", :FIRE, :special, 25, 25)].map do |m|
      with_menu { |menu| open(menu, Fighter.new([m], [nil]), 0) }
      SpeakCapture.last
    end
    assert_includes lines[0], T.t(:reb_move_random_type)
    refute_includes lines[1], T.t(:reb_move_also_type, :t => PBTypes.getName(:WATER))
  end

  test "Desolation's line takes its one added type and the field's mark from its buttons' pbFieldNotesBattle" do
    added = Class.new(Move) { def getSecondaryType(_attacker); :ICE; end }
    ember = added.new(:EMBER, "Ember", :FIRE, :special, 25, 25)
    buttons = Object.new
    def buttons.pbFieldNotesBattle(_move); 2; end
    with_menu do |menu|
      menu.instance_variable_set(:@buttons, buttons)
      open(menu, PlainFighter.new([ember]), 0)
    end
    assert_equal [[["Ember", type(ember), T.t(:reb_move_also_type, :t => PBTypes.getName(:ICE)), T.t(:cat_special),
                    T.t(:mv_pp, :pp => 25, :tot => 25), T.t(:reb_move_weakened)].join(". "), true]], SpeakCapture.log
  end

  test "releasing Z-Move says it off, then the move again" do
    with_menu do |menu|
      open(menu, fighter, 0, :zButton => [1, 2])
      SpeakCapture.clear
      menu.zButton = 1
    end
    assert_equal [[toggled(:bt_special_off, :bt_m_zmove), true], [line(HYPER_VOICE), false]], SpeakCapture.log
  end

  test "on a move with no Z-move, pressing Z-Move is said and the move is not said again" do
    with_menu do |menu|
      open(menu, fighter, 1, :zButton => [1])
      SpeakCapture.clear
      menu.zButton = 2
    end
    assert_equal [[toggled(:bt_special_on, :bt_m_zmove), true]], SpeakCapture.log
  end

  test "the menu opened again with the button left on says the move itself, then the button coming up" do
    with_menu do |menu|
      open(menu, fighter, 0, :zButton => [1, 2])
      SpeakCapture.clear
      open(menu, fighter, 0, :zButton => [1])
    end
    assert_equal [[line(HYPER_VOICE), true], [ready(:bt_m_zmove), false]], SpeakCapture.log
  end

  test "Desolation's battler keeps each move in place with Z-Move on, the button still said" do
    with_menu do |menu|
      open(menu, PlainFighter.new([HYPER_VOICE, EMBER]), 0, :zButton => [1])
      SpeakCapture.clear
      menu.zButton = 2
      menu.setIndex(1)
    end
    assert_equal [[toggled(:bt_special_on, :bt_m_zmove), true], [line(EMBER), true]], SpeakCapture.log
  end

  test "the Terastallization button is said as it comes up, queued, and as it toggles, cutting in, the move unsaid" do
    with_menu do |menu|
      open(menu, fighter, 0, :teraButton => [1])
      menu.teraButton = 2
      menu.teraButton = 1
    end
    assert_equal [[line(HYPER_VOICE), true], [ready(:bt_m_tera), false], [toggled(:bt_special_on, :bt_m_tera), true],
                  [toggled(:bt_special_off, :bt_m_tera), true]], SpeakCapture.log
  end

  test "a button that stays hidden, stays as it was or comes up pressed says nothing" do
    [[0, 0], [1, 1], [2, 2], [0, 2], [nil, 2], [1, 0], [2, 0], [1, 3]].each do |from, to|
      [:teraButton=, :zButton=].each do |setter|
        with_menu do |menu|
          menu.send(setter, from) unless from.nil?
          SpeakCapture.clear
          menu.send(setter, to)
        end
        assert_nothing_spoken "#{setter} from #{from.inspect} to #{to}"
      end
    end
  end

  test "each button keeps its state apart from the other and from core's Mega Evolution one" do
    with_menu do |menu|
      open(menu, fighter, 0, :megaButton => [1], :teraButton => [1], :zButton => [1])
      SpeakCapture.clear
      menu.zButton = 2
      menu.teraButton = 2
      menu.megaButton = 2
    end
    assert_equal [toggled(:bt_special_on, :bt_m_zmove), z_line(BLITZ), toggled(:bt_special_on, :bt_m_tera),
                  T.t(:bt_mega_on)], SpeakCapture.lines
  end

  test "the display holds the game's class name only while the hooks bind, not while a test runs" do
    held = with_menu { |_menu| Object.const_defined?(:FightMenuDisplay) ? Object.const_get(:FightMenuDisplay) : nil }
    refute_same Display, held
  end

  private

  # A battler with Hyper Voice, which turns into Breakneck Blitz, and Ember, which has no Z-move.
  def fighter
    Fighter.new([HYPER_VOICE, EMBER], [BLITZ, nil])
  end

  # The menu opened as Rejuvenation's pbFightMenu opens it: the battler set, the cursor put on slot, then each button
  # set hidden and then to each state given for it.
  def open(menu, battler, slot, states = {})
    menu.battler = battler
    menu.setIndex(slot)
    [:megaButton, :ultraButton, :teraButton, :zButton].each do |button|
      ([0] + (states[button] || [])).each { |v| menu.send("#{button}=", v) }
    end
  end

  # A move's line at full verbosity, as core's reader says it: name, type, category and PP.
  def line(m)
    [m.name, type(m), T.t(:cat_special), T.t(:mv_pp, :pp => m.pp, :tot => m.totalpp)].join(". ")
  end

  # A Z-move's line at full verbosity: name, type and category, with no PP.
  def z_line(m)
    [m.name, type(m), T.t(:cat_special)].join(". ")
  end

  def type(m)
    T.t(:mv_type, :t => PBTypes.getName(m.type))
  end

  # The line of a button coming up for mechanic name.
  def ready(name)
    T.t(:bt_special_ready, :name => T.t(name))
  end

  # The line of a button toggled (key on or off) for mechanic name.
  def toggled(key, name)
    T.t(key, :name => T.t(name))
  end

  # Yields a new display with the chains bound to Display attached and rv_common's overrides of core's fight line in
  # core's place meanwhile.
  def with_menu
    meta = PokeAccess::Battle.singleton_class
    core = SWAPPED.map { |n| [n, meta.instance_method(n)] }
    self.class.readers.each { |n, um| meta.send(:define_method, n, um) }
    attached(BOUND) { yield Display.new }
  ensure
    core.each { |n, um| meta.send(:define_method, n, um) }
  end

  # Runs the block with the hook chains bound to Display at load attached, then takes them away, putting back whatever
  # chains held those keys before. Display holds the game's class name only while bind evaluates the hooks.
  def attached(bound)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = bound.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(bound)
    yield
  ensure
    bound.each_key { |k| chains.delete(k) }
    (held || []).each { |k, v| chains[k] = v }
  end

  class << self
    # The [name, method] pairs rv_common's binding puts in core's place, kept aside by bind.
    attr_reader :readers

    private

    # Evaluates core's gen-6 battle hooks and binds rv_common's fight menu over Display, set for the moment as
    # FightMenuDisplay, and answers the hook chains bound to it, to attach per test. rv_common's overrides of the
    # SWAPPED methods are kept aside and core's put back; all else the binding changed (the name, other chains,
    # function bodies, the overrides listed, the wrappers kept bound, the missing list, the battle marks and
    # singletons) is put back as it was.
    def bind
      hooks = PokeAccess::Hooks
      meta = PokeAccess::Battle.singleton_class
      core = SWAPPED.map { |n| [n, meta.instance_method(n)] }
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      overrides = hooks.overrides.length
      kept = hooks.instance_variable_get(:@bound).length
      missing = hooks.missing.dup
      marks = PokeAccess::Battle::ICON_MARKS.dup
      singletons = [:shown_sex, :shown_level].map { |n| [n, PokeAccess::Battle.method(n)] }
      ours = lambda { |key| key.start_with?("FightMenuDisplay#") }
      chains.delete_if { |k, _v| ours.call(k) }
      prior = Object.const_defined?(:FightMenuDisplay) ? Object.send(:remove_const, :FightMenuDisplay) : nil
      Object.const_set(:FightMenuDisplay, Display)
      verbose = $VERBOSE
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      PokeAccess::FightRV.bind
      @readers = SWAPPED.map { |n| [n, meta.instance_method(n)] }
      chains.select { |k, _v| ours.call(k) }
    ensure
      $VERBOSE = verbose
      (core || []).each { |n, um| meta.send(:define_method, n, um) }
      Object.send(:remove_const, :FightMenuDisplay) if Object.const_defined?(:FightMenuDisplay)
      Object.const_set(:FightMenuDisplay, prior) if prior
      (chains.keys - chains_was.keys).each do |key|
        cname, meth = key.split("#", 2)
        k = PokeAccess.const_at(cname)
        orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
        unwrap = !ours.call(key) && k.is_a?(Module) && (k.method_defined?(orig) || k.private_method_defined?(orig))
        k.send(:alias_method, meth, orig) if unwrap
        chains.delete(key)
      end
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.overrides.slice!(overrides..-1)
      hooks.instance_variable_get(:@bound).slice!(kept..-1)
      hooks.missing.replace(missing)
      PokeAccess::Battle::ICON_MARKS.replace(marks)
      singletons.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) }
    end
  end

  # The chains on Display, bound once as this file loads: evaluating a file again starts its coverage afresh, so
  # binding before any test lets every test's reading count.
  BOUND = bind
end
