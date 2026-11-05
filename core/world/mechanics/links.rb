module PokeAccess
  module World
    module Mechanics
      # What a control does to the walls of its mechanic, read off the obstacles' own pages: each shows the page whose
      # conditions hold, last first as RPG Maker picks it, the other flags taken as they stand (a lever that powers a
      # room is seen through); a variable by its value, so a door can wait for a count.
      module Links
        # The obstacle events that flipping watch entry w's flag would change now, as [[event, :open | :close, label],
        # ...], label the declared name of the wall it shows or takes away (nil for none).
        def self.effects(inst, w)
          return [] unless inst && inst.spec[:obstacles] && w
          over = { key(w) => flipped(w) }
          out = []
          walls(inst).each do |ev|
            now = live_page(ev, {})
            later = live_page(ev, over)
            closes = blocks?(later)
            next if blocks?(now) == closes
            out.push([ev, closes ? :close : :open, label(inst, ev, closes ? later : now)])
          end
          out
        end

        # A watch entry's flag the other way: a variable just past or short of where it reads on.
        def self.flipped(w)
          return !State.flag(w) unless w[:var]
          State.flag(w) ? (w[:from] || 1) - 1 : (w[:from] || 1)
        end

        # The label of the first wall entry of the declaration that takes in an event as a page draws it, or nil.
        def self.label(inst, ev, pg)
          hit = inst.spec[:obstacles].find { |o| o[:kind] != :mover && drawn_by?(o, ev, pg) }
          hit && hit[:label]
        end

        # True when an obstacle's entry takes in an event as a page draws it.
        def self.drawn_by?(o, ev, pg)
          Mechanics.takes?(o, ev, (pg.graphic.character_name.to_s rescue ""), (pg.graphic.tile_id rescue 0))
        end

        # A watch entry's flag as the key of an override: [:switch, id] or [:var, id].
        def self.key(w)
          w[:switch] ? [:switch, w[:switch]] : [:var, w[:var]]
        end

        # The events whose pages draw a wall the declaration names (moving obstacles aside), by id, kept per declaration
        # of the map: an event's pages never change.
        def self.walls(inst)
          @walls ||= {}
          key = [inst.map_id, inst.spec.object_id]
          return @walls[key] if @walls[key]
          entries = inst.spec[:obstacles].reject { |o| o[:kind] == :mover }
          list = ($game_map.events || {}).values.select do |ev|
            pages(ev).any? { |pg| entries.any? { |o| drawn_by?(o, ev, pg) } }
          end
          @walls[key] = list.sort_by { |ev| ev.id }
        end

        # What a plan takes as standing in the way as its page leaves it: the walls and the solid controls, as a boulder is until
        # it goes once worked.
        def self.standing(inst)
          out = walls(inst).dup
          (inst.controls || {}).each_key do |id|
            ev = ($game_map.events || {})[id]
            out.push(ev) if ev && !out.include?(ev) && !(ev.through rescue false)
          end
          out
        end

        # The flags some wall's pages depend on, as key => true: the only ones a press can change a wall by.
        def self.flags(inst)
          out = {}
          walls(inst).each do |ev|
            pages(ev).each do |pg|
              c = pg.condition
              next unless c
              out[[:switch, c.switch1_id]] = true if (c.switch1_valid rescue false)
              out[[:switch, c.switch2_id]] = true if (c.switch2_valid rescue false)
              out[[:var, c.variable_id]] = true if (c.variable_valid rescue false)
            end
          end
          out
        end

        # Drops the walls kept (a map change).
        def self.forget; @walls = nil; end

        # An event's pages.
        def self.pages(ev)
          rev = PokeAccess.ivar(ev, :@event)
          (rev && rev.pages) || []
        end

        # The page RPG Maker shows: the last whose conditions hold, with the flags in over ({key => on}, an event's self
        # switches among them) taken as given; nil when none does or the event was erased (it is gone either way).
        def self.live_page(ev, over)
          return nil if PokeAccess.ivar(ev, :@erased)
          pages(ev).reverse.find { |pg| holds?(pg.condition, ev, over) }
        end

        # Whether a page's conditions hold.
        def self.holds?(c, ev, over)
          return true unless c
          return false if (c.switch1_valid rescue false) && !switch(c.switch1_id, over)
          return false if (c.switch2_valid rescue false) && !switch(c.switch2_id, over)
          return false if (c.variable_valid rescue false) && variable(c.variable_id, over) < c.variable_value.to_i
          return false if (c.self_switch_valid rescue false) && !self_switch(ev.id, c.self_switch_ch, over)
          true
        end

        # An event's self switch as over gives it ([:self, event id, letter]), else as it stands.
        def self.self_switch(id, ch, over)
          k = [:self, id, ch]
          return over[k] if over.key?(k)
          $game_self_switches && $game_self_switches[[$game_map.map_id, id, ch]] ? true : false
        end

        # A switch as over gives it, else as it stands.
        def self.switch(id, over)
          k = [:switch, id]
          over.key?(k) ? over[k] : ($game_switches[id] ? true : false)
        end

        # A variable as over gives it, else as it stands.
        def self.variable(id, over)
          k = [:var, id]
          over.key?(k) ? over[k] : ($game_variables[id] || 0).to_i
        end

        # The tiles what stands in the way blocks with the flags in over, as Events.key (the routes' own) => true.
        def self.blocked(inst, over)
          out = {}
          standing(inst).each do |ev|
            next unless blocks?(live_page(ev, over))
            Events.tiles_of(ev).each { |x, y| out[Events.key(x, y)] = true }
          end
          out
        end

        # Whether a page draws a wall: a graphic, its through off.
        def self.blocks?(pg)
          return false unless pg
          g = pg.graphic
          drawn = !(g.character_name.to_s rescue "").empty? || (g.tile_id rescue 0).to_i > 0
          drawn && !(pg.through rescue false)
        end
      end
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::World::Mechanics::Links.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Mechanics::Links.forget }
