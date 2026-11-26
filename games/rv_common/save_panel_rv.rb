module PokeAccess
  # The save panel of the engine Reborn and Rejuvenation share: its Pokedex field paints the owned and the seen counts
  # as "owned/seen", said with what each one counts.
  module SaveRV
    DEX = /(Pok.{1,2}dex,\s*)(\d[\d,]*\d|\d)\/(\d[\d,]*\d|\d)/

    # The panel's line with its Pokedex counts worded.
    def self.worded(text)
      text.to_s.sub(DEX) { "#{$1}#{PokeAccess::I18n.t(:rv_dex_counts, :owned => $2, :seen => $3)}" }
    end

    # Reads the panel's window as core does, its counts worded; a panel without that window is left to core.
    def self.bind
      PokeAccess::Hooks.override("PokeAccess::SavePanel", :say, :tag => "rv_common") do |_mod, original, args|
        win = PokeAccess.sprite(args[0], "locwindow")
        next original.call unless win
        t = PokeAccess::SaveRV.worded(PokeAccess.clean_fields((win.text rescue nil)))
        PokeAccess.speak(t, false) unless t.empty?
      end
    end
  end
end

PokeAccess::SaveRV.bind if PokeAccess::DataRV.engine?
