# Soulstones 2's bag sorting (V, A to Z and Z to A in turn): the direction is said from the flag the sort leaves
# for the next press, and the list's cursor is reset so its first row follows, queued.
module PokeAccess
  module SS2BagSort
    @scene = nil

    # Runs one item choice with its scene watched, the one a sort can come from; a nested choice hands the
    # outer one back when it returns.
    def self.watching(scene)
      prev = @scene
      @scene = scene
      yield
    ensure
      @scene = prev
    end

    def self.sorted(bag)
      az = bag.instance_variable_get(:@descending_sort) ? true : false
      PokeAccess.speak(PokeAccess::I18n.t(az ? :bag_sorted_az : :bag_sorted_za), true)
      win = @scene && PokeAccess.sprite(@scene, "itemlist")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("PokemonBag_Scene", :pbChooseItem) do |scene, nxt, _a|
    PokeAccess::SS2BagSort.watching(scene) { nxt.call }
  end

  after("PokemonBag", :sort_pocket_alphabetically) do |bag, _r, _a|
    PokeAccess::SS2BagSort.sorted(bag)
  end
end
