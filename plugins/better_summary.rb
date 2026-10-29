module PokeAccess
  # Better Summary's ability page (the special button), painted outside drawPage: the ability, its description,
  # the sex sign and the held item, from the Pokemon showAbilityDescription is handed; and a Shadow Pokemon's heart
  # page (the same button on the info page), its heart paragraph as painted.
  module BetterSummary
    @shadow = nil

    def self.ability(pkmn)
      a = (pkmn.ability rescue nil)
      return unless a
      name = PokeAccess.clean((a.name rescue "").to_s)
      return if name.empty?
      desc = PokeAccess.clean((a.description rescue "").to_s)
      PokeAccess.speak(PokeAccess::Util.join_parts([name, desc] + extras(pkmn)), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The sex and the held item as the page writes them: the item line is always painted, "none" included.
    def self.extras(pkmn)
      out = []
      sex = (PokeAccess::Party.gender_glyph(pkmn) rescue nil)
      out.push(sex) if sex
      it = ((pkmn.hasItem? rescue false) ? (pkmn.item.name rescue nil) : nil)
      out.push(PokeAccess::I18n.t(:sum_item, :i => it || PokeAccess::I18n.t(:bs_no_item)))
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The heart page about to paint: forgets the page underneath, so its redraw on closing is read, and arms the
    # capture of the page, kept with the Pokemon until it is said.
    def self.open_shadow(scene, pkmn)
      PokeAccess::Summary.forget_page(scene)
      @shadow = pkmn
      PokeAccess::PaintCapture.arm(:bsum_shadow)
    end

    # Once the heart page has painted (the first frame of its wait for a key): the heart paragraph, then the sex and
    # the held item it writes.
    def self.flush_shadow
      return unless @shadow && PokeAccess::PaintCapture.pending?(:bsum_shadow)
      pkmn = @shadow
      @shadow = nil
      heart = PokeAccess.clean((PokeAccess::PaintCapture.take(:bsum_shadow, :formatted) || []).join(" "))
      PokeAccess.speak(PokeAccess::Util.join_parts((heart.empty? ? [] : [heart]) + extras(pkmn)), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The heart page closed: a capture no frame said is dropped.
    def self.close_shadow
      @shadow = nil
      PokeAccess::PaintCapture.take(:bsum_shadow)
    end
  end
end

# Forgets the page underneath as the ability page opens, so its redraw on closing is read.
PokeAccess::Hooks.before_hook("PokemonSummary_Scene", :showAbilityDescription, :optional => true) do |scene, args|
  PokeAccess::Summary.forget_page(scene)
  PokeAccess::BetterSummary.ability(args[0])
end

# The heart page paints and then waits for a key in a loop of its own, whose first frame says what it painted.
PokeAccess::Hooks.around_hook("PokemonSummary_Scene", :showShadowDescription, :optional => true) do |scene, nxt, args|
  (PokeAccess::BetterSummary.open_shadow(scene, args[0]) rescue nil)
  begin
    nxt.call
  ensure
    (PokeAccess::BetterSummary.close_shadow rescue nil)
  end
end
PokeAccess::Frame.each_pulse { PokeAccess::BetterSummary.flush_shadow }
