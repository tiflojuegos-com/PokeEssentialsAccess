# Reborn's fight menu: the move line with the move's real type, a type the field adds and the field's boost (Reborn's
# pbFieldNotesBattle); the Z-Move button said as it comes up and toggles, the Z-move then in the move's place.
class RebornFightTest < PokeAccessTest
  # A battle move of Reborn: its symbol in move, its real type from pbType, the types the field adds.
  class Move
    attr_reader :move, :name, :pp, :totalpp, :type, :category
    def initialize(move, name, type, real = nil, extra = nil)
      @move = move; @name = name; @type = type; @real = real || type; @extra = extra
      @pp = 10; @totalpp = 15; @category = :special
    end
    def pbType(_attacker); @real; end
    def getSecondaryType(_attacker); @extra; end
  end

  # The battle, by its field.
  Battle = Struct.new(:FE)

  # The battler: its moves, the Z-moves they turn into (nil where none), and its battle. As in Reborn, the Z-move
  # check takes a move, or a slot when its flag says so.
  class Battler
    attr_reader :moves, :zmoves, :battle
    def initialize(moves, zmoves, field)
      @moves = moves; @zmoves = zmoves; @battle = Battle.new(field)
    end
    def pbCompatibleZMoveFromMove?(move, moveindex = false)
      !@zmoves[moveindex ? move : @moves.index(move)].nil?
    end
  end

  # Reborn's fight window as far as the reader goes: the battler and cursor it is set up with, and its zButton.
  class Display
    attr_reader :zButton
    def zButton=(v); @zButton = v; end
    def initialize(battler, index)
      @battler = battler; @index = index
    end
  end

  HYPER_VOICE = Move.new(:HYPERVOICE, "Hyper Voice", :NORMAL, :FAIRY)
  FLYING_PRESS = Move.new(:FLYINGPRESS, "Flying Press", :FIGHTING, nil, [:FLYING])
  ROCK_SLIDE = Move.new(:ROCKSLIDE, "Rock Slide", :ROCK, nil, [:GROUND])
  BLITZ = Move.new(:BREAKNECKBLITZ, "Breakneck Blitz", :NORMAL)

  # Reborn's check behind a move button's highlight: 1 when the field boosts the move, 2 when it weakens it, else 0; it
  # fails on Struggle, which has no notes.
  FIELD_NOTES = {
    :pbFieldNotesBattle => lambda do |move|
      raise ArgumentError, "no field notes for Struggle" if move.move == :STRUGGLE
      { :HYPERVOICE => 1, :ROCKSLIDE => 2 }[move.move].to_i
    end
  }

  class << self
    # The profile's read_fight_move, kept aside by load_profile.
    attr_reader :reader
  end

  # Evaluates the profile file once, as boot does, with Display standing as FightMenuDisplay for its zButton hook. Its
  # read_fight_move is kept aside and core's put back, so the other tests of the process keep core's;
  # with_profile_reader puts the profile's in for a test.
  def self.load_profile
    meta = PokeAccess::Battle.singleton_class
    core = meta.instance_method(:read_fight_move)
    profiles = PokeAccess::Game.profiles.dup
    prior = Object.const_defined?(:FightMenuDisplay) ? Object.send(:remove_const, :FightMenuDisplay) : nil
    Object.const_set(:FightMenuDisplay, Display)
    path = File.join(Harness::ROOT, "games", "reborn", "fight_menu.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @reader = meta.instance_method(:read_fight_move)
  ensure
    meta.send(:define_method, :read_fight_move, core)
    Object.send(:remove_const, :FightMenuDisplay)
    Object.const_set(:FightMenuDisplay, prior) if prior
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the core fight read says Reborn's line: the move's real type and the field's boost, cutting in" do
    assert_equal [[line("MovHYPERVOICE", "TipoFAIRY", nil, t(:reb_move_boosted)), true]],
                 read(Display.new(cave_battler, 0))
  end

  test "asked to queue, the core fight read queues Reborn's line" do
    with_profile_reader { PokeAccess::Battle.read_fight_move(Display.new(cave_battler, 0), false) }
    assert_equal [false], SpeakCapture.log.map { |_text, interrupt| interrupt }
  end

  test "a type the field adds is named after the move's own" do
    want = line("MovFLYINGPRESS", "TipoFIGHTING", t(:reb_move_also_type, :t => "TipoFLYING"), nil)
    assert_equal [[want, true]], read(Display.new(cave_battler, 1))
  end

  test "a move the field weakens says so" do
    want = line("MovROCKSLIDE", "TipoROCK", t(:reb_move_also_type, :t => "TipoGROUND"), t(:reb_move_weakened))
    assert_equal [[want, true]], read(Display.new(cave_battler, 2))
  end

  test "an added type that repeats the move's own is not named again" do
    ember = Move.new(:EMBER, "Ember", :FIRE, nil, [:FIRE])
    assert_equal [[line("MovEMBER", "TipoFIRE", nil, nil), true]],
                 read(Display.new(Battler.new([ember], [nil], :CAVE), 0))
  end

  test "an empty list of added types adds nothing" do
    tackle = Move.new(:TACKLE, "Tackle", :NORMAL, nil, [])
    assert_equal [[line("MovTACKLE", "TipoNORMAL", nil, nil), true]],
                 read(Display.new(Battler.new([tackle], [nil], :CAVE), 0))
  end

  test "on Rainbow and Crystal Cavern the added type is a random or a crystal one, Flying Press's own excepted" do
    rock = lambda { |added| line("MovROCKSLIDE", "TipoROCK", added, t(:reb_move_weakened)) }
    press = line("MovFLYINGPRESS", "TipoFIGHTING", t(:reb_move_also_type, :t => "TipoFLYING"), nil)
    { [:RAINBOW, ROCK_SLIDE] => rock.call(t(:reb_move_random_type)),
      [:CRYSTALCAVERN, ROCK_SLIDE] => rock.call(t(:reb_move_crystal_type)),
      [:RAINBOW, FLYING_PRESS] => press, [:CRYSTALCAVERN, FLYING_PRESS] => press }.each do |(field, move), want|
      assert_equal [[want, true]], read(Display.new(Battler.new([move], [nil], field), 0)), "#{move.name} on #{field}"
      SpeakCapture.clear
    end
  end

  test "a move the field notes cannot rate says nothing of the field" do
    struggle = Move.new(:STRUGGLE, "Struggle", :NORMAL)
    assert_equal [[line("MovSTRUGGLE", "TipoNORMAL", nil, nil), true]],
                 read(Display.new(Battler.new([struggle], [nil], :CAVE), 0))
  end

  test "the same slot read again is not said twice" do
    d = Display.new(cave_battler, 0)
    read(d)
    SpeakCapture.clear
    assert_equal [], read(d)
  end

  test "a slot with no move, or a move with no id, says nothing" do
    { "an empty slot" => [], "a move with no id" => [Move.new(nil, "", :NORMAL)] }.each do |what, moves|
      assert_equal [], read(Display.new(Battler.new(moves, [nil], :CAVE), 0)), what
    end
  end

  test "the info key tells of the move just said" do
    read(Display.new(cave_battler, 2))
    assert_match(/\ARock Slide\b/, PokeAccess::Info.info_text.to_s)
  end

  test "the Z-Move button coming up is said, queued" do
    d = Display.new(cave_battler, 0)
    toggle(d, 0)
    SpeakCapture.clear
    toggle(d, 1)
    assert_equal [[t(:bt_special_ready, :name => t(:bt_m_zmove)), false]], SpeakCapture.log
  end

  test "a button still hidden says nothing" do
    d = Display.new(cave_battler, 0)
    toggle(d, 0)
    assert_equal [], SpeakCapture.log
  end

  test "turning Z-Move on says so, then the Z-move in the move's place, with no PP of its own" do
    d = z_ready(0)
    toggle(d, 2)
    assert_equal [[t(:bt_special_on, :name => t(:bt_m_zmove)), true],
                  [line("MovBREAKNECKBLITZ", "TipoNORMAL", nil, t(:reb_move_boosted), false), false]],
                 SpeakCapture.log
  end

  test "while Z-Move is on, the info key tells of the Z-move" do
    toggle(z_ready(0), 2)
    assert_match(/\ABreakneck Blitz\b/, PokeAccess::Info.info_text.to_s)
  end

  test "turning Z-Move off says so, then the move again" do
    d = z_ready(0)
    toggle(d, 2)
    SpeakCapture.clear
    toggle(d, 1)
    assert_equal [[t(:bt_special_off, :name => t(:bt_m_zmove)), true],
                  [line("MovHYPERVOICE", "TipoFAIRY", nil, t(:reb_move_boosted)), false]],
                 SpeakCapture.log
  end

  test "on a move with no Z-move, turning it on is said and the move is not read again" do
    d = z_ready(1)
    toggle(d, 2)
    assert_equal [[t(:bt_special_on, :name => t(:bt_m_zmove)), true]], SpeakCapture.log
  end

  test "a battler that cannot tell its Z-moves keeps the move in place" do
    battler = cave_battler
    def battler.pbCompatibleZMoveFromMove?(_move, _moveindex = false); raise ArgumentError, "no Z-crystal data"; end
    d = z_ready(0, battler)
    toggle(d, 2)
    assert_equal [[t(:bt_special_on, :name => t(:bt_m_zmove)), true]], SpeakCapture.log
  end

  test "setting the button to the state it is in says nothing" do
    d = z_ready(0)
    toggle(d, 2)
    SpeakCapture.clear
    toggle(d, 2)
    assert_equal [], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A battler on the Cave field with Hyper Voice (which turns into Breakneck Blitz), Flying Press and Rock Slide.
  def cave_battler
    Battler.new([HYPER_VOICE, FLYING_PRESS, ROCK_SLIDE], [BLITZ, nil, nil], :CAVE)
  end

  # A move line as the fight menu says it at full: name, type, added type, category, PP (10 of 15, none for a Z-move)
  # and the field's mark.
  def line(name, type, added, field, with_pp = true)
    pp = with_pp ? t(:mv_pp, :pp => 10, :tot => 15) : nil
    [name, t(:mv_type, :t => type), added, t(:cat_special), pp, field].compact.join(". ")
  end

  # What the core fight read says of the display's slot with the profile's reader in place.
  def read(display)
    with_profile_reader { PokeAccess::Battle.read_fight_move(display) }
    SpeakCapture.log.dup
  end

  # Sets the display's Z-Move button as Reborn's fight menu does, with the profile's reader in place.
  def toggle(display, state)
    with_profile_reader { display.zButton = state }
  end

  # A display of battler on slot idx whose move was read and whose Z-Move button came up, the log then cleared.
  def z_ready(idx, battler = cave_battler)
    d = Display.new(battler, idx)
    read(d)
    toggle(d, 0)
    toggle(d, 1)
    SpeakCapture.clear
    d
  end

  # The block's value with the profile's read_fight_move in core's place and Reborn's field notes in place.
  def with_profile_reader
    meta = PokeAccess::Battle.singleton_class
    core = meta.instance_method(:read_fight_move)
    meta.send(:define_method, :read_fight_move, self.class.reader)
    GameFunctions.with(FIELD_NOTES) { yield }
  ensure
    meta.send(:define_method, :read_fight_move, core)
  end
end
