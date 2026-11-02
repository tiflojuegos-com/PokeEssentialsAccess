# What the summary of Clara Dragon's games adds to the stock pages: the friendship hearts on the data sheet, the EVs
# beside the stats, the key hint it paints with its own drawFormattedTextEx2, and the information page the action key
# opens over the stats (drawInfoPage, a modal loop): the ability with its description and the Hidden Power's type icon.
module PokeAccess
  module ClaraSummary
    # The friendship the sheet paints as a row of hearts, one per this much happiness.
    HEARTS_STEP = 44
    HEARTS = 5

    # The hearts of a Pokemon's sheet as a sentence; nil for an egg or a friendship that cannot be read.
    def self.friendship(pk)
      n = (pk.happiness rescue nil)
      return nil if n.nil? || PokeAccess::Summary.egg?(pk)
      PokeAccess::I18n.t(:mui_happiness_value, :n => n.to_i / HEARTS_STEP, :max => HEARTS)
    end

    # The EV column the stats page paints, in its rows' order.
    def self.evs(pk)
      list = PokeAccess::Summary::STAT_ROWS.map { |i, key| "#{PokeAccess::I18n.t(key)} #{pk.ev[i].to_i}" }
      PokeAccess::I18n.t(:clara_evs, :list => list.join(", "))
    end

    # The Hidden Power type the information page draws as an icon; nil when it cannot be worked out.
    def self.hidden_power(pk)
      name = PokeAccess::Data.type_name(pbHiddenPower(pk.iv)[0])
      name.to_s.empty? ? nil : PokeAccess::I18n.t(:sm_hidden_power, :t => name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The information page as it opens, cutting in; the stats page it returns to is said again.
    def self.info_page(scene, pk)
      PokeAccess::Summary.forget_page(scene)
      text = PokeAccess.sentences([PokeAccess::Summary.ability_line(pk), hidden_power(pk)])
      PokeAccess.speak(text, true, :menu) unless text.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("clara_common") do
  override("PokeAccess::Info", :summary_text) do |_mod, original, args|
    text = original.call
    hearts = text && PokeAccess::ClaraSummary.friendship(args[0])
    hearts ? "#{text} #{hearts}" : text
  end
  override("PokeAccess::SummaryGen6", :stats_extras) do |_mod, original, args|
    original.call + [PokeAccess::ClaraSummary.evs(args[0])]
  end
  kernel("drawFormattedTextEx2") { |args, _r| PokeAccess::PaintCapture.note(args[5], :formatted, args[1], args[2]) }
  before("PokemonSummaryScene", :drawInfoPage, :optional => true) do |scene, args|
    PokeAccess::ClaraSummary.info_page(scene, args[0])
  end
end
