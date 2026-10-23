module PokeAccess
  # Whether the player can use a field move now (Surf, Cut, Rock Smash, Dive), checked as the game does: a party
  # Pokemon that knows it (the game's own finders), an item that stands in, the badge; nil (unreadable) is not a no.
  module FieldMoves
    # Items a game gives a field move to, registered from its profile: move symbol => item symbols.
    @items = {}
    # Tools a game lets the player use a field move with in place of a Pokemon that knows it, the badge still asked,
    # registered from its profile: move symbol => [sets of items, each wanted whole; whether they are the one way].
    @tools = {}
    @named = true

    # Registers an item that lets the player use a field move without a Pokemon that knows it.
    def self.register_item(move, item)
      (@items[move] ||= []).push(item) unless (@items[move] || []).include?(item)
    end

    # Registers a set of items that, all in the bag, stands in for a Pokemon that knows the move; with only, the
    # game takes no Pokemon for it at all.
    def self.register_tool(move, items, only = false)
      entry = (@tools[move] ||= [[], false])
      entry[0].push(items) unless entry[0].include?(items)
      entry[1] ||= only
    end

    # true / false / nil: whether the player can use the move now.
    def self.can?(move)
      hm = hm_items_item(move)
      return bag_has?(hm) unless hm.nil?
      return true if item_ready?(move)
      tool = tool_ready?(move)
      k = tool ? true : (tools_only?(move) ? tool : knows?(move))
      return k unless k
      badge_ok?(move)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # true when a registered set of tools for the move is all in the bag, nil when the bag cannot be read, else false.
    def self.tool_ready?(move)
      entry = @tools[move]
      return false unless entry
      counts = entry[0].map { |set| set.map { |it| PokeAccess::Engine.bag_quantity(it) } }
      return true if counts.any? { |set| set.all? { |n| n.to_i > 0 } }
      counts.flatten.include?(nil) ? nil : false
    end

    # True when the game's tools are the one way to use the move (register_tool's only).
    def self.tools_only?(move)
      entry = @tools[move]
      entry ? entry[1] : false
    end

    # Whether the mod names what clears an obstacle: under a game's own profile, whose field-move rules
    # test/static/field_moves_test.rb holds against the game's scripts; the generic profile turns it off, since an
    # unknown game may clear its obstacles some other way.
    def self.named?; @named; end

    # Turns naming what clears an obstacle on or off (the profile DSL's field_moves_unnamed).
    def self.named=(value); @named = value; end

    # true / false / nil: whether the player can clear a gate's obstacle now, by its item or its move.
    def self.clear?(gate)
      gate[:item] ? bag_has?(gate[:item]) : can?(gate[:move])
    end

    # What clears a gate's obstacle, as the game spells it: its item, else its move.
    def self.clearer(gate)
      gate[:item] ? item_name(gate[:item]) : name(gate[:move])
    end

    # The spelling Marin's HM Items script gives a move in its constants, where it differs from ours.
    HM_ITEMS_NAMES = { :ROCKSMASH => "ROCK_SMASH" }

    # The item Marin's HM Items script has taken a move over with (<MOVE>_ITEM, switched on by
    # USING_<MOVE>_ITEM), or nil. With it on, the item is the whole rule: the move itself does not work.
    def self.hm_items_item(move)
      n = HM_ITEMS_NAMES[move] || move.to_s
      return nil unless Object.const_defined?("USING_#{n}_ITEM") && Object.const_get("USING_#{n}_ITEM")
      Object.const_defined?("#{n}_ITEM") ? Object.const_get("#{n}_ITEM") : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True if an item stands in for the move: one the profile registered, or the Advanced Items plugin's
    # own item for it, asked through the plugin's predicate (it checks the item, its badge and its switches).
    def self.item_ready?(move)
      return true if (@items[move] || []).any? { |it| bag_has?(it) }
      cfg = advanced_items_config(move)
      return false if cfg.nil? || cfg[:item] == false
      Kernel.send(:pbCanUseItem, cfg) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The Advanced Items plugin's configuration for a move (its <MOVE>_CONFIG), or nil without the plugin.
    def self.advanced_items_config(move)
      return nil unless defined?(::AdvancedItemsFieldMoves) && Object.private_method_defined?(:pbCanUseItem)
      name = "#{move}_CONFIG"
      return nil unless ::AdvancedItemsFieldMoves.const_defined?(name)
      cfg = ::AdvancedItemsFieldMoves.const_get(name)
      cfg.is_a?(Hash) ? cfg : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the bag holds an item, asked by the game's own id for it where it has one (a gen-6 bag may read no
    # symbol; 0 is the id of none).
    def self.bag_has?(item)
      id = (PokeAccess::Data.item_id(item)[0] rescue nil)
      id = item if id.nil? || id == 0
      PokeAccess::Engine.bag_quantity(id).to_i > 0
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True when the game lets a Pokemon use a field move it could learn but does not know.
    def self.learn_counts?(pl)
      return false unless pl.respond_to?(:get_pokemon_can_learn_move)
      defined?(::Settings) && ::Settings.const_defined?(:USE_HM_WITHOUT_LEARNING_THEM) &&
        ::Settings::USE_HM_WITHOUT_LEARNING_THEM ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end

    # The badge a move needs: Settings::BADGE_FOR_<MOVE> from v19, BADGEFOR<MOVE> on gen-6; nil without one.
    def self.badge_for(move)
      if defined?(::Settings) && ::Settings.const_defined?("BADGE_FOR_#{move}")
        return ::Settings.const_get("BADGE_FOR_#{move}").to_i
      end
      Object.const_defined?("BADGEFOR#{move}") ? Object.const_get("BADGEFOR#{move}").to_i : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The move's name as the game spells it.
    def self.name(move)
      n = (PokeAccess::Data.move_name(PokeAccess::Data.move_id(move)) rescue nil)
      (n.nil? || n.to_s.empty?) ? PokeAccess::Util.capitalized(move) : n.to_s
    end

    # The item's name as the game spells it (Data.item_id's [id, name]).
    def self.item_name(item)
      n = (PokeAccess::Data.item_id(item)[1] rescue nil)
      (n.nil? || n.to_s.empty?) ? PokeAccess::Util.capitalized(item) : n.to_s
    end
  end
end
