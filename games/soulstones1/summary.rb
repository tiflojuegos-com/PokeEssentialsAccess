module PokeAccess
  # Soulstones' five-page summary (PokemonSummary_Scene, 0150_PScreen_Summary.rb): after the skills page, drawPageFour
  # paints each stat's EVs and IVs with the ability, and drawPageFive the moves; it has no ribbons page. The core reads
  # its page 4 as the moves and its page 5 as the ribbons.
  module Soulstones1Summary
    # The ability the EVs/IVs page names under the rows, with the description it writes below the name, as the
    # skills page line says it.
    def self.ability_text(pk)
      PokeAccess::Summary.ability_line(pk)
    rescue StandardError
      nil
    end

    # The EVs/IVs page: its title, each stat's EV and IV in the stock order, then the ability.
    def self.eviv_text(pk)
      rows = PokeAccess::Summary.eviv_rows(pk)
      ab = ability_text(pk)
      rows.push(ab) if ab
      "#{PokeAccess::I18n.t(:ss1_sum_eviv)}. #{rows.join('. ')}"
    rescue StandardError
      nil
    end

    # Puts each core page read on the page Soulstones draws there: the core's page 4 (drawPageFour) is the EVs/IVs
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

PokeAccess::Game.define("soulstones1") do
  override("PokeAccess::Summary", :speak_page) do |_mod, original, args|
    PokeAccess::Soulstones1Summary.repage(args)
    original.call
  end
end
