# A Pokemon arriving shiny in a trade, which the trade scene shows only on the sprite: said right after the line that
# names it, the first one after the arrival (pbScene2).
PokeAccess::Hooks.variants(["PokemonTradeScene", "PokemonTrade_Scene"], :pbScene2, "trade_shiny") do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbScene2, :optional => true) do |scene, _a|
    pk = PokeAccess.ivar(scene, :@pokemon2)
    PokeAccess.after_next_line(PokeAccess::I18n.t(:pk_shiny_hatch)) if pk && PokeAccess::Party.shiny?(pk)
  end
end
