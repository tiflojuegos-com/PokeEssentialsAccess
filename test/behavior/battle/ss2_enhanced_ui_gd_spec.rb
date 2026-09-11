# Enhanced UI 1.1.2 as Soulstones 2 ships it -- an OLD release, edited by the game. The reader for the
# current release lives in plugins/ and would bind to these very method names with the wrong arities, so
# this one lives in the profile. What is pinned here is exactly that difference: the panel is driven with
# 1.1.2's signatures, and what comes out has to be the panel's own numbers.
#
# The stand-in reproduces the three things that matter and nothing else: the batch of painted rows ends with
# power, accuracy and effect chance in that order; the effectiveness strip is returned as icon rows whose
# frame index IS the verdict; and the toggles are the booleans this release uses.
module Battle
  class Scene
    attr_accessor :moveUIToggle, :infoUIToggle, :battle

    # 1.1.2: (battler, index). The current release takes (battler, specialAction, cw).
    def pbUpdateMoveInfoWindow(battler, index)
      return if !@moveUIToggle
      pbDrawTypeEffectiveness(0, 0, nil, nil)
      pbDrawTextPositions(nil, [["Placaje", 10, 8], ["Pot:", 20, 10], ["Prec:", 20, 39], ["Efec:", 30, 39],
                                [@power || "90", 40, 10], ["100", 40, 39], ["---", 50, 39]])
      drawTextEx(nil, 10, 70, 400, 2, "Un ataque fisico de embestida.")
      index
    end

    # The strip the panel draws over each foe: [file, x, y, frame * 64, 0, 64, 76].
    def pbDrawTypeEffectiveness(_x, _y, _move, _type)
      rows = (@effect_frames || []).map { |f| ["effectiveness", 0, 0, f * 64, 0, 64, 76] }
      pbDrawTypeEffectivenessResult(rows)
    end
    def pbDrawTypeEffectivenessResult(rows); rows; end
    def effect_frames=(f); @effect_frames = f; end
    def power=(p); @power = p; end

    # 1.1.2: (battler). The current release takes (battler, effects, idxEffect = 0).
    def pbUpdateBattlerInfo(battler); battler; end

    # 1.1.2: ([side, i], select). The current release takes (idxSide, idxPoke, select).
    def pbUpdateBattlerSelection(index, select = false); [index, select]; end
    def pbSelectBattlerInfo; nil; end
    def pbToggleBattleInfo; nil; end
  end
end
require File.expand_path("../../../games/soulstones2/enhanced_ui", File.dirname(__FILE__))

Suite.define("soulstones 2 enhanced ui: the move panel is read with the numbers it painted") do
  scene = Battle::Scene.new
  move = Object.new
  def move.name; "Placaje"; end
  def move.category; 0; end
  def move.type; :NORMAL; end
  def move.pbCalcType(_b); :NORMAL; end
  battler = Object.new
  battler.instance_variable_set(:@m, [move])
  def battler.moves; @m; end
  def battler.index; 0; end

  scene.moveUIToggle = true
  scene.effect_frames = [3]
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  line = SpeakCapture.lines.join(" ")
  match "the move's name leads", line, /Placaje/
  match "the POWER is the one painted, which is the whole damage calculation of this copy",
        line, /#{PokeAccess::I18n.t(:mv_power, :p => "90")}/
  match "so is the accuracy", line, /#{PokeAccess::I18n.t(:mv_acc, :a => "100")}/
  falsy "an effect chance of --- is not read as a number", line.include?("---")
  match "the effectiveness comes from the icon the game itself chose",
        line, /#{PokeAccess::I18n.t(:mv_eff_super)}/
  match "and the description the panel writes underneath is read too", line, /embestida/

  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  silent "the same panel drawn again says nothing"

  # The verdict is whatever the strip says, never recomputed: this copy decides it with a revealed-ability
  # system, custom types and custom abilities of the game's own. And staging a mechanic repaints the panel
  # with a new power WITHOUT the cursor moving, which a key made of [battler, move] would have swallowed.
  scene.effect_frames = [1]
  scene.power = "135"
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  line2 = SpeakCapture.lines.join(" ")
  match "a different icon means a different word", line2, /#{PokeAccess::I18n.t(:mv_eff_none)}/
  match "and a power that changed under a still cursor is spoken again", line2,
        /#{PokeAccess::I18n.t(:mv_power, :p => "135")}/

  # This game's strip has two frames past the vanilla five, four times and a quarter; read off a
  # five-entry table they came out as "effectiveness unknown", the opposite of what the icon says.
  scene.effect_frames = [5]
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  match "the sixth frame is four times", SpeakCapture.lines.join(" "), /#{PokeAccess::I18n.t(:mv_eff_hyper)}/
  scene.effect_frames = [6]
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  match "and the seventh a quarter", SpeakCapture.lines.join(" "), /#{PokeAccess::I18n.t(:mv_eff_barely)}/

  scene.moveUIToggle = false
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  silent "and with the panel shut there is nothing to read"
end

Suite.define("soulstones 2 enhanced ui: the battler panel and the selection grid read their own shapes") do
  scene = Battle::Scene.new
  foe = Object.new
  def foe.name; "Rival"; end
  def foe.index; 1; end
  def foe.level; 30; end
  def foe.hp; 20; end
  def foe.totalhp; 40; end
  def foe.status; :NONE; end
  def foe.pbOwnedByPlayer?; false; end
  def foe.abilityName; "Secreta"; end

  scene.infoUIToggle = true
  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(foe)
  line = SpeakCapture.lines.join(" ")
  match "a foe's panel says who and what level", line, /Rival/
  falsy "but not the ability, which its own panel keeps behind the owner check",
        line.include?("Secreta")
  falsy "nor the exact hit points", line =~ /20\s*\/\s*40|20 de 40/

  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(foe)
  silent "the same battler redrawn says nothing"

  # The panel that RUNS is the Boss Battles plugin's: it paints a foe's ability once the game has revealed
  # it, and a raid boss's shields where the player's own would show their hit points.
  saved_revealed = defined?($RevealedAbility) ? $RevealedAbility : nil
  begin
    $RevealedAbility = { 1 => { 0 => { :pkmn => foe, :abil => :SECRETA } } }
    PokeAccess::Cursor.reset(scene, :ss2_binfo)
    SpeakCapture.clear
    scene.pbUpdateBattlerInfo(foe)
    truthy "a revealed ability is read, as the panel now paints it", SpeakCapture.lines.join(" ").include?("Secreta")

    boss = Object.new
    def boss.name; "Jefe"; end
    def boss.index; 3; end
    def boss.level; 60; end
    def boss.hp; 300; end
    def boss.totalhp; 400; end
    def boss.status; :NONE; end
    def boss.pbOwnedByPlayer?; false; end
    def boss.isbossmon; true; end
    def boss.shieldCount; 2; end
    SpeakCapture.clear
    scene.pbUpdateBattlerInfo(boss)
    match "a raid boss says its shields", SpeakCapture.lines.join(" "), /#{PokeAccess::I18n.t(:ss2_shields, :n => 2)}/
  ensure
    $RevealedAbility = saved_revealed
  end

  # The grid highlights a [side, index] PAIR in this release, not two separate arguments.
  battle = Object.new
  mine = Object.new
  def mine.name; "Chispa"; end
  def mine.index; 0; end
  def mine.pokemon; self; end
  def mine.displayPokemon; self; end
  battle.instance_variable_set(:@mine, [mine])
  def battle.allSameSideBattlers; @mine; end
  def battle.allOtherSideBattlers; []; end
  def battle.pbGetOwnerFromBattlerIndex(_i); nil; end
  scene.battle = battle
  scene.instance_variable_set(:@battle, battle)

  SpeakCapture.clear
  scene.pbUpdateBattlerSelection([0, 0], false)
  eq "the pair is resolved to the battler it highlights", SpeakCapture.lines, ["Chispa"]
end
