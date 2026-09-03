module PokeAccess
  # The one dedup primitive for cursor/selection reads. Almost every reader voices a focused entry the game
  # re-asserts every frame, so it must speak only when the focus actually changes; the subtle cases -- a
  # fresh scene must re-read the same index, a key is a tuple like [page, party_index], the text changed
  # without the index changing -- live here once instead of once per reader.
  #
  # The dedup state lives ON the holder (a scene/visuals instance, or any object), under a per-reader slot
  # symbol, so two readers on the same scene never shadow each other and the state dies with the instance.
  # A holder of nil falls back to a module-wide table keyed by slot (for readers with no instance to hang on).
  module Cursor
    @global = {}

    # Drops the module-wide table. Dedup normally dies with the scene it hangs on, but readers with no
    # instance to hang on (the HUD text line, Awakening's affinity cards) land here instead, and this table
    # outlives everything. Nothing cleared it in the running game -- only the test harness did, between
    # suites, which is the tell that it was known to leak. Registered on :map_changed below.
    def self.reset_global; @global = {}; end

    # The slot with any legacy leading @ stripped (:@access_x and :access_x are the same slot), so the
    # composed dedup ivar is always a legal instance-variable name and never raises inside the rescue.
    def self.bare_slot(slot)
      slot.to_s.sub(/\A@+/, "").to_sym
    end

    # The [bare slot, dedup ivar] pair for a slot name, built once. announce asks for it TWICE per call
    # (pending? and then changed?) and each build costs a regexp plus a symbol interpolation, on a path that
    # runs every frame for every active window. The table cannot grow with play: slot names are symbols
    # written by hand in the readers, a closed set, never derived from game data.
    def self.slot_pair(slot)
      @pairs ||= {}
      @pairs[slot] ||= (b = bare_slot(slot); [b, :"@access_cur_#{b}"])
    end

    # True (and records the new key) when key differs from what slot last held on holder; false when equal.
    # A nil key always counts as "unchanged" so a missing value never speaks. Use this when you want to gate
    # arbitrary work; for the speak-the-focused-entry case prefer on_change / announce.
    # param holder the object to hang the dedup state on, or nil for the module-wide table
    # param slot a symbol naming this reader's dedup state (distinct per reader on a shared holder)
    # param key the current selection key (an index, a string, or an array tuple); nil never changes
    def self.changed?(holder, slot, key)
      return false if key.nil?
      return false if key == current(holder, slot)
      store(holder, slot, key)
      true
    rescue StandardError
      false
    end

    # The key a slot holds on holder (nil when fresh or reset), and its setter: the one place that knows
    # whether the state lives in an ivar on holder or in the module-wide table.
    def self.current(holder, slot)
      slot, ivar = slot_pair(slot)
      holder ? (holder.instance_variable_get(ivar) rescue nil) : @global[slot]
    end

    def self.store(holder, slot, val)
      slot, ivar = slot_pair(slot)
      holder ? holder.instance_variable_set(ivar, val) : (@global[slot] = val)
    end

    # Clears slot on holder so the next changed?/on_change speaks even if the key is unchanged. Call when a
    # screen (re)opens with the cursor possibly on the same entry as last time, so reopening still reads it.
    def self.reset(holder, slot)
      slot, ivar = slot_pair(slot)
      holder ? holder.instance_variable_set(ivar, nil) : @global.delete(slot)
    rescue StandardError
      nil
    end

    # True when slot holds no key yet on holder -- the FIRST read of a freshly opened (or reset) cursor, as
    # opposed to a later move between entries. Lets a reader queue the opening read (so it does not cut the
    # lines already playing when a screen opens) while still interrupting on every move after. A reader that
    # open-coded this kept a separate "seen" ivar beside the dedup one; this reads it off the dedup state
    # itself, so there is nothing extra to reset. Checked BEFORE the change? call that records the key.
    def self.pending?(holder, slot)
      prev = current(holder, slot)
      prev.nil? || retry_marker?(prev)
    rescue StandardError
      false
    end

    # Runs the block only when key changed (see changed?), returning the block's value then, else nil. The
    # block computes the line lazily, so an unchanged cursor does no work.
    # return the block result on change, else nil
    def self.on_change(holder, slot, key)
      return nil unless changed?(holder, slot, key)
      yield
    rescue StandardError
      nil
    end

    # The common shape: on a cursor change, speak the line the block builds. Cleaned and, by default,
    # interrupting (focus moves should cut the previous read). A nil/blank line UN-BURNS the key for the next
    # RETRY_FRAMES polls, so a row whose data lands a few frames after the cursor does is retried until it has
    # words, and a deliberately silent row stops costing a block call per frame once that budget is spent
    # (moving away and back re-arms it, as any new key does). A RAISING block burns at once: a permanently
    # broken reader must log once and stop, not spin.
    # param interrupt whether the spoken line interrupts the queue (true) or waits (false)
    # param first_interrupt interrupt value for the FIRST read of a fresh/reset cursor (when the slot is
    #   pending), for the "queue the opening read, interrupt later moves" pattern. nil (default) uses
    #   interrupt for every read, preserving the plain behaviour.
    # return true when a line was spoken, else nil
    def self.announce(holder, slot, key, interrupt = true, first_interrupt = nil)
      prev = current(holder, slot)
      first = !first_interrupt.nil? && (prev.nil? || retry_marker?(prev))
      return unless changed?(holder, slot, key)
      t = yield
      if t.nil? || t.to_s.empty?
        retry_blank(holder, slot, key, prev)
        return
      end
      PokeAccess.speak(PokeAccess.clean(t.to_s), first ? first_interrupt : interrupt)
      true
    rescue StandardError => e
      PokeAccess.log_once("cursor_#{slot}", e)
      nil
    end

    RETRY_FRAMES = 20

    # Leaves the slot holding a retry marker for key instead of key itself, counting the blank polls, so
    # changed? keeps answering true for it until RETRY_FRAMES blanks in a row; then the key stays burned.
    def self.retry_blank(holder, slot, key, prev)
      n = (retry_marker?(prev) && prev[1] == key) ? prev[2] + 1 : 1
      store(holder, slot, [:pa_retry, key, n]) if n < RETRY_FRAMES
    end

    def self.retry_marker?(v)
      v.is_a?(Array) && v[0] == :pa_retry
    end
  end
end

# The instance-held dedup dies with its scene; the module-wide fallback needs saying so explicitly.
PokeAccess::Caches.register(:cursor_global) { PokeAccess::Cursor.reset_global }
