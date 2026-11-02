# Vitro's bag (0162_PScreen_Bag) lights, beside a Mega Stone or an evolution item, a ball per team member that can use it, as
# the BES card does for a machine: said as marks of the row, from the bag reading's medium. And it paints the keys that sort a
# pocket, said after the screen opens while key hints are said.
module PokeAccess
  module VitroBag
    @able = nil

    # The name stands as the game gives it.
    def self.name(_ad, _itemid)
      nil
    end

    # An item's marks: who in the team can use it, or that nobody can; none for any other item.
    def self.marks(_bag, itemid)
      return [] unless stone?(itemid)
      names = able(itemid)
      names.empty? ? [:vitro_stone_nobody] : [[:vitro_stone_able, { :names => names.join(", ") }]]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Whether the screen lights the balls for this item.
    def self.stone?(itemid)
      pbIsMegaStone?(itemid) || pbIsEvolutionItem?(itemid)
    end

    # The names of the members whose ball is lit, asked of the game once per team and item, as each answer reads its data.
    def self.able(itemid)
      party = $Trainer.party
      key = [itemid, party.map { |pk| pk && [pk.species, (pk.form rescue 0), pk.name] }]
      @able = [key, learners(itemid, party)] unless @able && @able[0] == key
      @able[1]
    end

    # The members the game says can use the item, by the check the ball is drawn from.
    def self.learners(itemid, party)
      mega = pbIsMegaStone?(itemid)
      able = party.compact.select { |pk| (mega ? pbCheckMegastoneSpecies(pk, itemid) : pbCheckEvolution(pk, itemid)) > 0 }
      able.map { |pk| PokeAccess.clean(pk.name.to_s) }
    end

    # The keys the screen paints, while key hints are said.
    def self.hints
      return nil unless PokeAccess::Verbosity.hints?
      rows = [_INTL("[Z] Organizar Auto"), _INTL("[A] Organizar")]
      PokeAccess.sentences(rows.map { |row| PokeAccess::KeyHints.localize(PokeAccess.clean(row), nil, true) })
    end

    # Forgets the team's answer.
    def self.reset
      @able = nil
    end
  end
end

PokeAccess::Caches.register(:vitro_bag) { PokeAccess::VitroBag.reset }

unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::VitroBag)
  PokeAccess::Menus.bag_decorators.push(PokeAccess::VitroBag)
end

PokeAccess::Game.define("vitro") do
  read_on_open("PokemonBag_Scene", :pbStartScene, :optional => true, :hook_container => true) do |_scene|
    PokeAccess::VitroBag.hints
  end
end
