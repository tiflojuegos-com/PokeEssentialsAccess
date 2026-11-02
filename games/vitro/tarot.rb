# Vitro's tarot reader (clTiradaTarot in 0344_Tarot, map 113): three cards turned over one by one, pictures that carry a Roman
# numeral and no name, before the messages of the reading, which core reads and which do not all name their card. Each card's
# name is said, queued, as it turns, and the info key keeps those shown while the pictures stay up.
module PokeAccess
  module VitroTarot
    # The cards by the number of their picture, in clTiradaTarot's order.
    CARDS = [:vitro_tarot_fool, :vitro_tarot_magician, :vitro_tarot_priestess, :vitro_tarot_empress, :vitro_tarot_emperor,
             :vitro_tarot_pope, :vitro_tarot_lover, :vitro_tarot_chariot, :vitro_tarot_strength, :vitro_tarot_hermit,
             :vitro_tarot_wheel, :vitro_tarot_justice, :vitro_tarot_hanged, :vitro_tarot_death, :vitro_tarot_temperance,
             :vitro_tarot_devil, :vitro_tarot_tower, :vitro_tarot_star, :vitro_tarot_moon, :vitro_tarot_sun,
             :vitro_tarot_judgement, :vitro_tarot_world]

    # A card's name by its picture's name ("Carta7"), or nil.
    def self.card(picture)
      number = picture.to_s[/\d+\z/]
      key = number && CARDS[number.to_i]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # Says the card just turned and keeps it, with the ones before, for the info key.
    def self.turned(animation, picture)
      name = card(picture)
      return unless name
      shown = (PokeAccess.ivar(animation, :@access_cards) || []) + [name]
      animation.instance_variable_set(:@access_cards, shown)
      PokeAccess.speak(PokeAccess::I18n.t(:vitro_tarot_card, :name => name), false)
      PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:vitro_tarot_cards, :list => shown.join(", ")), name)
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("TarotAnimation", :reveal_card, :hook_container => true) do |animation, _r, args|
    PokeAccess::VitroTarot.turned(animation, args[1])
  end
  clear_info_on("TarotAnimation", :dispose)
end
