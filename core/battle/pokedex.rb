module PokeAccess
  # Shared numeric formatting for the pokedex readers. The dex page a battle opens on a new capture needs
  # no hook here: pbShowPokedex lands in a scene a reader already covers on every game (drawPage on the
  # modern family, pbChangeToDexEntry on gen-6), and a pre-read from the battle side spoke the same entry
  # twice with the first copy cut off.
  module Pokedex
    # Formats a tenth-units integer (decimetres/hectograms) as one decimal, with the separator the active
    # language declares (lang key decimal_sep: comma in Spanish, point in English) rather than one fixed per
    # engine. Shared by every dex height/weight reader.
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
