# The IV star the stats page draws beside each stat (pbDisplayIVStars): empty up to 6, low to 16, high to 25,
# perfect above; said in the page's order, speed last.
module PokeAccess
  module IVStars
    # The star a value earns, by the page's own thresholds.
    def self.star(iv)
      return :iv_star_perfect if iv > 25
      return :iv_star_high if iv > 16
      return :iv_star_low if iv > 6
      :iv_star_empty
    end

    # Every stat with its star, as one sentence.
    def self.text(pk)
      rows = PokeAccess::Summary::STAT_ROWS.map do |i, k|
        "#{PokeAccess::I18n.t(k)} #{PokeAccess::I18n.t(star((pk.iv[i] rescue 0).to_i))}"
      end
      PokeAccess::I18n.t(:iv_stars, :list => rows.join(", "))
    end
  end
end

PokeAccess::Game.define("lostie_common") do
  override("PokeAccess::SummaryGen6", :stats_extras) do |_mod, original, args|
    original.call + [PokeAccess::IVStars.text(args[0])]
  end
end
