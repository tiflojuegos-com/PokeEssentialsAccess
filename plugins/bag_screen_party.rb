module PokeAccess
  # The "Bag screen with interactable party" addon (PokemonBag_Scene with PokemonBagPartyPanel), bundled by
  # several games alike: the team panels embedded in the bag are navigable, but live in PokemonBagPartyPanel
  # -- a Sprite subclass unrelated to the standard PokemonPartyPanel -- so the core party hook never sees
  # them.
  #
  # Read off the scene's @activecmd, not off the panels' selected= setter: two panels are selected at once
  # here, because the screen marks the fusion partner last and unconditionally, so the setter would always
  # end a move by naming the slot the player is not on.
  module BagParty
    @scene = nil
    @depth = 0

    # Holds the scene for as long as ANY selection loop is running. They nest -- moving an item opens a
    # second loop from inside the first -- so a depth counter is what keeps the outer one watched when the
    # inner returns. The dedup slot is cleared on entry and exit because the screen puts @activecmd back to
    # 0 each time, which is usually the member already announced.
    def self.watch(scene)
      @scene = scene
      @depth += 1
      PokeAccess::UIV21.reset(:party)
    end

    def self.unwatch
      @depth = [@depth - 1, 0].max
      @scene = nil if @depth == 0
      PokeAccess::UIV21.reset(:party)
    end

    # The focused member, with the annotation that is the reason the bag opens the team at all: it says
    # whether the item can be used on this one ("able" / "not able" / "learned"). The panel keeps it in the
    # same place the standard party panel does.
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
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::UIV21.speak_changed(:party, PokeAccess::UIV21.party_member(pk, ann) + panel_extras(pk), i)
    rescue StandardError
      nil
    end

    # The panel paints four states beyond the standard party line -- status ailment, held item,
    # shininess and an active Pokerus infection -- so they travel with the member. Status resolves through Data so both engines' shapes
    # (gen-6 integer, modern symbol) read right.
    def self.panel_extras(pk)
      parts = []
      st = (pk.status rescue nil)
      if st && st != 0 && st.to_s != "NONE"
        sn = (PokeAccess::Data.status_name(st) rescue nil)
        parts.push(sn) if sn && !sn.to_s.empty?
      end
      it = (pk.item_id rescue nil)
      it = (pk.item rescue nil) if it.nil?
      if it && it != 0
        iname = (PokeAccess::Data.item_name(it) rescue nil)
        parts.push(PokeAccess::I18n.t(:pk_holds, :item => iname)) if iname && !iname.to_s.empty?
      end
      parts.push(PokeAccess::I18n.t(:dbk_shiny)) if (pk.shiny? rescue false)
      parts.push(PokeAccess::I18n.t(:pk_pokerus)) if (pk.pokerusStage rescue 0).to_i == 1
      parts.empty? ? "" : ", " + parts.join(", ")
    rescue StandardError
      ""
    end
  end
end

# Both selection loops. pbChoosePokemon is the fusion picker, called only by the DNA splicers; the everyday
# one, reached from Use, Give, Teach and Select, is pbChoosePoke(option, switching). They share @activecmd
# and the same panel sprites, so one poller serves both.
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChoosePoke, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.watch(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unwatch; end
end
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChoosePokemon, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.watch(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::BagParty.poll }
