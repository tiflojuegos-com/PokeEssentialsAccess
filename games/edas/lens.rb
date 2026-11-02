# Edas' Eye of Truth (0192_Eye of Truth) takes any event whose name carries EOT, the hash left out too.
PokeAccess::Game.define("edas") do
  override("PokeAccess::Locator", :lens_tile?) do |_mod, _original, args|
    (args[0].name.to_s rescue "") =~ /EOT/ ? true : false
  end
end
