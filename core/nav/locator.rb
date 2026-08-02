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
                  :surfaces => :tcat_surfaces, :puzzles => :tcat_puzzles, :lens => :tcat_lens }

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
      return nil unless $game_map && ev.respond_to?(:id)
      PokeAccess::Tags.category($game_map.map_id, ev.id)
    rescue StandardError
      nil
    end

    # True if the player hid this event (Ctrl+K), so it is left out of the locator entirely.
    def self.tag_hidden?(ev)
      return false unless $game_map && ev.respond_to?(:id)
      PokeAccess::Tags.hidden?($game_map.map_id, ev.id)
    rescue StandardError
      false
    end

    # True if an event belongs in the given target category. A player override (Ctrl+K) wins over the
    # automatic detection, so a mislabelled object can be moved to the right category.
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
      when :extras then !named && examinable?(ev) && !sign_event?(ev)
      when :lens   then lens_tile?(ev)
      when :all    then named || transfer_event?(ev) || examinable?(ev) || lens_tile?(ev)
      else              named && event_category(ev) == cat
      end
    end

    # The categories to cycle now: the configured set, plus "puzzles" only while the current puzzle has
    # something worth locating (its cells, obstacle walls, or statues), plus "lens" only on maps that hold a
    # navigable Eye/Lens-of-Truth tile (#EOT), so the category never shows up empty. Targets come from
    # Puzzles/the event scan.
    def self.active_categories
      base = PokeAccess::Config.categories.reject { |c| c == :puzzles || c == :lens }
      base += [:puzzles] if (PokeAccess::Puzzles.has_locator_targets? rescue false)
      base += [:lens] if any_lens_tile?
      base
    end

    # True if the current map holds a lens (#EOT) tile worth cycling to, gating the :lens category. With
    # "hide unreachable" on, lens tiles behind their walls do not count, so the category does not appear
    # empty (those tiles only become reachable once the lens reveals them).
    def self.any_lens_tile?
      return false unless $game_map
      tiles = $game_map.events.values.select { |ev| lens_tile?(ev) }
      return false if tiles.empty?
      return true unless (PokeAccess::Config.hide_unreachable rescue false)
      tiles.any? { |ev| reachable?(ev) }
    rescue StandardError
      false
    end

    # Rebuilds the target list for the current category, sorted by distance (nearest first). With "hide
    # unreachable" on, an empty reachable set is normally treated as a flood-fill misfire and the full list is
    # kept; the lens category is the exception -- its tiles legitimately sit behind walls the lens reveals, so
    # an empty result there stays empty rather than falling back to the unreachable list.
    def self.rebuild_targets
      @targets = []
      return unless $game_map && $game_player
      px = $game_player.x; py = $game_player.y
      cats = active_categories
      @cat = 0 if @cat >= cats.length
      cat = cats[@cat]
      synthetic = (cat == :surfaces || cat == :puzzles)
      if cat == :surfaces
        @targets = (surface_targets.dup rescue [])
      elsif cat == :puzzles
        @targets = (PokeAccess::Puzzles.category_targets rescue [])
      else
        @targets = $game_map.events.values.select { |ev| in_category?(ev, cat) && !tag_hidden?(ev) }
        @targets = cluster_exits(@targets, px, py) if cat == :exits || cat == :all
        @targets.concat(connection_targets) if cat == :exits || cat == :all
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
    end

    # Collapses a wide doorway -- adjacent transfer tiles whose destinations match -- into a single exit,
    # keeping the tile nearest the player. Adjacency is 8-connected; two events merge only when their
    # destinations are the same map AND the landing spot is within one tile, so a multi-tile door (its
    # tiles land on the same or adjacent spot) groups while two distinct doors that merely share a map
    # (but land far apart) stay separate. Only transfer events are clustered (others keep a nil descriptor
    # and pass through untouched), so this is safe to call on the mixed :all list too. Destination-unknown
    # doors fall back to grouping by script-map or sprite, so a sprite-less (g0) doorway still collapses.
    # Union-find for transitive grouping (the doorway 11-12-13 merges as one chain).
    def self.cluster_exits(events, px, py)
      n = events.length
      return events if n <= 1
      descs = events.map { |ev| (transfer_event?(ev) rescue false) ? exit_descriptor(ev) : nil }
      groups = PokeAccess::Util.union_groups(n) do |a, b|
        !descs[a].nil? && same_exit?(descs[a], descs[b]) &&
          (events[a].x - events[b].x).abs <= 1 && (events[a].y - events[b].y).abs <= 1
      end
      groups.map do |idxs|
        g = idxs.map { |i| events[i] }
        g.length == 1 ? g[0] : g.min_by { |ev| (ev.x - px).abs + (ev.y - py).abs }
      end
    rescue StandardError
      events
    end

    # A descriptor of an exit's destination for clustering: the resolved transfer target [map, x, y]
    # (command 201), the script-transfer map, or the sprite name when neither resolves. Uses the sprite,
    # NOT the event name -- doorway tiles are distinct events (EV002/EV003...) but share one sprite (or are
    # all blank g0), so the sprite is what makes those group.
    def self.exit_descriptor(ev)
      xy = (transfer_command_dest_xy(ev) rescue nil)
      return [:xy, xy[0], xy[1], xy[2]] unless xy.nil?
      sd = (transfer_script_dest(ev) rescue nil)
      return [:map, sd] unless sd.nil?
      [:char, (ev.character_name.to_s rescue "")]
    end

    # True if two exit descriptors belong to one doorway: same destination map with a landing spot within
    # one tile (so a multi-tile door collapses but two far-apart doors do not), or -- when the target is
    # unknown -- the same script-map or the same sprite.
    def self.same_exit?(a, b)
      return false if a.nil? || b.nil?
      if a[0] == :xy
        b[0] == :xy && a[1] == b[1] && (a[2] - b[2]).abs <= 1 && (a[3] - b[3]).abs <= 1
      else
        a == b
      end
    end

    # True if the player can walk to (a tile adjacent to) an event, for the hide-unreachable filter.
    # Backed by one cached flood-fill per player tile instead of an A* per target (which was the
    # seconds-long lag), reused across category changes. Reachable when the event's tile or a neighbour
    # is in the flood set (find_path likewise routes to an adjacent tile); also handles cross-counter desks.
    def self.reachable?(ev)
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

    # True when the current target still applies: a surface tile while on the same map, or an event that still exists.
    def self.target_valid?
      return false unless @target && $game_map
      return true if @target.is_a?(SurfaceTarget)
      id = (@target.id rescue nil)
      !id.nil? && $game_map.events[id] == @target
    end

    # Ensures there is a valid target, rebuilding if needed; keeps the list position when the previous
    # target vanished (e.g. an event changed page after talking to it) instead of snapping to the first.
    def self.ensure_target
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
    end

    # Moves the selection (+1/-1) keeping focus on the current target: the list is rebuilt fresh and the
    # cursor resumes from where that target now sits, instead of snapping back to the nearest each time.
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

    # Gives the focused object a custom spoken label (Shift+K), stored in the shareable tag dictionary.
    # An empty entry removes it; surfaces (no event id) cannot be tagged.
    def self.rename_target
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && @target.respond_to?(:id)
      mid = $game_map.map_id; eid = @target.id
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

    # Shows a choice message and returns the picked (or cancel) index, across engines: gen-6 exposes the
    # message function only as Kernel.pbMessage, modern as a global pbMessage. Calling the absent one
    # raises NoMethodError (which the Ctrl+K menu used to swallow), so pick whichever the game provides.
    def self.show_menu(msg, choices, cancel)
      return Kernel.pbMessage(msg, choices, cancel) if Kernel.respond_to?(:pbMessage)
      pbMessage(msg, choices, cancel)
    end

    # The Ctrl+K mini-menu for the focused object: recategorise (when the mod guessed wrong) or hide it.
    # Uses the game's own choice window (read by the generic menu hook) and persists via Tags.
    def self.tag_menu
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_cant_label), true) unless $game_map && @target.respond_to?(:id)
      mid = $game_map.map_id; eid = @target.id
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
      t.respond_to?(:id) ? [0, t.id.to_i] : [1, t.x.to_i, t.y.to_i]
    end

    # A stable per-map number for a target (its rank by stable_key), so an object keeps its number while
    # you stay on the map -- the cycling list itself stays distance-sorted, so its raw index would shift.
    # The ordering is cached keyed by the @targets array identity (the reference, so a GC.compact reusing an
    # object_id can't cause a false hit); rebuild_targets reassigns @targets, so the cache self-invalidates.
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

    # The walking-distance suffix for a target: the real A* path length, or a no-route note. Empty when
    # already adjacent. One A* per selection (a keypress), not per frame.
    def self.step_phrase(target)
      path = (PokeAccess::Pathfinder.find_path(target.x, target.y) rescue nil)
      if path.nil?
        return ", " + PokeAccess::I18n.t(:loc_surf_route) if (PokeAccess::Pathfinder.surf_launch(target.x, target.y) rescue nil)
        return ", " + PokeAccess::I18n.t(:loc_no_route)
      end
      return "" if path.empty?
      ", " + PokeAccess::I18n.t(:loc_steps, :n => path.length)
    rescue StandardError
      ""
    end

    # Speaks the selected target and its direction. param withname true prepends the target name.
    def self.announce_selected(withname)
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil? || $game_player.nil?
      phrase = dir_phrase(@target.x - $game_player.x, @target.y - $game_player.y)
      unless withname
        return PokeAccess.speak(phrase, true)
      end
      ord = ordinal_of(@target)
      ordtxt = (ord && !@targets.empty?) ? (PokeAccess::I18n.t(:loc_count, :n => ord, :total => @targets.length) + ", ") : ""
      PokeAccess.speak("#{target_name(@target)}, #{ordtxt}#{phrase}#{step_phrase(@target)}", true)
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
    end

    # Speaks the A* route to the current target.
    def self.announce_route
      ensure_target
      return PokeAccess.speak(PokeAccess::I18n.t(:loc_nothing_selected), true) if @target.nil?
      PokeAccess.speak(PokeAccess::I18n.t(:loc_route, :steps => PokeAccess::Pathfinder.path_to_text(
        PokeAccess::Pathfinder.find_path(@target.x, @target.y))), true)
    end

    # Announces the map name once when entering a new map (orientation, no key needed), and is the single
    # trigger for :map_changed -- so it is also what makes Caches.reset_all run.
    #
    # The map id alone is not enough to notice a LOAD. Loading a save can land on the very map the player
    # was already standing on, and then the id has not changed: nothing was announced and, worse, no cache
    # was reset, so the previous run's emitters and targets carried over. The load screens used to paper
    # over this by calling forget_map, but only the two classic ones do -- v22 loads through UI::LoadVisuals
    # and nobody called it there, and a future engine would go the same way.
    #
    # Loading rebuilds $game_map from the save, so it is a DIFFERENT object even for the same id, and the
    # map factory hands back the cached instance when the player merely walks back to a map already visited.
    # Comparing identity as well as id therefore catches every load, in any era, without knowing a single
    # thing about which screen performed it.
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
      PokeAccess.speak(nm, false) if nm && !nm.to_s.strip.empty?
    end

    # True while the player is mid-jump, i.e. hopping a ledge (the engine sets @x/@y two tiles at once and
    # marks @jump_timer, so jumping? is true on that frame). Present in every engine variant (stock RMXP
    # Game_Character); the rescue keeps a missing method from ever raising here.
    def self.player_jumping?
      !!($game_player.jumping? rescue false)
    end

    # Announces an internal teleport: a jump of more than one tile on the SAME map (a within-map warp,
    # staircase or transfer), which announce_map_change never catches because the map id does not change --
    # leaving the player silently relocated. Tracks the last position; a same-map jump beyond a step (and not
    # a forced move route, i.e. a cutscene walk) is spoken with the destination's cardinal direction and the
    # targets are rebuilt for the new spot. A ledge hop also moves two tiles in one frame with no forced
    # route, so jumping? guards it out -- the announcement and the target rebuild are skipped, keeping the
    # locator's selection alive across the jump. The first frame and any map change just seed the position.
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

    # Drops the target list and selection (NOT @last_map_id), so the locator never offers an event from the
    # previous map. This is the cache reset run on :map_changed; it must NOT clear @last_map_id, or
    # announce_map_change would see "changed" again next frame and re-announce/re-emit forever.
    # Also drops the guide's route memo. @noroute_key is [px, py, tx, ty] with no map in it, so a "there is
    # no route" answered on one map would be replayed verbatim on another at the same coordinates -- and
    # replayed WITHOUT running A*, which is the part that makes it wrong rather than merely stale.
    def self.clear_targets
      @targets = []; @target = nil; @ti = 0
      @guide_path = nil; @guide_from = nil; @guide_target = nil; @noroute_key = nil
    end

    # Forgets the current map so the next announce_map_change fires even on the same map_id. Used ONLY when
    # loading a save (which may land on the map the player was already on); NOT wired to :map_changed.
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
      PokeAccess.speak("#{nm ? nm + '. ' : ''}x #{$game_player.x}, y #{$game_player.y}", true)
    end

    # Rebuilds the list the instant a running event finishes (an item picked up, a switch flipped) so a
    # collected object drops out and the count updates at once. Fires once on the running->idle edge, only
    # while the list is non-empty (an idle map pays nothing).
    def self.refresh_on_event_end
      run = ($game_system && $game_system.map_interpreter && $game_system.map_interpreter.running?) rescue false
      if @interp_running && !run
        (PokeAccess::Pathfinder.invalidate_cache rescue nil)
        (PokeAccess::Locator.forget_noroute rescue nil)
        (PokeAccess::Locator.clear_verdicts rescue nil)
        rebuild_targets unless @targets.empty?
      end
      @interp_running = run
    rescue StandardError
      @interp_running = false
    end

    # Runs every map frame: map-change announce, battle/info reset, spatial audio, guide, keys.
    def self.map_poll
      return unless $game_map && $game_player
      return unless (PokeAccess::Keys.enabled rescue true)
      return if PokeAccess::ConfigMenu.active?
      announce_map_change
      announce_internal_teleport
      refresh_on_event_end
      PokeAccess::Battle.clear_battle
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess::Spatial.tick
      guide_tick
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
        PokeAccess::Keys.shift_down? ? toggle_guide : announce_route
      end
    end
  end
end

# Per-frame map driver, hooked on Game_Player#update (not Scene_Map#update): some games run their whole
# map loop inside Scene_Map#update, so an after-hook there would only fire on leaving the map, but
# Game_Player#update runs each frame on the map in every engine variant. frame_hook, not after_hook: gen-6
# runs a whole wild battle inside Game_Player#update, so guarding it would pin the reentrancy stack for the
# entire fight and mute every battle reader (messages, command menu, moves).
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end

# Rebuild the target list when something elsewhere changes tags (e.g. an object un-hidden from the menu).
PokeAccess::Events.on(:tags_changed) { (PokeAccess::Locator.rebuild_targets rescue nil) }

# Drop the target list / selected target on map change (Caches.reset_all), so the locator never offers an
# event from the previous map; announce_map_change rebuilds it for the new map on the next frame. Uses
# clear_targets, NOT forget_map: clearing @last_map_id here would loop (reset -> re-announce -> reset).
PokeAccess::Caches.register(:locator) { PokeAccess::Locator.clear_targets }
