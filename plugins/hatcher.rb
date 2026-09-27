# KYU's Hatcher incubator, read through core's Incubator on each refresh, which runs on every cursor move and
# once on opening.
PokeAccess::Hooks.before_hook("Hatcher", :refresh, :optional => true) { |_scene, _args| PokeAccess::Incubator.arm }
PokeAccess::Hooks.after_hook("Hatcher", :refresh, :optional => true) { |scene, _result, _args| PokeAccess::Incubator.announce(scene) }
PokeAccess::Hooks.after_hook("Hatcher", :dispose, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

PokeAccess::Verbosity.define_reading(:incubator, :vb_incubator, :vbh_incubator)
