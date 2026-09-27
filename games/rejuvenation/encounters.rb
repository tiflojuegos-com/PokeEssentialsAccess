module PokeAccess
  # The encounter list of Rejuvenation's nest page (Window_EncounterDetails, X on the page): each row an icon for how
  # the species is met, its chance and the map, "<icon=Encounters/OldRod> 25% Route 1". The icon is worded here, as
  # the game's own ttsEncTypeIconsInText names it; an underwater map adds "Underwater" to the icon's name.
  module RejuvEncounters
    # Encounter icon names => the i18n key of their method.
    METHODS = { "Land" => :rj_enc_land, "LandMorning" => :rj_enc_landmorning, "LandDay" => :rj_enc_landday,
                "LandNight" => :rj_enc_landnight, "Cave" => :rj_enc_cave, "RockSmash" => :rj_enc_rocksmash,
                "Headbutt" => :rj_enc_headbutt, "OldRod" => :rj_enc_oldrod, "GoodRod" => :rj_enc_goodrod,
                "SuperRod" => :rj_enc_superrod, "Water" => :rj_enc_water, "Lava" => :rj_enc_lava }

    ICON = /<icon=Encounters\/(\w+)>/
    FIGURE_SPACE = [0x2007].pack("U")

    # The method an icon stands for, with "underwater" after it for an underwater map's; nil for one it has no word for.
    def self.method_word(icon)
      base = icon.sub(/Underwater\z/, "")
      key = METHODS[base]
      return nil if key.nil?
      word = PokeAccess::I18n.t(key)
      base == icon ? word : "#{word} #{PokeAccess::I18n.t(:rj_enc_underwater)}"
    end

    # A row as its method, its chance and its map.
    def self.row(text)
      t = text.to_s
      icon = t[ICON, 1]
      rest = PokeAccess.clean(t.sub(ICON, "").gsub(FIGURE_SPACE, " "))
      rest = "#{$1}, #{$2}" if rest =~ /\A(\d+%)\s+(.+)\z/
      word = icon ? method_word(icon) : nil
      word ? "#{word}, #{rest}" : rest
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  screen_reader("Window_EncounterDetails") do |win, i|
    cmds = win.instance_variable_get(:@commands)
    (cmds.is_a?(Array) && cmds[i]) ? PokeAccess::RejuvEncounters.row(cmds[i]) : nil
  end
end
