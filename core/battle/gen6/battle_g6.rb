# Gen-6 battle hooks (PokeBattle_Scene, CommandMenuDisplay, FightMenuDisplay): messages, command and move menus,
# targets, mechanic buttons, level-up and damage. The spoken logic lives in PokeAccess::Battle.
module PokeAccess
  module BattleG6
    # The scene to bind, or "" where PokeBattle_Scene only aliases Battle::Scene (Soulstones 2): the modern reader
    # binds that one, and binding both would say everything twice.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "PokeBattle_Scene", "Battle::Scene")
  end
end

# Battle messages, also capturing the battle for the hp and field keys. The message hooks use say_dialogue, which
# files the line for the repeat key (gen 6's loop never reaches Kernel.pbMessageDisplay).
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbDisplayMessage) do |scene, args|
  battle = scene.instance_variable_get(:@battle)
  PokeAccess::Battle.set_battle(battle)
  PokeAccess.say_dialogue(args[0])
  PokeAccess::Battle.announce_opening_field(battle)
end

# Paused battle messages (exp, level up): a different method from pbDisplayMessage, so its own hook.
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbDisplayPausedMessage) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# Move-target selection in doubles, through pbUpdateSelected or, on a fork without it, pbSelectBattler in mode 2
# (a spread move's array and the -1 deselect pass too). hook_container: the original drives hooked setters.
if PokeAccess::Engine.has?("#{PokeAccess::BattleG6::SCENE}#pbUpdateSelected")
  PokeAccess::Hooks.after_hook(PokeAccess::BattleG6::SCENE, :pbUpdateSelected, :hook_container => true) do |scene, _r, args|
    PokeAccess::Battle.announce_target(scene, args[0])
  end
else
  PokeAccess::Hooks.after_hook(PokeAccess::BattleG6::SCENE, :pbSelectBattler, :hook_container => true) do |scene, _r, args|
    choosing = args[0].is_a?(Array) || (args[0].is_a?(Integer) && (args[1] == 2 || args[0] < 0))
    PokeAccess::Battle.announce_target(scene, args[0]) if choosing
  end
end

# The battler choosing a target, kept on the scene while pbChooseTarget(index, ...) runs: a scene with its own fight
# menu (the Elite Battle System's) leaves the old fight window without a battler.
PokeAccess::Hooks.around_hook(PokeAccess::BattleG6::SCENE, :pbChooseTarget, :optional => true) do |scene, nxt, args|
  scene.instance_variable_set(:@access_target_chooser, args[0])
  begin
    nxt.call
  ensure
    scene.instance_variable_set(:@access_target_chooser, nil)
  end
end

# Battle prompts with options: the question goes straight onto the message window, not through
# pbDisplayMessage. The yes/no list itself is a Window_CommandPokemon the generic hook already reads.
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbShowCommands) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# Stashes the four command labels, which a display that draws buttons discards; runs before setIndexAndMode.
PokeAccess::Hooks.after_hook("CommandMenuDisplay", :setTexts) do |disp, _r, args|
  PokeAccess::Battle.stash_command_texts(disp, args[0])
end

# Command menu, which is also where the info key goes back to describing the foe. The opening read is
# queued so it does not cut the hp and turn lines; navigation interrupts.
PokeAccess::Hooks.after_hook("CommandMenuDisplay", :index=) do |disp, _r, args|
  PokeAccess::Info.set_info(:battle_foe, nil)
  PokeAccess::Battle.read_command(disp, args[0], !PokeAccess::Battle.cmd_opening_consume)
end

# The command menu opening through setIndexAndMode (v19 on), which assigns @index without index=; consumes the
# opening flag so the first navigation interrupts.
if PokeAccess::Engine.has?("CommandMenuDisplay#setIndexAndMode")
  PokeAccess::Hooks.after_hook("CommandMenuDisplay", :setIndexAndMode) do |disp, _r, args|
    PokeAccess::Info.set_info(:battle_foe, nil)
    PokeAccess::Battle.cmd_opening_consume
    PokeAccess::Battle.read_command(disp, args[0], false)
  end
end

# pbCommandMenu sets the initial cursor with cw.index=, so the next index= read is flagged as an open.
[PokeAccess::BattleG6::SCENE].each do |cn|
  ["pbCommandMenu", "pbCommandMenuEx"].each do |m|
    PokeAccess::Hooks.before_hook(cn, m) { |_s, _args| PokeAccess::Battle.cmd_opening! }
  end
end

# Move selection, off setIndex or, on a fork with a BattleMenuBase parent, index=; read when the focused move changes.
PokeAccess::Hooks.after_hook("FightMenuDisplay",
                             (PokeAccess::Engine.has?("FightMenuDisplay#setIndex") ? :setIndex : :index=)) do |disp, _r, _a|
  PokeAccess::Battle.read_fight_move(disp)
end

# The fight menu opening on that fork (setIndexAndMode, which bypasses both setters): queued, priming @access_mega
# with the opening mode; a button that opens available is said after the move.
if !PokeAccess::Engine.has?("FightMenuDisplay#setIndex") && PokeAccess::Engine.has?("FightMenuDisplay#setIndexAndMode")
  PokeAccess::Hooks.after_hook("FightMenuDisplay", :setIndexAndMode) do |disp, _r, args|
    m = args[1]
    disp.instance_variable_set(:@access_mega, m) if m.is_a?(Integer)
    PokeAccess::Battle.read_fight_move(disp, false)
    PokeAccess.speak(PokeAccess::Battle.ready_text(PokeAccess::Battle.zud_mechanic(disp)), false) if m == 1
  end
end

# Reset the dedup when the menu is set up for a battler, so the move is read on open.
PokeAccess::Hooks.after_hook("FightMenuDisplay", :battler=) do |disp, _r, _a|
  PokeAccess::Cursor.reset(disp, :fight_move)
end

# The fight menu's mechanic buttons (0 hidden, 1 shown, 2 registered), said on coming up and on each toggle; a ZUD
# toggle (mode=) is named for its mechanic, and a Z-move or dynamax one re-reads the renamed focused move.
[["megaButton=", :@access_mega, :bt_mega_on, :bt_mega_off],
 ["ultraButton=", :@access_ultra, :bt_ultra_on, :bt_ultra_off],
 ["mode=", :@access_mega, :bt_mega_on, :bt_mega_off]].each do |setter, slot, on, off|
  next unless PokeAccess::Engine.has?("FightMenuDisplay##{setter}")
  next if setter == "mode=" && PokeAccess::Engine.has?("FightMenuDisplay#megaButton=")
  PokeAccess::Hooks.after_hook("FightMenuDisplay", setter.to_sym) do |disp, _r, args|
    v = args[0]
    last = disp.instance_variable_get(slot)
    mech = (setter == "mode=") ? PokeAccess::Battle.zud_mechanic(disp) : nil
    k = mech ? PokeAccess::Battle.zud_key(mech, last, v) : PokeAccess::Battle.mega_key(last, v, on, off)
    disp.instance_variable_set(slot, v) if v.is_a?(Integer)
    if PokeAccess::Battle.mega_reveal?(last, v)
      PokeAccess.speak(PokeAccess::Battle.ready_text(mech || (setter == "ultraButton=" ? :ultra : :mega)), false)
    elsif k
      PokeAccess.speak(k.is_a?(Array) ? PokeAccess::I18n.t(k[0], :name => PokeAccess::I18n.t(k[1])) : PokeAccess::I18n.t(k), true)
      if mech == :zmove || mech == :dynamax
        PokeAccess::Cursor.reset(disp, :fight_move)
        PokeAccess::Battle.read_fight_move(disp, false)
      end
    end
  end
end

# The ability splash (v18/v19 scenes): the battler's name and ability, or the text passed in; only while the
# scene's USE_ABILITY_SPLASH is on, since with it off the effect message names the ability.
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbShowAbilitySplash, :optional => true) do |s, args|
  if (PokeBattle_SceneConstants::USE_ABILITY_SPLASH rescue true)
    shown = PokeAccess::BattleScene.splash_ability(s, args)
    PokeAccess.speak(PokeAccess::BattleScene.ability_text(args[0], shown), false)
  end
end

# Level-up stat gains, said before the original blocks on its panels, which are muted; optional, as a gen-6 lineage
# may show a stat window of its own instead (read from that game's profile). A local, not a constant (it would land
# on Object); two hooks on purpose: an around body's errors propagate, a before-hook's are swallowed.
levelup_modern_order = PokeAccess::Engine.gamedata?
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbLevelUp, :optional => true) do |_s, a|
  PokeAccess.speak(PokeAccess::Battle.levelup_from_args(a, levelup_modern_order), false)
end
PokeAccess::Hooks.around_hook(PokeAccess::BattleG6::SCENE, :pbLevelUp, :optional => true) do |_s, nxt, _a|
  PokeAccess::ModalPanel.muted { nxt.call }
end

# The hp change, said before the original animates the bar (the caller has already lowered hp and passes the old;
# the Reborn engine passes a list of such pairs and an animation flag, which hp_changed tells apart).
PokeAccess::Hooks.before_hook(PokeAccess::BattleG6::SCENE, :pbHPChanged) do |_s, args|
  PokeAccess::Battle.hp_changed(args[0], args[1])
end

# Holds the in-battle flag for the whole of pbBattleAnimation (gen 6 never sets $game_temp.in_battle) and suspends
# Audio3D, whose tick gets no frame while a wild battle runs inside Game_Player#update.
PokeAccess::Hooks.wrap_kernel("pbBattleAnimation", "hook_battle_sonar", :around) do |args, call_next|
  PokeAccess::Battle.battle_started
  (PokeAccess::Audio3D.suspend rescue nil)
  begin
    call_next.call
  ensure
    PokeAccess::Battle.battle_ended
  end
end

# The icons a databox draws beside a battler's name (battleBoxOwned, shiny, the Mega and Primal boxes), as marks.
PokeAccess::Hooks.around_hook("PokemonDataBox", :refresh, :optional => true) do |box, nxt, _a|
  PokeAccess::Battle.marks_around(box) { nxt.call }
end
