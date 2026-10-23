# The six-page gen-6 summary Insurgence and Sevii share (PokemonSummaryScene with a drawPageSix): after the stats,
# drawPageFour paints each stat's EV and IV with the ability, drawPageFive the moves and drawPageSix the ribbons, one
# page later than the stock gen-6 summary the core reads.
module PokeAccess
  module SummarySixPages
    # The EV & IV page: its title, each stat's EV and IV in the stock order, the nature's effect its labels' tint shows
    # and the ability with the description the page paints under it.
    def self.eviv_text(pk)
      rows = PokeAccess::Summary.eviv_rows(pk)
      extra = [PokeAccess::Summary.nature_effect_line(pk), PokeAccess::Summary.ability_line(pk)].compact
      (["#{PokeAccess::I18n.t(:sm_eviv)}. #{rows.join('. ')}."] + extra).join(" ")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Puts each core page read on the page a six-page summary draws there: the core's page 4 (drawPageFour) is the
    # EV & IV page, its page 5 (drawPageFive) the moves; a summary with no sixth page is left as the core read it.
    # param args Summary.speak_page's arguments (scene, pokemon, page, text), changed in place
    def self.repage(args)
      return args unless args[0].respond_to?(:drawPageSix)
      pk = args[1]
      case args[2]
      when 4 then args[3] = eviv_text(pk)
      when 5 then args[3] = PokeAccess::Summary.moves_text(pk)
      end
      args
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Summary, :speak_page, :tag => "summary_six_pages") do |_mod, original, args|
  PokeAccess::SummarySixPages.repage(args)
  original.call
end

# The ribbons page, on arrival, on another Pokemon and back from the ribbon grid.
PokeAccess::Hooks.after_hook("PokemonSummaryScene", :drawPageSix, :optional => true) do |s, _r, args|
  pk = PokeAccess::SummaryGen6.subject(s, args)
  PokeAccess::Summary.speak_page(s, pk, 6, PokeAccess::SummaryGen6.ribbons_text(pk))
end
