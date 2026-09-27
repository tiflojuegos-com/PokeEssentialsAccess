module PokeAccess
  # Locator part 3 of 4 (core): holds all locator state, builds/cycles the target list by category,
  # numbers targets, speaks the focused target/route/coords, and drives everything once per map frame.
  # Naming lives in locator_naming, surface targets in locator_surfaces, the guide in guide.
  module Locator
    @targets = []; @ti = 0; @cat = 0; @target = nil
    @guide = false
    @last_map_id = nil; @last_map_ref = nil
    @guide_path = nil; @guide_from = nil; @guide_target = nil
    @surface_cache = nil; @surface_cache_pos = nil
    @interp_running = false

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
    rescue StandardError
      nil
    end

    # True if the player hid this event (Ctrl+K), so it is left out of the locator entirely.
    def self.tag_hidden?(ev)
      eid = event_id_of(ev)
      return false unless $game_map && eid
      PokeAccess::Tags.hidden?($game_map.map_id, eid)
    rescue StandardError
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
    rescue StandardError
      false
    end

    # True if the current map holds a lens (#EOT) tile, a reachable one with hide_unreachable on; gates :lens.
    def self.any_lens_tile?
      return false unless $game_map
      tiles = $game_map.events.values.select { |ev| lens_tile?(ev) }
      return false if tiles.empty?
      return true unless (PokeAccess::Config.hide_unreachable rescue false)
      tiles.any? { |ev| reachable?(ev) }
    rescue StandardError
      false
    end

    # Rebuilds the target list for the current category, nearest first. With hide_unreachable, an empty reachable set
    # keeps the full list (taken as a flood misfire), except in lens, whose tiles sit behind walls the lens reveals.
    def self.rebuild_targets
      @targets_stale = false
      @targets = []
      return unless $game_map && $game_player
      px = $game_player.x; py = $game_player.y
      cats = active_categories
      @cat = 0 if @cat >= cats.length
      cat = cats[@cat]
      synthetic = (cat == :surfaces || cat == :puzzles || cat == :marks)
      if cat == :surfaces
        @targets = (surface_targets.dup rescue [])
      elsif cat == :puzzles
        @targets = (PokeAccess::Puzzles.category_targets rescue [])
      elsif cat == :marks
        @targets = mark_targets
      else
        @targets = $game_map.events.values.select { |ev| in_category?(ev, cat) && !tag_hidden?(ev) }
        @targets = cluster_exits(@targets, px, py) if cat == :exits || cat == :all
        @targets.concat(connection_targets.map { |t| aim_connection(t) }) if cat == :exits || cat == :all
      end
      @targets = @targets.sort_by { |ev| (ev.x - px).abs + (ev.y - py).abs }
      if !synthetic && (PokeAccess::Config.hide_noninteractive rescue false)
        @targets = @targets.select { |ev| ev.is_a?(SurfaceTarget) || interactable?(ev) }
      end
      if !synthetic && (PokeAccess::Config.hide_unreachable rescue false)
        reachable_only = @targets.select { |ev| ev.is_a?(SurfaceTarget) || reachable?(ev) }
        if cat == :lens
          @targets = reachable_only
        else
          @targets = reachable_only unless reachable_only.empty?
        end
      end
      @ti = 0 if @ti >= @targets.length
      refresh_selected_mark
    end

    # Points the selection at the fresh copy of the selected mark after a rebuild (same tile, new struct,
    # possibly a new name); leaves it alone when the list no longer holds that tile.
    def self.refresh_selected_mark
      return unless mark_target?(@target)
      fresh = @targets.find { |t| mark_target?(t) && t.x == @target.x && t.y == @target.y }
      return unless fresh
      @target = fresh
      @ti = @targets.index(fresh)
    end

    # Collapses a wide doorway (8-connected transfer tiles with one exit, see same_exit?) into its tile nearest the
    # player, chained by union-find; other events pass through, and order is not kept.
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
      groups.each do |idxs|
        best = idxs.min_by { |k| (events[doors[k]].x - px).abs + (events[doors[k]].y - py).abs }
        kept[doors[best]] = true
      end
      out = []
      events.each_with_index { |ev, i| out.push(ev) if kept[i] || !is_door[i] }
      out
    rescue StandardError
      events
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

    # True if the event's tile, a neighbour or the tile across a counter is in the player's cached flood fill (for
    # hide_unreachable); true whenever the flood was truncated, as absence from it proves nothing.
    def self.reachable?(ev)
      return true unless (PokeAccess::Pathfinder.reachable_set_complete? rescue false)
      s = (PokeAccess::Pathfinder.reachable_set rescue {})
      tx = ev.x; ty = ev.y
      pf = PokeAccess::Pathfinder
      return true if s[pf.pkey(tx, ty)] || s[pf.pkey(tx - 1, ty)] || s[pf.pkey(tx + 1, ty)] ||
                     s[pf.pkey(tx, ty - 1)] || s[pf.pkey(tx, ty + 1)]
      [[-1, 0], [1, 0], [0, -1], [0, 1]].any? do |dx, dy|
        ($game_map.counter?(tx + dx, ty + dy) rescue false) && !!s[pf.pkey(tx + 2 * dx, ty + 2 * dy)]
      end
    rescue StandardError
      true
    end

    # True when the current target still applies: a mark still set, a surface tile, or an event that still exists.
    def self.target_valid?
      return false unless @target && $game_map
      return !PokeAccess::Marks.get($game_map.map_id, @target.x, @target.y).nil? if mark_target?(@target)
      return true if @target.is_a?(SurfaceTarget)
      id = (@target.id rescue nil)
      !id.nil? && $game_map.events[id] == @target
    end

    # Ensures a valid target: a stale list is rebuilt keeping the selection, and a vanished target is replaced by the
    # one now at its index.
    def self.ensure_target
      if @targets_stale && target_valid?
        prev = @target
        rebuild_targets
        i = @targets.index(prev)
        @ti = i if i
        return
      end
      unless target_valid?
        rebuild_targets
        @ti = @targets.length - 1 if @ti >= @targets.length
        @ti = 0 if @ti < 0
        @target = @targets[@ti]
      end
    end

    # Selects the target at the current index and announces it.
    def self.select_current
      @target = @targets[@ti]
      announce_selected(true)
      auto_guide_on
      auto_steps_on
    end

    # Moves the selection by delta (+1/-1) from where the current target sits in the freshly rebuilt list.
    def self.step(delta)
      prev = @target
      rebuild_targets
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_no_targets), true) if @targets.empty?
      base = @targets.index(prev)
      @ti = base ? (base + delta) % @targets.length : (@ti % @targets.length)
      select_current
    end

    # The shared rename flow: announce "label for X", prompt with the current value, empty clears / text
    # saves (via the block), announce the outcome. keys: [announce_key, prompt_key, removed_key, saved_key].
    def self.prompt_rename(current_name, current_value, keys)
      PokeAccess.speak(PokeAccess::I18n.t(keys[0], :name => current_name), true)
      txt = (pbEnterText(PokeAccess::I18n.t(keys[1]), 0, 40, current_value) rescue nil)
      return if txt.nil?
      if txt.strip.empty?
        yield("")
        PokeAccess.speak(PokeAccess::I18n.t(keys[2]), true)
      else
        yield(txt.strip)
        PokeAccess.speak(PokeAccess::I18n.t(keys[3], :label => txt.strip), true)
      end
    end

    # The player's marks on this map as synthetic targets (SurfaceTarget with the key :mark).
    def self.mark_targets
      mid = $game_map.map_id
      PokeAccess::Marks.on_map(mid).map { |x, y, name| SurfaceTarget.new(x, y, name, :mark) }
    rescue StandardError
      []
    end

    # True if a target is one of the player's marks (a synthetic target carrying the :mark key).
    def self.mark_target?(t)
      t.is_a?(SurfaceTarget) && t.key == :mark
    end

    # The map-event id of a target, or nil for a synthetic one (a surface, a mark, a map edge). Decided by class, not
    # respond_to?(:id): on 1.8.7 every object has Object#id.
    def self.event_id_of(t)
      return nil if t.nil? || t.is_a?(SurfaceTarget)
      (t.id rescue nil)
    end

    # Gives the focused object a custom spoken label (Shift+K), stored in the shareable tag dictionary.
    # An empty entry removes it; surfaces (no event id) cannot be tagged.
    def self.rename_target
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return edit_mark(@target.x, @target.y) if mark_target?(@target)
      eid = event_id_of(@target)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && eid
      mid = $game_map.map_id
      cur = (PokeAccess::Tags.get(mid, eid) rescue nil).to_s
      prompt_rename(target_name(@target), cur, [:loc_label_for, :loc_label_prompt, :loc_label_removed, :loc_label_saved]) do |label|
        PokeAccess::Tags.set(mid, eid, label)
      end
    end

    # Renames the current map (Shift+M), stored in the shareable map-name dictionary. An empty entry
    # restores the game's own name. The override also drives how exits to this map are announced.
    def self.rename_map
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map
      mid = $game_map.map_id
      cur = (PokeAccess::MapNames.get(mid) rescue nil).to_s
      prompt_rename(map_name(mid).to_s, cur, [:map_label_for, :map_label_prompt, :map_label_removed, :map_label_saved]) do |label|
        PokeAccess::MapNames.set(mid, label)
      end
    end

    # Category options the player can force via Ctrl+K: nil = automatic detection, then the categories.
    TAG_OVERRIDES = [nil, :people, :objects, :exits, :signs]

    # Shows a choice message and returns the chosen (or cancel) index, through Kernel.pbMessage on gen-6 and the
    # global pbMessage elsewhere.
    def self.show_menu(msg, choices, cancel)
      return Kernel.pbMessage(msg, choices, cancel) if Kernel.respond_to?(:pbMessage)
      pbMessage(msg, choices, cancel)
    end

    # The Ctrl+K menu for the focused object, in the game's choice window: rename, recategorise or hide it (Tags).
    def self.tag_menu
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return mark_menu(@target) if mark_target?(@target)
      eid = event_id_of(@target)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && eid
      mid = $game_map.map_id
      loop do
        sel = (show_menu(PokeAccess::I18n.t(:tag_menu, :name => target_name(@target)),
                         [PokeAccess::I18n.t(:tag_rename), PokeAccess::I18n.t(:tag_recat),
                          PokeAccess::I18n.t(:tag_hide), PokeAccess::I18n.t(:back)], 4) rescue 3)
        if sel == 0
          rename_target
        elsif sel == 1
          labels = TAG_OVERRIDES.map { |c| PokeAccess::I18n.t(c.nil? ? :tag_auto : TCAT_KEYS[c]) }
          ci = (show_menu(PokeAccess::I18n.t(:tag_cat_prompt), labels, labels.length + 1) rescue -1)
          if ci >= 0 && ci < TAG_OVERRIDES.length
            PokeAccess::Tags.set_category(mid, eid, TAG_OVERRIDES[ci])
            rebuild_targets
            PokeAccess.speak(PokeAccess::I18n.t(:tag_recat_done, :cat => labels[ci]), true)
          end
        elsif sel == 2
          nm = target_name(@target)
          PokeAccess::Tags.set_hidden(mid, eid, true)
          rebuild_targets
          @ti = 0; @target = @targets[0]
          return PokeAccess.speak(PokeAccess::I18n.t(:tag_hidden_done, :name => nm), true)
        else
          return
        end
      end
    rescue StandardError
      nil
    end

    # Position-independent sort key for stable numbering: events by id, surfaces by tile.
    def self.stable_key(t)
      eid = event_id_of(t)
      eid ? [0, eid.to_i] : [1, t.x.to_i, t.y.to_i]
    end

    # A stable per-map number for a target, its rank by stable_key; cached per @targets array by identity, which
    # rebuild_targets replaces.
    def self.stable_ordinal(target)
      unless @stable_ref.equal?(@targets)
        @stable_ref = @targets
        @stable_ord = {}
        @targets.sort_by { |t| stable_key(t) }.each_with_index { |t, i| @stable_ord[t] = i + 1 }
      end
      @stable_ord[target]
    end

    # The spoken position number for the focused target: fixed (a per-map number, via stable_ordinal) or
    # proximity (the live index in the distance-sorted list), per the fixed_target_number setting.
    def self.ordinal_of(target)
      if (PokeAccess::Config.fixed_target_number rescue true)
        stable_ordinal(target)
      else
        i = (@targets.index(target) rescue nil)
        i ? i + 1 : nil
      end
    end

    # The walking-distance suffix for a target: the route's step count, or why there is none (a field-move obstacle,
    # water to surf, no route); empty when already adjacent.
    def self.step_phrase(target)
      pf = PokeAccess::Pathfinder
      cuts = pf.cuts
      path = route_to(target)
      if path.nil?
        g = pf.gated_path(target.x, target.y)
        return ", " + gate_route_text(g[1]) if g
        return ", " + PokeAccess::I18n.t(:loc_surf_route) if pf.surf_launch(target.x, target.y)
        return ", " + pf.no_route_text(pf.cuts != cuts)
      end
      return "" if path.empty?
      ", " + PokeAccess::I18n.t(:loc_steps, :n => path.length)
    rescue StandardError
      ""
    end

    # The walking route to a target: onto the tile for a spot acted on where it lies (dive), beside it otherwise.
    def self.route_to(t)
      pf = PokeAccess::Pathfinder
      dive_key(t) ? pf.find_path_onto(t.x, t.y) : pf.find_path(t.x, t.y)
    rescue StandardError
      nil
    end

    # "blocked by a cut tree, use Cut": what stands between the player and a target an assisted route
    # reaches, and what gets them past it.
    def self.gate_route_text(g)
      t = PokeAccess::I18n
      case g[:kind]
      when :act then t.t(:loc_act_route)
      when :dismount then t.t(:loc_dismount_route)
      else
        return t.t(:loc_gate_route_push, :what => t.t(g[:label])) if g[:move].nil?
        t.t(:loc_gate_route, :what => t.t(g[:label]), :move => PokeAccess::FieldMoves.name(g[:move]))
      end
    end

    # What an assisted route leads up to, as "route to <this>" names it.
    def self.gate_what(g)
      case g[:kind]
      when :act then PokeAccess::I18n.t(:loc_act_spot)
      when :dismount then PokeAccess::I18n.t(:loc_dismount_spot)
      else PokeAccess::I18n.t(g[:label])
      end
    end

    # Speaks the direction to the selected target, and with withname its name, the marks shown over it, its number
    # and walking distance too.
    def self.announce_selected(withname)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil? || $game_player.nil?
      phrase = dir_phrase(@target.x - $game_player.x, @target.y - $game_player.y)
      unless withname
        return PokeAccess.speak(phrase, true)
      end
      ord = ordinal_of(@target)
      ordtxt = (ord && !@targets.empty?) ? (PokeAccess::I18n.t(:loc_count, :n => ord, :total => @targets.length) + ", ") : ""
      name = [target_name(@target)].concat((name_marks(@target) rescue []) || []).join(", ")
      PokeAccess.speak("#{name}, #{ordtxt}#{phrase}#{step_phrase(@target)}", true)
    end

    # The words for what a plugin draws over a target (a quest marker), said after its name; none here, a plugin that
    # draws them adds its own.
    def self.name_marks(_target); []; end

    # Ctrl+G: sets, renames or (with a blank answer) removes the mark on the player's tile. Map only: the key is
    # polled from Input.update, which also runs in menus and battles.
    def self.mark_here
      return PokeAccess.speak(PokeAccess::I18n.t(:mark_map_only), true) unless on_map?
      edit_mark($game_player.x, $game_player.y)
    rescue StandardError
      nil
    end

    # Prompts for the name of the mark on a tile (new or existing) and persists the answer; a blank answer
    # removes it. Shared by Ctrl+G, Shift+K on a mark and the Ctrl+K menu.
    def self.edit_mark(x, y)
      mid = $game_map.map_id
      cur = (PokeAccess::Marks.get(mid, x, y) rescue nil).to_s
      shown = cur.empty? ? coords_text(x, y) : cur
      keys = [cur.empty? ? :mark_for : :mark_edit_for, :mark_prompt, :mark_removed, :mark_saved]
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
    rescue StandardError
      nil
    end

    # True while the player is on the map (Scene_Map, no menu open).
    def self.on_map?
      return false unless $game_map && $game_player
      return false if (($game_temp && $game_temp.in_menu) rescue false)
      ($scene.is_a?(Scene_Map) rescue true)
    end

    # A tile as it is spoken: "x 15, y 17".
    def self.coords_text(x, y)
      "x #{x}, y #{y}"
    end

    # Toggles the hide-unreachable filter on the fly (Ctrl+M), announces it, persists, and rebuilds.
    def self.toggle_hide_unreachable
      v = !(PokeAccess::Config.hide_unreachable rescue false)
      PokeAccess::Config.hide_unreachable = v
      (PokeAccess::Settings.write rescue nil)
      rebuild_targets
      PokeAccess.speak("#{PokeAccess::I18n.t(:lbl_hide_unreachable)}, #{PokeAccess::I18n.t(v ? :val_on : :val_off)}", true)
    end

    # Cycles the target category (+1/-1) and announces it.
    def self.cycle_category(dir)
      cats = active_categories
      @cat = (@cat + dir) % cats.length
      @ti = 0; rebuild_targets; @target = @targets[0]
      PokeAccess.speak(PokeAccess::I18n.t(:loc_category, :cat => cat_name(cats[@cat]), :n => @targets.length), true)
      auto_guide_on
      auto_steps_on
    end

    # Speaks the A* route to the current target, or, when a field-move obstacle stands in the way, the route
    # up to it and what it is.
    def self.announce_route
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      pf = PokeAccess::Pathfinder
      cuts = pf.cuts
      path = route_to(@target)
      g = path.nil? ? pf.gated_path(@target.x, @target.y) : nil
      if g
        return PokeAccess.speak(PokeAccess::I18n.t(:loc_route_gate, :what => gate_what(g[1]),
                                                   :steps => pf.path_to_text(g[0])), true)
      end
      PokeAccess.speak(PokeAccess::I18n.t(:loc_route, :steps => pf.path_to_text(path, pf.cuts != cuts)), true)
    end

    # Announces the map name on entering a new map and emits :map_changed (which runs Caches.reset_all). The map
    # object is compared too: a load rebuilds $game_map, even onto the same map id.
    def self.announce_map_change
      mid = ($game_map.map_id rescue nil)
      ref = ($game_map.__id__ rescue nil)
      return if mid.nil? || (mid == @last_map_id && ref == @last_map_ref)
      @last_map_id = mid
      @last_map_ref = ref
      PokeAccess::Events.emit(:map_changed, mid)
      @targets = []; @target = nil; @ti = 0
      (rebuild_targets rescue nil)
      nm = (map_name(mid) rescue nil)
      PokeAccess.speak(nm, false)
    end

    # True while the player is mid-jump (a ledge hop moves them two tiles in one frame).
    def self.player_jumping?
      !!($game_player.jumping? rescue false)
    end

    # Announces a teleport within the map (a move of over one tile in a frame) with its cardinal direction, and
    # rebuilds the targets; a ledge hop or a forced move route does not count.
    def self.announce_internal_teleport
      x = ($game_player.x rescue nil); y = ($game_player.y rescue nil); mid = ($game_map.map_id rescue nil)
      return if x.nil? || y.nil? || mid.nil?
      prev = @last_pos
      @last_pos = [x, y, mid]
      return if prev.nil? || prev[2] != mid
      jump = (prev[0] - x).abs + (prev[1] - y).abs
      return if jump <= 1
      return if player_jumping?
      return if ($game_player.move_route_forcing rescue false)
      dir = (cardinal_of(x, y) rescue nil)
      msg = dir ? PokeAccess::I18n.t(:loc_teleported, :dir => PokeAccess::I18n.t(dir)) :
                  PokeAccess::I18n.t(:loc_teleported_plain)
      clear_targets
      (rebuild_targets rescue nil)
      PokeAccess.speak(msg, false)
    rescue StandardError
      nil
    end

    # Drops the targets, the selection, the surface cache and the guide's route state (the no-route memo has no map
    # id); run on :map_changed. Keeps @last_map_id, or the map change would be announced again every frame.
    def self.clear_targets
      @targets = []; @target = nil; @ti = 0
      @guide_path = nil; @guide_from = nil; @guide_target = nil; @noroute_key = nil
      @guide_gate = nil; @guide_surf = false; @hold_said = nil
      @steps_at = nil; @steps_leg = nil
      @surface_cache = nil; @surface_cache_pos = nil
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

    # On the edge where a running event finishes: drops the route caches and rebuilds (or marks stale) a non-empty
    # target list, so a collected object drops out.
    def self.refresh_on_event_end
      run = ($game_system && $game_system.map_interpreter && $game_system.map_interpreter.running?) rescue false
      if @interp_running && !run
        (PokeAccess::Pathfinder.invalidate_cache rescue nil)
        (PokeAccess::Puzzles.forget_obstacles rescue nil)
        (PokeAccess::Locator.forget_noroute rescue nil)
        (PokeAccess::Locator.clear_verdicts rescue nil)
        stale_or_rebuild unless @targets.empty?
      end
      @interp_running = run
    rescue StandardError
      @interp_running = false
    end

    # The target list after an event ends: marked stale for ensure_target to rebuild when next used, with
    # defer_target_rebuild (on by default; rebuilding floods the map as a conversation closes), else rebuilt now.
    def self.stale_or_rebuild
      if (PokeAccess::Config.defer_target_rebuild rescue true)
        @targets_stale = true
      else
        rebuild_targets
      end
    end

    # Whether map_poll runs this frame: a map, a player, the mod on and its menu shut; the game-bump filter asks too.
    def self.polling?
      return false unless $game_map && $game_player
      return false unless (PokeAccess::Keys.enabled rescue true)
      !PokeAccess::ConfigMenu.active?
    end

    # Sets the info key to the trainer every map frame, so a menu drawn over the map answers with it too; not while a
    # menu with help is open, whose help the key reads instead.
    def self.refresh_info
      PokeAccess::Info.set_info(:trainer, nil) unless PokeAccess::CommandHelp.current
    end

    # Runs every map frame (map_frame), filing what it says under navigation.
    def self.map_poll
      return unless polling?
      PokeAccess::Speech.as(:nav) { map_frame }
    end

    # One map frame's work: the map and teleport lines, the guides, and the locator's keys.
    def self.map_frame
      announce_map_change
      announce_internal_teleport
      refresh_on_event_end
      PokeAccess::Battle.clear_battle
      refresh_info
      PokeAccess::Spatial.tick
      guide_tick
      steps_tick
      PokeAccess::Puzzles.tick rescue nil
      return if (($game_temp && $game_temp.in_menu) rescue false)
      return unless PokeAccess::Keys.focused?
      return if PokeAccess::Spatial.keys_locked?
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
          toggle_steps
        else
          PokeAccess::Keys.shift_down? ? toggle_guide : announce_route
        end
      end
    end
  end
end

# Per-frame map driver on Game_Player#update (some games loop the whole map inside Scene_Map#update). A frame_hook:
# gen-6 runs wild battles inside this update, and a guarded hook would mute every battle reader.
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end

# Rebuild the target list when something elsewhere changes tags (e.g. an object un-hidden from the menu).
PokeAccess::Events.on(:tags_changed) { (PokeAccess::Locator.rebuild_targets rescue nil) }

# Clears the targets on a map change; clear_targets, not forget_map, whose clearing of @last_map_id would loop.
PokeAccess::Caches.register(:locator) { PokeAccess::Locator.clear_targets }
