module PokeAccess
  # The sort keys of Rejuvenation's bag, Pokedex list and move relearner, which reorder the list with only a sound and
  # the line the game's own reader says: the order set, cutting in, with the list's focused row queued behind it, the
  # Pokedex's back on its first row.
  module RejuvSorts
    KEYS = { :name => :rj_sorted_name, :type => :rj_sorted_type, :number => :rj_sorted_number }

    # The line for an order (:name, :type or :number), or nil for any other.
    def self.text(order)
      key = KEYS[order]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # Says the order a list was just sorted by, the list's next read queued behind it.
    # param list the list's command window, or the relearner's scene
    def self.say(order, list)
      t = text(order)
      return unless t
      PokeAccess.speak(t, true)
      PokeAccess::Menus.queue_next_read(list)
    end

    # The Pokedex list's window, kept apart in its @pokedexSprites.
    def self.dex_list(scene)
      sprites = PokeAccess.ivar(scene, :@pokedexSprites)
      sprites.is_a?(Hash) ? sprites["pokedex"] : nil
    end

    # The order a Pokedex sort shortcut asks for (mode 0 by number, 1 by name), or nil for a sort from the search, which
    # the game does not say, or one that changes nothing.
    def self.dex_order(scene, args)
      opts = args[1]
      return nil unless opts.is_a?(Hash) && opts[:shortcut]
      return nil if (scene.getSortMode rescue nil) == args[0]
      args[0] == 0 ? :number : :name
    end

    # The order the relearner's key just set for its page (X by name, A by type, Y by number), or nil when the list is
    # rebuilt for another reason.
    def self.relearner_order(scene)
      order = if Input.trigger?(Input::X) then :name
              elsif Input.trigger?(Input::A) then :type
              elsif Input.trigger?(Input::Y) then :number
              end
      sorting = ($PokemonGlobal.moveRelearnerSorting rescue nil)
      (order && sorting && sorting[PokeAccess.ivar(scene, :@page)] == order) ? order : nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("PokemonBag_Scene", :pbHandleSort, :optional => true) do |scene, _r, args|
    PokeAccess::RejuvSorts.say(args[1], PokeAccess.sprite(scene, "itemwindow"))
  end

  before("PokemonPokedexScene", :pbExecuteSort, :optional => true) do |scene, args|
    PokeAccess::RejuvSorts.say(PokeAccess::RejuvSorts.dex_order(scene, args), PokeAccess::RejuvSorts.dex_list(scene))
  end

  before("MoveRelearnerScene", :refreshMoves, :optional => true) do |scene, _a|
    PokeAccess::RejuvSorts.say(PokeAccess::RejuvSorts.relearner_order(scene), scene)
  end
end
