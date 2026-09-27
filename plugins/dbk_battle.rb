module PokeAccess
  # Deluxe Battle Kit mechanic toggle: after Battle#pbToggleSpecialActions(idxBattler, cmd), says whether the
  # mechanic (mega, dynamax, tera, Z-move...) turned on or off; the hook is optional, as only the kit has it.
  module DBKBattle
    MECH = { :mega => :dbk_mega, :dynamax => :dbk_dynamax, :tera => :dbk_tera,
             :zmove => :dbk_zmove, :ultra => :dbk_ultra, :style => :dbk_style }

    # The spoken line for toggling a mechanic on/off for a battler, or nil.
    def self.toggle_text(battle, idx, cmd)
      return nil unless cmd
      name = MECH[cmd] ? PokeAccess::I18n.t(MECH[cmd]) : cmd.to_s
      on = (battle.pbBattleMechanicIsRegistered?(idx, cmd) rescue nil)
      on.nil? ? name : PokeAccess::I18n.t(on ? :dbk_on : :dbk_off, :m => name)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("Battle", :pbToggleSpecialActions, :optional => true) do |battle, _ret, args|
  t = PokeAccess::DBKBattle.toggle_text(battle, args[0], args[1])
  PokeAccess.speak(t, true)
end

# A styled databox draws the player's side with the Pokemon's own sex sign (not Illusion's) and level, a foe with
# its name alone; the hp and info keys say the same.
PokeAccess::Hooks.override(PokeAccess::Battle, :shown_sex, :tag => "dbk_battle") do |_mod, original, args|
  b = args[0]
  if PokeAccess::Battle.styled_box(b)
    s = (b.index.even? rescue false) ? PokeAccess::Party.sign((b.gender rescue nil)) : nil
    s ? " #{s}" : ""
  else
    original.call
  end
end
PokeAccess::Hooks.override(PokeAccess::Battle, :shown_level, :tag => "dbk_battle") do |_mod, original, args|
  b = args[0]
  PokeAccess::Battle.styled_box(b) && !(b.index.even? rescue false) ? nil : original.call
end

# The icon the kit's databox draws beside a Shadow Pokemon in Hyper Mode.
PokeAccess::Battle.icon_mark(/\Aicon_hyper_mode\z/i, :dbk_mark_hyper)
