module PokeAccess
  # GameData data provider (v19+), registered above gen-6 so an engine that also ships PB* shims resolves through
  # GameData. Resolvers stay raw: PokeAccess::Data.resolve rescues every call.
  module DataV21
    def self.move_name(id);        GameData::Move.get(id).name; end
    # A move symbol is its own id; nil for one the game does not have.
    def self.move_id(sym);         GameData::Move.exists?(sym) ? sym : nil; end
    # power, or base_damage (its name before v21), which both Infinite Fusion games keep.
    def self.move_power(id);       PokeAccess.attr_of(GameData::Move.get(id), :power, :base_damage); end
    def self.move_accuracy(id);    GameData::Move.get(id).accuracy; end
    def self.move_total_pp(id);    PokeAccess.attr_of(GameData::Move.get(id), :total_pp, :totalpp); end
    def self.move_type_name(id);   GameData::Type.get(GameData::Move.get(id).type).name; end
    def self.move_category(id);    GameData::Move.get(id).category; end
    def self.move_description(id); GameData::Move.get(id).description; end
    def self.type_name(id);        GameData::Type.get(id).name; end
    def self.item_name(id);        GameData::Item.get(id).name; end
    # name_plural first, for the Infinite Fusion games: they keep that v19 accessor and lack the portion_* pair.
    def self.item_name_plural(id); d = GameData::Item.get(id); (d.name_plural rescue nil) || (d.portion_name_plural rescue nil) || (d.portion_name rescue nil) || d.name; end
    def self.item_description(id); GameData::Item.get(id).description; end
    def self.species_name(id);     GameData::Species.get(id).name; end
    def self.ability_name(id);     GameData::Ability.get(id).name; end
    def self.ability_description(id); GameData::Ability.get(id).description; end
    def self.nature_name(id);      GameData::Nature.get(id).name; end
    def self.status_name(st);      GameData::Status.get(st).name; end
    def self.stat_name(s);         GameData::Stat.get(s).name; end

    # The species pokedex entry as [name, category, dex_text] from the GameData::Species registry.
    def self.species_entry(id)
      d = GameData::Species.get(id)
      [d.name, (d.category rescue nil), (d.pokedex_entry rescue nil)]
    end

    # The spoken type names of a pokemon, from its modern symbol types.
    def self.pokemon_types(pk)
      (pk.types rescue []).map { |s| (GameData::Type.get(s).name rescue nil) }.compact
    end

    # The spoken type names of a species: types from v20, the type1/type2 pair v19 still had.
    def self.species_types(id)
      d = GameData::Species.get(id)
      ts = d.respond_to?(:types) ? d.types : [d.type1, d.type2]
      ts.compact.uniq.map { |s| (GameData::Type.get(s).name rescue nil) }.compact
    end

    # The name of a trainer class by its id, or nil, never asking the table about an id it does not know (see
    # safe_item_name): the ids come from sprite file names, which name classes a game may not have.
    def self.trainer_type_name(id)
      key = id.is_a?(Integer) ? id : id.to_s.to_sym
      tt = GameData::TrainerType
      return (tt.try_get(key).name rescue nil) if tt.respond_to?(:try_get)
      return nil if tt.respond_to?(:exists?) && !tt.exists?(key)
      tt.get(key).name
    end

    # An item symbol or name parsed from an event script as [symbol, name]; modern items are keyed by symbol.
    def self.item_id(sym)
      s = sym.to_s.to_sym
      [s, (safe_item_name(s) rescue nil)]
    end

    # An item's name, or nil, never asking the table about an id it does not know: try_get, then exists?, because
    # get on an unknown id can recurse into SystemStackError (Infinite Fusion), which rescue does not catch.
    def self.safe_item_name(s)
      return (GameData::Item.try_get(s).name rescue nil) if GameData::Item.respond_to?(:try_get)
      return nil if GameData::Item.respond_to?(:exists?) && !GameData::Item.exists?(s)
      GameData::Item.get(s).name
    end
  end
end

PokeAccess::Data.register(20, PokeAccess::DataV21) if defined?(GameData) && defined?(GameData::Move)
