module PokeAccess
  # Per-option help. Where the Options scene really has one, it draws each option's description into
  # @sprites["textbox"] on selection change; the name/value are read by the command-window extractor, so
  # the description is offered on the info key (read on demand).
  module OptionHelp
    # Stores the description drawn for the focused option, once the textbox has PROVED to be per-option: in
    # most gen-6 games @sprites["textbox"] is the speech-frame sample window, a constant on every option.
    # Proof is two different texts at two different indices, or at the same index with the same option value
    # (something other than the player rewrote it; a changed speech-frame option rewrites the sample
    # legitimately and does not count). Until proved, nothing is stored.
    def self.read(scene)
      tb = PokeAccess.sprite(scene, "textbox")
      d = (tb.text rescue nil)
      return if d.nil? || d.to_s.strip.empty?
      text = PokeAccess.clean(d)
      opt = PokeAccess.sprite(scene, "option")
      idx = (opt.index rescue nil)
      val = (opt[idx] rescue nil)
      seen = PokeAccess.ivar(scene, :@access_help_seen)
      scene.instance_variable_set(:@access_help_seen, [idx, val, text])
      return if seen.nil?
      unless PokeAccess.ivar(scene, :@access_help_ok)
        return if seen[2] == text
        return if seen[0] == idx && seen[1] != val
        scene.instance_variable_set(:@access_help_ok, true)
      end
      PokeAccess::Info.set_info(:text, text)
    rescue StandardError
      nil
    end
  end
end

# Only names every game has. A scene belonging to exactly one fangame is bound from that profile instead,
# next to the rest of its reader.
#
# The method that fires on a selection change is not named the same everywhere: stock Essentials calls
# pbChangeSelection; some forks call updateDescription(index). They write to the very same
# @sprites["textbox"], so only the hook point differs. :optional -- a scene that has neither is skipped
# silently, and a scene with both is harmless (read only stores the line, it never speaks on its own).
PokeAccess::Engine.scene_classes("PokemonOption_Scene", "PokemonOptionScene").each do |cn|
  ["pbChangeSelection", "updateDescription"].each do |meth|
    PokeAccess::Hooks.after_hook(cn, meth.to_sym, :optional => true) do |scene, _r, _a|
      PokeAccess::OptionHelp.read(scene)
    end
  end

  # pbUpdate covers the era that has neither selection-change method. It is the scene's own per-frame loop,
  # so it also sees the textbox of a screen whose widget is not help at all -- which is why read verifies
  # before it offers anything.
  #
  # hook_container is NOT optional here: pbUpdate DRIVES the option window whose cursor-change reader
  # announces the option itself. Guarded, it would pin :pbUpdate on the reentrancy stack for the whole
  # frame and that reader would be dropped as nested_other?: the help would arrive and the options would
  # go mute.
  PokeAccess::Hooks.after_hook(cn, :pbUpdate, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::OptionHelp.read(scene)
  end
end
