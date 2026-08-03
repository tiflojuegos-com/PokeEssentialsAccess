# Gen-6 battle scene reader (PokeBattle_Scene + CommandMenuDisplay/FightMenuDisplay): battle messages,
# command/move menus, target selection, mega flag, level-up and damage. Binds only where the gen-6 scene
# classes exist; the modern battle reader is core/battle/v21/battle_v21.rb. All the spoken logic lives in the
# shared PokeAccess::Battle module (core/battle/battle.rb); these are just the gen-6 bindings.

# Battle messages (also captures the battle for the hp/field keys).
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess::Battle.set_battle(scene.instance_variable_get(:@battle))
  PokeAccess.speak_clean(args[0], false)
end

# Paused battle messages (exp gained, level up): routed via pbDisplayPaused, a different method than
# pbDisplayMessage, so it needs its own hook.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayPausedMessage) do |_s, args|
  PokeAccess.speak_clean(args[0], false)
end

# Move-target selection in doubles: read whoever is under the cursor as it moves. hook_container because the
# original drives the command/fight display's own hooked index setters internally; guarding it would mute
# those readers.
#
# Stock gen-6 has pbUpdateSelected(index), which exists for exactly this. Some forks dropped it and
# their pbChooseTarget highlights through pbSelectBattler(index, 2) instead -- the same call the
# command phase uses with the default mode, so the mode argument is what separates "choosing a target" from
# "this battler's turn began" and keeps the second from being announced. A bare -1 still passes: that is
# pbChooseTarget deselecting on the way out, which is what lets re-entering selection read again.
if PokeAccess::Engine.has?("PokeBattle_Scene#pbUpdateSelected")
  PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbUpdateSelected, :hook_container => true) do |scene, _r, args|
    PokeAccess::Battle.announce_target(scene, args[0])
  end
else
  PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbSelectBattler, :hook_container => true) do |scene, _r, args|
    choosing = args[0].is_a?(Integer) && (args[1] == 2 || args[0] < 0)
    PokeAccess::Battle.announce_target(scene, args[0]) if choosing
  end
end

# Battle prompts with options (yes/no like "give a nickname?", fainted-pokemon choices): the question
# text is set straight on the message window, not via pbDisplayMessage, so it is read here; the Si/No
# options are a Window_CommandPokemon read by the generic hook.
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbShowCommands) do |_s, args|
  PokeAccess.speak_clean(args[0], false)
end

# Command menu (also resets the info key to read the foe here). The first read after the menu opens is
# queued so it does not cut the hp/turn lines; navigation interrupts.
PokeAccess::Hooks.after_hook("CommandMenuDisplay", :index=) do |disp, _r, args|
  PokeAccess::Info.set_info(:battle_foe, nil)
  PokeAccess::Battle.read_command(disp, args[0], !PokeAccess::Battle.cmd_opening_consume)
end

# Opening the command menu from v19 on: setIndexAndMode assigns @index DIRECTLY, so index= never runs and
# the menu opened in silence -- and it opens on whatever command you chose last turn, so the only way to
# learn where the cursor was would be to press a direction, which moves you off it. This is the same hole
# the FightMenuDisplay block below already closes for the move list; the command menu never got it. The
# flag is consumed here so the first real navigation still interrupts instead of being queued as if it
# were the open. Pre-v19 has no such method, so this installs nowhere it is not needed.
if PokeAccess::Engine.has?("CommandMenuDisplay#setIndexAndMode")
  PokeAccess::Hooks.after_hook("CommandMenuDisplay", :setIndexAndMode) do |disp, _r, args|
    PokeAccess::Info.set_info(:battle_foe, nil)
    PokeAccess::Battle.cmd_opening_consume
    PokeAccess::Battle.read_command(disp, args[0], false)
  end
end

# The command menu opens at the start of the command phase via pbCommandMenu/Ex (which sets the initial
# cursor with cw.index=), so flag the next index= read as an open.
["PokeBattle_Scene"].each do |cn|
  ["pbCommandMenu", "pbCommandMenuEx"].each do |m|
    PokeAccess::Hooks.before_hook(cn, m) { |_s, _args| PokeAccess::Battle.cmd_opening! }
  end
end

# Move selection: read only when the focused move actually changes, so pressing a direction toward an empty
# slot (the move does not move) is not mistaken for a re-read. An empty/absent slot passes key nil, which
# Cursor treats as unchanged, so it neither speaks nor records -- returning to the same real move still reads.
#
# Which method to hang this on is not the same in every fork. Stock gen-6 declares FightMenuDisplay as a
# standalone class with setIndex. Some forks instead give it a BattleMenuBase parent whose
# cursor setter is index=, and no setIndex at all -- so the move list was silent there while the command
# menu (CommandMenuDisplay#index=, which they do inherit) read fine. Gated on the capability rather than
# hooked twice: where setIndex exists nothing changes, so the games that already work are untouched.
PokeAccess::Hooks.after_hook("FightMenuDisplay",
                             (PokeAccess::Engine.has?("FightMenuDisplay#setIndex") ? :setIndex : :index=)) do |disp, _r, _a|
  PokeAccess::Battle.read_fight_move(disp)
end

# Opening the fight menu on the fork: setIndexAndMode places the initial cursor by assigning @index and
# @mode DIRECTLY, bypassing both setters, so neither hook above fires and pressing Fight would land on a
# move nobody read. Queued (interrupt false) so it does not cut the hp/turn lines, and it primes @access_mega
# with the opening mode so the first real available->registered toggle still gets announced rather than being
# swallowed as if it were the open. Stock gen-6 opens through setIndex, which is already covered.
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

# Mega button (gen-6, one-way): announce when it flips to registered. Stock gen-6 exposes it as
# attr_accessor :megaButton; a forked variant keeps the same 0=hidden/1=shown/2=pressed state in
# @mode on BattleMenuBase (its own code reads @mode to draw that very button) and offers no megaButton=.
# Same three values either way, so the reader just binds whichever setter the fork has, and neither where
# there is no mega button at all.
mega_setter = ["megaButton=", "mode="].detect { |m| PokeAccess::Engine.has?("FightMenuDisplay##{m}") }

if mega_setter
  PokeAccess::Hooks.after_hook("FightMenuDisplay", mega_setter.to_sym) do |disp, _r, args|
    v = args[0]
    k = PokeAccess::Battle.mega_key(disp.instance_variable_get(:@access_mega), v)
    disp.instance_variable_set(:@access_mega, v) if v == 1 || v == 2
    PokeAccess.speak(PokeAccess::I18n.t(k), true) if k
  end
end

# Level-up stat gains (gen-6): the panel is graphic-only. Old-stat arg order here is hp,atk,def,speed,
# spatk,spdef, so speed is a[5] and spatk/spdef are a[6]/a[7].
PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbLevelUp) do |_s, _r, a|
  PokeAccess.speak(PokeAccess::Battle.levelup_text(a[0], a[2], a[3], a[4], a[6], a[7], a[5]), false)
end

# Damage number (not a message, so it is read here).
PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbHPChanged) do |_s, _r, args|
  PokeAccess::Battle.announce_hp_change(args[0], args[1])
end

# Silence the map sonar during gen-6 battles. gen-6 never sets $game_temp.in_battle and runs the whole
# fight inside Scene_Map, so the scene-change / in_battle checks never fire for wild encounters (trainer
# fights happened to be covered by the running interpreter, but wild ones are not). pbBattleAnimation is the
# top-level function that WRAPS the entire battle (both wild and trainer) in its block, so an around wrap on
# it marks the in-battle flag for the whole fight and clears it on the way out, whatever raised. No-op where
# the function is absent (modern engines already silence via the scene change).
PokeAccess::Hooks.wrap_kernel("pbBattleAnimation", "hook_battle_sonar", :around) do |args, call_next|
  PokeAccess::Battle.battle_started
  begin
    call_next.call
  ensure
    PokeAccess::Battle.battle_ended
  end
end
