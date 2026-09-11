# gen-6 party / storage / pause triggers. The spoken content is the agnostic PokeAccess::Party
# (party_storage.rb at the module root); this file only wires the classic-Essentials scenes, so the
# version-specific hooks live under gen6/ as the module-first layout intends.

# Party selection on classic Essentials: PokemonScreen_Scene#pbChangeSelection both moves the cursor and
# reports where it landed, where the GameData-era scene reports through PokemonPartyPanel#selected= (read in
# core/menus/v21/ui_v21.rb). The split is by WHICH object reports the move, so no era gate is needed. Bound
# to the class that OWNS pbChangeSelection (an alias on an empty compatibility bridge never runs for the
# parent's instances), and only where that bridge exists, or a GameData game would speak every move twice.
party_sel_owner = lambda do |cn|
  k = PokeAccess.const_at(cn)
  k && (k.instance_methods(false).any? { |m| m.to_s == "pbChangeSelection" } rescue false)
end
if party_sel_owner.call("PokemonScreen_Scene")
  PokeAccess::Hooks.after_hook("PokemonScreen_Scene", :pbChangeSelection) do |scene, ret, args|
    PokeAccess::Party.announce_party(scene, scene.instance_variable_get(:@party), ret, args[1])
  end
elsif PokeAccess::Engine.has?("PokemonScreen_Scene#pbChangeSelection") && party_sel_owner.call("PokemonParty_Scene")
  PokeAccess::Hooks.after_hook("PokemonParty_Scene", :pbChangeSelection) do |scene, ret, args|
    PokeAccess::Party.announce_party(scene, scene.instance_variable_get(:@party), ret, args[1])
  end
end

# PC storage cursor (pbUpdateOverlay runs whenever the focused slot changes).
PokeAccess::Hooks.after_hook("PokemonStorageScene", :pbUpdateOverlay) do |scene, _r, args|
  PokeAccess::Party.announce_pc(scene, args[0], args[1])
end

# The PC's cursor MODE (normal, quick swap, and one plugin's multi-select), shown by nothing but the colour
# of the arrow. Read from the scene's ivars rather than the argument, because the cycling form ignores what
# it is passed; interrupting, because it answers the key just pressed.
module PokeAccess
  module StorageModes
    def self.say(scene)
      k = if PokeAccess.ivar(scene, :@multi) then :pc_mode_multi
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

# Every (re)entry to the selection loop forgets the dedup key: the outer PC loop calls this again after
# each command menu, and its header repaints via pbUpdateOverlay, so coming back from Withdraw/Summary/
# Exit re-reads the focused slot instead of staying quiet on an unchanged key.
PokeAccess::Hooks.before_hook("PokemonStorageScene", :pbSelectBoxInternal) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :pc_key)
end

# Trainer info via the info key when the classic pause menu opens (so the info key reads the trainer, not a
# stale :pokemon left over from the party screen or a previous battle).
# hook_container: this body only STORES, it never speaks, and pbStartScene calls selectButton -- whose hook is
# the one that announces. Guarded, that opening read is dropped as nested_other? and the screen opens
# in silence; the guard is only useful when the outer hook is itself the announcer.
PokeAccess::Hooks.after_hook("PokemonMenu_Scene", :pbStartScene, :hook_container => true) do |_s, _r, _a|
  PokeAccess::Info.set_info(:trainer, nil)
end
