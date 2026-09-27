module PokeAccess
  # Emergency data provider, always registered at priority 0 so PokeAccess::Data has one on any engine: most names are
  # the raw id, other fields nil or empty. The engine providers (10 and up) outrank it; boot logs when it serves.
  module DataFallback
    def self.move_name(id);        id.to_s; end
    def self.move_power(id);       nil; end
    def self.move_accuracy(id);    nil; end
    def self.move_total_pp(id);    nil; end
    def self.move_type_name(id);   nil; end
    def self.move_category(id);    nil; end
    def self.move_description(id); nil; end
    def self.type_name(id);        id.to_s; end
    def self.item_name(id);        id.to_s; end
    def self.item_name_plural(id);  id.to_s; end
    def self.item_description(id); nil; end
    def self.species_name(id);     id.to_s; end
    def self.species_entry(id);    [id.to_s, nil, nil]; end
    def self.ability_name(id);     id.to_s; end
    def self.ability_description(id); nil; end
    def self.nature_name(id);      id.to_s; end
    def self.stat_name(s);         s.to_s; end
    def self.status_name(st);      nil; end
    def self.pokemon_types(pk);    []; end
    def self.species_types(id);    []; end
    def self.trainer_type_name(id); nil; end
    def self.item_id(sym);         [sym, sym.to_s]; end
    def self.move_id(sym);         sym; end
  end
end

PokeAccess::Data.register(0, PokeAccess::DataFallback)
