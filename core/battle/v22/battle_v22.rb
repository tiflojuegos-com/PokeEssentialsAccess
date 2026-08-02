module PokeAccess
  # Battle::Scene menu OPENING bindings for vanilla Essentials v19-v21.1 AND v22: they share these method
  # names (set_index_and_commands / set_battler_and_index / set_texts_and_mode / mega_evolution_state=). The
  # Sky fork instead uses setIndexAndMode / mode= / shiftMode= (handled in battle_v21); gen-6 has no
  # Battle::Scene. Each hook binds only where the method exists, so it no-ops on the fork and on gen-6;
  # cursor navigation (index=) and all spoken content stay shared via the agnostic PokeAccess::BattleScene.
  module BattleV22
    # after_hooks Battle::Scene::<name>#<meth> as :optional, so v21/gen-6 (which lack the class or the
    # v22 method) neither bind nor flag a false typo.
    def self.bind(name, meth, &blk)
      PokeAccess::Hooks.after_hook("Battle::Scene::#{name}", meth, :optional => true, &blk)
    end

    # Binds a menu's update_input to read the focused option when @index changes, deduped on the given ivar.
    # v22 vanilla menus move the cursor by mutating @index inside update_input (never via index=), so this is
    # how their navigation is voiced; each menu keeps its own dedup ivar so they do not cross-trigger.
    def self.bind_nav(name, ivar)
      bind(name, :update_input) do |menu, _ret, _args|
        idx = (menu.index rescue nil)
        if idx && idx != PokeAccess.ivar(menu, ivar)
          menu.instance_variable_set(ivar, idx)
          PokeAccess::BattleScene.read_menu(menu)
        end
      end
    end
  end
end

# Menu opening on v22: the command menu opens via set_index_and_commands and the fight menu via
# set_battler_and_index (v21 used setIndexAndMode). Read the initial option, queued (interrupt false) so it
# does not cut the hp/turn lines just spoken.
# Prime the update_input dedup ivar on open so the next frame's update_input does not re-read (and
# interrupt) the same option the queued open read just announced. Mirrors the TargetMenu priming in
# battle_v21's index= hook.
PokeAccess::BattleV22.bind("CommandMenu", :set_index_and_commands) do |menu, _ret, _args|
  menu.instance_variable_set(:@access_cmd_idx, (menu.index rescue nil))
  PokeAccess::BattleScene.read_menu(menu, false)
end
PokeAccess::BattleV22.bind("FightMenu", :set_battler_and_index) do |menu, _ret, _args|
  menu.instance_variable_set(:@access_fight_idx, (menu.index rescue nil))
  PokeAccess::BattleScene.read_menu(menu, false)
end
# Cursor navigation on v22 vanilla: the target menu (double/triple battles) and the command (Fight/Bag/...)
# and move menus all move the cursor by mutating @index INSIDE update_input (never via index=), so the
# shared index= hook never fires -- bind update_input (deduped per menu) to voice the focused option on
# open and every move. The Sky fork navigates via cw.index= (caught by the index= hook) and has no
# update_input, so these bind only on vanilla/v22; there target_label's battler_at fallback still names
# hidden-foe slots.
PokeAccess::BattleV22.bind_nav("TargetMenu",  :@access_tgt_idx)
PokeAccess::BattleV22.bind_nav("CommandMenu", :@access_cmd_idx)
PokeAccess::BattleV22.bind_nav("FightMenu",   :@access_fight_idx)

# Mega evolution toggle on v22: signalled by mega_evolution_state= (0 hide, 1 available, 2 pressed),
# replacing v21's mode=. Announce a real available/pressed change, not the initial reveal.
PokeAccess::BattleV22.bind("FightMenu", :mega_evolution_state=) do |menu, _ret, args|
  v = args[0]
  k = PokeAccess::Battle.mega_key(menu.instance_variable_get(:@access_mega), v)
  menu.instance_variable_set(:@access_mega, v) if v == 1 || v == 2
  PokeAccess.speak(PokeAccess::I18n.t(k), true) if k
end
