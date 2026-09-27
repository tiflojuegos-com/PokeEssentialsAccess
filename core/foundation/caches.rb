module PokeAccess
  # Registry of per-run cache resets (audio3d's emitters, the locator's targets, the pathfinder's grid...), all run
  # by reset_all on :map_changed, which loading a save fires too, even onto the same map.
  module Caches
    @resets = {}

    # Registers the block that drops a module's cached state; registering the same name again replaces it.
    def self.register(name, &block)
      @resets[name] = block
    end

    # Runs every registered reset; a failing one is logged once and does not stop the others.
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

# Resets every per-run cache on :map_changed (emitted by Locator.announce_map_change).
PokeAccess::Events.on(:map_changed) { PokeAccess::Caches.reset_all }
