module PokeAccess
  # v22 options screen (UI::OptionsVisualsList, vanilla v22, whose entries are option hashes): the focused option's
  # name and value on navigation and on left/right, deduped on [index, value], the value by option[:type] as
  # draw_option_values paints it.
  module OptionsV22
    # The spoken value of the focused option, by type, or nil when there is none to read.
    def self.value_text(win, i, o)
      type = (o[:type] rescue nil)
      params = (o[:parameters] rescue nil)
      if type == :control
        vals = PokeAccess.ivar(win, :@values)
        v = (vals.is_a?(Array) ? vals[i] : nil)
        return nil unless v.is_a?(Array)
        return v.map { |k| k ? (Input.input_name(k) rescue k.to_s) : "---" }.join(", ")
      end
      if type == :number_type
        painted = (PokeAccess.ivar(win, :@access_painted) || {})[i]
        return painted if painted
      end
      cur = (o[:get_proc].call rescue nil)
      return nil if cur.nil? || cur.is_a?(Array) || cur.is_a?(Hash)
      if type == :toggle
        return params[cur].to_s if params.is_a?(Array) && params.length >= 2 && params[cur]
        return PokeAccess::I18n.t(cur == 0 ? :val_on : :val_off)
      end
      if params.is_a?(Array) && cur.is_a?(Integer) && cur >= 0 && cur < params.length && params[cur].is_a?(String)
        return params[cur].to_s
      end
      cur.to_s
    rescue StandardError
      nil
    end

    # "name: value" for the focused option, or just the name when there is no simple value.
    def self.line(win)
      opts = PokeAccess.ivar(win, :@options)
      i = (win.index rescue nil)
      return nil unless opts.is_a?(Array) && i && i >= 0 && opts[i]
      name = (opts[i][:name] rescue nil).to_s
      return nil if name.empty?
      v = value_text(win, i, opts[i])
      v ? "#{PokeAccess.clean(name)}: #{PokeAccess.clean(v.to_s)}" : PokeAccess.clean(name)
    rescue StandardError
      nil
    end

    # Speaks the focused option when its index or value changes.
    def self.poll(win)
      opts = PokeAccess.ivar(win, :@options)
      i = (win.index rescue nil)
      o = (opts.is_a?(Array) && i && i >= 0) ? opts[i] : nil
      key = [i, (o ? value_text(win, i, o) : nil)]
      return unless PokeAccess::Cursor.changed?(win, :opt_val, key)
      t = line(win)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end
  end
end

# A :number_type value is painted as words ("Type 3/8") while the option holds a bare index: the paint is kept
# per row, for the options list it was painted from, and read instead.
PokeAccess::Hooks.around_hook("UI::OptionsVisualsList", :draw_option_values, :optional => true) do |win, nxt, args|
  opts = PokeAccess.ivar(win, :@options)
  o = opts.is_a?(Array) ? opts[args[0].to_i] : nil
  if o.is_a?(Hash) && o[:type] == :number_type
    ret = nil
    rows = PokeAccess::PaintCapture.shadow_sample { ret = nxt.call }
    painted = PokeAccess.ivar(win, :@access_painted_for) == opts.object_id ? PokeAccess.ivar(win, :@access_painted) : nil
    painted ||= {}
    painted[args[0].to_i] = PokeAccess.clean(rows.join(" ")) unless rows.empty?
    win.instance_variable_set(:@access_painted, painted)
    win.instance_variable_set(:@access_painted_for, opts.object_id)
    ret
  else
    nxt.call
  end
end if PokeAccess::Engine.has?("UI::OptionsVisualsList")

# Polled per frame on the options list, only where the class exists; a frame hook, since the list repaints inside
# its update and a guarded hook would skip the value capture above.
PokeAccess::Hooks.frame_hook("UI::OptionsVisualsList", :update) do |win, _a|
  PokeAccess::OptionsV22.poll(win)
end if PokeAccess::Engine.has?("UI::OptionsVisualsList")

# The page tabs (index -1): the active page's name from the game's page handler, with its place among the pages.
PokeAccess::Hooks.after_hook("UI::OptionsVisuals", :draw_page_tabs, :optional => true) do |vis, _r, args|
  pages = args[0]; active = args[2]
  if pages.is_a?(Array) && active
    PokeAccess::Cursor.announce(vis, :opt_tab, active, true) do
      h = (PageHandlers.call(PokeAccess.ivar(vis, :@menu), active) rescue nil)
      nm = (h.is_a?(Hash) ? (h[:name].respond_to?(:call) ? h[:name].call : h[:name]) : nil).to_s
      pos = (pages.index(active) rescue nil)
      if nm.empty?
        nil
      elsif pos
        PokeAccess::Verbosity.list_entry(PokeAccess::I18n.t(:opt_tab_name, :name => PokeAccess.clean(nm)), pos + 1,
                                         pages.length)
      else
        PokeAccess.clean(nm)
      end
    end
  end
end

# The option's description in the speech box, stored for the info key on every selection change.
PokeAccess::Hooks.after_hook("UI::OptionsVisuals", :refresh_selected_option, :optional => true) do |vis, _r, _a|
  box = (PokeAccess.ivar(vis, :@sprites) || {})[:speech_box]
  t = (box.text rescue nil)
  PokeAccess::Info.set_info(:text, (t.nil? || t.to_s.strip.empty?) ? nil : PokeAccess::KeyHints.localize(PokeAccess.clean(t.to_s), nil, true))
end
