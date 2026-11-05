# The ice Keishou's copy of Advanced Items adds (pbIceSmash, 03_Item Handler.rb): events named SmashIce on the routes that
# only its Ice Pick breaks. Named and gated like a rock, by the same page: a broken one has no script left to ask.
module PokeAccess
  module KeishouIce
    # The name of a SmashIce event that still stands, or nil.
    def self.name(ev)
      return nil unless (ev.name.to_s rescue "") == "SmashIce"
      label = PokeAccess::Routes::Effects.scripted_gate_label(ev)
      label ? PokeAccess::I18n.t(label) : nil
    end
  end
end

PokeAccess::Game.define("keishou") do
  field_gate(/\bpbIceSmash\b/, :loc_ice_block, :ICEBARRIEREITEM)
  event_name { |ev| PokeAccess::KeishouIce.name(ev) }
end
