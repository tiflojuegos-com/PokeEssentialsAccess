# The PC panel of Edas (0150_PScreen_Storage*) draws an IV star for each stat, with the thresholds of its own "IV Star
# Gauge": empty at 0, low below 30, high at 30, perfect at 31; said among the full details, in the panel's order.
module PokeAccess
  module EdasStorage
    # The star a value earns.
    def self.star(iv)
      return :iv_star_perfect if iv > 30
      return :iv_star_high if iv > 29
      iv > 0 ? :iv_star_low : :iv_star_empty
    end

    # Every stat with its star, as one sentence.
    def self.stars(pk)
      rows = PokeAccess::Summary::STAT_ROWS.map do |i, key|
        "#{PokeAccess::I18n.t(key)} #{PokeAccess::I18n.t(star((pk.iv[i] rescue 0).to_i))}"
      end
      PokeAccess::I18n.t(:iv_stars, :list => rows.join(", "))
    end
  end
end

PokeAccess::Game.define("edas") do
  override("PokeAccess::Party", :pc_details) do |_mod, original, args|
    original.call + [[PokeAccess::EdasStorage.stars(args[0]), :full]]
  end
end
