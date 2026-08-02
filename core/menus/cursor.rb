module PokeAccess
  # The one dedup primitive for cursor/selection reads. Almost every reader voices a focused entry that the
  # game re-asserts every frame, so it must speak only when the focus actually changes -- otherwise the same
  # item repeats continuously. Before this, each reader open-coded that with its own @access_* ivar; the
  # subtle cases (a fresh scene must re-read the same index; a key is a tuple like [page, party_index]; the
  # text changed without the index changing) were re-solved, and re-broken, per file. Cursor centralises it.
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

    # True (and records the new key) when key differs from what slot last held on holder; false when equal.
    # A nil key always counts as "unchanged" so a missing value never speaks. Use this when you want to gate
    # arbitrary work; for the speak-the-focused-entry case prefer on_change / announce.
    # @param holder the object to hang the dedup state on, or nil for the module-wide table
    # @param slot a symbol naming this reader's dedup state (distinct per reader on a shared holder)
    # @param key the current selection key (an index, a string, or an array tuple); nil never changes
    def self.changed?(holder, slot, key)
      return false if key.nil?
      slot = bare_slot(slot)
      ivar = :"@access_cur_#{slot}"
      prev = holder ? (holder.instance_variable_get(ivar) rescue nil) : @global[slot]
      return false if key == prev
      holder ? holder.instance_variable_set(ivar, key) : (@global[slot] = key)
      true
    rescue StandardError
      false
    end

    # Clears slot on holder so the next changed?/on_change speaks even if the key is unchanged. Call when a
    # screen (re)opens with the cursor possibly on the same entry as last time, so reopening still reads it.
    def self.reset(holder, slot)
      slot = bare_slot(slot)
      ivar = :"@access_cur_#{slot}"
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
      slot = bare_slot(slot)
      ivar = :"@access_cur_#{slot}"
      prev = holder ? (holder.instance_variable_get(ivar) rescue nil) : @global[slot]
      prev.nil?
    rescue StandardError
      false
    end

    # Runs the block only when key changed (see changed?), returning the block's value then, else nil. The
    # block computes the line lazily, so an unchanged cursor does no work.
    # @return the block result on change, else nil
    def self.on_change(holder, slot, key)
      return nil unless changed?(holder, slot, key)
      yield
    rescue StandardError
      nil
    end

    # The common shape: on a cursor change, speak the line the block builds. Cleaned and, by default,
    # interrupting (focus moves should cut the previous read). No-op when the line is nil/blank.
    # @param interrupt whether the spoken line interrupts the queue (true) or waits (false)
    # @param first_interrupt interrupt value for the FIRST read of a fresh/reset cursor (when the slot is
    #   pending), for the "queue the opening read, interrupt later moves" pattern. nil (default) uses
    #   interrupt for every read, preserving the plain behaviour.
    def self.announce(holder, slot, key, interrupt = true, first_interrupt = nil)
      first = !first_interrupt.nil? && pending?(holder, slot)
      t = on_change(holder, slot, key) { yield }
      return if t.nil? || t.to_s.empty?
      PokeAccess.speak(PokeAccess.clean(t.to_s), first ? first_interrupt : interrupt)
    rescue StandardError
      nil
    end
  end
end

# The instance-held dedup dies with its scene; the module-wide fallback needs saying so explicitly.
PokeAccess::Caches.register(:cursor_global) { PokeAccess::Cursor.reset_global }
