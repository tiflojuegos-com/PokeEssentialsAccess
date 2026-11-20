module PokeAccess
  # Anil's Pokemon that heal, drawn by their number (the Wobbuffet of Cueva Celeste, map 170, at 14,20): named and
  # listed as a centre's attendant, the nurse it replaced, instead of an object.
  module AnilPokemonHealer
    # True for an unnamed action event with a numbered sprite whose live page recovers the whole party.
    def self.healer?(ev)
      return false unless ev.character_name.to_s =~ /\A\d+s?\z/ && PokeAccess.ivar(ev, :@trigger) == 0
      return false unless PokeAccess::Locator.placeholder_name?(PokeAccess::Locator.own_name(ev))
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array)
      list.any? { |c| (c.code rescue 0) == PokeAccess::EventPages::RECOVER_ALL && (c.parameters[0] rescue 1) == 0 }
    end
  end
end

PokeAccess::Game.define("anil") do
  event_name { |ev| PokeAccess::AnilPokemonHealer.healer?(ev) ? PokeAccess::I18n.t(:loc_healing_attendant) : nil }
  event_category(:people) { |ev| PokeAccess::AnilPokemonHealer.healer?(ev) }
end
