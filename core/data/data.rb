module PokeAccess
  # Data resolution layer: an id or symbol to a spoken name or field, whatever the engine. Each engine registers
  # a provider and the highest priority serves; data_fallback.rb (priority 0) is always registered.
  module Data
    @providers = []

    # Registers an engine's data provider; the highest priority registered serves.
    def self.register(priority, provider)
      @providers.push([priority, provider]); @active_entry = nil
    end

    # The [priority, provider] of the active provider (highest priority registered), or nil if none.
    def self.active_entry
      @active_entry ||= @providers.max_by { |pr| pr[0] }
    end

    # The active provider, or nil if none registered.
    def self.active
      e = active_entry; e && e[1]
    end

    # The active provider's priority, or nil; 0 means only the emergency fallback is registered (boot logs it).
    def self.active_priority
      e = active_entry; e && e[0]
    end

    # One datum from the active provider; nil when there is none, the datum is absent or the provider raised.
    def self.resolve(method, arg)
      pr = active
      return nil unless pr
      begin
        pr.send(method, arg)
      rescue StandardError => e
        note_error(method, e)
        nil
      end
    end

    # A datum only some engines' providers give (a Pokedex row, the MapInfos they load, a nature's stats): nil unless
    # the active provider answers the method.
    def self.optional(method, *args)
      pr = active
      return nil unless pr && pr.respond_to?(method)
      begin
        pr.send(method, *args)
      rescue StandardError => e
        note_error(method, e)
        nil
      end
    end

    # Records a provider exception once per method and exception class, and writes it to the load marker.
    def self.note_error(method, e)
      @errors ||= {}
      key = "#{method}:#{e.class}"
      return if @errors[key]
      @errors[key] = "#{method}: #{e.class}: #{e.message}"
      (PokeAccess.write_marker("data provider error -- #{@errors[key]}\n") rescue nil)
    end

    # The recorded provider errors (empty on a clean run); for diagnostics.
    def self.errors; (@errors || {}).values; end

    # Resolvers, each through resolve; the two type lists default to [].
    def self.move_name(id);        resolve(:move_name, id); end
    def self.move_power(id);       resolve(:move_power, id); end
    def self.move_accuracy(id);    resolve(:move_accuracy, id); end
    def self.move_total_pp(id);    resolve(:move_total_pp, id); end
    def self.move_type_name(id);   resolve(:move_type_name, id); end
    def self.move_category(id);    resolve(:move_category, id); end
    def self.move_description(id); resolve(:move_description, id); end
    def self.type_name(id);        resolve(:type_name, id); end
    def self.item_name(id);        resolve(:item_name, id); end
    def self.item_name_plural(id);  resolve(:item_name_plural, id); end
    def self.item_description(id); resolve(:item_description, id); end
    def self.species_name(id);     resolve(:species_name, id); end
    def self.species_entry(id);    resolve(:species_entry, id); end
    def self.ability_name(id);     resolve(:ability_name, id); end
    def self.ability_description(id); resolve(:ability_description, id); end
    def self.nature_name(id);      resolve(:nature_name, id); end
    def self.stat_name(s);         resolve(:stat_name, s); end
    def self.status_name(st);      resolve(:status_name, st); end
    def self.pokemon_types(pk);    resolve(:pokemon_types, pk) || []; end
    def self.species_types(id);    resolve(:species_types, id) || []; end
    def self.trainer_type_name(id); resolve(:trainer_type_name, id); end
    def self.item_id(sym);         resolve(:item_id, sym); end
    def self.move_id(sym);         resolve(:move_id, sym); end
  end
end
