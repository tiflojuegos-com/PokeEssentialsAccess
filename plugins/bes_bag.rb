module PokeAccess
  # Essentials BES's bag: beside a machine the screen paints a card (drawTMInfo) with its move's type, category, power,
  # accuracy and PP, and a ball per team member, lit for those that can learn it. Said as marks of the bag row, from the
  # bag reading's medium level, and kept with the row for Ctrl+T.
  module BesBag
    @cards = {}
    @able = nil

    # The name stands as the game gives it.
    def self.name(_ad, _itemid)
      nil
    end

    # A machine's marks: its move's card, then who in the team can learn it; none for any other item, or on a bag that
    # paints no card.
    def self.marks(_bag, itemid)
      return [] unless card_screen?
      move = PokeAccess::Info.machine_move(itemid)
      return [] unless move
      card(move) + able(move)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Whether the bag scene is one that paints the machine card.
    def self.card_screen?
      scene = PokeAccess.const_at("PokemonBag_Scene")
      scene ? scene.method_defined?(:drawTMInfo) : false
    end

    # The move's figures as bag marks, worked out once: they never change.
    def self.card(move)
      @cards[move] ||= figures(move)
    end

    # Type, category, power, accuracy and PP as keys with their slots; a figure the data lacks is left out, and a
    # power or accuracy of 0, which the card paints as dashes, is said in words.
    def self.figures(move)
      type = PokeAccess::Data.move_type_name(move)
      number = PokeAccess::Data.move_category(move)
      category = number.is_a?(Integer) ? PokeAccess::MoveInfo::CATEGORIES[number] : nil
      power = PokeAccess::Data.move_power(move)
      accuracy = PokeAccess::Data.move_accuracy(move)
      pp = PokeAccess::Data.move_total_pp(move).to_i
      out = []
      out.push([:mv_type, { :t => type }]) if type && !type.to_s.empty?
      out.push(category) if category
      out.push([:mv_power, { :p => PokeAccess::MoveInfo.power_phrase(power) }]) unless power.nil?
      out.push([:mv_acc, { :a => PokeAccess::MoveInfo.accuracy_phrase(accuracy) }]) unless accuracy.nil?
      out.push([:mv_pp, { :pp => pp, :tot => pp }]) if pp > 0
      out
    end

    # Who can learn the move, as the balls say it, or that nobody can. Asked of the game once per team and machine,
    # since each answer reads its data files.
    def self.able(move)
      party = ($Trainer.party rescue nil)
      return [] unless party.is_a?(Array)
      key = [move, party.map { |pk| pk && [pk.species, (pk.form rescue 0), pk.name, PokeAccess::Summary.egg?(pk)] }]
      @able = [key, learners(move, party)] unless @able && @able[0] == key
      names = @able[1]
      names.empty? ? [:tut_nobody] : [[:tut_can_list, { :names => names.join(", ") }]]
    end

    # The names of the team's members, eggs apart, that the game says are compatible with the move.
    def self.learners(move, party)
      able = party.select { |pk| pk && !PokeAccess::Summary.egg?(pk) && pk.isCompatibleWithMove?(move) }
      able.map { |pk| PokeAccess.clean(pk.name.to_s) }
    end

    # Forgets the figures and the team's answer.
    def self.reset
      @cards = {}
      @able = nil
    end
  end
end

PokeAccess::Caches.register(:bes_bag) { PokeAccess::BesBag.reset }

unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::BesBag)
  PokeAccess::Menus.bag_decorators.push(PokeAccess::BesBag)
end
