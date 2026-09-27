# A Pokemon hatching shiny, which the hatch scene shows only on the sprite: said right after its hatch line.
PokeAccess::Hooks.variants(["PokemonEggHatch_Scene", "PokemonEggHatchScene"], :pbMain, "hatch_shiny") do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbMain, :optional => true) do |scene, _a|
    pk = PokeAccess.ivar(scene, :@pokemon)
    PokeAccess.after_next_line(PokeAccess::I18n.t(:pk_shiny_hatch)) if pk && PokeAccess::Party.shiny?(pk)
  end
end
