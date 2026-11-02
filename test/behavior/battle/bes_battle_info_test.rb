# Essentials BES's in-battle info screen (plugins/bes_battle_info.rb, BattleInfoScene): the grid of battlers is read as
# the cursor moves, with the balls of both teams the first time, and a battler's sheet when C opens it and as the arrows
# switch it, from the battler and the screen's own rows (the weather, the effects, the critical stage).

# The game's switches for what the sheet shows of a foe.
module BattleInfoConfig
  MOSTRAR_PS_RIVAL = true
  MOSTRAR_HABILIDAD_RIVAL = true
  MOSTRAR_OBJETO_RIVAL = true
end

# A battler as the screen reads it, its stages the engine's array of eight.
class BesInfoBattler
  attr_accessor :name, :level, :hp, :totalhp, :status, :ability, :item, :lastMoveUsed, :effects, :type1, :type2, :disguise

  def initialize(name, opts = {})
    @name = name
    @level = opts.fetch(:level, 50)
    @hp = opts.fetch(:hp, 30)
    @totalhp = opts.fetch(:totalhp, 45)
    @status = opts.fetch(:status, 0)
    @ability = opts.fetch(:ability, 9)
    @item = opts.fetch(:item, 0)
    @lastMoveUsed = opts.fetch(:last, -1)
    @stages = opts.fetch(:stages, [0] * 8)
    @effects = {}
    @type1 = opts.fetch(:type1, 3)
    @type2 = opts.fetch(:type2, 3)
  end

  def pbTypes(_real = false); [@type1, @type2].uniq; end
end

# A member of a team, as the balls count it.
BesInfoMember = Struct.new(:hp, :status) do
  def isEgg?; false; end
end

# The battle the screen reads.
class BesInfoBattle
  attr_accessor :turncount, :opponent, :weather

  def initialize(turncount = 2, opponent = true, weather = "Despejado")
    @turncount = turncount
    @opponent = opponent
    @weather = weather
  end

  def active_weather; @weather; end

  def pbParty(idx)
    if idx == 0
      [BesInfoMember.new(30, 0), BesInfoMember.new(0, 0), BesInfoMember.new(20, 2), BesInfoMember.new(10, 0)]
    else
      [BesInfoMember.new(40, 0), BesInfoMember.new(0, 0)]
    end
  end
end

# A battle whose team is longer than the balls: seven slots, an empty one and an egg among them, a member with a status
# and the seventh fainted.
class BesInfoCrowdedBattle < BesInfoBattle
  Egg = Struct.new(:hp, :status) do
    def isEgg?; true; end
  end

  def pbParty(idx)
    return super unless idx == 0
    [BesInfoMember.new(30, 0), nil, Egg.new(1, 0), BesInfoMember.new(15, 1), BesInfoMember.new(0, 0),
     BesInfoMember.new(20, 0), BesInfoMember.new(0, 0)]
  end
end

# The screen: a script of [position, details] steps, each shown for a frame, as the loop's frames repaint it.
class BattleInfoScene
  def initialize(battle, all, own_count, script)
    @battle = battle
    @all_battlers = all
    @player_battlers = all[0, own_count]
    @opponent_battlers = all[own_count..-1]
    @position = 0
    @show_details = false
    @script = script
  end

  def main
    @script.each do |position, details|
      @position = position
      @show_details = details
      PokeAccess::Frame.run_pollers
    end
    :closed
  end

  def get_critical_stage(_battler); @crit || 0; end
  def get_display_pokemon(battler); battler.disguise || battler; end
  def get_all_battle_effects; @effects || []; end

  def with(crit, effects)
    @crit = crit
    @effects = effects
    self
  end
end

# The plugin's registrations bound to the stand-in (the harness's own load of the file ran before it existed).
eval(Harness.source(File.join(Harness::ROOT, "plugins", "bes_battle_info.rb")).split(/^end\n/, 2)[1], TOPLEVEL_BINDING,
     "plugins/bes_battle_info.rb")

class BesBattleInfoTest < PokeAccessTest
  T = PokeAccess::I18n
  ME = BesInfoBattler.new("Pikachu", :level => 52, :hp => 31, :totalhp => 45, :ability => 9, :item => 1, :last => 85,
                          :stages => [0, 2, -1, 0, 0, 0, 1, 0], :type1 => 13, :type2 => 13)
  FOE = BesInfoBattler.new("Onix", :level => 48, :hp => 10, :totalhp => 80, :status => 1, :ability => 5, :item => 0,
                           :type1 => 5, :type2 => 4)
  EFFECTS = ["Confuso", "Enamorado", "Pantalla de Luz", "Reflejo", "Gravedad", "Sol"]

  test "the grid reads the battler under the cursor with its side, and the balls of both teams the first time" do
    scene([[0, false], [1, false]]).main
    teams = "#{lineup(:bt_side_yours, [[:dbk_lineup_ok, 2], [:dbk_lineup_status, 1], [:dbk_lineup_fainted, 1]])}. " \
            "#{lineup(:bt_side_foe, [[:dbk_lineup_ok, 1], [:dbk_lineup_fainted, 1]])}"
    first = "#{T.t(:list_entry, :name => "Pikachu, #{T.t(:bt_target_self)}", :n => 1, :tot => 2)}. #{teams}"
    second = T.t(:list_entry, :name => "Onix, #{T.t(:bt_target_foe)}", :n => 2, :tot => 2)
    assert_equal [[first, false], [second, true]], SpeakCapture.log
  end

  test "the info key keeps the grid's battler and both teams, past the first read, and its row the battler alone" do
    scene([[0, false], [1, false]]).main
    second = T.t(:list_entry, :name => "Onix, #{T.t(:bt_target_foe)}", :n => 2, :tot => 2)
    assert_includes PokeAccess::Info.info_text, second
    assert_includes PokeAccess::Info.info_text, lineup(:bt_side_foe, [[:dbk_lineup_ok, 1], [:dbk_lineup_fainted, 1]])
    assert_equal second, PokeAccess::Info.row_text
  end

  test "a foe's place in the grid says it is the foe's" do
    scene([[1, false]]).main
    assert_includes SpeakCapture.lines.first, "Onix, #{T.t(:bt_target_foe)}"
  end

  test "a battle with no trainer opposite says the player's team alone" do
    scene([[0, false]], BesInfoBattle.new(2, false)).main
    assert_includes SpeakCapture.lines.first, T.t(:bt_side_yours)
    refute_includes SpeakCapture.lines.first, T.t(:bt_side_foe)
  end

  test "the sheet of the player's own battler says who it is, its HP, changes, types, ability, item, last move, weather and turn" do
    scene([[0, true]]).main
    changes = PokeAccess::Battle.stat_changes(ME).sub(/\A[.,]\s*/, "")
    want = PokeAccess.sentences([T.t(:sum_whose, :name => "Pikachu", :level => 52), T.t(:bt_hp_exact, :hp => 31, :tot => 45),
                                 changes, T.t(:bt_type, :t => "Tipo13"), T.t(:dbk_ability, :a => "Habilidad9"),
                                 T.t(:dbk_item, :i => "Pocion"), T.t(:dbk_lastmove, :m => "Mov85"),
                                 T.t(:bt_weather, :w => "Despejado"), T.t(:dbk_turn, :n => 3)])
    assert_equal [[want, false]], SpeakCapture.log
  end

  test "the sheet says the critical stage and every effect, not the five the screen shows at a time" do
    scene([[0, true]]).with(2, EFFECTS).main
    said = SpeakCapture.lines.first
    assert_includes said, "#{T.t(:dbk_crit)} +2"
    assert_includes said, T.t(:ss2_effects, :list => EFFECTS.join(", "))
  end

  test "the sheet of a foe says its status and the ability and item the game shows" do
    scene([[1, true]]).main
    said = SpeakCapture.lines.first
    assert_includes said, T.t(PokeAccess::Config.status_names[1])
    assert_includes said, T.t(:dbk_ability, :a => "Habilidad5")
    assert_includes said, T.t(:dbk_item, :i => T.t(:sum_none))
  end

  test "a foe's HP, status, ability and item are left out where the game does not show them" do
    switch_off(:MOSTRAR_PS_RIVAL, :MOSTRAR_HABILIDAD_RIVAL, :MOSTRAR_OBJETO_RIVAL) { scene([[1, true]]).main }
    said = SpeakCapture.lines.first
    refute_includes said, T.t(:bt_hp_exact, :hp => 10, :tot => 80)
    refute_includes said, T.t(PokeAccess::Config.status_names[1])
    refute_includes said, "Habilidad5"
    refute_includes said, T.t(:sum_none)
  end

  test "the types are the ones the sheet paints, not the ones a move changed in battle" do
    soaked = BesInfoBattler.new("Squirtle", :type1 => 11, :type2 => 11)
    soaked.define_singleton_method(:pbTypes) { |_real = false| [3] }
    BattleInfoScene.new(BesInfoBattle.new, [soaked, FOE], 1, [[0, true]]).main
    assert_includes SpeakCapture.lines.first, T.t(:bt_type, :t => "Tipo11")
  end

  test "under Illusion the types are the disguise's" do
    disguised = BesInfoBattler.new("Zoroark", :type1 => 17, :type2 => 17)
    disguised.disguise = Struct.new(:type1, :type2).new(5, 4)
    BattleInfoScene.new(BesInfoBattle.new, [disguised, FOE], 1, [[0, true]]).main
    said = SpeakCapture.lines.first
    assert_includes said, T.t(:bt_type, :t => "Tipo5 Tipo4")
    refute_includes said, "Tipo17"
  end

  test "the player's own battler keeps its HP, ability and item where the game hides a foe's" do
    switch_off(:MOSTRAR_PS_RIVAL, :MOSTRAR_HABILIDAD_RIVAL, :MOSTRAR_OBJETO_RIVAL) { scene([[0, true]]).main }
    said = SpeakCapture.lines.first
    assert_includes said, T.t(:bt_hp_exact, :hp => 31, :tot => 45)
    assert_includes said, T.t(:dbk_ability, :a => "Habilidad9")
    assert_includes said, T.t(:dbk_item, :i => "Pocion")
  end

  test "a foe's ability or item is said where only its own switch is on" do
    switch_off(:MOSTRAR_PS_RIVAL, :MOSTRAR_OBJETO_RIVAL) { scene([[1, true]]).main }
    switch_off(:MOSTRAR_PS_RIVAL, :MOSTRAR_HABILIDAD_RIVAL) { scene([[1, true]]).main }
    ability, item = SpeakCapture.lines
    assert_includes ability, "Habilidad5"
    refute_includes ability, T.t(:sum_none)
    assert_includes item, T.t(:dbk_item, :i => T.t(:sum_none))
    refute_includes item, "Habilidad5"
  end

  test "a screen with no battler under the cursor reads nothing" do
    assert_nil PokeAccess::BesBattleInfo.reading(Object.new)
    past = scene([[0, false]])
    past.instance_variable_set(:@position, 5)
    assert_nil PokeAccess::BesBattleInfo.reading(past)
  end

  test "a grid with no battle behind it says the battler alone" do
    BattleInfoScene.new(nil, [ME, FOE], 1, [[0, false]]).main
    assert_equal [[T.t(:list_entry, :name => "Pikachu, #{T.t(:bt_target_self)}", :n => 1, :tot => 2), false]],
                 SpeakCapture.log
  end

  test "the balls count six members at most, leave out eggs and empty slots, and tell a status from healthy" do
    scene([[0, false]], BesInfoCrowdedBattle.new).main
    want = lineup(:bt_side_yours, [[:dbk_lineup_ok, 2], [:dbk_lineup_status, 1], [:dbk_lineup_fainted, 1]])
    assert_includes SpeakCapture.lines.first, want
  end

  test "a critical stage of 1 is said, and none of 0" do
    scene([[0, true]]).with(1, []).main
    scene([[1, true]]).with(0, []).main
    stage, none = SpeakCapture.lines
    assert_includes stage, "#{T.t(:dbk_crit)} +1"
    refute_includes none, T.t(:dbk_crit)
  end

  test "a battler that has used no move and a battle with no weather say neither" do
    fresh = BesInfoBattler.new("Eevee", :last => 0)
    BattleInfoScene.new(BesInfoBattle.new(2, true, ""), [fresh, FOE], 1, [[0, true]]).main
    said = SpeakCapture.lines.first
    refute_includes said, T.t(:dbk_lastmove, :m => "Mov0")
    refute_includes said, T.t(:bt_weather, :w => "")
  end

  test "reading the sheet again on the same battler says nothing, switching battler or mode reads again" do
    scene([[0, true], [0, true], [1, true], [1, false]]).main
    assert_equal [false, true, true], SpeakCapture.log.map { |_, interrupt| interrupt }
  end

  test "the whole sheet reaches the info key" do
    scene([[0, true]]).main
    assert_equal SpeakCapture.lines.first, PokeAccess::Info.info_text
  end

  test "brief verbosity says who it is, the HP, the changes and the effects, and not the rest" do
    lines = vb_levels do
      SpeakCapture.clear
      scene([[0, true]]).with(0, ["Confuso"]).main
      SpeakCapture.lines.first
    end
    assert_includes lines[0], T.t(:bt_hp_exact, :hp => 31, :tot => 45)
    assert_includes lines[0], T.t(:ss2_effects, :list => "Confuso")
    refute_includes lines[0], T.t(:dbk_ability, :a => "Habilidad9")
    assert_includes lines[1], T.t(:dbk_ability, :a => "Habilidad9")
    refute_includes lines[1], T.t(:dbk_turn, :n => 3)
    assert_includes lines[2], T.t(:dbk_turn, :n => 3)
  end

  private

  def scene(script, battle = BesInfoBattle.new)
    BattleInfoScene.new(battle, [ME, FOE], 1, script)
  end

  def lineup(side, counts)
    T.t(:dbk_lineup, :name => T.t(side), :list => counts.map { |key, n| T.t(key, :n => n) }.join(", "))
  end

  def switch_off(*names)
    saved = names.map { |n| [n, BattleInfoConfig.const_get(n)] }
    names.each do |n|
      BattleInfoConfig.send(:remove_const, n)
      BattleInfoConfig.const_set(n, false)
    end
    yield
  ensure
    saved.each do |n, v|
      BattleInfoConfig.send(:remove_const, n)
      BattleInfoConfig.const_set(n, v)
    end
  end
end
