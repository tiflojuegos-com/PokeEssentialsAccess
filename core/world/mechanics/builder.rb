module PokeAccess
  module World
    module Mechanics
      # What a profile's mechanic block declares (Mechanics.define), verb by verb, as the spec the types read: a :state
      # (watched flags, phases, an info line), a :grid or turning statues (:facing).
      class Builder
        attr_reader :spec

        def initialize(kind); @spec = { :kind => kind }; end

        # A watched switch or variable, its label and the words for on and off: {:switch | :var, :label, :on, :off}.
        def watch(opts); add(:watch, opts); end

        # Finds the controls among the map's events: those whose page, fired by the player, writes a watched flag
        # (levers, plates). Not for rooms whose floor sensors write them.
        def controls; @spec[:controls] = true; end

        # Events whose graphic matches pattern block the way; :moving => true for one that moves, which sounds as a
        # trap and is left out of the list; :label, the name the walls it matches go by (the locator, and what a
        # control does to them), patterns tried in the order declared.
        def obstacle(pattern, opts = {})
          add(:obstacles, :match => pattern, :kind => opts[:moving] ? :mover : :wall, :label => opts[:label])
        end

        # The win: its test, what is said once it holds (nil: nothing) and, with :quiet, left to the info key alone.
        def solved(say = nil, opts = {}, &test)
          @spec[:solved] = test
          @spec[:solved_msg] = say
          @spec[:solved_quiet] = opts[:quiet]
        end

        # The hint, said with the puzzle assist.
        def hint(label); @spec[:hint] = label; end

        # A rule said on arriving at the map, queued, in full only (a description), and closing the info key's line;
        # not a spoiler: how the room works.
        def arrival_hint(label); @spec[:arrival_hint] = label; end

        # A named point for the locator: {:at => [x, y] | :event => id, :label}.
        def spot(opts); add(:spots, opts); end

        # The info key's line, asked each time; with the assist, the hint follows it.
        def info(&blk); @spec[:info] = blk; end

        # While the mechanic answers the info key (by default: a :state with an info line until solved).
        def active(&blk); @spec[:active] = blk; end

        # A phase, live while test holds (the first live one is current): opts :title, :quiet, :hint, :progress,
        # :values, :sum, :spots, :hidden and :track (see State).
        def phase(test, opts = {}); add(:phases, opts.dup.merge!(:when => test)); end

        # A grid's cells in reading order, cols to a row.
        def cells(cols, list)
          @spec[:cols] = cols
          @spec[:rows] = list.length / cols
          @spec[:cells] = list
        end

        # Whether a grid's cell, by its index, is lit.
        def lit(&blk); @spec[:lit] = blk; end

        # The letter a grid asks for now, {:name, :pattern}, or nil.
        def target(&blk); @spec[:target] = blk; end

        # Turning statues: the graphic they wear and their name.
        def statues(pattern, label)
          @spec[:match] = pattern
          @spec[:label] = label
        end

        # The facing the game checks for each statue, by its tile: {[x, y] => direction}.
        def goals(map); @spec[:targets] = map; end

        private

        def add(key, item); (@spec[key] ||= []).push(item); end
      end
    end
  end
end
