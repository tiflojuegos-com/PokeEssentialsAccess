module PokeAccess
  # Per-option help. Where the Options scene really has one, it draws each option's description into
  # @sprites["textbox"] on selection change; the name/value are read by the command-window extractor, so
  # the description is offered on the info key (read on demand).
  module OptionHelp
    # Stores the description drawn for the focused option -- but only once it has PROVED to be per-option.
    #
    # @sprites["textbox"] is not a help box in every game. Across the gen-6 catalogue it is the speech-frame
    # sample window: opalo, africanvs, armonia and reminiscencia all write "Marco de dialogo N" into it,
    # realidea a fixed "Edita las opciones de juego", and awakening has no such sprite at all. Scraping it
    # made the info key answer with that one constant on every option of the screen -- a sentence that has
    # nothing to do with the option under the cursor, which is worse than saying nothing.
    #
    # So the widget has to earn it, and there are two ways of earning it. Both compare consecutive samples
    # of [option index, option value, text], all three of which the scene already exposes:
    #
    #   - two different texts at two different INDICES. A banner reads the same on every option.
    #   - two different texts at the same index with the same VALUE. Nothing the player did can explain
    #     that, so something is writing a description on its own. This is the one that matters on the fork
    #     that DOES have help: its textbox is created holding the speech-frame sample too and is overwritten
    #     with the real description a frame later, so on the index rule alone the option the screen opens on
    #     would stay unread until the player moved. The value is in the pair because changing the
    #     speech-frame option rewrites that sample legitimately, and that must not count as proof.
    #
    # Until proved, nothing is stored: on a screen with no help the info key stays quiet rather than
    # reciting a sentence about an option the cursor is not on.
    def self.read(scene)
      tb = PokeAccess.sprite(scene, "textbox")
      d = (tb.text rescue nil)
      return if d.nil? || d.to_s.strip.empty?
      text = PokeAccess.clean(d).to_s.strip
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
