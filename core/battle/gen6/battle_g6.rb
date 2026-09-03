# Gen-6 battle scene reader (PokeBattle_Scene + CommandMenuDisplay/FightMenuDisplay): battle messages,
# command/move menus, target selection, mega flag, level-up and damage. Binds only where the gen-6 scene
# classes exist; the modern battle reader is core/battle/v21/battle_v21.rb. All the spoken logic lives in the
# shared PokeAccess::Battle module (core/battle/battle.rb); these are just the gen-6 bindings.

# Battle messages, also capturing the battle for the hp and field keys.
#
# say_dialogue and not speak_clean in all three message hooks: it also files the line for the repeat key,
# which gen-6 reaches from nowhere else -- its message loop never touches Kernel.pbMessageDisplay. The
# half-second dedup inside it is what keeps the two paths from reading one line twice.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess::Battle.set_battle(scene.instance_variable_get(:@battle))
  PokeAccess.say_dialogue(args[0])
end

# Paused battle messages (exp, level up): a different method from pbDisplayMessage, so its own hook.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayPausedMessage) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# Move-target selection in doubles: reads whoever is under the cursor. hook_container because the original
# drives the display's own hooked setters.
#
# Stock gen-6 has pbUpdateSelected; a fork without it highlights through pbSelectBattler(index, 2), the same
# call the command phase makes with the default mode, so the mode is what separates choosing a target from a
# battler's turn beginning. Index -1 passes through: it is the deselect that lets re-entry read again.
if PokeAccess::Engine.has?("PokeBattle_Scene#pbUpdateSelected")
  PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbUpdateSelected, :hook_container => true) do |scene, _r, args|
    PokeAccess::Battle.announce_target(scene, args[0])
  end
else
  PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbSelectBattler, :hook_container => true) do |scene, _r, args|
    choosing = args[0].is_a?(Array) || (args[0].is_a?(Integer) && (args[1] == 2 || args[0] < 0))
    PokeAccess::Battle.announce_target(scene, args[0]) if choosing
  end
end

# Battle prompts with options: the question goes straight onto the message window, not through
# pbDisplayMessage. The yes/no list itself is a Window_CommandPokemon the generic hook already reads.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbShowCommands) do |_s, args|
  PokeAccess.say_dialogue(args[0])
end

# The four command labels, stashed as they go past: on both Infinite Fusion the display draws buttons and
# discards the strings, so this call is the only moment the labels exist. It runs before setIndexAndMode.
PokeAccess::Hooks.after_hook("CommandMenuDisplay", :setTexts) do |disp, _r, args|
  PokeAccess::Battle.stash_command_texts(disp, args[0])
end

# Command menu, which is also where the info key goes back to describing the foe. The opening read is
# queued so it does not cut the hp and turn lines; navigation interrupts.
PokeAccess::Hooks.after_hook("CommandMenuDisplay", :index=) do |disp, _r, args|
  PokeAccess::Info.set_info(:battle_foe, nil)
  PokeAccess::Battle.read_command(disp, args[0], !PokeAccess::Battle.cmd_opening_consume)
end

# From v19 on the menu opens through setIndexAndMode, which assigns @index directly and never runs index=.
# It opens on whatever command was chosen last turn, so the only other way to learn where the cursor sits is
# to press a direction, which moves off it. The flag is consumed here so the first real navigation
# interrupts instead of being queued as an open.
if PokeAccess::Engine.has?("CommandMenuDisplay#setIndexAndMode")
  PokeAccess::Hooks.after_hook("CommandMenuDisplay", :setIndexAndMode) do |disp, _r, args|
    PokeAccess::Info.set_info(:battle_foe, nil)
    PokeAccess::Battle.cmd_opening_consume
    PokeAccess::Battle.read_command(disp, args[0], false)
  end
end

# pbCommandMenu sets the initial cursor with cw.index=, so the next index= read is flagged as an open.
["PokeBattle_Scene"].each do |cn|
  ["pbCommandMenu", "pbCommandMenuEx"].each do |m|
    PokeAccess::Hooks.before_hook(cn, m) { |_s, _args| PokeAccess::Battle.cmd_opening! }
  end
end

# Move selection, read only when the focused move changes: a direction toward an empty slot does not move
# the cursor and must not count as a re-read. An empty slot passes key nil, which Cursor treats as unchanged.
#
# Bound by capability and not hooked twice: stock gen-6 declares FightMenuDisplay with setIndex, while a
# fork gives it a BattleMenuBase parent whose only cursor setter is index=.
PokeAccess::Hooks.after_hook("FightMenuDisplay",
                             (PokeAccess::Engine.has?("FightMenuDisplay#setIndex") ? :setIndex : :index=)) do |disp, _r, _a|
  PokeAccess::Battle.read_fight_move(disp)
end

# Opening the fight menu on that fork: setIndexAndMode assigns @index and @mode directly, bypassing both
# setters above. Queued, and it primes @access_mega with the opening mode so the first real toggle is still
# announced instead of being swallowed as the open.
if !PokeAccess::Engine.has?("FightMenuDisplay#setIndex") && PokeAccess::Engine.has?("FightMenuDisplay#setIndexAndMode")
  PokeAccess::Hooks.after_hook("FightMenuDisplay", :setIndexAndMode) do |disp, _r, args|
    m = args[1]
    disp.instance_variable_set(:@access_mega, m) if m == 1 || m == 2
    PokeAccess::Battle.read_fight_move(disp, false)
  end
end

# Reset the dedup when the menu is set up for a battler, so the move is read on open.
PokeAccess::Hooks.after_hook("FightMenuDisplay", :battler=) do |disp, _r, _a|
  PokeAccess::Cursor.reset(disp, :fight_move)
end

# The fight menu's mechanic buttons, one-way: announced when one flips to registered. Stock gen-6 exposes
# megaButton=; a fork keeps the same 0 hidden / 1 shown / 2 pressed state in @mode and has no such setter.
# ultraButton is a second button on the SAME key in one game, for when the active Pokemon cannot mega
# evolve, so every setter present is bound and each carries its own dedup slot.
[["megaButton=", :@access_mega, :bt_mega_on, :bt_mega_off],
 ["ultraButton=", :@access_ultra, :bt_ultra_on, :bt_ultra_off],
 ["mode=", :@access_mega, :bt_mega_on, :bt_mega_off]].each do |setter, slot, on, off|
  next unless PokeAccess::Engine.has?("FightMenuDisplay##{setter}")
  next if setter == "mode=" && PokeAccess::Engine.has?("FightMenuDisplay#megaButton=")
  PokeAccess::Hooks.after_hook("FightMenuDisplay", setter.to_sym) do |disp, _r, args|
    v = args[0]
    k = PokeAccess::Battle.mega_key(disp.instance_variable_get(slot), v, on, off)
    disp.instance_variable_set(slot, v) if v == 1 || v == 2
    PokeAccess.speak(PokeAccess::I18n.t(k), true) if k
  end
end

# Level-up stat gains, which the panel shows only as graphics. The argument order splits by era (v16-17 put
# SPEED before spatk/spdef, the v18 hybrids put it last) and nothing in the call tells them apart, so the
# era is asked once here. A local and not a constant: this file is top level, and a constant would land on
# the fangame's own Object. Before, because each stat panel blocks on a keypress.
levelup_modern_order = PokeAccess::Engine.gamedata?
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbLevelUp) do |_s, a|
  PokeAccess.speak(PokeAccess::Battle.levelup_from_args(a, levelup_modern_order), false)
end

# The damage number, which is not a message. Before, because the original waits out the HP-bar animation and
# the value is already knowable: the caller lowers hp first and passes the old one in.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbHPChanged) do |_s, args|
  PokeAccess::Battle.announce_hp_change(args[0], args[1])
end

# Silences the map sonar during a gen-6 battle. gen-6 never sets $game_temp.in_battle and runs the fight
# inside Scene_Map, so the scene checks never fire for a wild encounter. pbBattleAnimation wraps the whole
# fight, wild and trainer alike, so an around wrap holds the flag for its duration and clears it however it
# ends. No-op where the function is absent.
# Audio3D is suspended HERE as well as on the engine flag: the wild battle runs inside Game_Player#update,
# so tick -- the other silencer -- never gets another frame, and the looping channels (water, the winds)
# would keep sounding under the battle music for the whole fight.
PokeAccess::Hooks.wrap_kernel("pbBattleAnimation", "hook_battle_sonar", :around) do |args, call_next|
  PokeAccess::Battle.battle_started
  (PokeAccess::Audio3D.suspend rescue nil)
  begin
    call_next.call
  ensure
    PokeAccess::Battle.battle_ended
  end
end
