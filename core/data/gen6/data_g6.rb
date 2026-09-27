module PokeAccess
  # Gen-6 data provider (PB* tables and pbGetMessage), registered only on gen-6. Resolvers stay raw:
  # PokeAccess::Data.resolve rescues every call.
  module DataG6
    def self.move_name(id);        PBMoves.getName(id); end
    # A move symbol's numeric id, through the PBMoves constant or getID.
    def self.move_id(sym);         (PBMoves.const_get(sym) rescue nil) || getID(PBMoves, sym); end
    def self.move_power(id);       PBMoveData.new(id).basedamage; end
    def self.move_accuracy(id);    PBMoveData.new(id).accuracy; end
    def self.move_total_pp(id);    PBMoveData.new(id).totalpp; end
    def self.move_type_name(id);   PBTypes.getName(PBMoveData.new(id).type); end
    def self.move_category(id);    PBMoveData.new(id).category; end
    def self.move_description(id); pbGetMessage(MessageTypes::MoveDescriptions, id); end
    def self.type_name(id);        PBTypes.getName(id); end
    def self.item_name(id);        PBItems.getName(id); end
    def self.item_name_plural(id);  PBItems.getNamePlural(id); end
    def self.item_description(id); pbGetMessage(MessageTypes::ItemDescriptions, id); end
    def self.species_name(id);     PBSpecies.getName(id); end
    def self.ability_name(id);     PBAbilities.getName(id); end
    def self.ability_description(id); pbGetMessage(MessageTypes::AbilityDescs, id); end
    def self.nature_name(id);      PBNatures.getName(id); end
    def self.status_name(st);      PokeAccess::Config.status_names[st]; end
    def self.stat_name(s);         PBStats.getName(s); end

    # The species pokedex entry as [name, category, dex_text] from the gen-6 message tables.
    def self.species_entry(id)
      [PBSpecies.getName(id), (pbGetMessage(MessageTypes::Kinds, id) rescue nil),
       (pbGetMessage(MessageTypes::Entries, id) rescue nil)]
    end

    # The spoken type names of a pokemon, from its gen-6 numeric type1/type2.
    def self.pokemon_types(pk)
      [PBTypes.getName(pk.type1), (pk.type2 != pk.type1 ? PBTypes.getName(pk.type2) : nil)].compact
    end

    # The spoken type names of a species, read from the gen-6 dex data the way the engine reads them.
    def self.species_types(id)
      d = pbOpenDexData
      begin
        pbDexDataOffset(d, id, 8)
        t1 = d.fgetb
        t2 = d.fgetb
      ensure
        d.close
      end
      [PBTypes.getName(t1), (t2 != t1 ? PBTypes.getName(t2) : nil)].compact
    end

    # The name of a trainer class, by number or by the name of its PBTrainers constant; nil for a class the
    # game does not have.
    def self.trainer_type_name(id)
      unless id.is_a?(Integer)
        return nil unless id.to_s =~ /\A[A-Z]\w*\z/ && PBTrainers.const_defined?(id.to_s)
        id = PBTrainers.const_get(id.to_s)
        return nil unless id.is_a?(Integer)
      end
      PBTrainers.getName(id)
    end

    # An item symbol parsed from an event script as [numeric id, name], through the PBItems constant or getID.
    def self.item_id(sym)
      id = (PBItems.const_get(sym) rescue nil)
      id = (getID(PBItems, sym.to_sym) rescue nil) if id.nil?
      [id, (id ? (PBItems.getName(id) rescue nil) : nil)]
    end
  end
end

PokeAccess::Data.register(10, PokeAccess::DataG6) if defined?(PBMoves) && !defined?(GameData)
