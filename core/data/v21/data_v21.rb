module PokeAccess
  # GameData-era Essentials data provider (GameData, v19+): names and move/item fields via the GameData
  # registries (move power/accuracy/type/description verified against the v21/v22 source). Resolvers stay
  # raw -- PokeAccess::Data wraps each call nil-safe. Registered above gen-6 (see the guard) so a modern
  # engine that still ships PB* compatibility shims still resolves through GameData.
  module DataV21
    def self.move_name(id);        GameData::Move.get(id).name; end
    # base_damage is what this attribute was called before v21 renamed it, and the v18-era hybrids (both
    # Infinite Fusion) are GameData games that kept the old name -- so they resolve through here and would
    # otherwise report every move as powerless.
    def self.move_power(id);       PokeAccess.attr_of(GameData::Move.get(id), :power, :base_damage); end
    def self.move_accuracy(id);    GameData::Move.get(id).accuracy; end
    def self.move_type_name(id);   GameData::Type.get(GameData::Move.get(id).type).name; end
    def self.move_description(id); GameData::Move.get(id).description; end
    def self.type_name(id);        GameData::Type.get(id).name; end
    def self.item_name(id);        GameData::Item.get(id).name; end
    # name_plural comes first because the two Infinite Fusion games kept the v19 accessor and never gained
    # the portion_* pair, so the chain fell through to the singular and they read "2 Potion".
    def self.item_name_plural(id); d = GameData::Item.get(id); (d.name_plural rescue nil) || (d.portion_name_plural rescue nil) || (d.portion_name rescue nil) || d.name; end
    def self.item_description(id); GameData::Item.get(id).description; end
    def self.species_name(id);     GameData::Species.get(id).name; end
    def self.ability_name(id);     GameData::Ability.get(id).name; end
    def self.nature_name(id);      GameData::Nature.get(id).name; end
    def self.status_name(st);      GameData::Status.get(st).name; end
    def self.stat_name(s);         GameData::Stat.get(s).name; end

    # The species pokedex entry as [name, category, dex_text] from the GameData::Species registry.
    # param id the species id
    def self.species_entry(id)
      d = GameData::Species.get(id)
      [d.name, (d.category rescue nil), (d.pokedex_entry rescue nil)]
    end

    # The spoken type names of a pokemon, from its modern symbol types.
    # param pk the pokemon
    def self.pokemon_types(pk)
      (pk.types rescue []).map { |s| (GameData::Type.get(s).name rescue nil) }.compact
    end

    # Resolves an item symbol parsed from an event script to [symbol, name] (modern items are keyed by
    # symbol, so the symbol is the id).
    # param sym the item symbol/name string
    def self.item_id(sym)
      s = sym.to_s.to_sym
      [s, (GameData::Item.get(s).name rescue nil)]
    end
  end
end

PokeAccess::Data.register(20, PokeAccess::DataV21) if defined?(GameData) && defined?(GameData::Move)
