# Rejuvenation's fight menus (games/rejuvenation/fight_menu.rb): the special-move menu's ally moves as the cursor lands
# on each, with the panel that opens with it (power, "Used" or the charge, description), and the fight menu's details
# panel on A (the name, power and accuracy against the foe, priority, flags, description). The stand-ins below hold
# FightMenuDisplaySpecial's and PokeBattle_Scene's names only while the profile file is evaluated, so its hooks bind to
# them and no other test sees a battle scene.

# The special-move menu as far as the reader goes: the battler whose ally moves it lists, set each time the menu
# opens, and a cursor that moves only onto a move.
class RejuvSpecialMenuStandIn
  attr_reader :battler, :index

  def initialize
    @battler = nil
    @index = 0
  end

  def battler=(value)
    @battler = value
  end

  def setIndex(value)
    return false unless @battler && @battler.specialmoves[value]
    @index = value
    true
  end
end

# The battle scene's details panels as far as their text goes, each drawn over the one that shows: the fight panel
# paints its flags, then the move's name with its power, accuracy and priority, then the description; the special
# panel the name, the power and "Used" or the charge, then the description.
class RejuvFightSceneStandIn
  def initialize(menu)
    @sprites = { "fightwindowdx" => menu }
    @mdviewport = nil
  end

  def showingMoveDetails?
    !@mdviewport.nil?
  end

  def pbDisposeMoveDetails
    @mdviewport = nil
  end

  def pbDrawMoveDetails(battler, moveIndex, zmove)
    pbDisposeMoveDetails if showingMoveDetails?
    @mdviewport = :fight
    z = zmove && battler.pbCompatibleZMoveFromMove?(moveIndex, true)
    move = z ? battler.zmoves[moveIndex] : battler.moves[moveIndex]
    pbDrawTextPositions(nil, [[move.flags, 506, 128, :right]])
    pbDrawTextPositions(nil, [[move.shortname, 8, 26, 0], [move.power, 332, 26, :center],
                              [move.accuracy, 418, 26, :center], [move.priority, 490, 26, :center]])
    drawTextEx(nil, 8, 60, 496, 3, move.desc, nil, nil)
    :fight_panel
  end

  def pbDrawSpecialMoveDetails(battler, moveIndex, _zmove, _opts = {})
    pbDisposeMoveDetails if showingMoveDetails?
    @mdviewport = :special
    move = battler.specialmoves[moveIndex]
    charge = battler.charges[move.move]
    power = move.basedamage <= 1 ? (move.basedamage == 0 ? "---" : "???") : move.basedamage.to_s
    state = charge == -1 ? "Used" : format("Charge: %d/%d", charge, move.chargetime)
    pbDrawTextPositions(nil, [[move.name, 8, 26, 0], [power, 334, 26, 0], [state, 376, 26, 0]])
    drawTextEx(nil, 8, 60, 496, 3, move.desc, nil, nil)
    true
  end
end

rejuv_fight_made = [[:FightMenuDisplaySpecial, RejuvSpecialMenuStandIn],
                    [:PokeBattle_Scene, RejuvFightSceneStandIn]].reject { |n, _k| Object.const_defined?(n) }
rejuv_fight_profiles = PokeAccess::Game.profiles.dup
rejuv_fight_made.each { |n, k| Object.const_set(n, k) }
begin
  rejuv_fight = File.join(Harness::ROOT, "games", "rejuvenation", "fight_menu.rb")
  eval(Harness.source(rejuv_fight), TOPLEVEL_BINDING, rejuv_fight)
ensure
  PokeAccess::Game.profiles.replace(rejuv_fight_profiles)
  rejuv_fight_made.each { |n, _k| Object.send(:remove_const, n) }
end

class RejuvenationFightTest < PokeAccessTest
  T = PokeAccess::I18n

  # An ally move as the battle builds it: no PP of its own (maxpp 0), the turns it charges for and its description.
  Special = Struct.new(:move, :name, :type, :category, :basedamage, :pp, :totalpp, :chargetime, :desc)
  LONELY_MOON = Special.new(:LONELYMOON, "Lonely Moon", :PSYCHIC, :special, 95, 0, 0, 3,
                            "A singular moon drops from the sky onto the target.")
  ORBITAL_RING = Special.new(:ORBITALRING, "Orbital Ring", :FAIRY, :status, 0, 0, 0, 3,
                             "The user endures for the rest of the turn.")
  VENGEFUL_NUKE = Special.new(:VENGEFULNUKE, "Vengeful Nuke", :DARK, :physical, 80, 0, 0, 3,
                              "A nuclear blast of vengeance.")
  ALAINS_PROMISE = Special.new(:PROMISEDALAIN, "Alain's Promise", :QMARKS, :special, 999, 0, 0, 1,
                               "A promise kept.")

  # A fight move as the details panel paints it: its figures already worked out against the foe ahead.
  Move = Struct.new(:shortname, :power, :accuracy, :priority, :flags, :desc)
  QUICK_ATTACK = Move.new("Quick Attack", "40", "100", "+1", "Contact", "The user lunges at the target first.")
  SWORDS_DANCE = Move.new("Swords Dance", "---", "---", "0", "Dance", "A frenetic dance to uplift the fighting spirit.")
  SEISMIC_TOSS = Move.new("Seismic Toss", "???", "100", "0", "", "Damage equal to the user's level.")
  BLITZ = Move.new("Breakneck Blitz", "140", "---", "0", "", "The user builds up momentum and crashes into the target.")

  # The battler choosing: its slot, its ally moves and the charge each has built (-1 once used), and its fight moves
  # with the Z-moves they turn into (nil where none).
  class Fighter
    attr_reader :index, :specialmoves, :charges, :moves, :zmoves

    def initialize(specialmoves, charges = {}, moves = [], zmoves = [])
      @index = 0
      @specialmoves = specialmoves
      @charges = charges
      @moves = moves
      @zmoves = zmoves
    end

    def pbCompatibleZMoveFromMove?(i, _by_index)
      !@zmoves[i].nil?
    end
  end

  # The game's type names (getTypeName), "???" for the type of the Promise moves; the rest of gen 6's data as it is.
  module TypeNames
    NAMES = { :PSYCHIC => "Psychic", :FAIRY => "Fairy", :DARK => "Dark", :QMARKS => "???" }
    def self.type_name(id); NAMES[id]; end
    def self.method_missing(name, *args); PokeAccess::DataG6.send(name, *args); end
    def self.respond_to_missing?(name, priv = false); PokeAccess::DataG6.respond_to?(name, priv); end
  end

  CHARGES = { :LONELYMOON => 2, :ORBITALRING => 3, :VENGEFULNUKE => -1, :PROMISEDALAIN => 1 }

  test "opening the special menu says the focused ally move, then its panel's power, charge and description, queued" do
    shown = named { open_menu(king_and_queen) }
    assert_equal [[line("Lonely Moon", "Psychic", :cat_special), true],
                  ["#{power('95')}, Charge: 2/3. #{LONELY_MOON.desc}", false]], SpeakCapture.log
    assert_equal true, shown, "the panel still answers the game's flag, which pbFightMenuDX keeps"
  end

  test "each ally move the cursor lands on is said, then its redrawn panel without the name, queued" do
    named do
      open_menu(king_and_queen)
      SpeakCapture.clear
      press(1)
    end
    assert_equal [[line("Orbital Ring", "Fairy", :cat_status), true], ["Charge: 3/3. #{ORBITAL_RING.desc}", false]],
                 SpeakCapture.log, "a power painted as --- is left out"
  end

  test "a used ally move's panel says Used, as painted" do
    named { open_menu(king_and_queen, 2) }
    assert_equal "#{power('80')}, Used. #{VENGEFUL_NUKE.desc}", SpeakCapture.last
  end

  test "the panel repainted on the last move when the cursor cannot go further says nothing again" do
    named do
      open_menu(king_and_queen, 2)
      assert_equal 2, SpeakCapture.log.length, "the move and its panel as the menu opens"
      SpeakCapture.clear
      press(1)
    end
    assert_nothing_spoken
  end

  test "with the panel closed the cursor says the moves alone, and A brings the panel back with the name, cutting in" do
    named do
      open_menu(king_and_queen)
      toggle
      SpeakCapture.clear
      press(1)
      assert_equal [[line("Orbital Ring", "Fairy", :cat_status), true]], SpeakCapture.log
      SpeakCapture.clear
      toggle
    end
    assert_equal [["Orbital Ring. Charge: 3/3. #{ORBITAL_RING.desc}", true]], SpeakCapture.log,
                 "the move's line was said frames before"
  end

  test "the panel A brings back on the move the menu opened on says its name too, cutting in" do
    named do
      open_menu(king_and_queen)
      toggle
      SpeakCapture.clear
      toggle
    end
    assert_equal [["Lonely Moon. #{power('95')}, Charge: 2/3. #{LONELY_MOON.desc}", true]], SpeakCapture.log
  end

  test "the info key holds the ally move whole, and the move's line alone while the panel is closed" do
    named do
      open_menu(king_and_queen)
      assert_equal "#{line('Lonely Moon', 'Psychic', :cat_special)}. #{power('95')}, Charge: 2/3. #{LONELY_MOON.desc}",
                   PokeAccess::Info.info_text
      toggle
      press(1)
    end
    assert_equal line("Orbital Ring", "Fairy", :cat_status), PokeAccess::Info.info_text
  end

  test "the menu opened again on the same move says it again" do
    named do
      open_menu(king_and_queen)
      SpeakCapture.clear
      leave
      reopen
    end
    assert_equal [[line("Lonely Moon", "Psychic", :cat_special), true],
                  ["#{power('95')}, Charge: 2/3. #{LONELY_MOON.desc}", false]], SpeakCapture.log
  end

  test "a Promise's type, painted as ???, is said as unknown" do
    named { open_menu(Fighter.new([ALAINS_PROMISE], CHARGES)) }
    assert_equal line("Alain's Promise", T.t(:pdx_unknown_short), :cat_special), SpeakCapture.lines.first
  end

  test "a move with PP of its own says them after its name" do
    filled = Special.new(:LONELYMOON, "Lonely Moon", :PSYCHIC, :special, 95, 1, 2, 3, LONELY_MOON.desc)
    named { open_menu(Fighter.new([filled], CHARGES)) }
    want = [line("Lonely Moon", "Psychic", :cat_special), T.t(:mv_pp, :pp => 1, :tot => 2)].join(". ")
    assert_equal want, SpeakCapture.lines.first
  end

  test "the ally move's line says its name at brief, its type from medium and its category in full" do
    lines = named do
      vb_levels do
        SpeakCapture.clear
        menu_on(king_and_queen)
        SpeakCapture.last
      end
    end
    type = T.t(:mv_type, :t => "Psychic")
    assert_equal ["Lonely Moon", "Lonely Moon. #{type}", line("Lonely Moon", "Psychic", :cat_special)], lines
  end

  test "at brief, the info key and Ctrl+T keep the ally move whole" do
    PokeAccess::Config.verbosity = :brief
    named { menu_on(king_and_queen) }
    whole = line("Lonely Moon", "Psychic", :cat_special)
    assert_equal [whole, whole], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "at brief, the move says its name and the panel its figures, without the description" do
    PokeAccess::Config.verbosity = :brief
    named { open_menu(king_and_queen) }
    assert_equal [["Lonely Moon", true], ["#{power('95')}, Charge: 2/3", false]], SpeakCapture.log
  ensure
    PokeAccess::Config.verbosity = :full
  end

  test "A opens the fight panel with the name, the figures against the foe, priority and flags, then the description" do
    ret = fight_scene.pbDrawMoveDetails(fight_battler, 0, false)
    figures = [power("40"), T.t(:mv_acc, :a => "100"), T.t(:mv_priority, :n => "+1"), flags("Contact")].join(", ")
    assert_equal [["Quick Attack. #{figures}. #{QUICK_ATTACK.desc}", true]], SpeakCapture.log
    assert_equal :fight_panel, ret, "the panel is still the game's"
  end

  test "with the fight panel open, the move the cursor lands on is said behind the fight line, without the name" do
    scene = fight_scene
    scene.pbDrawMoveDetails(fight_battler, 0, false)
    SpeakCapture.clear
    scene.pbDrawMoveDetails(fight_battler, 1, false)
    figures = [T.t(:mv_acc, :a => T.t(:mv_acc_perfect)), flags("Dance")].join(", ")
    assert_equal [["#{figures}. #{SWORDS_DANCE.desc}", false]], SpeakCapture.log,
                 "no power where it paints ---, and no priority at 0"
  end

  test "a variable power, painted as ???, is said as variable" do
    fight_scene.pbDrawMoveDetails(fight_battler, 2, false)
    figures = [power(T.t(:mv_power_var)), T.t(:mv_acc, :a => "100")].join(", ")
    assert_equal "Seismic Toss. #{figures}. #{SEISMIC_TOSS.desc}", SpeakCapture.last
  end

  test "the panel redrawn for the Z-move its button puts in place says its figures, the fight line naming it" do
    scene = fight_scene
    scene.pbDrawMoveDetails(fight_battler, 0, false)
    SpeakCapture.clear
    scene.pbDrawMoveDetails(fight_battler, 0, true)
    figures = [power("140"), T.t(:mv_acc, :a => T.t(:mv_acc_perfect))].join(", ")
    assert_equal [["#{figures}. #{BLITZ.desc}", false]], SpeakCapture.log
  end

  test "A opens the panel on the Z-move with its name, cutting in" do
    fight_scene.pbDrawMoveDetails(fight_battler, 0, true)
    figures = [power("140"), T.t(:mv_acc, :a => T.t(:mv_acc_perfect))].join(", ")
    assert_equal [["Breakneck Blitz. #{figures}. #{BLITZ.desc}", true]], SpeakCapture.log
  end

  private

  # The battler of the King and Queen fight, its three ally moves charged two, three of three, and used.
  def king_and_queen
    Fighter.new([LONELY_MOON, ORBITAL_RING, VENGEFUL_NUKE], CHARGES)
  end

  # A battler with three fight moves, the first turning into a Z-move.
  def fight_battler
    @fight_battler ||= Fighter.new([], {}, [QUICK_ATTACK, SWORDS_DANCE, SEISMIC_TOSS], [BLITZ])
  end

  # A battle scene with no special menu, for the fight panel.
  def fight_scene
    RejuvFightSceneStandIn.new(nil)
  end

  # Runs the block with the game's type names in place and Graphics counting the frames the key presses below play.
  def named
    Harness.with_provider(TypeNames) { with_frames { yield } }
  end

  # Runs the block with Graphics.frame_count, which the stubs leave out, answering the frames played; the engine's own
  # comes back after, or none.
  def with_frames
    meta = Graphics.singleton_class
    had = meta.method_defined?(:frame_count, false) ? Graphics.method(:frame_count) : nil
    @frames = 0
    played = lambda { @frames }
    Graphics.define_singleton_method(:frame_count) { played.call }
    yield
  ensure
    had ? Graphics.define_singleton_method(:frame_count, had) : meta.send(:remove_method, :frame_count)
  end

  # A frame played, as pbFightMenuDX's loop plays one before each key press it handles, and one opens the menu.
  def frame!
    @frames = @frames.to_i + 1
  end

  # The special menu set up for fighter with no panel open, its cursor put on the first move.
  def menu_on(fighter)
    menu = RejuvSpecialMenuStandIn.new
    menu.battler = fighter
    menu.setIndex(0)
  end

  # A battle's special menu and scene for fighter, the menu opened on slot.
  def open_menu(fighter, slot = 0)
    @fighter = fighter
    @menu = RejuvSpecialMenuStandIn.new
    @scene = RejuvFightSceneStandIn.new(@menu)
    reopen(slot)
  end

  # The menu opened as pbFightMenuDX opens it, in one frame: the battler set, the cursor put on slot, then the panel
  # drawn.
  def reopen(slot = 0)
    frame!
    @menu.battler = @fighter
    @menu.setIndex(slot)
    @scene.pbDrawSpecialMoveDetails(@fighter, @menu.index, false, :specialmove => true)
  end

  # The menu left with C or B, which closes the panel.
  def leave
    frame!
    @scene.pbDisposeMoveDetails
  end

  # A left or right press on the special menu: the cursor moved where it can, the panel redrawn in the same frame
  # while it shows.
  def press(step)
    frame!
    @menu.setIndex(@menu.index + step)
    @scene.pbDrawSpecialMoveDetails(@fighter, @menu.index, false, :specialmove => true) if @scene.showingMoveDetails?
  end

  # A on the special menu: the panel closed while it shows, else drawn.
  def toggle
    frame!
    if @scene.showingMoveDetails?
      @scene.pbDisposeMoveDetails
    else
      @scene.pbDrawSpecialMoveDetails(@fighter, @menu.index, false, :specialmove => true)
    end
  end

  # A special move's line at full verbosity: its name, type and category.
  def line(name, type, category)
    [name, T.t(:mv_type, :t => type), T.t(category)].join(". ")
  end

  def power(p)
    T.t(:mv_power, :p => p)
  end

  def flags(list)
    T.t(:dbk_flags, :list => list)
  end
end
