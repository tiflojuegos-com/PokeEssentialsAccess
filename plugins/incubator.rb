# Egg incubator (Kyu's plugin, class Incubadora): the core Hatcher screen's six-slot grid under another class name,
# read by the core reader on refresh (on open and after every move).
PokeAccess::Hooks.before_hook("Incubadora", :refresh, :optional => true) { |_scene, _a| PokeAccess::Incubator.arm }
PokeAccess::Hooks.after_hook("Incubadora", :refresh, :optional => true) do |scene, _r, _a|
  PokeAccess::Incubator.announce(scene)
end
PokeAccess::Hooks.after_hook("Incubadora", :dispose, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

PokeAccess::Verbosity.define_reading(:incubator, :vb_incubator, :vbh_incubator)
