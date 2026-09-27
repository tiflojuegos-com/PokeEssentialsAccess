module PokeAccess
  # The "Bag screen with interactable party" addon: its team panels (PokemonBagPartyPanel, not the core party
  # panel), read off the scene's @activecmd, since selected= also marks the fusion partner; and, while the item list
  # is browsed, the word each panel shows for the focused item in place of its HP.
  module BagParty
    @scene = nil
    @depth = 0

    # Holds the scene while any selection loop runs (they nest, hence the depth), clearing the dedup on entry
    # and exit, where the screen puts @activecmd back to 0.
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

    # The focused member with its annotation (whether the item can be used on it).
    def self.poll
      s = @scene
      return unless s
      i = PokeAccess.ivar(s, :@activecmd)
      return unless i.is_a?(Integer) && i >= 0
      panel = PokeAccess.sprite(s, "pokemon#{i}")
      return unless panel
      pk = PokeAccess.ivar(panel, :@pokemon)
      return unless pk
      ann = PokeAccess.ivar(panel, :@text)
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { member(pk, ann) })
      PokeAccess::UIV21.speak_changed(:party, member(pk, ann), i)
    rescue StandardError
      nil
    end

    # A member as this panel shows it: the state slot kept under an annotation, no game party icons. SHINYICON
    # and PKRSICON pick the star and pokerus icon; a release without them draws the star and pokerus in the slot.
    def self.member(pk, ann)
      return PokeAccess::UIV21.party_member(pk, ann) if PokeAccess::Summary.egg?(pk)
      rus = pokerus_icon(pk)
      PokeAccess::Party.member_line(pk, :annotation => ann, :status_always => true,
                                    :shiny => setting(:SHINYICON) != false, :pokerus_slot => setting(:PKRSICON).nil?,
                                    :panel_marks => false, :marks => (rus ? [rus] : []))
    end

    # The panel's own pokerus icon, or nil where it draws none.
    def self.pokerus_icon(pk)
      return nil unless setting(:PKRSICON)
      case (pk.pokerusStage rescue 0).to_i
      when 1 then PokeAccess::I18n.t(:pk_pokerus)
      when 2 then PokeAccess::I18n.t(:pk_pokerus_cured)
      end
    end

    # One of the addon's switches as the game sets it, nil where its release has no such switch.
    def self.setting(name)
      k = PokeAccess.const_at("BagScreenWiInParty")
      (k && k.const_defined?(name)) ? k.const_get(name) == true : nil
    rescue StandardError
      nil
    end

    @browsing = nil
    @annotated = nil

    # Holds the scene while its item list is browsed (pbChooseItem); browsing it again (back from an item's menu)
    # starts from what the panels show, so nothing already said is repeated.
    def self.browse(scene)
      again = PokeAccess.ivar(scene, :@pa_bag_browsed) ? true : false
      scene.instance_variable_set(:@pa_bag_browsed, true)
      @browsing = scene
      @annotated = again ? annotation_state(scene) : nil
    end

    def self.unbrowse; @browsing = nil; end

    # The focused item and what the panels write in place of HP for it, grouped by word in team order, as
    # [item, [[word, [member, ...]], ...]]; no groups for an item they annotate nothing for.
    def self.annotation_state(scene)
      list = PokeAccess.sprite(scene, "itemlist")
      item = (list.item rescue nil)
      groups = []
      (::Settings::MAX_PARTY_SIZE rescue 6).times do |i|
        panel = PokeAccess.sprite(scene, "pokemon#{i}")
        pk = PokeAccess.ivar(panel, :@pokemon) if panel
        word = PokeAccess.clean(PokeAccess.ivar(panel, :@text).to_s) if panel
        next if pk.nil? || word.nil? || word.empty?
        who = PokeAccess::Summary.egg?(pk) ? PokeAccess::I18n.t(:pty_egg) : PokeAccess.clean(pk.name.to_s)
        g = groups.assoc(word)
        g ? g[1].push(who) : groups.push([word, [who]])
      end
      [item, groups]
    end

    # After the game annotates the panels while an item is browsed: when the item or its annotations changed, who
    # is able, unable or has it learned, queued after the item's row from the bag reading's medium level, and kept
    # with the row for Ctrl+T.
    def self.annotations(scene)
      return unless @browsing && @browsing.equal?(scene)
      state = annotation_state(scene)
      return if state == @annotated
      @annotated = state
      return if state[1].empty?
      text = PokeAccess.sentences(state[1].map { |word, who| "#{word}: #{who.join(', ')}" })
      PokeAccess::Info.add_to_row(text, :bagp_ann)
      return unless PokeAccess::Verbosity.keep?(:bag_item, :medium)
      PokeAccess.speak(text, false, :menu)
    rescue StandardError
      nil
    end
  end
end

# Both selection loops, one poller: pbChoosePoke (Use, Give, Teach, Select) and pbChoosePokemon (the DNA
# splicers' fusion picker).
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChoosePoke, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.watch(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unwatch; end
end
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChoosePokemon, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.watch(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::BagParty.poll }

# While the item list is browsed, the per-frame pbUpdateAnnotation rewrites each panel's word for the focused item
# (a machine or an evolution stone); the item's row is read first, by the list's own update.
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbChooseItem, :optional => true) do |scene, nxt, _a|
  PokeAccess::BagParty.browse(scene)
  begin; nxt.call; ensure; PokeAccess::BagParty.unbrowse; end
end
PokeAccess::Hooks.around_hook("PokemonBag_Scene", :pbUpdateAnnotation, :optional => true) do |scene, nxt, _a|
  ret = nxt.call
  PokeAccess::BagParty.annotations(scene)
  ret
end
