module PokeAccess
  # The dedup primitive for cursor reads: speak a focused entry only when its key changes. The state lives on the
  # holder (a scene or any object) under a per-reader slot, so it dies with the instance; a nil holder uses a
  # module-wide table keyed by slot.
  module Cursor
    @global = {}

    # Drops the module-wide table, which outlives every scene; run on map change (registered below).
    def self.reset_global; @global = {}; end

    # The slot with any leading @ stripped (:@access_x and :access_x are one slot), so the dedup ivar name is legal.
    def self.bare_slot(slot)
      slot.to_s.sub(/\A@+/, "").to_sym
    end

    # The [bare slot, dedup ivar] pair for a slot name, memoised: a per-frame path, and slot names are a closed set
    # of hand-written symbols, so the table cannot grow with play.
    def self.slot_pair(slot)
      @pairs ||= {}
      @pairs[slot] ||= (b = bare_slot(slot); [b, :"@access_cur_#{b}"])
    end

    # True, recording key, when key differs from what slot last held on holder; false when equal or nil.
    # param holder the object holding the dedup state, or nil for the module-wide table
    # param slot a symbol naming this reader's dedup state (distinct per reader on a shared holder)
    def self.changed?(holder, slot, key)
      return false if key.nil?
      return false if key == current(holder, slot)
      store(holder, slot, key)
      true
    rescue StandardError
      false
    end

    # The key a slot holds, or nil when fresh or reset: an ivar on holder, else the module-wide table; store sets it.
    def self.current(holder, slot)
      slot, ivar = slot_pair(slot)
      holder ? (holder.instance_variable_get(ivar) rescue nil) : @global[slot]
    end

    def self.store(holder, slot, val)
      slot, ivar = slot_pair(slot)
      holder ? holder.instance_variable_set(ivar, val) : (@global[slot] = val)
    end

    # Clears slot on holder so the next read speaks even on the same key (a screen reopening on the same entry).
    def self.reset(holder, slot)
      slot, ivar = slot_pair(slot)
      holder ? holder.instance_variable_set(ivar, nil) : @global.delete(slot)
    rescue StandardError
      nil
    end

    # True when slot holds no key yet (or only a retry marker): the first read of a fresh or reset cursor. Ask it
    # before changed?, which records the key.
    def self.pending?(holder, slot)
      prev = current(holder, slot)
      prev.nil? || retry_marker?(prev)
    rescue StandardError
      false
    end

    # Runs the block only when key changed (see changed?): the block's value then, else nil.
    def self.on_change(holder, slot, key)
      return nil unless changed?(holder, slot, key)
      yield
    rescue StandardError
      nil
    end

    # On a cursor change, speaks the block's line cleaned (true when spoken); a blank line retries the key for up to
    # RETRY_FRAMES polls, since row data can land a few frames late; a raising block does not retry.
    # param first_interrupt the interrupt for the first read of a fresh or reset cursor; nil uses interrupt
    def self.announce(holder, slot, key, interrupt = true, first_interrupt = nil)
      prev = current(holder, slot)
      first = !first_interrupt.nil? && (prev.nil? || retry_marker?(prev))
      return unless changed?(holder, slot, key)
      t = yield
      if t.nil? || t.to_s.empty?
        retry_blank(holder, slot, key, prev)
        return
      end
      PokeAccess.speak(PokeAccess.clean(t.to_s), first ? first_interrupt : interrupt, :menu)
      true
    rescue StandardError => e
      PokeAccess.log_once("cursor_#{slot}", e)
      nil
    end

    RETRY_FRAMES = 20

    # Stores a retry marker for key, counting blank polls, so changed? stays true for it until RETRY_FRAMES in a row.
    def self.retry_blank(holder, slot, key, prev)
      n = (retry_marker?(prev) && prev[1] == key) ? prev[2] + 1 : 1
      store(holder, slot, [:pa_retry, key, n]) if n < RETRY_FRAMES
    end

    def self.retry_marker?(v)
      v.is_a?(Array) && v[0] == :pa_retry
    end
  end
end

# Drops the module-wide table on map change; instance-held state dies with its scene.
PokeAccess::Caches.register(:cursor_global) { PokeAccess::Cursor.reset_global }
