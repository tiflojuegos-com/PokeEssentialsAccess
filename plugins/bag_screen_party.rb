# The "Bag screen with interactable party" addon (PokemonBag_Scene with PokemonBagPartyPanel), bundled by
# several games alike: the team panels embedded in the bag are navigable, but live in
# PokemonBagPartyPanel -- a Sprite subclass unrelated to the standard PokemonPartyPanel -- so the core party
# hook (ui_v21) never sees them. Mirror it: read the focused member on selected=, deduped through the shared
# :party reader, and expose its info. Gated by class existence so it no-ops where the addon is absent.
if PokeAccess::Engine.has?("PokemonBagPartyPanel")
  PokeAccess::Hooks.after_hook("PokemonBagPartyPanel", :selected=, :optional => true) do |panel, _r, args|
    if args[0]
      pk = PokeAccess.ivar(panel, :@pokemon)
      if pk
        PokeAccess::Info.set_info(:pokemon, pk)
        PokeAccess::UIV21.speak_changed(:party, PokeAccess::UIV21.party_member(pk))
      end
    end
  end
end
