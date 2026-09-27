# Classic-Essentials party, PC storage and pause-menu hooks; what they say lives in PokeAccess::Party
# (party_storage.rb).

# The party cursor where pbChangeSelection reports the move (GameData-era scenes report through
# PokemonPartyPanel#selected=, in ui_v21.rb). Bound to the class that owns the method, since an alias on an empty
# compatibility bridge never runs; PokemonParty_Scene only beside that bridge, or GameData games speak twice.
party_sel_owner = lambda do |cn|
  k = PokeAccess.const_at(cn)
  k && (k.instance_methods(false).any? { |m| m.to_s == "pbChangeSelection" } rescue false)
end
party_sel_class = if party_sel_owner.call("PokemonScreen_Scene")
                    "PokemonScreen_Scene"
                  elsif PokeAccess::Engine.has?("PokemonScreen_Scene#pbChangeSelection") && party_sel_owner.call("PokemonParty_Scene")
                    "PokemonParty_Scene"
                  end
if party_sel_class
  PokeAccess::Hooks.after_hook(party_sel_class, :pbChangeSelection) do |scene, ret, args|
    PokeAccess::Party.announce_party(scene, scene.instance_variable_get(:@party), ret, args[1])
  end
  # The member the cursor rests on when the list takes a choice (on opening, preselected, back from a sub-menu),
  # which no move reports; queued behind the help line.
  PokeAccess::Hooks.before_hook(party_sel_class, :pbChoosePokemon, :optional => true) do |scene, args|
    sel = args[1].is_a?(Integer) && args[1] >= 0 ? args[1] : scene.instance_variable_get(:@activecmd)
    PokeAccess::Party.announce_member(scene, scene.instance_variable_get(:@party), sel)
  end
end

# PC storage cursor (pbUpdateOverlay runs on every slot change), with what the overlay paints: the modern PC
# writes its buttons there.
PokeAccess::Hooks.before_hook("PokemonStorageScene", :pbUpdateOverlay) do |_scene, _a|
  PokeAccess::PaintCapture.arm(:pc_overlay)
end
PokeAccess::Hooks.after_hook("PokemonStorageScene", :pbUpdateOverlay) do |scene, _r, args|
  PokeAccess::Party.announce_pc(scene, args[0], args[1], PokeAccess::PaintCapture.take_pairs(:pc_overlay))
end

# Keeps the word a party button is built with, painted and stored nowhere else, for Party.button_label.
["PokeSelectionConfirmCancelSprite", "PokemonPartyConfirmCancelSprite"].each do |cn|
  PokeAccess::Hooks.before_hook(cn, :initialize, :optional => true) do |sprite, args|
    sprite.instance_variable_set(:@access_label, args[0].to_s)
  end
end

# The PC's cursor mode (normal, quick swap, a plugin's multi-select), shown only by the arrow's colour. Read from
# the scene's ivars, not the argument, which the cycling form ignores; said interrupting.
module PokeAccess
  module StorageModes
    # Says the PC cursor mode when it changes.
    # param key the mode's i18n key when a game names its modes; nil reads the scene's flags
    def self.say(scene, key = nil)
      k = if key then key
          elsif PokeAccess.ivar(scene, :@multi) then :pc_mode_multi
          elsif PokeAccess.ivar(scene, :@quickswap) then :pc_mode_quick
          else :pc_mode_normal
          end
      return unless PokeAccess::Cursor.changed?(scene, :pc_mode, k)
      PokeAccess.speak(PokeAccess::I18n.t(k), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonStorageScene", :pbSetQuickSwap, :optional => true) do |scene, _r, _a|
  PokeAccess::StorageModes.say(scene)
end

# Entering the box grid or party column loop forgets the dedup key, so the focused slot is re-read on return;
# not while its line is still the last spoken (pc_still_heard?).
["pbSelectBoxInternal", "pbSelectPartyInternal"].each do |m|
  PokeAccess::Hooks.before_hook("PokemonStorageScene", m.to_sym, :optional => m == "pbSelectPartyInternal") do |scene, _a|
    PokeAccess::Cursor.reset(scene, :pc_key) unless PokeAccess::Party.pc_still_heard?(scene)
  end
end

# The info key reads the trainer once the classic pause menu opens. hook_container: this body only stores, and
# the selectButton hook inside pbStartScene speaks (a guarded outer hook would drop it as nested_other?).
PokeAccess::Hooks.after_hook("PokemonMenu_Scene", :pbStartScene, :hook_container => true) do |_s, _r, _a|
  PokeAccess::Info.set_info(:trainer, nil)
end
