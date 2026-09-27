module PokeAccess
  # Battle::Scene menu bindings under the v22 method names (set_index_and_commands, set_battler_and_index,
  # update_input, mega_evolution_state=), each bound only where it exists; the spoken content is BattleScene's.
  module BattleV22
    # After-hooks Battle::Scene::<name>#<meth> as :optional, so an era without it binds nothing and logs no typo.
    def self.bind(name, meth, &blk)
      PokeAccess::Hooks.after_hook("Battle::Scene::#{name}", meth, :optional => true, &blk)
    end

    # Reads the focused option after a menu's update_input when @index changed, deduped on its own ivar (v22 menus
    # move @index there, never through index=).
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

# Menu opening on v22 (set_index_and_commands, set_battler_and_index): the first option, queued, with the
# update_input dedup ivar primed so the next frame does not read it again.
PokeAccess::BattleV22.bind("CommandMenu", :set_index_and_commands) do |menu, _ret, _args|
  menu.instance_variable_set(:@access_cmd_idx, (menu.index rescue nil))
  PokeAccess::BattleScene.read_menu(menu, false)
end
PokeAccess::BattleV22.bind("FightMenu", :set_battler_and_index) do |menu, _ret, _args|
  menu.instance_variable_set(:@access_fight_idx, (menu.index rescue nil))
  PokeAccess::BattleScene.read_menu(menu, false)
end
# Cursor navigation on v22, where the target, command and fight menus move @index inside update_input.
PokeAccess::BattleV22.bind_nav("TargetMenu",  :@access_tgt_idx)
PokeAccess::BattleV22.bind_nav("CommandMenu", :@access_cmd_idx)
PokeAccess::BattleV22.bind_nav("FightMenu",   :@access_fight_idx)

# The Mega button on v22's mega_evolution_state= (0 hidden, 1 available, 2 pressed): coming up available is said
# queued, a toggle interrupts.
PokeAccess::BattleV22.bind("FightMenu", :mega_evolution_state=) do |menu, _ret, args|
  v = args[0]
  last = menu.instance_variable_get(:@access_mega)
  k = PokeAccess::Battle.mega_key(last, v)
  menu.instance_variable_set(:@access_mega, v) if v.is_a?(Integer)
  if PokeAccess::Battle.mega_reveal?(last, v)
    PokeAccess.speak(PokeAccess::Battle.ready_text(:mega), false)
  elsif k
    PokeAccess.speak(PokeAccess::I18n.t(k), true)
  end
end
