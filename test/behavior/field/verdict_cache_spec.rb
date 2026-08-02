# The locator's verdict cache (F-L04-001). The invalidation lives inside the key (event id + identity
# of the live @list + kind), so these pin the load-bearing behaviours: a hit skips recomputation; a page
# flip (new @list identity) recomputes; flipping BACK revives the old, still-correct verdict; explicit
# clears (event end / map change) force recomputation; and the transfer_active_page_only setting is part
# of the key, so toggling it mid-game never serves a verdict computed under the other semantics.
Suite.define("locator: verdict cache keys by page identity and honours every invalidation") do
  World.clear_events
  loc = PokeAccess::Locator
  loc.clear_verdicts

  sign = World.event(:kind => :sign, :id => 21)
  list_a = PokeAccess.ivar(sign, :@list)
  truthy "the builder's sign has a live list", list_a.is_a?(Array)

  calls = 0
  r1 = loc.verdict(sign, :spec_probe) { calls += 1; :page_a }
  r2 = loc.verdict(sign, :spec_probe) { calls += 1; :recomputed }
  eq "the first call computes", r1, :page_a
  eq "the second call is a HIT (no recomputation)", [r2, calls], [:page_a, 1]

  list_b = [TestCmd.new(0)]
  sign.instance_variable_set(:@list, list_b)
  r3 = loc.verdict(sign, :spec_probe) { calls += 1; :page_b }
  eq "a page flip (new @list identity) recomputes", [r3, calls], [:page_b, 2]

  sign.instance_variable_set(:@list, list_a)
  r4 = loc.verdict(sign, :spec_probe) { calls += 1; :never }
  eq "flipping back revives the old verdict without recomputing", [r4, calls], [:page_a, 2]

  loc.clear_verdicts
  r5 = loc.verdict(sign, :spec_probe) { calls += 1; :fresh }
  eq "an explicit clear (event end / map change) recomputes", [r5, calls], [:fresh, 3]

  truthy "a real classifier answers through the cache", loc.sign_event?(sign)
  truthy "and answers identically on the cached path", loc.sign_event?(sign)

  falsy "a nil-ish verdict caches as a real hit (no recompute storm)",
        (loc.verdict(sign, :spec_nil) { nil } || loc.verdict(sign, :spec_nil) { :recomputed })

  prev = PokeAccess::Config.transfer_active_page_only
  begin
    PokeAccess::Config.transfer_active_page_only = true
    loc.transfer_command_dest_xy(sign)
    PokeAccess::Config.transfer_active_page_only = false
    loc.transfer_command_dest_xy(sign)
    store = loc.instance_variable_get(:@verdicts)
    kinds = store.keys.select { |k| k[0] == sign.id }.map { |k| k[2] }
    truthy "each transfer_active_page_only mode keeps its own verdict key",
           kinds.include?(:txy_active) && kinds.include?(:txy_all)
  ensure
    PokeAccess::Config.transfer_active_page_only = prev
  end

  World.clear_events
  loc.clear_verdicts
end
