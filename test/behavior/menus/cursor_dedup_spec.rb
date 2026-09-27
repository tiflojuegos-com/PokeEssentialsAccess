# The Cursor dedup: announce speaks once per key change; reset re-arms it, so a reopened screen reads again.
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

# changed? is true only on a real change: never on a repeat or a nil key.
Suite.define("cursor: changed? is true only on a real change") do
  holder = Object.new
  truthy "first key is a change", PokeAccess::Cursor.changed?(holder, :g, "a")
  falsy "same key is not a change", PokeAccess::Cursor.changed?(holder, :g, "a")
  truthy "a different key is a change", PokeAccess::Cursor.changed?(holder, :g, "b")
  falsy "a nil key never counts as a change", PokeAccess::Cursor.changed?(holder, :g, nil)
end

# A tuple key is compared by value, and each slot on a holder is independent.
Suite.define("cursor: tuple keys and independent slots") do
  holder = Object.new
  truthy "first tuple is a change", PokeAccess::Cursor.changed?(holder, :a, [1, 2])
  falsy "the same tuple is not a change", PokeAccess::Cursor.changed?(holder, :a, [1, 2])
  truthy "a different tuple is a change", PokeAccess::Cursor.changed?(holder, :a, [1, 3])
  truthy "a second slot on the same holder is independent", PokeAccess::Cursor.changed?(holder, :b, [1, 3])
end

# A nil holder keeps its state on the module-wide table, keyed by slot, and reset re-arms it there.
Suite.define("cursor: nil holder uses the module-wide table") do
  truthy "first key on the global table is a change", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
  falsy "the same global key is not a change", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
  PokeAccess::Cursor.reset(nil, :global_slot)
  truthy "after reset the global key re-reads", PokeAccess::Cursor.changed?(nil, :global_slot, 1)
end

# pending? is true until a fresh or reset cursor records its first key, telling the opening read from later moves.
Suite.define("cursor: pending? marks the first read of a fresh or reset cursor") do
  holder = Object.new
  truthy "a fresh slot is pending", PokeAccess::Cursor.pending?(holder, :p)
  PokeAccess::Cursor.changed?(holder, :p, 1)
  falsy "after the first key it is no longer pending", PokeAccess::Cursor.pending?(holder, :p)
  PokeAccess::Cursor.reset(holder, :p)
  truthy "after reset it is pending again", PokeAccess::Cursor.pending?(holder, :p)
end

# A blank line does not record the key: a row whose text arrives a frame late still speaks, and coming back from a
# row that stays blank re-reads the previous one.
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

# announce's first_interrupt is the interrupt of a fresh cursor's opening read (false queues it); later moves, and
# every read when it is nil, use the plain interrupt.
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
