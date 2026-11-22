# Kanto's Type Experts use an event name such as TYPE_EXPERT_POISON.
PokeAccess::Game.define("infinitefusion") do
  event_name do |event|
    tag = /\ATYPE_EXPERT_([A-Z]+)\z/.match(PokeAccess::Locator.own_name(event))
    next nil unless tag && defined?(::GameData::Type)

    type = ::GameData::Type.try_get(tag[1].to_sym)
    next nil unless type && !type.pseudo_type

    name = type.name.to_s.strip
    next nil if name.empty?

    PokeAccess::I18n.t(:if_type_expert, :type => name)
  end
end
