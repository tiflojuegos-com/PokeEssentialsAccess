module PokeAccess
  module World
    # The live state an event's pages are read against (switches, variables, self switches, the bag, visited maps, the
    # vehicle, a character's facing), noted by the facet that reads it so the facet goes when any of it changes; a read
    # nothing can watch (a game's script call) makes it volatile, lasting until the next event's end.
    module Flags
      @deps = nil
      @volatile = 0

      # Runs the block noting every read made inside it, and answers [the block's value, the reads as [key, value]
      # pairs]; nested readings each note their own.
      def self.reading
        outer = @deps
        @deps = []
        v = yield
        [v, @deps]
      ensure
        @deps = outer
      end

      # Ends the volatile facets' lease: an event's end may have changed what they read.
      def self.event_ended!; @volatile += 1; end

      # Notes a read nothing can watch.
      def self.volatile!; note([:volatile], @volatile); end

      # True while every read noted still gives the value it gave; a read that fails now has changed.
      def self.current?(deps)
        deps.each { |k, v| return false unless read(k) == v }
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Whether a switch is on.
      def self.switch(id); note([:switch, id], read([:switch, id])); end

      # A variable's value.
      def self.variable(id); note([:variable, id], read([:variable, id])); end

      # Whether a self switch ([map, event, letter]) is on.
      def self.self_switch(key); note([:self_switch, key], read([:self_switch, key])); end

      # Whether the player surfs, dives or rides (:surfing, :diving, :bicycle).
      def self.vehicle(name); note([:vehicle, name], read([:vehicle, name])); end

      # How many of an item (a symbol) the bag holds, or nil when no bag answers.
      def self.bag(item); note([:bag, item], read([:bag, item])); end

      # Whether a map has been visited.
      def self.visited(id); note([:visited, id], read([:visited, id])); end

      # Whether the player can use a field move now (FieldMoves.can?), asked once a frame.
      def self.field_move(move); note([:field_move, move], read([:field_move, move])); end

      # The facing of event id on this map, or nil; given the event itself, its own facing.
      def self.direction(id, ev = nil)
        note([:direction, id], ev ? (ev.direction rescue nil) : read([:direction, id]))
      end

      # Whether the Lens of Truth is in use (World::Lens.on?).
      def self.lens; note([:lens], read([:lens])); end

      # The live value behind a key, a switch as the floor looked at has it (Floors). A read that fails raises, as the
      # page reader takes a condition it cannot read for unknown; only a facing nobody has reads as nil.
      def self.read(k)
        case k[0]
        when :switch then Floors.on?(k[1])
        when :variable then $game_variables[k[1]]
        when :self_switch then ($game_self_switches[k[1]] ? true : false)
        when :vehicle then ($PokemonGlobal.send(k[1]) ? true : false)
        when :bag then PokeAccess::Engine.bag_quantity(k[1])
        when :visited then ($PokemonGlobal.visitedMaps[k[1]] ? true : false)
        when :direction then ($game_map.events[k[1]].direction rescue nil)
        when :volatile then @volatile
        when :lens then PokeAccess::World::Lens.on?
        when :field_move then field_move_now(k[1])
        end
      end

      # FieldMoves.can? for a move, kept for the frame (Epoch.frame): the events' check of their flags asks it every
      # frame.
      def self.field_move_now(move)
        f = PokeAccess::World::Epoch.frame
        @moves = [f, {}] unless @moves && @moves[0] == f
        kept = @moves[1]
        kept.key?(move) ? kept[move] : (kept[move] = PokeAccess::FieldMoves.can?(move))
      end

      # Notes a read made inside a reading and answers its value; a String or an Array is kept as it stands now, so a
      # change made to it in place still shows.
      def self.note(key, value)
        @deps.push([key, (value.is_a?(String) || value.is_a?(Array)) ? value.dup : value]) if @deps
        value
      end
    end
  end
end
