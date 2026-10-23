module PokeAccess
  module World
    # The world's memos of the last SIZE maps visited, where the game declared its passability plain (Probe.plain!):
    # kept as the player leaves a map and put back on coming back while its tiles stand (Epoch's fingerprint), the
    # probe's answers on its events' tiles dropped. Each keeper registers what it saves and how it puts it back.
    module Visits
      # How many maps are kept.
      SIZE = 8

      @keepers = []
      @kept = []

      # Registers a memo kept per map: save gives its state, restore takes such a state back.
      def self.keeper(save, restore); @keepers.push([save, restore]); end

      # Keeps the memos of the map being left (its id and Epoch's fingerprint of its tiles), with the tiles its events
      # covered.
      def self.leave(map_id, print)
        return if map_id.nil? || print.nil? || !Probe.plain?
        @kept.delete_if { |k| k[0] == map_id }
        @kept.push([map_id, print, Events.covered, @keepers.map { |save, _restore| save.call }])
        @kept.shift while @kept.length > SIZE
      end

      # Puts back the memos kept for the map entered when its tiles are as they were left, dropping the probe's answers
      # on the tiles its events covered then; a map whose tiles changed is forgotten.
      def self.enter(map_id, print)
        hit = @kept.find { |k| k[0] == map_id }
        return unless hit
        @kept.delete(hit)
        return unless !print.nil? && hit[1] == print && Probe.plain?
        @keepers.each_with_index { |(_save, restore), i| restore.call(hit[3][i]) }
        Probe.forget_tiles(hit[2])
      end

      # The ids of the maps kept, oldest first.
      def self.maps; @kept.map { |k| k[0] }; end

      # Forgets every map kept.
      def self.forget; @kept = []; end
    end
  end
end
