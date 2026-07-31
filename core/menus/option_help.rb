# Per-option help. The Options scene draws each option's description into @sprites["textbox"] on
# selection change; the name/value are read by the command-window extractor, so the description is
# offered on the info key (read on demand). Covers both engine scene names; no-op where absent.
#
# The method that fires on a selection change is not named the same everywhere: stock Essentials calls
# pbChangeSelection, both Infinite Fusion games call updateDescription(index). They write to the very same
# @sprites["textbox"], so only the hook point differs. Registering per capability rather than blindly means
# a scene that has neither is skipped silently instead of reporting a missing method, and a scene with both
# is harmless -- set_info only stores the line for the info key, it never speaks on its own.
["PokemonOption_Scene", "PokemonOptionScene", "PokemonOptionPuntos_Scene"].each do |cn|
  ["pbChangeSelection", "updateDescription"].each do |meth|
    next unless PokeAccess::Engine.has?("#{cn}##{meth}")
    PokeAccess::Hooks.after_hook(cn, meth.to_sym) do |scene, _r, _a|
      tb = PokeAccess.sprite(scene, "textbox")
      d = (tb.text rescue nil)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(d)) if d && !d.to_s.strip.empty?
    end
  end
end
