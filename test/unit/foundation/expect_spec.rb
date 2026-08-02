# expect!: the "a reader went quiet" tracer. It must be a pure pass-through for its value (nil or not),
# and a nil value must leave exactly ONE diagnostic line per key (log_once semantics) -- a per-frame
# reader hitting an absent object every frame may not flood the marker file.
Suite.define("expect!: passes the value through and logs a nil once per key") do
  eq "a present value passes through untouched", PokeAccess.expect!("spec.present", :obj), :obj
  eq "a nil value still returns nil", PokeAccess.expect!("spec.absent", nil), nil

  logged = PokeAccess.instance_variable_get(:@logged_once) || {}
  truthy "the nil was logged under its expect key", logged["expect.spec.absent"]
  falsy "the present value logged nothing", logged["expect.spec.present"]

  before = logged.keys.length
  PokeAccess.expect!("spec.absent", nil)
  PokeAccess.expect!("spec.absent", nil)
  after = (PokeAccess.instance_variable_get(:@logged_once) || {}).keys.length
  eq "repeated nils on the same key add no new log entries", after, before
end
