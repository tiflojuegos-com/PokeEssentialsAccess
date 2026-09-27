module PokeAccess
  # Game options screen: rows as painted, and the new value when left/right changes it under the same index.
  module Options
    # A numeric option's [floor, ceiling]: optstart/optend (gen-6, v19) or lowest_value/highest_value; nil otherwise.
    def self.bounds(o)
      return [o.optstart, (o.respond_to?(:optend) ? o.optend : nil)] if o.respond_to?(:optstart)
      return [o.lowest_value, (o.respond_to?(:highest_value) ? o.highest_value : nil)] if o.respond_to?(:lowest_value)
      nil
    rescue StandardError
      nil
    end

    # The SliderOption class, resolved once (value_of runs every frame); false when absent, so it is not asked again.
    def self.slider_class
      return @slider_class unless @slider_class.nil?
      @slider_class = (PokeAccess.const_at("SliderOption") || false)
    end

    # True for a slider: told by class, since NumberOption and SliderOption are siblings with the same accessors.
    def self.slider?(o)
      k = slider_class
      k ? o.is_a?(k) : false
    rescue StandardError
      false
    end

    # An option's value composed from the option: an enum's label, a number option's "value/total" (the row's paint,
    # its word included, is painted_value), a slider's value alone; a value kept as an offset from the floor is
    # shifted back, so a 1..N option reads its real value.
    def self.value_of(o, v)
      return (o.values[v] rescue v).to_s if o.respond_to?(:values)
      b = bounds(o)
      return v.to_s if b.nil?
      shown = stores_offset?(o, b) ? b[0] + v : v
      return format("%.1f", shown) if fractional?(o)
      return shown.to_s if b[1].nil? || slider?(o)
      "#{shown}/#{b[1] - b[0] + 1}"
    end

    # Whether the option steps by less than one, like the rv engine's Turbo Speed (0.1), whose window paints the value
    # with one decimal and no position out of a count.
    def self.fractional?(o)
      step = (o.optinc rescue nil)
      step.is_a?(Numeric) && step < 1
    end

    # Whether the option keeps its value as an offset from its floor, as every stock option does. A slider whose own
    # next() tops out at the ceiling itself, rather than at ceiling minus floor, keeps the value it paints.
    # param b the option's [floor, ceiling] (bounds)
    def self.stores_offset?(o, b)
      return true unless slider?(o) && b[1] && b[0] != 0
      (o.next(b[1]) rescue nil) != b[1]
    end

    # The spoken value of the focused option, or nil for the exit row / a valueless option.
    def self.value_label(win, idx)
      opts = win.instance_variable_get(:@options)
      return nil if opts.nil? || idx.nil? || idx >= opts.length
      return nil if button?(opts[idx]) || opts[idx].is_a?(String)
      painted_value(win, idx, win[idx]) || value_of(opts[idx], win[idx])
    end

    # True for a ButtonOption row, which opens a submenu and is painted by name alone.
    def self.button?(o)
      o.class.name.to_s =~ /(\A|::)ButtonOption\z/ ? true : false
    end

    # The option row as the screen paints it: a bare string (a list's section heading or closing row) as its text, a
    # button by its name, any other with its value, the painted one when the caller has it (painted_value).
    def self.row(o, v, painted = nil)
      return PokeAccess.clean(o) if o.is_a?(String)
      button?(o) ? o.name.to_s : "#{o.name}: #{painted || value_of(o, v)}"
    end

    # True for a row that paints its value as text beside its name: not a list of labels, a slider's bar or a button.
    def self.number_row?(o)
      !o.respond_to?(:values) && !button?(o) && !slider?(o) && !bounds(o).nil?
    end

    # Keeps what a number row painted after its name ("Type 3/40", "Tipo 3/40", or the number alone on some
    # engines) with the value the row held, for painted_value.
    # param strings the row's pbDrawShadowText strings in paint order, its name first
    def self.keep_painted(win, idx, strings)
      return unless strings.is_a?(Array) && strings.length >= 2
      t = PokeAccess.clean(strings.last.to_s)
      return if t.empty?
      kept = PokeAccess.ivar(win, :@access_painted)
      kept = win.instance_variable_set(:@access_painted, {}) unless kept.is_a?(Hash)
      kept[idx] = [win[idx], t]
    end

    # A number row's value as it was last painted, while the row still holds the value it was painted for; nil
    # otherwise, and value_of composes it.
    def self.painted_value(win, idx, v)
      kept = PokeAccess.ivar(win, :@access_painted)
      pair = kept.is_a?(Hash) ? kept[idx] : nil
      pair && pair[0] == v ? pair[1] : nil
    end

    # The exit row's word as painted (kept by the drawItem hook below); nil while unpainted, so the reader asks
    # again, and the mod's own word from the third miss.
    def self.exit_label(win)
      t = PokeAccess.clean(PokeAccess.ivar(win, :@access_exit_label).to_s)
      return t unless t.empty?
      misses = PokeAccess.ivar(win, :@access_exit_misses).to_i + 1
      win.instance_variable_set(:@access_exit_misses, misses)
      misses < 3 ? nil : PokeAccess::I18n.t(:sm_exit)
    end

    # Marks an options screen's end, so the screen under a submenu resets its row dedup and says the row again.
    def self.returned!; @returned = true; end

    def self.consume_return(win)
      return unless @returned
      @returned = false
      PokeAccess::Cursor.reset(win, :cmd_focus)
    end
  end
end

# Speaks the focused option's new value on left/right. A container: a button row opens its whole submenu inside
# this update.
PokeAccess::Hooks.after_hook("Window_PokemonOption", :update, :hook_container => true) do |win, _r, _a|
  PokeAccess::Options.consume_return(win)
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

# The last row's word, and a number row's value, kept as they are painted.
PokeAccess::Hooks.around_hook("Window_PokemonOption", :drawItem, :optional => true) do |win, nxt, args|
  opts = PokeAccess.ivar(win, :@options)
  idx = args[0]
  if opts.is_a?(Array) && idx == opts.length
    ret = nil
    word = PokeAccess::PaintCapture.shadow_sample { ret = nxt.call }.first
    win.instance_variable_set(:@access_exit_label, word) if word
    ret
  elsif opts.is_a?(Array) && idx.is_a?(Integer) && opts[idx] && PokeAccess::Options.number_row?(opts[idx])
    ret = nil
    strings = PokeAccess::PaintCapture.shadow_sample { ret = nxt.call }
    PokeAccess::Options.keep_painted(win, idx, strings)
    ret
  else
    nxt.call
  end
end

PokeAccess::Engine.scene_classes("PokemonOption_Scene", "PokemonOptionScene").each do |cn|
  PokeAccess::Hooks.after_hook(cn, :pbEndScene, :optional => true, :hook_container => true) do |_s, _r, _a|
    PokeAccess::Options.returned!
  end
end
