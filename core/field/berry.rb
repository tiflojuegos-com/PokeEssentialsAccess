module PokeAccess
  # Berry-plant state for the locator's target name. The growth data sits on the plant event's variable, a
  # BerryPlantData (modern) or a plain array (gen-6); stages 1 planted .. 5+ ready, moisture 0 dry/1 damp/2 wet.
  module Berry
    STAGE = { 1 => :berry_planted, 2 => :berry_sprouted, 3 => :berry_taller,
              4 => :berry_flowering, 5 => :berry_ready }
    MOIST = { 0 => :berry_dry, 1 => :berry_damp, 2 => :berry_wet }

    # The suffix appended to a berry plant's name (", stage, berry, moisture"), or "" when unplanted or unreadable.
    def self.state_suffix(ev)
      stage, item, moist, newmech = read((ev.variable rescue nil))
      return "" if stage.nil? || stage <= 0
      parts = [PokeAccess::I18n.t(STAGE[stage > 5 ? 5 : stage] || :berry_planted)]
      bn = berry_name(item); parts.push(bn) if bn
      parts.push(PokeAccess::I18n.t(MOIST[moist])) if newmech && moist && MOIST[moist]
      ", " + parts.join(", ")
    rescue StandardError
      ""
    end

    # Normalizes the two storage shapes to [stage, berry_id, moisture_stage, new_mechanics?]; nil stage
    # when the slot is unplanted or unrecognised.
    def self.read(d)
      return [nil, nil, nil, false] if d.nil?
      if d.respond_to?(:growth_stage)
        return [nil, nil, nil, false] unless (d.planted? rescue false)
        nm = (d.new_mechanics rescue false)
        [d.growth_stage.to_i, (d.berry_id rescue nil), (nm ? (d.moisture_stage rescue nil) : nil), nm]
      elsif d.is_a?(Array) && d[0]
        nm = d.length > 6
        moist = nm ? (d[4].to_i > 50 ? 2 : (d[4].to_i > 0 ? 1 : 0)) : nil
        [d[0].to_i, d[1], moist, nm]
      else
        [nil, nil, nil, false]
      end
    rescue StandardError
      [nil, nil, nil, false]
    end

    # The localized berry item name, via the engine's data provider.
    def self.berry_name(item)
      return nil if item.nil? || item == 0
      n = PokeAccess::Data.item_name(item)
      (n && !n.to_s.empty?) ? n : nil
    rescue StandardError
      nil
    end
  end
end
