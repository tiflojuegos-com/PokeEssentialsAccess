# Hooks.wrap_singleton: a game module's own singleton method (def self.x, called as Module.x) wrapped the
# way wrap_kernel wraps Kernel's. A class hook on such a name binds the instance side, a copy nobody calls;
# Añil's ability changer keeps its help-carrying command call on MessageUI, which is why this exists.
module PaSingletonRig
  def self.run(a, b = 1); a * b; end
end

Suite.define("hooks: wrap_singleton wraps a module function around, keeps its result, and skips the absent") do
  trace = []
  PokeAccess::Hooks.wrap_singleton("PaSingletonRig", :run, "spec_singleton", :around) do |args, call_next|
    trace.push([:enter, args.dup])
    begin
      call_next.call
    ensure
      trace.push(:leave)
    end
  end

  eq "the wrapped call still answers what the original answers", PaSingletonRig.run(3, 4), 12
  eq "and the body ran around it, with the arguments it was given", trace, [[:enter, [3, 4]], :leave]

  trace.clear
  begin
    PaSingletonRig.run(nil)
  rescue StandardError
    nil
  end
  eq "a raise inside still runs the leave half, so a mark can never stay set", trace.last, :leave

  before = PokeAccess::Hooks.fn_absent.length
  PokeAccess::Hooks.wrap_singleton("PaSingletonRig", :missing_function, "spec_singleton", :around) { |_a, n| n.call }
  PokeAccess::Hooks.wrap_singleton("PaNoSuchModule", :run, "spec_singleton", :around) { |_a, n| n.call }
  eq "an absent method or module is recorded as absent, not raised on",
     PokeAccess::Hooks.fn_absent[before..-1], ["PaSingletonRig.missing_function", "PaNoSuchModule.run"]
end
