module PokeAccess
  # DBK (Deluxe Battle Kit, bundled by La Base de Sky) battle-mechanic toggle. The special mechanic
  # (mega / dynamax / tera / z-move...) is chosen with Battle#pbToggleSpecialActions(idxBattler, cmd) and
  # shown only as an icon, so a blind player misses it; announce whether the mechanic named by cmd just
  # turned on or off. Gated by method existence, so non-DBK and gen-6 games never bind.
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
  PokeAccess.speak(t, true) if t && !t.to_s.empty?
end
