module PokeAccess
  # Locator part 3 of 3 (core): holds all locator state, builds/cycles the target list by category,
  # numbers targets, speaks the focused target/route/coords, and drives everything once per map frame.
  # Naming lives in locator_naming, surface targets in locator_surfaces; the guides toward the target are Guide's.
  module Locator
    @targets = []; @ti = 0; @cat_id = :all; @target = nil
    @last_map_id = nil; @last_map_ref = nil
    @surface_cache = nil; @surface_cache_pos = nil
    @interp_running = false
    @teleport_causes = []

    # The categories whose targets are made by the locator itself, not events: never hidden by reach, nor grouped by
    # room.
    SYNTHETIC = [:surfaces, :puzzles, :marks]

    # Category symbol => spoken-name localization key.
    TCAT_KEYS = { :all => :tcat_all, :people => :tcat_people, :objects => :tcat_objects,
                  :exits => :tcat_exits, :signs => :tcat_signs, :extras => :tcat_extras,
                  :surfaces => :tcat_surfaces, :puzzles => :tcat_puzzles, :lens => :tcat_lens,
                  :marks => :tcat_marks }

    # The spoken name of a target category.
    def self.cat_name(cat)
      PokeAccess::I18n.t(TCAT_KEYS[cat] || :tcat_all)
    end

    # A relative direction phrase from a delta (e.g. "3 left, 2 up").
    def self.dir_phrase(dx, dy)
      parts = []
      parts.push("#{dx.abs} #{PokeAccess::I18n.t(dx < 0 ? :dir_left : :dir_right)}") if dx != 0
      parts.push("#{dy.abs} #{PokeAccess::I18n.t(dy < 0 ? :dir_up : :dir_down)}") if dy != 0
      parts.empty? ? PokeAccess::I18n.t(:loc_here) : parts.join(", ")
    end

    # The player's category override for an event (:people/:objects/:exits/:signs), or nil for auto.
    def self.tag_override(ev)
      eid = event_id_of(ev)
      return nil unless $game_map && eid
      PokeAccess::Tags.category($game_map.map_id, eid)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True if the player hid this event (Ctrl+K), so it is left out of the locator entirely.
    def self.tag_hidden?(ev)
      eid = event_id_of(ev)
      return false unless $game_map && eid
      PokeAccess::Tags.hidden?($game_map.map_id, eid)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an event belongs in the given target category: the player's override (Ctrl+K) wins over detection, and
    # an exit never counts as a person or an object, sprite or not.
    def self.in_category?(ev, cat)
      ov = tag_override(ev)
      if ov
        return true if cat == :all
        return cat == ov
      end
      named = !ev.character_name.to_s.empty?
      case cat
      when :exits  then transfer_event?(ev)
      when :signs  then sign_event?(ev)
      when :extras then !named && examinable?(ev) && !sign_event?(ev) && !transfer_event?(ev)
      when :lens   then lens_tile?(ev)
      when :all    then named || transfer_event?(ev) || examinable?(ev) || lens_tile?(ev)
      else              named && !transfer_event?(ev) && event_category(ev) == cat
      end
    end

    # The categories to cycle now: the configured ones, with puzzles, lens (#EOT tiles) and marks only while there is
    # something to locate in them.
    def self.active_categories
      base = PokeAccess::Config.categories.reject { |c| c == :puzzles || c == :lens || c == :marks }
      base += [:puzzles] if (PokeAccess::Puzzles.has_locator_targets? rescue false)
      base += [:lens] if any_lens_tile?
      base += [:marks] if marks_here?
      base
    end

    # True if the current map carries at least one of the player's marks, gating the :marks category.
    def self.marks_here?
      !!($game_map && PokeAccess::Marks.any_on?($game_map.map_id))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if the current map holds a lens (#EOT) tile, a reachable one while hiding; gates :lens.
    def self.any_lens_tile?
      return false unless $game_map
      tiles = $game_map.events.values.select { |ev| lens_tile?(ev) }
      return false if tiles.empty?
      return true unless hiding?
      tiles.any? { |ev| reachable?(ev) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The category the list shows: the one chosen while it can be cycled to, else all.
    def self.category
      cats = active_categories
      cats.include?(@cat_id) ? @cat_id : cats[0]
    end

    # Rebuilds the target list of the category shown, in the order chosen (target_order), numbers its targets
    # (number_of) and keeps the selection by identity.
    def self.rebuild_targets
      @targets_stale = false
      @targets = []
      @door_ids = {}
      return unless $game_map && $game_player
      cat = category
      all = candidates(cat)
      @rank = {}
      all.each_with_index { |t, i| @rank[identity(t)] = rank_key(t, i) }
      ranks = static_ranks(cat, all)
      @static = {}
      ranks.keys.sort_by { |id| ranks[id] }.each_with_index { |id, i| @static[id] = i + 1 }
      @static_total = ranks.length
      @targets = ordered(filtered(all, cat), cat)
      @dynamic = numbered(@targets)
      reselect
    end

    # Every target of category cat on the map before any is hidden: its events (a wide doorway as one, see
    # cluster_exits) and the connections the player can step off the map into, or its synthetic targets.
    def self.candidates(cat)
      case cat
      when :surfaces then (surface_targets.dup rescue [])
      when :puzzles then (PokeAccess::Puzzles.category_targets rescue [])
      when :marks then mark_targets
      else
        list = $game_map.events.values.select { |ev| in_category?(ev, cat) && !hidden?(ev) }
        list = cluster_exits(list, $game_player.x, $game_player.y)
        list.concat(connection_targets.map { |t| aim_connection(t) }.compact) if cat == :exits || cat == :all
        list
      end
    end

    # The targets of all to list in category cat: with hide_noninteractive only interactable ones (but in lens); while
    # hiding, only those the player can get to, map edges included (all when none can, but in lens); with :room, only
    # those of the player's own room.
    def self.filtered(all, cat)
      return all if SYNTHETIC.include?(cat)
      list = all
      if cat != :lens && (PokeAccess::Config.hide_noninteractive rescue false)
        list = list.select { |t| t.is_a?(SurfaceTarget) || interactable?(t) }
      end
      return list unless hiding?
      reachable_only = list.select { |t| reachable?(t) }
      list = reachable_only if cat == :lens || !reachable_only.empty?
      if (PokeAccess::Config.hide_unreachable rescue nil) == :room
        own = list.select { |t| (room_depth(t) || 0) == 0 }
        list = own unless own.empty?
      end
      list
    end

    # The targets in the order chosen (target_order), each one's key kept for J and L: :near by distance counting no
    # walls, :walk by fewest presses (Routes::Regions#presses_to; no way, or none known yet, last by distance), :fixed
    # alone; while rooms are told apart the player's own room comes first, except in :fixed. Ties go by rank_key.
    def self.ordered(list, cat)
      order = (PokeAccess::Config.target_order rescue :near)
      px = $game_player.x; py = $game_player.y
      reg = order == :walk ? PokeAccess::Routes::Regions.foot : nil
      rooms = order != :fixed && !SYNTHETIC.include?(cat) && rooms_apart?
      @keys = {}
      list.each do |t|
        id = identity(t)
        d = (t.x - px).abs + (t.y - py).abs
        w = reg && reg.presses_to(goal_of(t).tiles)
        key = case order
              when :fixed then [0, 0]
              when :walk then w ? [0, w] : [1, d]
              else [0, d]
              end
        @keys[id] = [rooms ? (room_depth(t) || 1000) : 0] + key + @rank[id]
      end
      list.sort_by { |t| @keys[identity(t)] }
    end

    # A target's identity, the same across rebuilds: an event's id (a wide doorway's, the least of its tiles' ids), a
    # connection's destination map, any other synthetic target's key with what it was made for (its ref; :surface for
    # a surface, whichever of its tiles is nearest) or else its tile.
    def self.identity(t)
      return [:event, (@door_ids && @door_ids[t.id]) || t.id] unless t.is_a?(SurfaceTarget)
      return [:edge, t.ref] if t.key.nil?
      t.ref.nil? ? [t.key, t.x, t.y] : [t.key, t.ref]
    end

    # A target's place in the fixed order: events by id (a wide doorway by its least), then connections by destination
    # map, then the synthetic targets in the order their source lists them (i).
    def self.rank_key(t, i)
      id = identity(t)
      case id[0]
      when :event then [0, id[1].to_i]
      when :edge then [1, id[1].to_i]
      else [2, i]
      end
    end

    # The fixed-order ranks the static numbers count (number_of), as { identity => rank_key }: of an event category,
    # every target of it seen since the map was entered, so a number keeps its gap when its target goes or is hidden;
    # of a synthetic one, those it has now.
    def self.static_ranks(cat, all)
      now = {}
      all.each { |t| now[identity(t)] = @rank[identity(t)] }
      return now if SYNTHETIC.include?(cat)
      seen = ((@seen ||= {})[cat] ||= {})
      seen.merge!(now)
    end

    # Numbers targets in the fixed order from 1, as { identity => number }.
    def self.numbered(list)
      out = {}
      list.map { |t| identity(t) }.sort_by { |id| @rank[id] }.each_with_index { |id, i| out[id] = i + 1 }
      out
    end

    # Points the selection at its target in the fresh list, found by identity; a target gone from it keeps the index,
    # or goes to the first one when that index is past the list's end.
    def self.reselect
      sel = @target && identity(@target)
      i = sel && @targets.index { |t| identity(t) == sel }
      if i
        @ti = i
        @target = @targets[i]
      elsif @ti >= @targets.length
        @ti = 0
      end
    end

    # Collapses a wide doorway (8-connected transfer tiles with one exit, see same_exit?) into the tile that stands for
    # it (door_rank), chained by union-find, noting for each of its tiles the least id among them, its identity; other
    # events pass through, and order is not kept.
    def self.cluster_exits(events, px, py)
      return events if events.length <= 1
      doors = []
      descs = []
      events.each_with_index do |ev, i|
        d = (transfer_event?(ev) rescue false) ? exit_descriptor(ev) : nil
        next if d.nil?
        doors.push(i)
        descs.push(d)
      end
      return events if doors.length <= 1
      groups = PokeAccess::Util.union_groups(doors.length) do |a, b|
        same_exit?(descs[a], descs[b]) &&
          (events[doors[a]].x - events[doors[b]].x).abs <= 1 &&
          (events[doors[a]].y - events[doors[b]].y).abs <= 1
      end
      is_door = {}
      doors.each { |i| is_door[i] = true }
      kept = {}
      reg = (PokeAccess::Config.target_order rescue :near) == :walk ? PokeAccess::Routes::Regions.foot : nil
      groups.each do |idxs|
        best = idxs.min_by { |k| door_rank(events[doors[k]], px, py, reg) }
        kept[doors[best]] = true
        least = idxs.map { |k| events[doors[k]].id }.min
        idxs.each { |k| @door_ids[events[doors[k]].id] = least } if @door_ids
      end
      out = []
      events.each_with_index { |ev, i| out.push(ev) if kept[i] || !is_door[i] }
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      events
    end

    # How a wide doorway's tile ranks to stand for it: one the player can get to first (walked for while hiding), then
    # the fewest presses on foot with reg (the walk order's regions), else the nearest counting no walls.
    def self.door_rank(ev, px, py, reg)
      w = reg && reg.presses_to(goal_of(ev).tiles)
      [reach_status(ev, hiding?)[0] == :no ? 1 : 0, w ? 0 : 1, w || (ev.x - px).abs + (ev.y - py).abs]
    end

    # An exit's destination for clustering: the transfer command's [map, x, y], else the script transfer's map, else
    # the sprite name (doorway tiles are distinct events that share a sprite).
    def self.exit_descriptor(ev)
      xy = (transfer_command_dest_xy(ev) rescue nil)
      return [:xy, xy[0], xy[1], xy[2]] unless xy.nil?
      sd = (transfer_script_dest(ev) rescue nil)
      return [:map, sd] unless sd.nil?
      [:char, (ev.character_name.to_s rescue "")]
    end

    # True if two exit descriptors belong to one doorway: the same map with landing spots within a tile of each other,
    # or, with no known landing spot, the same script map or sprite.
    def self.same_exit?(a, b)
      return false if a.nil? || b.nil?
      if a[0] == :xy
        b[0] == :xy && a[1] == b[1] && (a[2] - b[2]).abs <= 1 && (a[3] - b[3]).abs <= 1
      else
        a == b
      end
    end

    # True unless the player cannot get to the target (reach_status); true while that cannot be told yet.
    def self.reachable?(t)
      reach_status(t)[0] != :no
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end

    # How many rooms away the target lies, by the fewest transfers to other spots of the map on the way: 0 in the
    # player's own. Nil unless rooms_apart?, for a synthetic target but a map edge, and until the regions are all
    # walked and reach it.
    def self.room_depth(t)
      return nil if t.nil? || (t.is_a?(SurfaceTarget) && !edge?(t)) || !rooms_apart?
      s = reach_status(t)
      s[0] == :yes && PokeAccess::Routes::Regions.foot.done? ? s[1] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the player can get to the target, the answer the routes give up by too (Routes::Planner.reach of
    # goal_of), walked on within the question's allowance with walk.
    def self.reach_status(t, walk = true)
      PokeAccess::Routes::Planner.reach(goal_of(t), walk)
    end

    # What getting to a target means, the same for hiding it, ordering it and routing to it (Routes::Planner.goal_for).
    def self.goal_of(t)
      PokeAccess::Routes::Planner.goal_for(t.x, t.y, onto?(t))
    end

    # True for a target stood on rather than acted on: a spot to dive at or come up, a map edge, or a puzzle's floor
    # (Puzzles.onto?).
    def self.onto?(t)
      dive_key(t) || edge?(t) || PokeAccess::Puzzles.onto?(t) ? true : false
    end

    # True for a map edge's exit, the synthetic target with no surface kind.
    def self.edge?(t)
      t.is_a?(SurfaceTarget) && t.key.nil?
    end

    # True while the locator hides targets: hide_unreachable at :unreachable, or at :room, other rooms' too.
    def self.hiding?
      m = (PokeAccess::Config.hide_unreachable rescue :off)
      m == :unreachable || m == :room
    end

    # True when the regions tell rooms apart: while hiding, whose filter already asks them, on a map with a transfer
    # to another spot of itself.
    def self.rooms_apart?
      return false unless hiding?
      (PokeAccess::Routes::Effects.warp_map? rescue false) ? true : false
    end

    # The selected target, nil with none.
    def self.target; @target; end

    # True when the current target still applies: a mark still set, a surface tile, or an event still on the map with
    # something to locate (in_category? of all): not one erased, nor an item ball picked up.
    def self.target_valid?
      return false unless @target && $game_map
      return !PokeAccess::Marks.get($game_map.map_id, @target.x, @target.y).nil? if mark_target?(@target)
      return true if @target.is_a?(SurfaceTarget)
      id = (@target.id rescue nil)
      !id.nil? && $game_map.events[id] == @target && in_category?(@target, :all)
    end

    # Ensures a valid target: a stale list is rebuilt keeping the selection, and a vanished target is replaced by the
    # one now at its index.
    def self.ensure_target
      if @targets_stale && target_valid?
        rebuild_targets
        return
      end
      return if target_valid?
      rebuild_targets
      @ti = @targets.length - 1 if @ti >= @targets.length
      @ti = 0 if @ti < 0
      @target = @targets[@ti]
    end

    # Selects the target at the current index and announces it, after said (a line to say first) if any.
    def self.select_current(said = nil)
      @target = @targets[@ti]
      announce_selected(true, said)
      PokeAccess::Guide.arm(:cane)
      PokeAccess::Guide.arm(:steps)
    end

    # Moves the selection by delta (+1/-1) along the freshly rebuilt list: from the selected target, or, when it is no
    # longer listed, to the next (or previous) one in the order it held. A category gone, or left empty, gives way to
    # all, said before the target.
    def self.step(delta)
      sel = @target && identity(@target)
      prev = sel && (@keys || {})[sel]
      rebuild_targets
      said = back_to_all
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_no_targets), true) if @targets.empty?
      i = sel && @targets.index { |t| identity(t) == sel }
      @ti = if i then (i + delta) % @targets.length
            elsif prev then past(prev, delta)
            else @ti % @targets.length
            end
      select_current(said)
    end

    # When the chosen category is out of the cycle, or its list came out empty, shows all instead: the category line
    # to say before the target, or nil.
    def self.back_to_all
      cat = category
      return nil if cat == @cat_id && (!@targets.empty? || cat == :all)
      @cat_id = active_categories[0]
      rebuild_targets if cat != @cat_id
      PokeAccess::I18n.t(:loc_category, :cat => cat_name(@cat_id), :n => @targets.length)
    end

    # Where L (delta 1) or J (-1) goes when the selection is gone: the first target ordered after the key it held
    # (prev), or the last before it, round the list.
    def self.past(prev, delta)
      keys = @targets.map { |t| @keys[identity(t)] }
      if delta > 0
        keys.index { |k| (k <=> prev) > 0 } || 0
      else
        keys.rindex { |k| (k <=> prev) < 0 } || keys.length - 1
      end
    end

    # The shared rename flow: announce "label for X", prompt with the current value, save the name typed (via the
    # block) and say so; a blank answer, which is also what Escape gives, changes nothing and says it was cancelled.
    # keys: [announce_key, prompt_key, saved_key].
    def self.prompt_rename(current_name, current_value, keys)
      PokeAccess.speak(PokeAccess::I18n.t(keys[0], :name => current_name), true)
      txt = (pbEnterText(PokeAccess::I18n.t(keys[1]), 0, 40, current_value) rescue nil).to_s.strip
      return PokeAccess.speak(PokeAccess::I18n.t(:cancelled), true) if txt.empty?
      yield(txt)
      PokeAccess.speak(PokeAccess::I18n.t(keys[2], :label => txt), true)
    end

    # The player's marks on this map as synthetic targets (SurfaceTarget with the key :mark).
    def self.mark_targets
      mid = $game_map.map_id
      PokeAccess::Marks.on_map(mid).map { |x, y, name| SurfaceTarget.new(x, y, name, :mark) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # True if a target is one of the player's marks (a synthetic target carrying the :mark key).
    def self.mark_target?(t)
      t.is_a?(SurfaceTarget) && t.key == :mark
    end

    # The map-event id of a target, or nil for a synthetic one (a surface, a mark, a map edge). Checked by class, not
    # respond_to?(:id): on 1.8.7 every object has Object#id.
    def self.event_id_of(t)
      return nil if t.nil? || t.is_a?(SurfaceTarget)
      (t.id rescue nil)
    end

    # Gives the focused object a custom spoken label (Shift+K), stored in the shareable tag dictionary under each of
    # its tiles (tag_ids); a blank answer keeps the one it has, which the Ctrl+K menu takes off. Surfaces (no event
    # id) cannot be tagged.
    def self.rename_target
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return edit_mark(@target.x, @target.y) if mark_target?(@target)
      eid = event_id_of(@target)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && eid
      mid = $game_map.map_id
      ids = tag_ids(@target)
      cur = (PokeAccess::Tags.get(mid, eid) rescue nil).to_s
      prompt_rename(target_name(@target), cur, [:loc_label_for, :loc_label_prompt, :loc_label_saved]) do |label|
        ids.each { |k| PokeAccess::Tags.set(mid, k, label) }
      end
    end

    # The map-event ids a tag on target t goes under: every tile of a wide doorway (as cluster_exits noted them at the
    # last rebuild), else its own id.
    def self.tag_ids(t)
      eid = event_id_of(t)
      least = (@door_ids || {})[eid]
      return [eid] if least.nil?
      @door_ids.keys.select { |k| @door_ids[k] == least }.sort
    end

    # Renames the current map (Shift+M), stored in the shareable map-name dictionary; on a map the player has named, a
    # menu first offers to rename it or to restore the game's own name. The override also drives how exits to this
    # map are announced.
    def self.rename_map
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map
      mid = $game_map.map_id
      cur = (PokeAccess::MapNames.get(mid) rescue nil).to_s
      unless cur.empty?
        sel = (show_menu(PokeAccess::I18n.t(:map_menu, :name => map_name(mid).to_s),
                         [PokeAccess::I18n.t(:tag_rename), PokeAccess::I18n.t(:map_restore), PokeAccess::I18n.t(:back)], 3) rescue 2)
        if sel == 1
          PokeAccess::MapNames.delete(mid)
          return PokeAccess.speak(PokeAccess::I18n.t(:map_label_removed), true)
        end
        return unless sel == 0
      end
      prompt_rename(map_name(mid).to_s, cur, [:map_label_for, :map_label_prompt, :map_label_saved]) do |label|
        PokeAccess::MapNames.set(mid, label)
      end
    end

    # Category options the player can force via Ctrl+K: nil = automatic detection, then the categories.
    TAG_OVERRIDES = [nil, :people, :objects, :exits, :signs]

    # The Ctrl+K menu's entries => their label keys.
    TAG_MENU_KEYS = { :rename => :tag_rename, :unname => :tag_unname, :recat => :tag_recat, :hide => :tag_hide,
                      :back => :back }

    # Shows a choice message and returns the chosen (or cancel) index, through Kernel.pbMessage on gen-6 and the
    # global pbMessage elsewhere.
    def self.show_menu(msg, choices, cancel)
      return Kernel.pbMessage(msg, choices, cancel) if Kernel.respond_to?(:pbMessage)
      pbMessage(msg, choices, cancel)
    end

    # The Ctrl+K menu for the focused object, in the game's choice window: rename it, take off the name the player gave
    # it (offered only while it has one), recategorise or hide it (Tags), each of its tiles (tag_ids).
    def self.tag_menu
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return mark_menu(@target) if mark_target?(@target)
      eid = event_id_of(@target)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && eid
      mid = $game_map.map_id
      ids = tag_ids(@target)
      loop do
        named = !(PokeAccess::Tags.get(mid, eid) rescue nil).to_s.empty?
        acts = named ? [:rename, :unname, :recat, :hide, :back] : [:rename, :recat, :hide, :back]
        sel = (show_menu(PokeAccess::I18n.t(:tag_menu, :name => target_name(@target)),
                         acts.map { |a| PokeAccess::I18n.t(TAG_MENU_KEYS[a]) }, acts.length) rescue acts.length - 1)
        case acts[sel]
        when :rename
          rename_target
        when :unname
          ids.each { |k| PokeAccess::Tags.set(mid, k, "") }
          PokeAccess.speak(PokeAccess::I18n.t(:loc_label_removed), true)
        when :recat
          labels = TAG_OVERRIDES.map { |c| PokeAccess::I18n.t(c.nil? ? :tag_auto : TCAT_KEYS[c]) }
          ci = (show_menu(PokeAccess::I18n.t(:tag_cat_prompt), labels, labels.length + 1) rescue -1)
          if ci >= 0 && ci < TAG_OVERRIDES.length
            ids.each { |k| PokeAccess::Tags.set_category(mid, k, TAG_OVERRIDES[ci]) }
            rebuild_targets
            PokeAccess.speak(PokeAccess::I18n.t(:tag_recat_done, :cat => labels[ci]), true)
          end
        when :hide
          nm = target_name(@target)
          ids.each { |k| PokeAccess::Tags.set_hidden(mid, k, true) }
          rebuild_targets
          @ti = 0; @target = @targets[0]
          return PokeAccess.speak(PokeAccess::I18n.t(:tag_hidden_done, :name => nm), true)
        else
          return
        end
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The number a target is said with and its total, by target_numbering: its place in the list (:off), in the fixed
    # order among those listed (:dynamic), or among every target of the category seen on the map, gaps kept for those
    # hidden or gone (:static, static_ranks). Nil for a target the list does not hold.
    def self.number_of(t)
      id = identity(t)
      case (PokeAccess::Config.target_numbering rescue :dynamic)
      when :off
        i = @targets.index { |x| identity(x) == id }
        i ? [i + 1, @targets.length] : nil
      when :static then (n = (@static || {})[id]) ? [n, @static_total] : nil
      else (n = (@dynamic || {})[id]) ? [n, @targets.length] : nil
      end
    end

    # The walking route to a target and the suffix it is said with: [route or nil, the list's suffix (Routes::Text)].
    def self.route_phrase(target)
      plan = route_plan(target)
      [plan.kind == :walk ? plan.route : nil, PokeAccess::Routes::Text.listing(plan)]
    rescue StandardError => e
      PokeAccess.log_once("route_phrase", e)
      [nil, ""]
    end

    # The note on a target in another room of the map: "in another room", or how many rooms away; nil in the
    # player's own room, where it cannot be told, or when the room_note reading leaves it out. The regions tell it
    # while rooms_apart?, else the route about to be said, by the transfers it goes through.
    def self.room_note(t, path)
      return nil unless PokeAccess::Verbosity.keep?(:room_note, :medium)
      n = rooms_apart? ? room_depth(t) : (path.respond_to?(:rooms) ? path.rooms : nil)
      return nil if n.nil? || n <= 0
      n == 1 ? PokeAccess::I18n.t(:loc_other_room) : PokeAccess::I18n.t(:loc_rooms_away, :n => n)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The way to a target (Routes::Planner), to stand on it or to act on it as goal_of takes it; for a puzzle's goal
    # with the assist, the way to push its piece into it (Puzzles.carry_plan).
    def self.route_plan(t)
      PokeAccess::Puzzles.carry_plan(t) || PokeAccess::Routes::Planner.plan(t.x, t.y, onto?(t))
    rescue StandardError => e
      PokeAccess.log_once("route_plan", e)
      PokeAccess::Routes::Plan.new(:none)
    end

    # Speaks the direction to the selected target (on a map edge's exit, the way off the map: edge_out), and with
    # withname its name, the marks shown over it, its number and walking distance too, after said (a line to say
    # first) if any.
    def self.announce_selected(withname, said = nil)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil? || $game_player.nil?
      out = edge_out(@target)
      phrase = out ? PokeAccess::Routes::Text.out(out) : dir_phrase(@target.x - $game_player.x, @target.y - $game_player.y)
      unless withname
        return PokeAccess.speak(phrase, true)
      end
      ord = number_of(@target)
      ordtxt = ord ? (PokeAccess::I18n.t(:loc_count, :n => ord[0], :total => ord[1]) + ", ") : ""
      path, steps = route_phrase(@target)
      parts = [target_name(@target)].concat((name_marks(@target) rescue []) || [])
      note = room_note(@target, path)
      parts.push(note) if note
      line = "#{parts.join(", ")}, #{ordtxt}#{phrase}#{steps}"
      PokeAccess.speak(said ? "#{said}. #{line}" : line, true)
    end

    # Ctrl+G: sets or renames the mark on the player's tile. Map only, with the locator's keys free (Control.keys?: no
    # battle, no screen looping over the map): the key is polled from Input.update, which also runs in menus and
    # battles.
    def self.mark_here
      unless PokeAccess::Control.on_map? && PokeAccess::Control.keys?
        return PokeAccess.speak(PokeAccess::I18n.t(:mark_map_only), true)
      end
      edit_mark($game_player.x, $game_player.y)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Prompts for the name of the mark on a tile (new or existing) and persists the answer; a blank answer changes
    # nothing (the Ctrl+K menu deletes a mark). Shared by Ctrl+G, Shift+K on a mark and the Ctrl+K menu.
    def self.edit_mark(x, y)
      mid = $game_map.map_id
      cur = (PokeAccess::Marks.get(mid, x, y) rescue nil).to_s
      shown = cur.empty? ? coords_text(x, y) : cur
      keys = [cur.empty? ? :mark_for : :mark_edit_for, :mark_prompt, :mark_saved]
      prompt_rename(shown, cur, keys) { |label| PokeAccess::Marks.set(mid, x, y, label) }
      PokeAccess::Events.emit(:tags_changed)
      ensure_target
    end

    # The Ctrl+K menu of a mark: rename or delete.
    def self.mark_menu(t)
      sel = (show_menu(PokeAccess::I18n.t(:mark_menu, :name => t.name),
                       [PokeAccess::I18n.t(:tag_rename), PokeAccess::I18n.t(:mark_delete), PokeAccess::I18n.t(:back)], 3) rescue 2)
      if sel == 0
        edit_mark(t.x, t.y)
      elsif sel == 1
        PokeAccess::Marks.delete($game_map.map_id, t.x, t.y)
        PokeAccess::Events.emit(:tags_changed)
        @ti = 0; @target = @targets[0]
        PokeAccess.speak(PokeAccess::I18n.t(:mark_deleted, :name => t.name), true)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end


    # A tile as it is spoken: "x 15, y 17".
    def self.coords_text(x, y)
      "x #{x}, y #{y}"
    end

    # Steps the hide setting on the fly (Ctrl+M) to its next value, announces it, persists, and rebuilds.
    def self.toggle_hide_unreachable
      s = PokeAccess::Config.setting(:hide_unreachable)
      v = PokeAccess::Config.set(s.key, PokeAccess::Config.next_value(s, 1))
      (PokeAccess::Settings.write rescue nil)
      rebuild_targets
      PokeAccess.speak("#{PokeAccess::I18n.t(s.label)}, #{PokeAccess::Config.value_name(s, v)}", true)
    end

    # Cycles the target category (+1/-1) and says it, its first target after it, selected as J and L select one, the
    # guides following it; an empty one is said alone and turns the guides off without a word, leaving nothing to follow.
    def self.cycle_category(dir)
      cats = active_categories
      @cat_id = cats[((cats.index(category) || 0) + dir) % cats.length]
      @target = nil
      @ti = 0
      rebuild_targets
      said = PokeAccess::I18n.t(:loc_category, :cat => cat_name(@cat_id), :n => @targets.length)
      return select_current(said) unless @targets.empty?
      PokeAccess::Guide.stop if PokeAccess::Guide.on?
      PokeAccess.speak(said, true)
    end

    # Speaks the route to the current target (Routes::Text.line, or why there is none), the piece's line on a puzzle
    # goal holding it (Puzzles.carried_line), or arrived_line on a target the player stands on (onto?); with route_stats
    # on, how its search went too.
    def self.announce_route
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      plan = route_plan(@target)
      at = [$game_player.x, $game_player.y]
      kinds = plan.route && PokeAccess::Routes::Moves.one_way(at[0], at[1], PokeAccess::Pathfinder.bridge_level, plan.route)
      here = plan.kind == :walk && plan.route && plan.route.empty? && onto?(@target)
      line = PokeAccess::Puzzles.carried_line(@target) ||
             (here ? arrived_line(@target, true) : PokeAccess::Routes::Text.line(plan, at, kinds))
      stats = (PokeAccess::Config.route_stats rescue false) ? PokeAccess::Routes::Text.stats(plan) : nil
      PokeAccess.speak(stats ? "#{line}. #{stats}" : line, true)
    end

    # Announces the map name on entering a new map, emitting :map_changed before it (which runs Caches.reset_all) and
    # :map_named after it, for what is said following the name. The map object is compared too: a load rebuilds
    # $game_map, even onto the same map id.
    def self.announce_map_change
      mid = ($game_map.map_id rescue nil)
      ref = ($game_map.__id__ rescue nil)
      return if mid.nil? || (mid == @last_map_id && ref == @last_map_ref)
      @last_map_id = mid
      @last_map_ref = ref
      PokeAccess::Events.emit(:map_changed, mid)
      clear_targets
      nm = (map_name(mid) rescue nil)
      PokeAccess.speak(nm, false)
      PokeAccess::Events.emit(:map_named, mid)
    end

    # True while the player is mid-jump (a ledge hop moves them two tiles in one frame).
    def self.player_jumping?
      !!($game_player.jumping? rescue false)
    end

    # Registers a profile's cause for a teleport within the map under a name (registering a name again replaces it):
    # the block gets the place left and the place reached, each [x, y, map id], and gives the line said in place of
    # the teleport line, or nil for a teleport not its own.
    def self.teleport_cause(name, &blk)
      @teleport_causes.reject! { |n, _b| n == name }
      @teleport_causes.push([name, blk])
    end

    # The line the newest cause that knows a teleport gives (teleport_cause), or nil; a failing cause gives none.
    def self.cause_line(from, to)
      @teleport_causes.reverse_each do |_name, blk|
        line = blk.call(from, to)
        return line if line
      end
      nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Announces a teleport within the map (over one tile in a frame) by its cause's profile line (cause_line), else
    # teleport_line, and has the list rebuilt when next used; a ledge hop, a forced move route or a walk the drawn
    # player has yet to make (drawn_walk?) does not count.
    def self.announce_internal_teleport
      x = ($game_player.x rescue nil); y = ($game_player.y rescue nil); mid = ($game_map.map_id rescue nil)
      return if x.nil? || y.nil? || mid.nil?
      prev = @last_pos
      drawn = @last_drawn
      @last_pos = [x, y, mid]
      @last_drawn = drawn_at
      return if prev.nil? || prev[2] != mid
      jump = (prev[0] - x).abs + (prev[1] - y).abs
      return if jump <= 1
      return if player_jumping? || drawn_walk?(drawn, @last_drawn)
      return if ($game_player.move_route_forcing rescue false)
      @targets_stale = true
      PokeAccess.speak(cause_line(prev, @last_pos) || teleport_line(x - prev[0], y - prev[1], x, y), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A teleport of (dx, dy) tiles onto (x, y) at the teleport reading's level: that the player moved (brief), how far
    # each way (medium), then the part of the map it lands in, left out near the centre (full).
    def self.teleport_line(dx, dy, x, y)
      return PokeAccess::I18n.t(:loc_teleported_plain) unless PokeAccess::Verbosity.keep?(:teleport, :medium)
      moved = PokeAccess::Routes::Text.moved(dx, dy)
      zone = PokeAccess::Verbosity.keep?(:teleport, :full) ? cardinal_of(x, y) : nil
      zone ? moved + "; " + PokeAccess::I18n.t(:loc_teleport_zone, :zone => PokeAccess::I18n.t(zone)) : moved
    end

    # Where the player is drawn, [real_x, real_y], or nil where the engine does not tell.
    def self.drawn_at
      rx = ($game_player.real_x rescue nil); ry = ($game_player.real_y rescue nil)
      rx.is_a?(Numeric) && ry.is_a?(Numeric) ? [rx, ry] : nil
    end

    # True when the drawn player moved at most a tile since the last frame while the tile moved further: a walk of
    # several tiles in one update (up a waterfall, a climb) or a diagonal step, which the sprite has yet to make. A
    # transfer moves the drawn player with the tile.
    def self.drawn_walk?(before, now)
      return false if before.nil? || now.nil?
      tile = defined?(::Game_Map::REAL_RES_X) ? ::Game_Map::REAL_RES_X : 128
      (now[0] - before[0]).abs + (now[1] - before[1]).abs <= tile
    end

    # Drops the targets and their stale mark, the selection, the targets seen for static numbers, the surface cache and
    # the map names the game gave; run on :map_changed. Keeps @last_map_id, or the map change would be announced again
    # every frame.
    def self.clear_targets
      @targets = []; @targets_stale = false; @target = nil; @ti = 0
      @keys = nil; @static = nil; @dynamic = nil; @door_ids = {}; @seen = nil
      @surface_cache = nil; @surface_cache_pos = nil
      @game_names = nil
    end

    # Forgets the current map so the next announce_map_change fires even on the same map id (a load screen calls it).
    def self.forget_map
      @last_map_id = nil
      @last_map_ref = nil
      @last_pos = nil
      clear_targets
    end

    # Speaks the current map name and coordinates.
    def self.announce_coords
      return unless $game_player && $game_map
      nm = (map_name($game_map.map_id) rescue nil)
      PokeAccess.speak("#{nm ? nm + '. ' : ''}#{coords_text($game_player.x, $game_player.y)}", true)
    end

    # On the edge where a running event finishes: drops the route caches and the surfaces listed, and marks a non-empty
    # target list stale, for ensure_target to rebuild when it is next used (so a collected object drops out);
    # rebuilding there and then would walk the map's regions afresh as a conversation closes.
    def self.refresh_on_event_end
      run = ($game_system && $game_system.map_interpreter && $game_system.map_interpreter.running?) rescue false
      if @interp_running && !run
        (PokeAccess::Pathfinder.invalidate_cache rescue nil)
        (PokeAccess::Guide.event_ended rescue nil)
        (PokeAccess::Locator.clear_verdicts rescue nil)
        @surface_cache = nil
        @targets_stale = true unless @targets.empty?
      end
      @interp_running = run
    rescue StandardError => e
      PokeAccess.swallowed(e)
      @interp_running = false
    end

    # Whether Frame runs the map frame's world, control and nav stages: a map, a player, the mod on and its menu shut;
    # the game-bump filter asks too. While the mod is off the player's last place is forgotten, so that turning it back
    # on after a walk is no teleport.
    def self.polling?
      return false unless $game_map && $game_player
      unless (PokeAccess::Keys.enabled rescue true)
        @last_pos = nil
        return false
      end
      !PokeAccess::ConfigMenu.active?
    end

    # Hands the info key to the map every map frame (Info.map_text), so a menu drawn over the map answers with it too;
    # not while a menu with help is open, whose help the key reads instead.
    def self.refresh_info
      PokeAccess::Info.set_info(:map, nil) unless PokeAccess::CommandHelp.current
    end

    # The locator's keys, Frame's last :nav step: only with the game focused and the keys free.
    def self.poll_keys
      return unless PokeAccess::Keys.focused?
      return unless PokeAccess::Control.keys?
      if PokeAccess::Keys.key(:next)
        PokeAccess::Keys.shift_down? ? cycle_category(1) : step(1)
      elsif PokeAccess::Keys.key(:prev)
        PokeAccess::Keys.shift_down? ? cycle_category(-1) : step(-1)
      elsif PokeAccess::Keys.key(:where)
        if PokeAccess::Keys.ctrl_down?
          tag_menu
        elsif PokeAccess::Keys.shift_down?
          rename_target
        else
          ensure_target; announce_selected(true)
        end
      elsif PokeAccess::Keys.key(:route)
        if PokeAccess::Keys.ctrl_down?
          PokeAccess::Guide.toggle(:steps)
        else
          PokeAccess::Keys.shift_down? ? PokeAccess::Guide.toggle(:cane) : announce_route
        end
      end
    end
  end
end

# Rebuild the target list when something elsewhere changes tags (e.g. an object un-hidden from the menu).
PokeAccess::Events.on(:tags_changed) { (PokeAccess::Locator.rebuild_targets rescue nil) }

# Clears the targets on a map change; clear_targets, not forget_map, whose clearing of @last_map_id would loop.
PokeAccess::Caches.register(:locator) { PokeAccess::Locator.clear_targets }
