module PokeAccess
  # Per-option help. The Options scene draws each option's description into @sprites["textbox"] on
  # selection change; the name/value are read by the command-window extractor, so the description is
  # offered on the info key (read on demand).
  module OptionHelp
    # Stores the description currently drawn for the focused option. Only stores -- the info key speaks it.
    def self.read(scene)
      tb = PokeAccess.sprite(scene, "textbox")
      d = (tb.text rescue nil)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(d)) if d && !d.to_s.strip.empty?
    end
  end
end

# The method that fires on a selection change is not named the same everywhere: stock Essentials calls
# pbChangeSelection; some forks call updateDescription(index). They write to the very same
# @sprites["textbox"], so only the hook point differs. :optional -- a scene that has neither is skipped
# silently, and a scene with both is harmless (read only stores the line, it never speaks on its own).
PokeAccess::Engine.scene_classes("PokemonOption_Scene", "PokemonOptionScene", "PokemonOptionPuntos_Scene").each do |cn|
  ["pbChangeSelection", "updateDescription"].each do |meth|
    PokeAccess::Hooks.after_hook(cn, meth.to_sym, :optional => true) do |scene, _r, _a|
      PokeAccess::OptionHelp.read(scene)
    end
  end

  # pbUpdate covers the whole gen-6 era: none of those seven games has either selection-change method
  # (their PokemonOptionScene writes the description inline inside pbOptions), so without it the info key
  # never had a description to offer in ANY of them -- and :optional meant it failed silently.
  #
  # hook_container is NOT optional here: pbUpdate is the scene's own per-frame loop, and it DRIVES the
  # option window whose cursor-change reader announces the option itself. Guarded, it would pin :pbUpdate
  # on the reentrancy stack for the entire frame and that reader would be dropped as nested_other? -- the
  # help would arrive and the options would go mute, which is exactly what happened in the game.
  PokeAccess::Hooks.after_hook(cn, :pbUpdate, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::OptionHelp.read(scene)
  end
end
