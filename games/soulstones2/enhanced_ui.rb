# Soulstones 2's edits to Enhanced UI 1.1.2, read by plugins/enhanced_ui_v1.rb: its battler panel paints, for a foe, the
# ability once revealed or a boss's shields.
module PokeAccess
  module SS2EnhancedUI
    # Whether the game has revealed a foe's ability, in its own record: $RevealedAbility[index][0] holds a
    # {:pkmn, :abil} pair once it has, and the pair of nils until then.
    def self.revealed_ability?(battler)
      rec = ($RevealedAbility[battler.index] rescue nil)
      rec.is_a?(Hash) && rec[0].is_a?(Hash) && rec[0] != { :pkmn => nil, :abil => nil }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # What the panel adds for a foe.
    def self.foe_parts(battler)
      if revealed_ability?(battler)
        ab = (battler.abilityName rescue nil)
        return (ab && !ab.to_s.empty?) ? [PokeAccess::I18n.t(:dbk_ability, :a => ab)] : []
      end
      return [PokeAccess::I18n.t(:ss2_shields, :n => (battler.shieldCount rescue 0).to_i)] if (battler.isbossmon rescue false)
      []
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::EnhancedUIV1", :foe_parts) { |_m, _original, args| PokeAccess::SS2EnhancedUI.foe_parts(args[0]) }
end
