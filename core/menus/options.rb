module PokeAccess
  # Game options screen. The generic command hook reads "name: value" when the index changes, but
  # changing a value with left/right keeps the same index, so this announces the new value on its own.
  module Options
    # The floor and ceiling of a numeric option, whichever names the era gives them: gen-6 and v19 call them
    # optstart/optend, modern Essentials lowest_value/highest_value. nil for an option that is not numeric.
    def self.bounds(o)
      return [o.optstart, (o.respond_to?(:optend) ? o.optend : nil)] if o.respond_to?(:optstart)
      return [o.lowest_value, (o.respond_to?(:highest_value) ? o.highest_value : nil)] if o.respond_to?(:lowest_value)
      nil
    rescue StandardError
      nil
    end

    # The SliderOption class, resolved once. value_of runs from an after-hook on the options window's own
    # update, so a constant lookup here would be a split, an inject and a const_get sixty times a second
    # for as long as the player is on the screen. false is the "asked and absent" marker, so a game without
    # the class is not asked again either.
    def self.slider_class
      return @slider_class unless @slider_class.nil?
      @slider_class = (PokeAccess.const_at("SliderOption") || false)
    end

    # True for a slider. NumberOption and SliderOption are SIBLING classes in all three eras (the engine's
    # own drawItem tests them one after the other), and they paint differently, so the class is the only
    # honest way to tell them apart -- both answer to the same floor/ceiling accessors.
    def self.slider?(o)
      k = slider_class
      k ? o.is_a?(k) : false
    rescue StandardError
      false
    end

    # The spoken text for an option's current value, said as the screen paints it. An enum reads its label.
    # A NumberOption paints "Type value/total" and so reads "value/total". A SLIDER paints only the value
    # over its bar, and reading it as a fraction invented a total the player cannot see -- the music volume
    # of every v19-era game came out as "50/101" for a screen showing "50", and Fire Ash's enemy buffs as
    # "3/7" for a bar that goes to 6. Both kinds add the cursor offset to their floor, so an option with a
    # non-zero minimum (a 1..N text frame) reads its real value and not the raw internal index.
    def self.value_of(o, v)
      return (o.values[v] rescue v).to_s if o.respond_to?(:values)
      b = bounds(o)
      return v.to_s if b.nil?
      shown = b[0] + v
      return shown.to_s if b[1].nil? || slider?(o)
      "#{shown}/#{b[1] - b[0] + 1}"
    end

    # The spoken value of the focused option, or nil for the exit row / a valueless option.
    def self.value_label(win, idx)
      opts = win.instance_variable_get(:@options)
      return nil if opts.nil? || idx.nil? || idx >= opts.length
      value_of(opts[idx], win[idx])
    end
  end
end

# Announce the new value when it changes on the focused option (left/right keeps the index, so the
# generic command hook stays silent).
PokeAccess::Hooks.after_hook("Window_PokemonOption", :update) do |win, _r, _a|
  if win.active
    idx = win.instance_variable_get(:@index)
    val = PokeAccess::Options.value_label(win, idx)
    if idx == win.instance_variable_get(:@access_oidx) &&
       val && val != win.instance_variable_get(:@access_oval)
      PokeAccess.speak(val, true)
    end
    win.instance_variable_set(:@access_oidx, idx)
    win.instance_variable_set(:@access_oval, val)
  end
end
