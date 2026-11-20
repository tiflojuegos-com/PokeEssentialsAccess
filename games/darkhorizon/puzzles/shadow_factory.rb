# Ferros Rock's Shadow Factory (maps 93 to 98): three key card items open its doors, each door testing the bag. Card 1 is in
# a chest (map 95, event 48), card 2 on the entrance hall's floor (map 94, event 40) and card 3 is Markus's after a battle
# (map 97, event 34). The doors only say they are locked; the assist adds which card each takes and where the missing ones are.
# Switch 105 (the factory done) is raised by the last boss's event on map 98, and silences the info key and the hint.
module PokeAccess
  module DHFactory
    CARDS = [:KEY_FACTORY_1, :KEY_FACTORY_2, :KEY_FACTORY_3]
    DOORS = { 93 => { 15 => 2 }, 94 => { 20 => 2 }, 95 => { 37 => 2, 38 => 1, 39 => 1 }, 97 => { 19 => 2, 28 => 3, 29 => 2 } }

    # True when the bag holds card n.
    def self.has?(n)
      ($bag.has?(CARDS[n - 1]) rescue false) ? true : false
    end

    # The cards in the bag, as numbers.
    def self.held
      [1, 2, 3].select { |n| has?(n) }
    end

    # A door's name: with the assist, the card it takes.
    def self.door(map, ev)
      PokeAccess::Puzzles.assist? ? [:dh_pz_fac_door_card, { :n => DOORS[map][ev.id] }] : :dh_pz_fac_door
    end

    # The info key's line: the cards held.
    def self.info
      list = held.empty? ? PokeAccess::I18n.t(:dh_pz_none) : held.join(", ")
      [:dh_pz_fac_info, { :list => list }]
    end

    # The hint: where each missing card is, or what the three open.
    def self.hint
      left = [1, 2, 3].reject { |n| has?(n) }
      return :dh_pz_fac_h_done if left.empty?
      PokeAccess.sentences(left.map { |n| PokeAccess::I18n.t("dh_pz_fac_h#{n}".to_sym) })
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  PokeAccess::DHFactory::DOORS.each do |map, doors|
    mechanic(:state, map) do
      auto
      name doors.keys, lambda { |ev| PokeAccess::DHFactory.door(map, ev) }
      name 40, :dh_pz_fac_card_item, :when => lambda { |_ev| !$game_self_switches[[94, 40, "A"]] } if map == 94
      info { PokeAccess::I18n.t(*PokeAccess::DHFactory.info) }
      solved { $game_switches[105] }
      hint lambda { PokeAccess::DHFactory.hint }
    end
  end
end
