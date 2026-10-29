# World Frontier's battle roulette (BattleRouletteUI, Victini Batalla): a reel of rule icons spins and stops on the rule
# of the next battle. Said as its overlay paints it: the lead line and the skip key while it spins, the rule it lands
# on (its name, as the overlay writes it under the icon) and the key to go on.
module PokeAccess
  module WfRoulette
    # The overlay's lines for a mode (:spinning, :announce or :view): the lead line until the rule is out, the rule
    # after, and the painted key while hints are said.
    def self.overlay(ui, mode)
      chosen = PokeAccess.ivar(ui, :@chosen)
      rule = (mode != :spinning && chosen.is_a?(Hash)) ? _INTL("¡{1}!", chosen[:name].to_s) : nil
      lead = (mode == :announce) ? nil : _INTL("La regla del combate es...")
      key = mode == :spinning ? _INTL("X para saltar") : _INTL("Pulsa C para continuar")
      PokeAccess.speak_clean(PokeAccess::WfHint.after(PokeAccess.sentences([lead, rule]), key, true), mode == :announce)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("BattleRouletteUI", :draw_overlay) { |ui, _r, args| PokeAccess::WfRoulette.overlay(ui, args[0]) }
end
