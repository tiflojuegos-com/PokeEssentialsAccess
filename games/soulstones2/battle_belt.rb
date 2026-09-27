# Soulstones 2's Battle Belt: a party-screen button, past the members, for three battle item slots shown only
# as icons (greyed once spent); a sprite class of its own, not a Confirm/Cancel button core reads.
module PokeAccess
  module SS2Belt
    SLOTS = [[:med1, :ss2_belt_med1], [:med2, :ss2_belt_med2], [:combat, :ss2_belt_combat]]

    # The button and what its three icons show: each slot's item, marked spent when its icon is greyed.
    def self.text
      belt = ($Trainer.battlebelt rescue nil)
      parts = SLOTS.map do |key, label|
        e = belt.is_a?(Hash) ? belt[key] : nil
        name = (e && e[0] && e[0] != :NONE) ? ((GameData::Item.try_get(e[0]).name rescue nil) || e[2].to_s) : nil
        what = if name.nil? then PokeAccess::I18n.t(:ss2_belt_none)
               elsif e[1].to_i > 0 then name
               else PokeAccess::I18n.t(:ss2_belt_spent, :item => name)
               end
        PokeAccess::I18n.t(label, :item => what)
      end
      PokeAccess::I18n.t(:ss2_belt, :items => parts.join(", "))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # Keyed by the sprite, like the party's own buttons, so the loop re-marking it every move stays quiet.
  after("PokemonPartyConfirmBattleBeltSprite", :selected=, :optional => true) do |sprite, _r, args|
    PokeAccess::UIV21.speak_changed(:party, PokeAccess::SS2Belt.text, sprite.object_id) if args[0]
  end
end
