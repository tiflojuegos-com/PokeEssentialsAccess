# Rejuvenation's battle boxes (games/rejuvenation/battle_boxes.rb): a boss's shields, said as its box comes up and as
# their count changes and listed with its marks for the info key; the crest the stock box and an SOS ally's box paint,
# said as a mark. The stand-ins below hold the boxes' names only while the file is evaluated, so its hooks bind to
# them; its override of the marks is kept aside and put in for each test, so the other tests keep core's.

# The boss's box as PokemonBossBattle.rb keeps it: made hidden and repainted, shown by appear after a repaint, and
# given the count pbUpdateShield sets before it repaints again; its shields are blitted, no image a capture sees.
class RjBossBox
  attr_reader :battler
  attr_accessor :shieldCount, :visible

  def initialize(battler)
    @battler = battler
    @shieldCount = battler.shieldCount
    @visible = false
    refresh
  end

  def appear
    refresh
    @visible = true
  end

  def refresh
    :repainted
  end
end

# The box of an ally a boss calls in, as PokemonBossBattle.rb draws its icons: the crest beside the name
# (battleApplyCrest for one lent), then the status, all drawn only along with a status, as the game draws them.
class RjSosBox
  def initialize(battler)
    @battler = battler
    refresh
  end

  def refresh
    imagepos = []
    if @battler.crested
      crest = @battler.fakeCrest ? "battleApplyCrest" : "battleCrest"
      imagepos.push(["Graphics/Pictures/Battle/#{crest}.png", 30, 8, 0, 0, -1, -1])
    end
    unless @battler.status.nil?
      imagepos.push(["Graphics/Pictures/Battle/BattleStatusesD#{@battler.status}", 2, 30, 0, 0, 64, 28])
      pbDrawImagePositions(nil, imagepos)
    end
    :repainted
  end
end

# The profile file evaluated once over the stand-ins, its overrides of the marks and the HP line kept aside and core's
# put back.
module RjBattleBoxesBinding
  STAND_INS = { :BossPokemonDataBox => RjBossBox, :SosPokemonDataBox => RjSosBox }.freeze

  class << self
    # The profile's shown_marks and battler_state.
    attr_reader :marks, :state
  end

  def self.load
    meta = PokeAccess::Battle.singleton_class
    core = [:shown_marks, :battler_state].map { |n| [n, meta.instance_method(n)] }
    overrides = PokeAccess::Hooks.overrides.length
    priors = STAND_INS.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    STAND_INS.each { |n, k| Object.const_set(n, k) }
    path = File.join(Harness::ROOT, "games", "rejuvenation", "battle_boxes.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @marks = meta.instance_method(:shown_marks)
    @state = meta.instance_method(:battler_state)
  ensure
    (core || []).each { |n, um| meta.send(:define_method, n, um) }
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    STAND_INS.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) if k }
  end
  load
end

class RejuvenationBattleBoxesTest < PokeAccessTest
  # A battler as the boxes read it, its battle reaching the scene whose boxes are its sprites.
  Fighter = Struct.new(:index, :name, :pokemon, :shieldCount, :crested, :fakeCrest, :status, :battle)
  # A boss as the HP key reads it.
  Boss = Struct.new(:index, :name, :level, :hp, :totalhp, :status, :shieldCount, :battle)
  # The battle and its scene.
  Battle = Struct.new(:scene)
  # A scene holding its boxes in @sprites, as battlebox<index>.
  class Scene
    def initialize(sprites)
      @sprites = sprites
    end
  end

  test "says a boss's shields with its name as its box comes up, nothing while it is hidden" do
    box = RjBossBox.new(boss(2))
    hidden = SpeakCapture.lines
    box.appear
    assert_equal [[], [[shields_line("Garchomp", 2), false]]], [hidden, SpeakCapture.log]
  end

  test "says a broken shield with those left as the count drops, and nothing for a repaint at the same count" do
    box = shown(boss(2))
    box.refresh
    box.shieldCount = 1
    box.refresh
    box.refresh
    assert_equal [[t(:ss2_shield_broken, :n => 1), false]], SpeakCapture.log
  end

  test "says a rise as the new count, with the boss's name" do
    box = shown(boss(1))
    box.shieldCount = 0
    box.refresh
    SpeakCapture.clear
    box.shieldCount = 2
    box.refresh
    assert_equal [shields_line("Garchomp", 2)], SpeakCapture.lines
  end

  test "says none left rather than a count below zero when a break takes several" do
    box = shown(boss(1))
    box.shieldCount = -2
    box.refresh
    assert_equal [t(:ss2_shield_broken, :n => 0)], SpeakCapture.lines
  end

  test "keeps quiet for a box made again for the same boss, and says a new boss in that slot" do
    garchomp = boss(2)
    shown(garchomp)
    RjBossBox.new(garchomp).appear
    quiet = SpeakCapture.lines
    garchomp.pokemon = Object.new
    garchomp.name = "Hydreigon"
    RjBossBox.new(garchomp).appear
    assert_equal [[], [shields_line("Hydreigon", 2)]], [quiet, SpeakCapture.lines]
  end

  test "the info key lists the shields a boss's box paints after its marks, and nothing for another box" do
    garchomp = boss(2)
    box = RjBossBox.new(garchomp)
    plain = Fighter.new(3, "Pikachu", Object.new, nil, nil, false, nil, nil)
    scene = Scene.new("battlebox1" => box, "battlebox3" => Object.new)
    garchomp.battle = plain.battle = Battle.new(scene)
    box.shieldCount = 1
    seen = with_profile_marks { [PokeAccess::Battle.shown_marks(garchomp), PokeAccess::Battle.shown_marks(plain)] }
    assert_equal [[t(:ss2_shields, :n => 1)], []], seen
  end

  test "the HP key keeps a boss's shields at every level, once: at its end in brief, among the marks above it" do
    garchomp = Boss.new(1, "Garchomp", 50, 30, 60, nil, 2, nil)
    garchomp.battle = Battle.new(Scene.new("battlebox1" => RjBossBox.new(garchomp)))
    lines = vb_levels { with_profile_state { PokeAccess::Battle.battler_state(garchomp, true) } }
    shield = t(:ss2_shields, :n => 2)
    assert_equal [1, 1, 1], lines.map { |l| l.scan(shield).length }, lines.inspect
    assert lines[0].end_with?(shield), lines[0]
  end

  test "the boss's box keeps its own result as it repaints a broken shield" do
    box = shown(boss(2))
    box.shieldCount = 1
    assert_equal [:repainted, [t(:ss2_shield_broken, :n => 1)]], [box.refresh, SpeakCapture.lines]
  end

  test "says the crest the stock box paints beside a foe's name as it comes in" do
    foe = Fighter.new(1, "Ampharos", Object.new, nil, :AMPHAROS, false, nil, nil)
    box = PokemonDataBox.new(foe)
    box.extra = %w[Battle/battleCrest]
    box.refresh
    assert_equal [[t(:bt_marks_entry, :name => "Ampharos", :marks => t(:rj_mark_crest)), false]], SpeakCapture.log
  end

  test "names a crest lent by the trainer apart from a held one" do
    foe = Fighter.new(1, "Swalot", Object.new, nil, :SWALOT, true, nil, nil)
    box = PokemonDataBox.new(foe)
    box.extra = %w[Battle/battleApplyCrest]
    box.refresh
    assert_equal [t(:rj_mark_applied_crest)], PokeAccess::Battle.shown_marks(foe)
  end

  test "says the crest an SOS ally's box paints with its status as it comes in, and keeps it among its marks" do
    ally = Fighter.new(3, "Ampharos", Object.new, nil, :AMPHAROS, false, :POISON, nil)
    RjSosBox.new(ally)
    marks = PokeAccess::Battle.shown_marks(ally)
    assert_equal [[[t(:bt_marks_entry, :name => "Ampharos", :marks => t(:rj_mark_crest)), false]], [t(:rj_mark_crest)]],
                 [SpeakCapture.log, marks]
  end

  test "says no crest for an SOS ally with no status, as its box then draws none, and keeps the one a status brings" do
    ally = Fighter.new(3, "Ampharos", Object.new, nil, :AMPHAROS, false, nil, nil)
    box = RjSosBox.new(ally)
    bare = [SpeakCapture.lines, PokeAccess::Battle.shown_marks(ally)]
    ally.status = :SLEEP
    ret = box.refresh
    assert_equal [[[], []], :repainted, [t(:rj_mark_crest)], []],
                 [bare, ret, PokeAccess::Battle.shown_marks(ally), SpeakCapture.lines]
  end

  private

  # Garchomp, a boss across the field with the given shields.
  def boss(shields)
    Fighter.new(1, "Garchomp", Object.new, shields, nil, false, nil, nil)
  end

  # The boss's box after it came up, with what that said cleared.
  def shown(battler)
    box = RjBossBox.new(battler)
    box.appear
    SpeakCapture.clear
    box
  end

  # The line said as a boss's box comes up, or as its shields rise.
  def shields_line(name, n)
    "#{name}, #{t(:ss2_shields, :n => n)}"
  end

  # The block's value with the profile's shown_marks in core's place.
  def with_profile_marks
    meta = PokeAccess::Battle.singleton_class
    core = meta.instance_method(:shown_marks)
    meta.send(:define_method, :shown_marks, RjBattleBoxesBinding.marks)
    yield
  ensure
    meta.send(:define_method, :shown_marks, core)
  end

  # The block's value with the profile's shown_marks and battler_state in core's place.
  def with_profile_state
    meta = PokeAccess::Battle.singleton_class
    core = meta.instance_method(:battler_state)
    meta.send(:define_method, :battler_state, RjBattleBoxesBinding.state)
    with_profile_marks { yield }
  ensure
    meta.send(:define_method, :battler_state, core)
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
