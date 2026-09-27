module PokeAccess
  # Per-option help: the description an Options scene draws into @sprites["textbox"] on selection change, offered on
  # the info key.
  module OptionHelp
    # Stores the focused option's description once the textbox proves per-option (in most gen-6 games it is the
    # speech-frame sample): a new text at another index, or at the same index and value.
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
      PokeAccess::Info.set_info(:text, PokeAccess::KeyHints.localize(text, nil, true))
    rescue StandardError
      nil
    end
  end
end

# The selection change is pbChangeSelection in stock Essentials and updateDescription in some forks; both :optional
# (OptionHelp.read only stores, so a scene with both is harmless). A one-game scene is bound from its profile.
PokeAccess::Engine.scene_classes("PokemonOption_Scene", "PokemonOptionScene").each do |cn|
  # Opening the screen clears the info key, which has nothing here until the textbox proves to be help.
  PokeAccess::Hooks.before_hook(cn, :pbStartScene, :optional => true) { |_s, _a| PokeAccess::Info.set_info(nil, nil) }
  ["pbChangeSelection", "updateDescription"].each do |meth|
    PokeAccess::Hooks.after_hook(cn, meth.to_sym, :optional => true) do |scene, _r, _a|
      PokeAccess::OptionHelp.read(scene)
    end
  end

  # pbUpdate, for the era with neither method: per frame, so read's proof matters. A container: pbUpdate drives the
  # option window, whose own reader would be dropped as nested under a guard.
  PokeAccess::Hooks.after_hook(cn, :pbUpdate, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::OptionHelp.read(scene)
  end
end
