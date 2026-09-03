# Cursor dedup primitive: almost every reader voices a focused entry the game re-asserts every frame, so it
# must speak only when the focus actually changes. announce speaks once per change; reset re-arms it so a
# reopened screen reads the same entry again; the key may be a tuple; and a nil holder falls back to the
# module-wide table. These are the subtle cases that were re-broken per file before Cursor centralised them.
Suite.define("cursor: announce speaks once per change, re-reads after reset") do
  holder = Object.new
  3.times { PokeAccess::Cursor.announce(holder, :slot, 5) { "entry five" } }
  spoke_once "an unchanged key speaks exactly once", /entry five/

  SpeakCapture.clear
  PokeAccess::Cursor.announce(holder, :slot, 6) { "entry six" }
  spoke "a changed key speaks again", /entry six/

  SpeakCapture.clear
  PokeAccess::Cursor.reset(holder, :slot)
  PokeAccess::Cursor.announce(holder, :slot, 6) { "entry six" }
  spoke "after reset the same key re-reads", /entry six/
end

# changed? gates arbitrary work: true only on a real change, false on the repeat and false on a nil key (a
# missing value must never speak).
Suite.define("cursor: changed? is true only on a real change") do
  holder = Object.new
  truthy "first key is a change", PokeAccess::Cursor.changed?(holder, :g, "a")
  falsy "same key is not a change", PokeAccess::Cursor.changed?(holder, :g, "a")
  truthy "a different key is a change", PokeAccess::Cursor.changed?(holder, :g, "b")
  falsy "a nil key never counts as a change", PokeAccess::Cursor.changed?(holder, :g, nil)
end

# A tuple key (e.g. [page, party_index]) is compared by value, and two readers on the same holder use
# distinct slots so they never shadow each other.
Suite.define("cursor: tuple keys and independent slots") do
  holder = Object.new
  truthy "first tuple is a change", PokeAccess::Cursor.changed?(holder, :a, [1, 2])
  falsy "the same tuple is not a change", PokeAccess::Cursor.changed?(holder, :a, [1, 2])
  truthy "a different tuple is a change", PokeAccess::Cursor.changed?(holder, :a, [1, 3])
  truthy "a second slot on the same holder is independent", PokeAccess::Cursor.changed?(holder, :b, [1, 3])
end

# A nil holder hangs the dedup state on the module-wide table keyed by slot (for readers with no instance),
# and reset on that table re-arms it.
Suite.define("cursor: nil holder uses the module-wide table") do
  truthy "first key on the global table is a change", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
  falsy "the same global key is not a change", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
  PokeAccess::Cursor.reset(nil, :global_slot)
  truthy "after reset the global key re-reads", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
end

# pending? is true only until the first key is recorded, so a reader can tell the opening read of a fresh (or
# reset) cursor from a later move. reset re-arms it. This is what lets the menu readers queue the opening line.
Suite.define("cursor: pending? marks the first read of a fresh or reset cursor") do
  holder = Object.new
  truthy "a fresh slot is pending", PokeAccess::Cursor.pending?(holder, :p)
  PokeAccess::Cursor.changed?(holder, :p, 1)
  falsy "after the first key it is no longer pending", PokeAccess::Cursor.pending?(holder, :p)
  PokeAccess::Cursor.reset(holder, :p)
  truthy "after reset it is pending again", PokeAccess::Cursor.pending?(holder, :p)
end

# A blank line un-burns the key: the row whose text lands a frame after the cursor (sprite not painted,
# ivar not assigned) must eventually speak, and before this contract the key was consumed on the empty
# frame and the row stayed mute until the cursor moved. The mute-then-back shape stays intact: a row that
# keeps yielding blank never records anything, so returning to the previous row re-reads it.
Suite.define("cursor: a blank line does not consume the key") do
  holder = Object.new
  late = nil
  PokeAccess::Cursor.announce(holder, :lb, 1) { late }
  silent "the empty frame stays silent"
  late = "arrived"
  PokeAccess::Cursor.announce(holder, :lb, 1) { late }
  spoke "the same key speaks once its text arrives", /arrived/

  SpeakCapture.clear
  PokeAccess::Cursor.announce(holder, :lb, 2) { nil }
  silent "a mute row stays silent"
  PokeAccess::Cursor.announce(holder, :lb, 1) { "back" }
  spoke "and coming back from it re-reads the previous row", /back/
end

# announce's first_interrupt: the opening read of a fresh cursor is queued (interrupt false) so it does not
# cut a title/question spoken just before, while every later move interrupts (true). This is the exact
# Window_DrawableCommand pattern, now owned by Cursor instead of a per-reader "seen" ivar. The plain 4-arg
# announce is unchanged: with first_interrupt nil, every read uses the same interrupt value.
Suite.define("cursor: first_interrupt queues the opening read, interrupts later moves") do
  holder = Object.new
  PokeAccess::Cursor.announce(holder, :cf, 0, true, false) { "first" }
  PokeAccess::Cursor.announce(holder, :cf, 1, true, false) { "second" }
  eq "opening read is queued, the move after interrupts",
     SpeakCapture.log, [["first", false], ["second", true]]

  SpeakCapture.clear
  holder2 = Object.new
  PokeAccess::Cursor.announce(holder2, :cf2, 0, true) { "plain" }
  eq "without first_interrupt the opening read uses the plain interrupt", SpeakCapture.log, [["plain", true]]
end
