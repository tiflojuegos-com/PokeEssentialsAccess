module PokeAccess
  # Registry of resettable per-run state. Many modules cache state tied to the current map or save (audio3d's
  # emitters, the locator's target list, the pathfinder's passability grid...), each with its own reset. The
  # gap this closes: nothing called all of them together, so state from a previous map or save could linger
  # after a transfer or a load (e.g. emitters from the map you just left). A module registers its reset once;
  # reset_all (wired to the :map_changed event) clears every registrant in one place, and a new cache is
  # covered just by registering it -- no central list to keep in sync. Loading a save resets too, and NOT
  # because a load screen asks it to (only the two classic ones ever did, so v22 loads slipped through):
  # announce_map_change compares the IDENTITY of $game_map as well as its id, and a load rebuilds that
  # object, so the first map after loading fires :map_changed even when it is the same map.
  module Caches
    @resets = {}

    # Registers a reset block under a name (idempotent: re-registering the same name replaces it). The block
    # should drop the module's cached state; it is guarded, so one failing reset never blocks the others.
    # param name a symbol identifying the cache (its module), for diagnostics and replacement
    def self.register(name, &block)
      @resets[name] = block
    end

    # Runs every registered reset (each guarded). Called on map change and on load so no run carries another
    # run's cached state.
    def self.reset_all
      @resets.each do |name, blk|
        begin
          blk.call
        rescue StandardError => e
          PokeAccess.log_once("cache_reset_#{name}", e)
        end
      end
    end

    # The registered cache names (for diagnostics).
    def self.names; @resets.keys; end
  end
end

# Reset per-run caches when the map changes, so stale map state never lingers. :map_changed is emitted by
# the locator's map-change detector; loading a save routes through it too (the load screen forgets the map,
# so the next frame's announce_map_change fires even on the same map_id). Modules register their own reset
# via Caches.register, so this stays a single wiring point.
PokeAccess::Events.on(:map_changed) { PokeAccess::Caches.reset_all }
