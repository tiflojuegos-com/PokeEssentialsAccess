# Enhanced UI 1.1.2 as Soulstones 2 ships it, old and edited (its reader lives in the profile), driven with 1.1.2's
# signatures. The stand-in paints power, accuracy and effect chance last, returns the effectiveness strip as icon rows
# whose frame is the verdict, and uses this release's boolean toggles.
module Battle
  class Scene
    attr_accessor :moveUIToggle, :infoUIToggle, :battle

    # 1.1.2: (battler, index). The current release takes (battler, specialAction, cw).
    def pbUpdateMoveInfoWindow(battler, index)
      return if !@moveUIToggle
      pbDrawMoveFlagIcons(0, 0, nil)
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

    # 1.1.2 takes (xpos, ypos, move), the release adds imagePos; the icons come back as [file, x, y, frame * 26, 0,
    # 26, 28] rows, in the order the panel draws them.
    def pbDrawMoveFlagIcons(_x, _y, _move)
      (@flag_frames || []).map { |f| ["icons", 5, 32, f * 26, 0, 26, 28] }
    end
    def flag_frames=(f); @flag_frames = f; end

    # 1.1.2: (battler). The current release takes (battler, effects, idxEffect = 0). The effects come from
    # pbAddEffectsDisplay's text rows, a name and a count per effect.
    def pbUpdateBattlerInfo(battler); pbAddEffectsDisplay(0, 0, 0, battler); battler; end
    def pbAddEffectsDisplay(_x, _y, _panel_x, _battler)
      rows = (@effect_rows || []).map { |n, c| [[n, 321, 140, 2, nil, nil], [c, 425, 140, 2, nil, nil]] }
      [[], rows.flatten(1)]
    end
    def effect_rows=(r); @effect_rows = r; end

    # Confirming, cancelling or ending the fight menu hides the move panel without repainting it.
    def pbHideMoveInfo; @moveUIToggle = false; end

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

  scene.effect_frames = [1]
  scene.power = "135"
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  line2 = SpeakCapture.lines.join(" ")
  match "a different icon means a different word", line2, /#{PokeAccess::I18n.t(:mv_eff_none)}/
  match "and a power that changed under a still cursor is spoken again", line2,
        /#{PokeAccess::I18n.t(:mv_power, :p => "135")}/

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

  scene.moveUIToggle = true
  bs = PokeAccess::BattleScene
  bs.instance_variable_set(:@panel_shut, false)
  bs.instance_variable_set(:@fight_line, [0, 0, ["Placaje", "PP 35 de 35"]])
  PokeAccess::Cursor.reset(scene, :ss2_move)
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  moved = SpeakCapture.lines.join(" ")
  falsy "the name the fight line has just said is not said again", moved.include?("Placaje")
  match "and what it did not say is", moved, /embestida/

  PokeAccess::Cursor.changed?(scene, :ss2_move, ["Placaje"])
  PokeAccess::BattleScene.instance_variable_set(:@panel_shut, false)
  scene.pbHideMoveInfo
  eq "hiding the panel lets its slot go", PokeAccess::Cursor.current(scene, :ss2_move), nil
  eq "and marks the next line as an opening", PokeAccess::BattleScene.instance_variable_get(:@panel_shut), true
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

  hidden = Object.new
  def hidden.celestial?; true; end
  eq "a type the panel hides as ??? is said as the word it means, not as marks a reader drops",
     PokeAccess::SS2EnhancedUI.types(hidden),
     PokeAccess::I18n.t(:mv_type, :t => PokeAccess::I18n.t(:pdx_unknown_short))

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

  def mine.gender; 1; end
  PokeAccess::Cursor.reset(scene, :ss2_bsel)
  SpeakCapture.clear
  scene.pbUpdateBattlerSelection([0, 0], false)
  eq "and says the sex icon the slot draws", SpeakCapture.lines, ["Chispa \xE2\x99\x80"]

  shown = Object.new
  def shown.name; "Absol"; end
  def shown.gender; 1; end
  hidden = Object.new
  def hidden.name; "Zoroark"; end
  def hidden.gender; 0; end
  zoro = Object.new
  zoro.instance_variable_set(:@shown, shown)
  zoro.instance_variable_set(:@hidden, hidden)
  def zoro.name; "Absol"; end
  def zoro.index; 1; end
  def zoro.level; 30; end
  def zoro.hp; 20; end
  def zoro.totalhp; 40; end
  def zoro.status; :NONE; end
  def zoro.pbOwnedByPlayer?; false; end
  def zoro.opposes?; true; end
  def zoro.displayPokemon; @shown; end
  def zoro.pokemon; @hidden; end
  def shown.types; [:ELECTRIC]; end
  def hidden.types; [:DARK]; end
  def zoro.pbTypes(_all); [:DARK]; end
  def zoro.effects; @eff ||= { PBEffects::Illusion => @shown }; end
  PokeAccess::Cursor.reset(scene, :ss2_binfo)
  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(zoro)
  line = SpeakCapture.lines.join(" ")
  truthy "the battler panel says the sign of the Pokemon a foe displays", line.include?("\xE2\x99\x80")
  falsy "never the one Illusion hides", line.include?("\xE2\x99\x82")
  truthy "the types are the disguise's, which is what the panel draws",
         line.include?(PokeAccess::Data.type_name(:ELECTRIC).to_s)
  falsy "never the real ones, which would give the illusion away",
        line.include?(PokeAccess::Data.type_name(:DARK).to_s)

  own = Object.new
  own.instance_variable_set(:@hidden, hidden)
  def own.name; "Absol"; end
  def own.index; 0; end
  def own.level; 30; end
  def own.hp; 20; end
  def own.totalhp; 40; end
  def own.status; :NONE; end
  def own.pbOwnedByPlayer?; true; end
  def own.opposes?; false; end
  def own.pokemon; @hidden; end
  PokeAccess::Cursor.reset(scene, :ss2_binfo)
  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(own)
  truthy "the player's own is named and signed as it is, as its panel paints it",
         SpeakCapture.lines.join(" ").start_with?("Zoroark, \xE2\x99\x82")
end

# The effects list under the panel (weather, terrain, screens, hazards, each with the turns it has left) is
# read as the panel lists it, with the counts it paints.
Suite.define("soulstones 2 enhanced ui: the battler panel reads the effects it lists") do
  scene = Battle::Scene.new
  mon = Object.new
  def mon.name; "Chispa"; end
  def mon.index; 0; end
  def mon.level; 12; end
  def mon.pbOwnedByPlayer?; true; end
  scene.infoUIToggle = true
  scene.effect_rows = [["Reflect", "3/5"], ["Stealth Rocks", ""], ["Trick Room", "---"]]

  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(mon)
  line = SpeakCapture.lines.join(" ")
  truthy "each effect with the count the panel paints, and none where it paints none",
         line.include?(PokeAccess::I18n.t(:ss2_effects, :list => "Reflect 3/5, Stealth Rocks, Trick Room"))

  scene.effect_rows = []
  PokeAccess::Cursor.reset(scene, :ss2_binfo)
  SpeakCapture.clear
  scene.pbUpdateBattlerInfo(mon)
  falsy "with nothing in play there is no effects part at all",
        SpeakCapture.lines.join(" ").include?(PokeAccess::I18n.t(:ss2_effects, :list => "").strip)
end

# The row of flag icons under the move's name (pbDrawMoveFlagIcons): protection and Mirror Move first, then the
# move's own flags, each frame a flag; the words name the moves as the game does.
Suite.define("soulstones 2 enhanced ui: the move panel says the flag icons it drew") do
  t = PokeAccess::I18n
  scene = Battle::Scene.new
  move = Object.new
  def move.name; "Puño Fuego"; end
  def move.category; 0; end
  def move.type; :FIRE; end
  def move.pbCalcType(_b); :FIRE; end
  battler = Object.new
  battler.instance_variable_set(:@m, [move])
  def battler.moves; @m; end
  def battler.index; 0; end
  PokeAccess::BattleScene.instance_variable_set(:@fight_line, nil)
  PokeAccess::BattleScene.panel_shut
  scene.moveUIToggle = true

  scene.flag_frames = [2, 3, 4, 9]
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  words = [t.t(:dbk_flag_noprotect, :move => PokeAccess::Data.move_name(:PROTECT)),
           t.t(:dbk_flag_nomirror, :move => PokeAccess::Data.move_name(:MIRRORMOVE)),
           t.t(:dbk_flag_contact), t.t(:dbk_flag_punch)]
  match "the icons are said as the panel draws them", SpeakCapture.lines.join(" "),
        /#{Regexp.escape(t.t(:dbk_flags, :list => words.join(", ")))}/
  match "the crossed shield names Protect as the game names it", SpeakCapture.lines.join(" "), /MovePROTECT/

  scene.flag_frames = [5, 16]
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  words = [t.t(:dbk_flag_minimize, :move => PokeAccess::Data.move_name(:MINIMIZE)), t.t(:dbk_flag_wind)]
  match "another move's icons are its own", SpeakCapture.lines.join(" "),
        /#{Regexp.escape(t.t(:dbk_flags, :list => words.join(", ")))}/

  scene.flag_frames = []
  SpeakCapture.clear
  scene.pbUpdateMoveInfoWindow(battler, 0)
  falsy "and a move that draws none has no properties part", SpeakCapture.lines.join(" ").include?(t.t(:dbk_flags, :list => "").strip)
  scene.pbHideMoveInfo
end

# The selection grid draws, for each trainer with a Pokemon still able to fight, a row of NUM_BALLS balls: healthy,
# with a status condition, fainted or an empty slot. The foes' rows sit on top.
Suite.define("soulstones 2 enhanced ui: the selection grid says each trainer's ball lineup as it opens") do
  t = PokeAccess::I18n
  mon = lambda do |able, status|
    pk = Object.new
    pk.instance_variable_set(:@able, able)
    pk.instance_variable_set(:@status, status)
    def pk.able?; @able; end
    def pk.status; @status; end
    pk
  end
  trainer = lambda do |name, party|
    tr = Object.new
    tr.instance_variable_set(:@name, name)
    tr.instance_variable_set(:@party, party)
    def tr.name; @name; end
    def tr.party; @party; end
    def tr.able_pokemon_count; @party.count { |p| p.able? }; end
    tr
  end
  foe = trainer.call("Kai", [mon.call(true, :NONE), mon.call(true, :POISON), mon.call(false, :NONE), mon.call(true, :NONE)])
  me = trainer.call("Tester", [mon.call(true, :NONE)])
  gone = trainer.call("Nadie", [mon.call(false, :NONE)])
  battle = Object.new
  battle.instance_variable_set(:@foes, [foe, gone])
  battle.instance_variable_set(:@mine, [me])
  def battle.opponent; @foes; end
  def battle.player; @mine; end
  def battle.allSameSideBattlers; []; end
  def battle.allOtherSideBattlers; []; end
  scene = Battle::Scene.new
  scene.instance_variable_set(:@battle, battle)
  scene.infoUIToggle = true

  SpeakCapture.clear
  scene.pbUpdateBattlerSelection([0, 0], true)
  kai = t.t(:dbk_lineup, :name => "Kai", :list => [t.t(:dbk_lineup_ok, :n => 2), t.t(:dbk_lineup_status, :n => 1),
                                                   t.t(:dbk_lineup_fainted, :n => 1)].join(", "))
  mine = t.t(:dbk_lineup, :name => "Tester", :list => t.t(:dbk_lineup_ok, :n => 1))
  eq "the foes' lineup first, then the player's, queued; a trainer with none able draws none",
     SpeakCapture.log, [["#{kai}. #{mine}", false]]

  SpeakCapture.clear
  scene.pbUpdateBattlerSelection([0, 0], false)
  silent "a repaint while the grid is up does not say them again"

  scene.infoUIToggle = false
  SpeakCapture.clear
  scene.pbUpdateBattlerSelection([0, 0], true)
  silent "and with the panel shut, which paints nothing, neither"
end

# The battler panel's last row, Crit. Hit, draws an arrow per Focus Energy and critical boost stage, four at most.
Suite.define("soulstones 2 enhanced ui: the battler panel says the Crit. Hit row's arrows with the stat changes") do
  t = PokeAccess::I18n
  made = []
  { :FocusEnergy => 901, :CriticalBoost => 902 }.each do |c, v|
    next if PBEffects.const_defined?(c)
    PBEffects.const_set(c, v)
    made.push(c)
  end
  begin
    mon = Object.new
    def mon.name; "Chispa"; end
    def mon.index; 0; end
    def mon.level; 12; end
    def mon.pbOwnedByPlayer?; true; end
    mon.instance_variable_set(:@stages, { :ATTACK => 1 })
    mon.instance_variable_set(:@fx, { PBEffects::FocusEnergy => 2, PBEffects::CriticalBoost => 1 })
    def mon.effects; @fx; end
    stat = PokeAccess::Data.stat_name(:ATTACK)
    crit = t.t(:dbk_crit)
    line = PokeAccess::SS2EnhancedUI.battler_text(mon).to_s
    match "the crit arrows follow the stat stages", line, /#{Regexp.escape(stat)} \+1, #{Regexp.escape(crit)} \+3/

    mon.instance_variable_set(:@fx, { PBEffects::FocusEnergy => 3, PBEffects::CriticalBoost => 3 })
    match "the row draws four arrows at most", PokeAccess::SS2EnhancedUI.battler_text(mon).to_s,
          /#{Regexp.escape(crit)} \+4/

    mon.instance_variable_set(:@stages, {})
    mon.instance_variable_set(:@fx, { PBEffects::FocusEnergy => 2 })
    line = PokeAccess::SS2EnhancedUI.battler_text(mon).to_s
    match "alone, it takes the changes wording", line,
          /#{Regexp.escape(t.t(:bt_changes, :list => "#{crit} +2").sub(/\A[.,]\s*/, ""))}/

    mon.instance_variable_set(:@fx, {})
    falsy "and with no arrow it is not said", PokeAccess::SS2EnhancedUI.battler_text(mon).to_s.include?(crit)
  ensure
    made.each { |c| PBEffects.send(:remove_const, c) }
  end
end
