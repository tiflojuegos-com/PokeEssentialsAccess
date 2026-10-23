module PokeAccess
  module World
    module Mechanics
      # What a control does to the walls of its mechanic, read off the obstacles' own pages: each shows the page whose
      # conditions hold, last first as RPG Maker picks it, the other flags taken as they stand (a lever that powers a
      # room is seen through); a variable counts as 1 on and 0 off, as the rooms that declare one write it.
      module Links
        # The obstacle events that flipping watch entry w's flag would change now, as [[event, :open | :close, label],
        # ...], label the declared name of the wall it shows or takes away (nil for none).
        def self.effects(inst, w)
          return [] unless inst && inst.spec[:obstacles] && w
          over = { key(w) => !State.flag(w) }
          out = []
          walls(inst).each do |ev|
            now = live_page(ev, {})
            later = live_page(ev, over)
            closes = blocks?(later)
            next if blocks?(now) == closes
            out.push([ev, closes ? :close : :open, label(inst, closes ? later : now)])
          end
          out
        end

        # The label of the first wall entry of the declaration whose pattern a page's graphic matches, or nil.
        def self.label(inst, pg)
          n = (pg.graphic.character_name.to_s rescue "")
          hit = inst.spec[:obstacles].find { |o| o[:kind] != :mover && n =~ o[:match] }
          hit && hit[:label]
        end

        # A watch entry's flag as the key of an override: [:switch, id] or [:var, id].
        def self.key(w)
          w[:switch] ? [:switch, w[:switch]] : [:var, w[:var]]
        end

        # The events whose pages draw a wall the declaration names (moving obstacles aside), by id, kept per map: an
        # event's pages never change.
        def self.walls(inst)
          return @walls[1] if @walls && @walls[0] == inst.map_id
          pats = inst.spec[:obstacles].reject { |o| o[:kind] == :mover }.map { |o| o[:match] }
          list = ($game_map.events || {}).values.select do |ev|
            pages(ev).any? { |pg| n = (pg.graphic.character_name.to_s rescue ""); pats.any? { |re| n =~ re } }
          end
          list = list.sort_by { |ev| ev.id }
          @walls = [inst.map_id, list]
          list
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

        # A variable as over gives it (1 on, 0 off), else as it stands.
        def self.variable(id, over)
          k = [:var, id]
          return (over[k] ? 1 : 0) if over.key?(k)
          ($game_variables[id] || 0).to_i
        end

        # The tiles the walls block with the flags in over, as Events.key (the routes' own) => true.
        def self.blocked(inst, over)
          out = {}
          walls(inst).each do |ev|
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
