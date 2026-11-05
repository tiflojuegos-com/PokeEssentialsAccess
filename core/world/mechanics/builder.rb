module PokeAccess
  module World
    module Mechanics
      # What a profile's mechanic block declares (Mechanics.define), verb by verb, as the spec the types read: a :state
      # (watched flags, counts, phases, an info line), a :grid or turning statues (:facing). Where a verb takes events,
      # they come as an id, a range or list of ids, or a pattern on the event's name or graphic.
      class Builder
        attr_reader :spec

        def initialize(kind); @spec = { :kind => kind }; end

        # A watched flag, said as it changes: {:switch | :var | :self => [event, letter, map or this one] | :event => id, :label,
        # :on, :off}, :event on while that event is drawn. A variable reads on from 1, or from :from; with :words (value => word) or
        # :number it is said by its value. With :say, that line is all that is said, each time it changes to something
        # other than off or 0; with :quiet, nothing, and it stays out of the info key: for what only the assisted routes read.
        def watch(opts); add(:watch, opts); end

        # Finds the controls among the map's events: those whose page, fired by the player, writes a watched flag
        # (levers, plates). Not for rooms whose floor sensors write them.
        def controls; @spec[:controls] = true; end

        # Keeps what the core says and lists by itself on a map with no declaration (Puzzles::Auto): what a control opens
        # or closes, and its silent controls. The map keeps it only if all its mechanics ask for it.
        def auto; @spec[:auto] = true; end

        # Events that block the way, a wall while its page is not walked through: those whose graphic matches a pattern,
        # or {:tile => id}, {:events => what} or {:named => pattern} for those drawn with a tile, picked by id or by their
        # own name. :moving => true for one that moves, which sounds as a trap and is left out of the list; :label, the
        # name the walls it matches go by (the locator, and what a control does to them), entries tried in the order
        # declared.
        def obstacle(pattern, opts = {})
          took = (pattern.is_a?(Hash) ? pattern.dup : { :match => pattern }).merge!(opts)
          item = { :kind => took[:moving] ? :mover : :wall, :label => took[:label] }
          item[:match] = took[:match] if took[:match]
          item[:tile] = took[:tile] if took[:tile]
          item[:events] = Mechanics.picked(took[:events]) if took[:events]
          item[:named] = took[:named] if took[:named]
          add(:obstacles, item)
        end

        # Names events, listed in the puzzles category while they are drawn or their page can run, and called that in
        # every list. :numbered => true adds :n, their place in reading order, to the label's interpolations; a lambda with
        # one parameter gives the label of each event, asked each time it is read; :assist => true, with the puzzle assist
        # alone; :when, a test given the event for while it is listed (false: never).
        def name(what, label, opts = {})
          add(:names, opts.dup.merge!(:events => Mechanics.picked(what), :label => label))
        end

        # Events a walk keeps off while there is another way: floor that changes the puzzle when stepped on, though no wall
        # reads it (plates that change where something leads). A walk that ends on one still goes.
        def avoid(what); add(:avoids, Mechanics.picked(what)); end

        # Events the core should not take for silent controls, on a map that keeps what it says by itself (auto): what only
        # starts a scene.
        def not_control(what); add(:not_controls, Mechanics.picked(what)); end

        # Leaves events out of the lists and the sonar; :assist => true, with the puzzle assist alone (false exits).
        def hide(what, opts = {})
          add(:hides, opts.dup.merge!(:events => Mechanics.picked(what)))
        end

        # A count said as "label: n of total" as it grows, and in the info key's line: of :value (a lambda), :var (less :from),
        # :flags, :switches => ids or :selfs => [ids, letter, map], out of :of (by default, how many flags). As it falls, :reset is
        # said with it (a line; false: nothing). :announce => false leaves it to the info key, :hide_zero leaves out a
        # count of 0, :assist asks for the assist.
        def count(label, opts = {})
          add(:counts, { :announce => true, :reset => true }.merge!(Mechanics.counter(opts)).merge!(:label => label))
        end

        # Says why the game moved the player: label, for a move that lands in :to and leaves from :from (each [x, y] or
        # [x0, x1, y0, y1]) while the event last used is among :events; what is left out does not matter. A teleport within the
        # map, by default; with :maps => ids, a transfer from those maps onto this one (the event used goes with its map, so
        # no :events); with :forced => true, the end of a move route, in place of how far it went.
        def sent_back(label, opts = {})
          item = opts.dup.merge!(:label => label)
          item[:events] = Mechanics.picked(opts[:events]) if opts[:events]
          item[:maps] = Mechanics.picked(opts[:maps]) if opts[:maps]
          add(:sent_back, item)
        end

        # A line said when the player uses an event, its page starting: a transcription of what it shows; a lambda with one
        # parameter gets the event; :assist => true, with the puzzle assist alone.
        def on_use(what, label, opts = {})
          add(:uses, opts.dup.merge!(:events => Mechanics.picked(what), :label => label))
        end

        # A line said as an event's page gets to a point, where on_use's would come too soon: :choice => an option (its place in
        # the menu, from 0, or a pattern on its words), as its branch starts; :text => a Show Text (its place among the page's,
        # from 0, or a pattern on its words), right after it is read. Takes what on_use takes.
        def on_reach(what, point, label, opts = {})
          add(:reaches, opts.dup.merge!(point).merge!(:events => Mechanics.picked(what), :label => label))
        end

        # The answer an event asks for, said with the assist alone as it is used: for what the page itself does not compare.
        def answer(what, text); on_use(what, [:puzzle_answer, { :a => text }], :assist => true); end

        # The right option of the menus an event asks, a Show Command or a \ch[...] in its message, said with the assist alone as
        # each opens, in the game's own words: the one whose branch does what :takes says and not what :avoids says, each
        # {:var => id}, {:switch => id}, {:self => letter}, :transfer, :battle or :item; or sets a variable to a value,
        # {:var => id, :value => a number or a lambda}, or to the one another event's page takes as right,
        # {:var => id, :compared_by => event}, the first it compares it with or, with :moving => var, the first whose branch writes
        # that variable. Nothing is said unless just one is left.
        def right_choice(what, opts)
          add(:choices, opts.dup.merge!(:events => Mechanics.picked(what)))
        end

        # The win: its test, what is said once it holds (nil: nothing, or on a grid the core's line) and, with :quiet, left
        # to the info key alone. While it holds the room's rule says no more and the info key is silent. A phase goes on telling
        # what opens as it opens, for the rooms the game keeps working: its test takes the end in if it should stop.
        def solved(say = nil, opts = {}, &test)
          @spec[:solved] = test
          @spec[:solved_msg] = say
          @spec[:solved_quiet] = opts[:quiet]
        end

        # The hint, said with the puzzle assist.
        def hint(label); @spec[:hint] = label; end

        # A rule said on arriving at the map, queued, in full only (a description), and closing the info key's line;
        # not a spoiler: how the room works.
        def arrival_hint(label, opts = {})
          @spec[:arrival_hint] = label
          @spec[:arrival_once] = opts[:once]
        end

        # A named point for the locator: {:at => [x, y] | :event => id, :label}; :assist => true with the puzzle assist
        # alone, :when a test for while it is listed, :onto => true when it is stood on rather than faced.
        def spot(opts); add(:spots, opts); end

        # The info key's line, asked each time; with the assist, the hint follows it.
        def info(&blk); @spec[:info] = blk; end

        # While the mechanic answers the info key (by default: a :state with an info line until solved).
        def active(&blk); @spec[:active] = blk; end

        # A test for a phase: the player stands in the box, in map tiles (Mechanics.at).
        def at(x0, x1, y0, y1); Mechanics.at(x0, x1, y0, y1); end

        # What a phase lists with the assist alone: the events that go on (Mechanics.right_way).
        def right_way(*events); Mechanics.right_way(*events); end

        # A phase, live while test holds (the first live one is current): opts :title, :quiet, :entry_title, :hint,
        # :progress (as count takes it), :values, :sum, :spots, :hidden and :track (see State).
        def phase(test, opts = {})
          item = opts.dup.merge!(:when => test)
          item[:progress] = Mechanics.counter(opts[:progress]) if opts[:progress]
          add(:phases, item)
        end

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

        # A grid of the map's events, in rows and columns as they lie: said as "row, column: state" as the player stands on
        # one, listed while not :done (true by default), and counted in the info key's line with what lies to each side.
        # The state is the event's self switch :self (a letter), or what the block gives for it; :words => {state => word},
        # :label names one in the list and :count the count ("label: n of total", of those :done).
        def tiles(what, opts = {}, &state)
          @spec[:tiles] = Mechanics.picked(what)
          @spec[:tile_self] = opts[:self]
          @spec[:tile_state] = state
          @spec[:tile_words] = opts[:words]
          @spec[:tile_done] = opts.key?(:done) ? opts[:done] : true
          @spec[:tile_label] = opts[:label]
          @spec[:tile_count] = opts[:count]
        end

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
