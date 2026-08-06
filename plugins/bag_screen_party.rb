module PokeAccess
  # The "Bag screen with interactable party" addon (PokemonBag_Scene with PokemonBagPartyPanel), bundled by
  # several games alike: the team panels embedded in the bag are navigable, but live in PokemonBagPartyPanel
  # -- a Sprite subclass unrelated to the standard PokemonPartyPanel -- so the core party hook never sees
  # them.
  #
  # Read off the SCENE's cursor, not off the panels' selected= setter. Two panels are selected at once here:
  # the loop marks the one under the cursor, and then the screen marks the fusion partner as well -- last,
  # and unconditionally. Hooking the setter therefore ended every cursor move by naming the partner, so the
  # final thing heard was always the slot the player was NOT on. The scene's own @activecmd has no such
  # ambiguity, and it is the same value the loop uses to decide which panel to mark.
  module BagParty
    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end

    def self.poll
      s = @scene
      return unless s
      i = PokeAccess.ivar(s, :@activecmd)
      return unless i.is_a?(Integer) && i >= 0
      panel = PokeAccess.sprite(s, "pokemon#{i}")
      return unless panel
      pk = PokeAccess.ivar(panel, :@pokemon)
      return unless pk
      PokeAccess::Info.set_info(:pokemon, pk)
      # The annotation is the reason the bag opens the team at all: it is what says whether the item can be
      # used on this member ("able" / "not able" / "learned"). The panel keeps it in the same place the
      # standard party panel does.
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::UIV21.speak_changed(:party, PokeAccess::UIV21.party_member(pk, ann))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChoosePokemon, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.watch(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::BagParty.poll }
