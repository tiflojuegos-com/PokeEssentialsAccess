module PokeAccess
  # Whether the player can use a field move now (Surf, Cut, Rock Smash, Dive), decided as the game does: a party
  # Pokemon that knows it (the game's own finders), an item that stands in, the badge; nil (unreadable) is not a no.
  module FieldMoves
    # Items a game gives a field move to, registered from its profile: move symbol => item symbols.
    @items = {}

    # Registers an item that lets the player use a field move without a Pokemon that knows it.
    def self.register_item(move, item)
      (@items[move] ||= []).push(item) unless (@items[move] || []).include?(item)
    end

    # true / false / nil: whether the player can use the move now.
    def self.can?(move)
      hm = hm_items_item(move)
      return bag_has?(hm) unless hm.nil?
      return true if item_ready?(move)
      k = knows?(move)
      return k unless k
      badge_ok?(move)
    rescue StandardError
      nil
    end

    # The spelling Marin's HM Items script gives a move in its constants, where it differs from ours.
    HM_ITEMS_NAMES = { :ROCKSMASH => "ROCK_SMASH" }

    # The item Marin's HM Items script has taken a move over with (<MOVE>_ITEM, switched on by
    # USING_<MOVE>_ITEM), or nil. With it on, the item is the whole rule: the move itself does not work.
    def self.hm_items_item(move)
      n = HM_ITEMS_NAMES[move] || move.to_s
      return nil unless Object.const_defined?("USING_#{n}_ITEM") && Object.const_get("USING_#{n}_ITEM")
      Object.const_defined?("#{n}_ITEM") ? Object.const_get("#{n}_ITEM") : nil
    rescue StandardError
      nil
    end

    # True if an item stands in for the move: one the profile registered, or the Advanced Items plugin's
    # own item for it, asked through the plugin's predicate (it checks the item, its badge and its switches).
    def self.item_ready?(move)
      return true if (@items[move] || []).any? { |it| bag_has?(it) }
      cfg = advanced_items_config(move)
      return false if cfg.nil? || cfg[:item] == false
      Kernel.send(:pbCanUseItem, cfg) ? true : false
    rescue StandardError
      false
    end

    # The Advanced Items plugin's configuration for a move (its <MOVE>_CONFIG), or nil without the plugin.
    def self.advanced_items_config(move)
      return nil unless defined?(::AdvancedItemsFieldMoves) && Object.private_method_defined?(:pbCanUseItem)
      name = "#{move}_CONFIG"
      return nil unless ::AdvancedItemsFieldMoves.const_defined?(name)
      cfg = ::AdvancedItemsFieldMoves.const_get(name)
      cfg.is_a?(Hash) ? cfg : nil
    rescue StandardError
      nil
    end

    # Whether the bag holds an item.
    def self.bag_has?(item)
      PokeAccess::Engine.bag_quantity(item).to_i > 0
    end

    # Whether a party Pokemon knows the move, by the engine's finder (v19+ get_pokemon_with_move, gen-6 pbCheckMove);
    # with USE_HM_WITHOUT_LEARNING_THEM, one that can learn it counts too.
    def self.knows?(move)
      pl = PokeAccess::Engine.player
      return nil if pl.nil?
      if pl.respond_to?(:get_pokemon_with_move)
        return true if pl.get_pokemon_with_move(move)
        return (pl.get_pokemon_can_learn_move(move) ? true : false) if learn_counts?(pl)
        return false
      end
      return (Kernel.pbCheckMove(move) ? true : false) if Kernel.respond_to?(:pbCheckMove)
      nil
    rescue StandardError
      nil
    end

    # True when the game lets a Pokemon use a field move it could learn but does not know.
    def self.learn_counts?(pl)
      return false unless pl.respond_to?(:get_pokemon_can_learn_move)
      defined?(Settings) && Settings.const_defined?(:USE_HM_WITHOUT_LEARNING_THEM) &&
        Settings::USE_HM_WITHOUT_LEARNING_THEM ? true : false
    rescue StandardError
      false
    end

    # Whether the badge the move needs has been won, or true when the game names no badge for it.
    def self.badge_ok?(move)
      badge = badge_for(move)
      return true if badge.nil?
      if Object.private_method_defined?(:pbCheckHiddenMoveBadge) || Kernel.respond_to?(:pbCheckHiddenMoveBadge)
        return Kernel.send(:pbCheckHiddenMoveBadge, badge, false) ? true : false
      end
      tr = PokeAccess::Engine.player
      return true if tr.nil? || badge < 0
      counts = defined?(HIDDENMOVESCOUNTBADGES) && HIDDENMOVESCOUNTBADGES
      (counts ? (tr.numbadges >= badge) : tr.badges[badge]) ? true : false
    rescue StandardError
      true
    end

    # The badge a move needs: Settings::BADGE_FOR_<MOVE> from v19, BADGEFOR<MOVE> on gen-6; nil without one.
    def self.badge_for(move)
      if defined?(Settings) && Settings.const_defined?("BADGE_FOR_#{move}")
        return Settings.const_get("BADGE_FOR_#{move}").to_i
      end
      Object.const_defined?("BADGEFOR#{move}") ? Object.const_get("BADGEFOR#{move}").to_i : nil
    rescue StandardError
      nil
    end

    # The move's name as the game spells it.
    def self.name(move)
      n = (PokeAccess::Data.move_name(PokeAccess::Data.move_id(move)) rescue nil)
      (n.nil? || n.to_s.empty?) ? move.to_s.capitalize : n.to_s
    end
  end
end
