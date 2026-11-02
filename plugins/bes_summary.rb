# Essentials BES's summary (PokemonSummaryScene rewritten: drawPage hands the five pages to drawPageInfo, drawPageData,
# drawPageStats, drawPageMoves and drawPageRibbons after drawCommonElements has painted the header they share): each
# page is read as the gen-6 summary's, with what BES draws beside them in pictures: the Gigantamax mark and the Tera
# type, the friendship bar and the Dynamax meter, the EV and IV columns, and the expanded view of the stats page. The
# same game's box panel draws the Tera type too, and its party panel the pokerus icon.
module PokeAccess
  module BesSummary
    MAX_HAPPINESS = 255

    # Whether the stats page paints the EV and IV columns and the friendship bar (the game's EXPANDED_SUMMARY_INFO).
    def self.expanded?
      (defined?(::EXPANDED_SUMMARY_INFO) && ::EXPANDED_SUMMARY_INFO) ? true : false
    end

    # Whether the game is one of the BES family, whose settings file declares the summary's expanded-info switch.
    def self.bes_game?
      defined?(::EXPANDED_SUMMARY_INFO) ? true : false
    end

    # Whether the header draws the Gigantamax mark, which BES asks of the Pokemon as gmaxFactor?.
    def self.factor?(pk)
      (pk.respond_to?(:gmaxFactor?) && pk.gmaxFactor?) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The Tera type page one draws beside the types, or nil where it draws none: the Pokemon has one, the player holds
    # the Tera Orb, the species is not Ogerpon or Terapagos and the game's switch against Terastallization is off.
    def self.tera_line(pk)
      type = (pk.teratype rescue nil)
      return nil if type.nil? || !(pbHasTeraOrb rescue false)
      return nil if [:OGERPON, :TERAPAGOS].any? { |s| pk.species == (getConst(PBSpecies, s) rescue nil) }
      return nil if ($game_switches[::NO_TERA_CRISTAL] rescue false)
      name = PokeAccess::Data.type_name(type)
      name.nil? || name.to_s.empty? ? nil : PokeAccess::I18n.t(:ss2_adv_tera, :t => name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The sentences page one adds to the data sheet: the Gigantamax mark and the Tera type.
    def self.info_extras(pk)
      [factor?(pk) ? PokeAccess::I18n.t(:dmax_factor) : nil, tera_line(pk)].compact
    end

    # The Dynamax level the page's meter shows, which it draws only for a Pokemon that can Dynamax and a player who
    # holds the Dynamax Band.
    def self.dynamax_level(pk)
      return nil unless pk.respond_to?(:dynamax) && (pbHasDBand rescue false)
      PokeAccess::I18n.t(:dmax_level, :n => (pk.dynamax_lvl rescue 0).to_i)
    end

    # The friendship the page's bar shows, as the number of the 255 the game keeps it to.
    def self.friendship(pk)
      return nil unless expanded?
      PokeAccess::I18n.t(:mui_happiness_value, :n => pk.happiness.to_i, :max => MAX_HAPPINESS)
    end

    # The memo page: the memo as it was painted, else composed from the Pokemon, then the Dynamax level and the
    # friendship, which the page draws as pictures.
    # param painted the strings drawFormattedTextEx painted, or nil
    def self.memo_page(pk, painted)
      memo = PokeAccess::Summary.painted_memo(painted) || PokeAccess::SummaryGen6.memo_text(pk)
      PokeAccess.sentences([memo, dynamax_level(pk), friendship(pk)])
    end

    # The sentence that gives the EV and IV the stats page paints in its two last columns, none while it paints none.
    def self.eviv_extras(pk)
      return [] unless expanded?
      ["#{PokeAccess::I18n.t(:sm_eviv)}. #{PokeAccess::Summary.eviv_rows(pk).join('. ')}."]
    end

    # The stats page: the gen-6 page with the EV and IV columns and the key hint it paints.
    # param painted the strings the page painted
    def self.stats_page(pk, painted)
      PokeAccess::Summary.with_hints(PokeAccess::SummaryGen6.stats_text(pk, painted, eviv_extras(pk)), painted)
    end

    # The Hidden Power type the expanded view draws, from the Pokemon's IVs, or nil.
    def self.hidden_power(pk)
      found = (pbHiddenPower(pk.iv) rescue nil)
      name = found.is_a?(Array) ? PokeAccess::Data.type_name(found[0]) : nil
      name.nil? || name.to_s.empty? ? nil : PokeAccess::I18n.t(:sm_hidden_power, :t => name)
    end

    # What the expanded view of the stats page draws: the ability with its description and the Hidden Power type.
    def self.expanded_text(pk)
      return nil unless pk
      PokeAccess.sentences([PokeAccess::Summary.ability_line(pk), hidden_power(pk)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the expanded view's own loop after saying its text, and forgets the page when it ends, so the stats page it
    # returns to is read again.
    def self.expanded_view(scene)
      text = expanded_text(PokeAccess.ivar(scene, :@pokemon))
      PokeAccess.speak(text, true) if text
      yield
    ensure
      PokeAccess::Summary.forget_page(scene)
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageInfo, :optional => true) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::SummaryGen6.info_page(s, pk, PokeAccess::BesSummary.info_extras(pk))
end

PokeAccess::Hooks.before_hook("PokemonSummaryScene", :drawPageData, :optional => true) do |_s, _a|
  PokeAccess::PaintCapture.arm(:summary_memo6)
end
PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageData, :optional => true) do |s, _r, args|
  painted = PokeAccess::PaintCapture.take(:summary_memo6, :formatted)
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 2, PokeAccess::BesSummary.memo_page(pk, painted))
end

PokeAccess::Hooks.before_hook("PokemonSummaryScene", :drawPageStats, :optional => true) do |_s, _a|
  PokeAccess::PaintCapture.arm(:summary_stats)
end
PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageStats, :optional => true) do |s, _r, args|
  painted = PokeAccess::PaintCapture.take(:summary_stats)
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 3, PokeAccess::BesSummary.stats_page(pk, painted))
end

PokeAccess::Hooks.around_hook("PokemonSummaryScene", :drawPageStatsExpanded, :optional => true) do |s, nxt, _a|
  PokeAccess::BesSummary.expanded_view(s) { nxt.call }
end

PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageMoves, :optional => true) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 4, PokeAccess::Summary.moves_text(pk))
end

PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageRibbons, :optional => true) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 5, PokeAccess::SummaryGen6.ribbons_text(pk))
end

# The family's party panel draws pokerus in the state slot of a member with no ailment.
PokeAccess::Hooks.override(PokeAccess::Party, :panel_pokerus?, :tag => "bes_summary") do |_m, original, _a|
  PokeAccess::BesSummary.bes_game? ? true : original.call
end

# The box panel draws the Tera type beside the types, under the conditions page one does.
PokeAccess::Hooks.override(PokeAccess::Party, :pc_details, :tag => "bes_summary") do |_m, original, args|
  tera = PokeAccess::BesSummary.tera_line(args[0])
  tera ? original.call + [tera] : original.call
end
