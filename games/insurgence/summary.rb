module PokeAccess
  # Insurgence's summary has six pages (PokemonSummaryScene, 099_PokemonSummary.rb): after the stats, drawPageFour paints
  # each stat's EV and IV, drawPageFive the moves and drawPageSix the ribbons, one page later than the stock gen-6
  # summary the core reads.
  module InsurgenceSummary
    # The EV & IV page: its title and each stat's EV and IV in the stock order.
    def self.eviv_text(pk)
      "#{PokeAccess::I18n.t(:ins_sum_eviv)}. #{PokeAccess::Summary.eviv_rows(pk).join('. ')}"
    rescue StandardError
      nil
    end

    # Puts each core page read on the page Insurgence draws there: the core's page 4 (drawPageFour) is the EV & IV
    # page, its page 5 (drawPageFive) the moves.
    # param args Summary.speak_page's arguments (scene, pokemon, page, text), changed in place
    def self.repage(args)
      pk = args[1]
      case args[2]
      when 4 then args[3] = eviv_text(pk)
      when 5 then args[3] = PokeAccess::Summary.moves_text(pk)
      end
      args
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::Summary", :speak_page) do |_mod, original, args|
    PokeAccess::InsurgenceSummary.repage(args)
    original.call
  end

  after("PokemonSummaryScene", :drawPageSix) do |s, _r, args|
    pk = PokeAccess::SummaryGen6.subject(s, args)
    PokeAccess::Summary.speak_page(s, pk, 6, PokeAccess::SummaryGen6.ribbons_text(pk))
  end
end
