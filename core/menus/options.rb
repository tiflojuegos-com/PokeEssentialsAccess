module PokeAccess
  # Game options screen. The generic command hook reads "name: value" when the index changes, but
  # changing a value with left/right keeps the same index, so this announces the new value on its own.
  module Options
    # The spoken text for an option's current value: an enum's label, a numeric option's offset value, or
    # the raw value. Shared with the Window_PokemonOption command-window extractor (menus.rb) so the focused
    # value and the live left/right change read identically. Numeric options name their floor differently by
    # era: gen-6 NumberOption uses optstart, modern (v21.1) NumberOption/SliderOption uses lowest_value -- both
    # add the cursor offset to the floor to get the shown value, so an option with a non-zero minimum (e.g. a
    # 1..N text frame) reads its real value, not the raw internal index.
    def self.value_of(o, v)
      if o.respond_to?(:values)
        (o.values[v] rescue v).to_s
      elsif o.respond_to?(:optstart)
        tot = (o.respond_to?(:optend) ? (o.optend - o.optstart + 1) : nil)
        tot ? "#{o.optstart + v}/#{tot}" : (o.optstart + v).to_s
      elsif o.respond_to?(:lowest_value)
        (o.lowest_value + v).to_s
      else
        v.to_s
      end
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
