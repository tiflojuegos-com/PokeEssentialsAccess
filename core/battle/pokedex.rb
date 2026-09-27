module PokeAccess
  # Shared numeric formatting for the pokedex readers. A capture's dex page needs no battle-side hook: the dex
  # scene's readers already say it.
  module Pokedex
    # Formats a tenth-units integer (decimetres, hectograms) as one decimal, with the language's decimal_sep.
    def self.fmt_dec(v)
      fmt_float(v / 10.0)
    rescue StandardError
      v.to_s
    end

    # One decimal place with the language's separator (see fmt_dec), for values already in real units.
    def self.fmt_float(f)
      s = format("%.1f", f.to_f)
      (PokeAccess::I18n.t(:decimal_sep).to_s == ",") ? s.gsub(".", ",") : s
    rescue StandardError
      f.to_s
    end

  end
end
