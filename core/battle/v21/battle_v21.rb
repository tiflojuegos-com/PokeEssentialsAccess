# Battle::Scene hooks for v19-v21.1 and the Sky fork: menu navigation and opening, messages, hp changes, ability
# splash, mechanic toggles and level-up. The spoken content lives in PokeAccess::BattleScene, shared with v22.

# Battle menu navigation (command, fight, target) on index=. On v22 a target menu opening also sets index=, so
# this syncs the update_input hook's dedup ivar and that hook reads only real navigation.
PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :index=) do |menu, _r, _a|
  if defined?(::Battle::Scene::TargetMenu) && menu.is_a?(::Battle::Scene::TargetMenu)
    menu.instance_variable_set(:@access_tgt_idx, (menu.index rescue nil))
  end
  PokeAccess::BattleScene.read_menu(menu)
end

# Battle menu opening (setIndexAndMode, bypassing mode=): the first option, queued; @access_mega is primed with the
# opening mode, and a button that opens available is said after the move.
if PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")
  PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :setIndexAndMode) do |menu, _r, args|
    fight = defined?(::Battle::Scene::FightMenu) && menu.is_a?(::Battle::Scene::FightMenu)
    m = args[1]
    menu.instance_variable_set(:@access_mega, m) if fight && m.is_a?(Integer)
    PokeAccess::BattleScene.read_menu(menu, false)
    PokeAccess.speak(PokeAccess::Battle.ready_text(PokeAccess::Battle.special_action), false) if fight && m == 1
  end
end

# Battle messages (also captures the battle so the hp key can read the active battlers).
PokeAccess::Hooks.before_hook("Battle::Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess::Battle.set_battle(scene.instance_variable_get(:@battle))
  PokeAccess.say_dialogue(args[0])
end

# Paused battle messages (exp, level up).
PokeAccess::Hooks.before_hook("Battle::Scene", :pbDisplayPausedMessage) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# The question of a battle prompt with options, which pbShowCommands writes straight onto the message window;
# before, as the original is the modal loop.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbShowCommands, :optional => true) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# Damage and healing off the battler's pbReduceHP and pbRecoverHP (the scene's pbHPChanged needs an animation). The
# loss wraps the call, as an after hook would mute a plugin's messages inside; one leaving hp no lower is not said.
PokeAccess::Hooks.around_hook("Battle::Battler", :pbReduceHP) do |battler, nxt, _a|
  before = (battler.hp rescue nil)
  ret = nxt.call
  unless before && (battler.hp rescue before) >= before
    PokeAccess.speak(PokeAccess::BattleScene.hp_change_text(battler, ret, true), false)
  end
  ret
end
PokeAccess::Hooks.after_hook("Battle::Battler", :pbRecoverHP) do |battler, ret, _a|
  PokeAccess.speak(PokeAccess::BattleScene.hp_change_text(battler, ret, false), false)
end

# The ability splash, said before the original, which is the blocking animation; it runs only with the splash on.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbShowAbilitySplash) do |_s, args|
  PokeAccess.speak(PokeAccess::BattleScene.ability_text(args[0]), false)
end

# Remembers which mechanic the fight menu opens for, the second argument the Deluxe Battle Kit passes.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbFightMenu, :optional => true) do |_s, args|
  PokeAccess::Battle.note_special_action(args[1])
end

# The fight menu's special-action toggle on mode= (:optional, v22 uses mega_evolution_state=), then the renamed
# focused move again, queued. Skipped where the Deluxe Battle Kit's pbToggleSpecialActions names the mechanic.
unless PokeAccess::Engine.has?("Battle#pbToggleSpecialActions")
PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :mode=, :optional => true) do |menu, _r, args|
  if defined?(::Battle::Scene::FightMenu) && menu.is_a?(::Battle::Scene::FightMenu)
    v = args[0]
    k = PokeAccess::Battle.special_key(menu.instance_variable_get(:@access_mega), v)
    menu.instance_variable_set(:@access_mega, v) if v.is_a?(Integer)
    if k.is_a?(Array)
      PokeAccess.speak(PokeAccess::I18n.t(k[0], :name => PokeAccess::I18n.t(k[1])), true)
    elsif k
      PokeAccess.speak(PokeAccess::I18n.t(k), true)
    end
    PokeAccess::BattleScene.read_menu(menu, false) if k
  end
end
end

# The shift button coming up available (0 to 1); :optional, absent where the engine has no shift.
PokeAccess::Hooks.after_hook("Battle::Scene::FightMenu", :shiftMode=, :optional => true) do |menu, _r, args|
  v = args[0]
  PokeAccess.speak(PokeAccess::I18n.t(:bt_shift), false) if v == 1 && menu.instance_variable_get(:@access_shift) != 1
  menu.instance_variable_set(:@access_shift, v)
end

# Level-up stat gains (v18+ argument order), said before the original blocks on its panels, which are muted. Two
# hooks on purpose: an around body's errors propagate, a before-hook's are swallowed.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbLevelUp) do |_s, a|
  PokeAccess.speak(PokeAccess::Battle.levelup_from_args(a, true), false)
end
PokeAccess::Hooks.around_hook("Battle::Scene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess::ModalPanel.muted { nxt.call }
end

# The icons a databox draws beside a battler's name (icon_own, shiny, icon_mega, icon_primal), as marks.
PokeAccess::Hooks.around_hook("Battle::Scene::PokemonDataBox", :refresh, :optional => true) do |box, nxt, _a|
  PokeAccess::Battle.marks_around(box) { nxt.call }
end
