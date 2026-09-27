module PokeAccess
  # Speech categories (dialogue, battle, menu, nav, info, system), which the history files lines under. A line's is
  # the one its speak call names, else the innermost Speech.as scope's, else what deduce makes of the moment.
  module Speech
    # The categories in the order the history offers them, each with the key of its spoken name.
    CATEGORIES = [[:dialogue, :msg_cat_dialogue], [:battle, :msg_cat_battle], [:menu, :msg_cat_menu],
                  [:nav, :msg_cat_nav], [:info, :msg_cat_info], [:system, :msg_cat_system]]

    # The history's own readouts: said like any other line, and kept out of the history they come from.
    REVIEW = :review

    @scope = []

    # Runs the block with every line said inside it filed under a category, however deep the call that says it.
    def self.as(category)
      @scope.push(category)
      yield
    ensure
      @scope.pop
    end

    # The category of a line: the one it was given, else the innermost scope's, else the moment's.
    def self.category_of(given)
      given || @scope.last || deduce
    end

    # The category of an unmarked line from where the game is: battle in a fight, dialogue under a message, menu off
    # the map or in its pause menu, else nav.
    def self.deduce
      return :battle if (PokeAccess::Battle.in_battle? rescue false)
      return :dialogue if (PokeAccess.message_depth > 0 rescue false)
      return :menu unless ($scene.is_a?(Scene_Map) rescue false)
      return :menu if (($game_temp && $game_temp.in_menu) rescue false)
      :nav
    end

    # The key of a category's spoken name, or nil for one the history does not offer.
    def self.label(category)
      row = CATEGORIES.assoc(category)
      row ? row[1] : nil
    end
  end
end
