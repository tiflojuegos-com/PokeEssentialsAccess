module PokeAccess
  # The world the routes, the cues and the locator read: the map's terrain, the passability the engine answers and the
  # events, each kept in memos that know when they stop holding.
  module World
    # Forgets everything the world keeps, to be read afresh: a forced invalidation, a test that builds a new map.
    def self.reset!; Epoch.reset!; end

    # When the world's memos stop holding: :map with a new map (its id or the map object, which a load rebuilds even
    # on the same id), :tiles with new tiles (layers, tileset tables, autotiles; a new map too). A memo registers what
    # to drop on each (on), what a full reset forgets besides (:reset) and what to take afresh each frame (:frame).
    module Epoch
      @drops = { :map => [], :tiles => [], :reset => [], :frame => [] }
      @dirty = true
      @frame = 0
      @tiles_due = false
      @tiles_fresh = false
      @map_ref = nil
      @print = nil

      # Registers what to drop on a new map (:map), new tiles (:tiles) or a reset (:reset), or what to take afresh each
      # frame (:frame).
      def self.on(name, &blk); @drops[name].push(blk); end

      # Marks the world unsettled, so the next question settles it: a new screen frame or map frame.
      def self.dirty!
        @dirty = true
        @tiles_fresh = false
        @frame += 1
      end

      # Counts the frames the world was marked unsettled in: what once-a-frame work (the events' sync) keys on.
      def self.frame; @frame; end

      # Asks for the tiles to be compared at the next settle: an event's end may have changed one.
      def self.tiles_due!
        @tiles_due = true
        @dirty = true
      end

      # Drops what hangs on :map or :tiles now, whatever a check would say; a new map drops what hangs on the tiles too.
      def self.touch(name)
        @drops[name].each { |blk| blk.call }
        touch(:tiles) if name == :map
      end

      # Keeps the memos of the map the world was last settled on (Visits), before a new map or a load drops them.
      def self.leave; Visits.leave(@map_ref && @map_ref[0], @print); end

      # Forgets what a full reset drops and the map seen, so the next settle takes the map as new.
      def self.reset!
        @drops[:reset].each { |blk| blk.call }
        @map_ref = nil
        @print = nil
        @dirty = true
      end

      # Settles the world: when unsettled, a new map bumps :map (Visits keeps and puts back memos), then :frame runs;
      # the tiles are compared when due, or about to be read (tiles) unless this frame did; :tiles if they differ.
      def self.settle(tiles = false)
        if @dirty
          @dirty = false
          m = $game_map
          ref = m ? [(m.map_id rescue nil), m.__id__] : nil
          if ref != @map_ref
            leave
            @map_ref = ref
            @print = fingerprint
            @tiles_due = false
            @tiles_fresh = true
            touch(:map)
            Visits.enter(ref && ref[0], @print)
          end
          @drops[:frame].each { |blk| blk.call }
        end
        return unless @tiles_due || (tiles && !@tiles_fresh)
        @tiles_due = false
        @tiles_fresh = true
        p = fingerprint
        return if !p.nil? && p == @print
        @print = p
        touch(:tiles)
      end

      # The map's tiles as they stand: the id, the layers, the tileset's passage, priority and terrain tables, its name
      # and the autotiles, dumped whole; nil when they cannot be read, which no later read equals.
      def self.fingerprint
        m = $game_map
        return nil unless m
        [m.map_id, Marshal.dump(m.data), Marshal.dump(table(m, :passages)), Marshal.dump(table(m, :priorities)),
         Marshal.dump(table(m, :terrain_tags)), Marshal.dump(table(m, :tileset_name)),
         Marshal.dump(table(m, :autotile_names))]
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # One of the map's tileset readers, nil where the engine has none.
      def self.table(m, name)
        m.respond_to?(name) ? m.send(name) : nil
      end
    end
  end
end

# A new map or a load (Caches.reset_all) keeps the memos of the map left (Visits) and forgets all the world keeps.
PokeAccess::Caches.register(:world) do
  PokeAccess::World::Epoch.leave
  PokeAccess::World.reset!
end
