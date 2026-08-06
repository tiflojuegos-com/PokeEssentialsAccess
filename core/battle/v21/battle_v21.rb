# GameData-era Essentials battle hooks (Battle::Scene), for v19-v21.1 vanilla and the Sky fork. These bind the
# triggers specific to this engine's menus (navigation via index=, opening via setIndexAndMode, the mega and
# shift toggles via mode=/shiftMode=) and route the spoken content through the engine-agnostic
# PokeAccess::BattleScene reader (core/battle/scene_reader.rb), shared with v22. Each hook binds only where
# the class/method exists, so it no-ops on gen-6 (no Battle::Scene) and never logs a false typo where a
# method is absent. Content uses the modern GameData API (inside BattleScene).

# Battle menu navigation (command / fight / target): index= fires on each move of the cursor (Sky fork and
# v19-v21). On v22 vanilla it also fires ONCE when the target menu opens (cw.index = pbFirstTarget), and the
# v22 TargetMenu#update_input hook would then re-read the same slot a frame later -- so sync that hook's
# dedup ivar here, making index= own the open read and update_input own only real navigation (no double-read).
PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :index=) do |menu, _r, _a|
  if defined?(::Battle::Scene::TargetMenu) && menu.is_a?(::Battle::Scene::TargetMenu)
    menu.instance_variable_set(:@access_tgt_idx, (menu.index rescue nil))
  end
  PokeAccess::BattleScene.read_menu(menu)
end

# Battle menu opening (v21.1 vanilla AND the Sky fork both use setIndexAndMode): places the initial cursor,
# so the first option is read, queued (interrupt false) so the reopening command menu does not cut the
# hp/turn lines. Bound only where the method exists, so v22 (which opens via set_index_and_commands, handled
# in battle_v22) does not record a false typo in Hooks.missing.
# setIndexAndMode assigns @mode directly (NOT via the mode= setter), so the mega hook below never sees the
# fight menu open; prime @access_mega with the opening mode (arg 1: 1=available, 0=hidden) so the first real
# available->registered toggle is announced instead of being swallowed as if it were the open. Mirrors how
# v22 primes @access_mega via its mega_evolution_state= reveal.
if PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")
  PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :setIndexAndMode) do |menu, _r, args|
    if defined?(::Battle::Scene::FightMenu) && menu.is_a?(::Battle::Scene::FightMenu)
      m = args[1]
      menu.instance_variable_set(:@access_mega, m) if m == 1 || m == 2
    end
    PokeAccess::BattleScene.read_menu(menu, false)
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

# Damage and healing: the scene's pbHPChanged only fires when an animation plays, so it misses many hits.
# The battler's pbReduceHP/pbRecoverHP run for every hp change and return the actual amount, so they are
# the reliable place to announce it.
PokeAccess::Hooks.after_hook("Battle::Battler", :pbReduceHP) do |battler, ret, _a|
  PokeAccess.speak(PokeAccess::BattleScene.hp_change_text(battler, ret, true), false)
end
PokeAccess::Hooks.after_hook("Battle::Battler", :pbRecoverHP) do |battler, ret, _a|
  PokeAccess.speak(PokeAccess::BattleScene.hp_change_text(battler, ret, false), false)
end

# Ability trigger: the scene splash is graphic-only, so announce which battler's ability fired (runs only
# when the splash is shown; off, the effect message names the ability instead).
PokeAccess::Hooks.after_hook("Battle::Scene", :pbShowAbilitySplash) do |_s, _r, args|
  PokeAccess.speak(PokeAccess::BattleScene.ability_text(args[0]), false)
end

# Which mechanic the fight menu is being opened for, remembered before the toggle below can be asked about
# it. :optional because only the Deluxe Battle Kit takes this second parameter.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbFightMenu, :optional => true) do |_s, args|
  PokeAccess::Battle.note_special_action(args[1])
end

# Special-action button toggle: mode= is shared by MenuBase subclasses, so gate to the FightMenu and announce
# only a real available(1)<->registered(2) toggle, not the initial open. :optional because v22 uses
# mega_evolution_state= instead (handled in battle_v22), so its absence is variance, not a typo.
PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :mode=, :optional => true) do |menu, _r, args|
  if defined?(::Battle::Scene::FightMenu) && menu.is_a?(::Battle::Scene::FightMenu)
    v = args[0]
    k = PokeAccess::Battle.special_key(menu.instance_variable_get(:@access_mega), v)
    menu.instance_variable_set(:@access_mega, v) if v == 1 || v == 2
    if k.is_a?(Array)
      PokeAccess.speak(PokeAccess::I18n.t(k[0], :name => PokeAccess::I18n.t(k[1])), true)
    elsif k
      PokeAccess.speak(PokeAccess::I18n.t(k), true)
    end
  end
end

# Shift button (multi-battle, modern only): announce when it becomes available (0 -> 1). :optional --
# absent where the engine has no shift mechanic.
PokeAccess::Hooks.after_hook("Battle::Scene::FightMenu", :shiftMode=, :optional => true) do |menu, _r, args|
  v = args[0]
  PokeAccess.speak(PokeAccess::I18n.t(:bt_shift), false) if v == 1 && menu.instance_variable_get(:@access_shift) != 1
  menu.instance_variable_set(:@access_shift, v)
end

# Level-up stat gains (modern): the panel is graphic-only. Every game with this scene class uses the v18+
# argument order, so the era question the gen-6 binding has to ask is already answered here.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbLevelUp) do |_s, _r, a|
  PokeAccess.speak(PokeAccess::Battle.levelup_from_args(a, true), false)
end
