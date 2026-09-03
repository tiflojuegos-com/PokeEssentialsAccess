module PokeAccess
  # v22 options screen (UI::OptionsVisualsList, a Window_DrawableCommand whose entries are option HASHES,
  # not strings, so the generic reader gets nothing). The class is VANILLA v22, declared in
  # Data/Scripts/016_UI/015_UI_Options.rb of the stock engine and not in La Base de Sky's: it is a core
  # reader, not a plugins/ one, or every other v22 game would lose it.
  #
  # Reads the focused option's name and value, on BOTH navigation (index change) and value edit (left/right
  # on the same option), by deduping on [index, value]. The value is formatted by option[:type], mirroring
  # draw_option_values: choice lists (:array/:array_one/:arrow_option) read the chosen label, :toggle reads
  # its label or ON/OFF, sliders and numbers read the number, :control reads the bound keys.
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

    # Reads the focused option when its index OR its value changes, so left/right value edits are spoken,
    # not only navigation between options.
    def self.poll(win)
      opts = PokeAccess.ivar(win, :@options)
      i = (win.index rescue nil)
      o = (opts.is_a?(Array) && i && i >= 0) ? opts[i] : nil
      key = [i, (o ? value_text(win, i, o) : nil)]
      return unless PokeAccess::Cursor.changed?(win, :opt_val, key)
      t = line(win)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    rescue StandardError
      nil
    end
  end
end

# Per-frame on the options list (index navigation AND left/right value edits both keep redrawing it).
# Registered only where the class exists, so the "::"-qualified name can't break gen-6's const handling.
PokeAccess::Hooks.after_hook("UI::OptionsVisualsList", :update) do |win, _r, _a|
  PokeAccess::OptionsV22.poll(win)
end if PokeAccess::Engine.has?("UI::OptionsVisualsList")

# The tab row: index -1 moves BETWEEN pages, and the poll above only reads options. The hook's own
# arguments carry the whole state (visible pages, scroll, the active page id); the page NAME comes from
# the game's page handler, so it says whatever this build says.
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
        PokeAccess::I18n.t(:opt_tab, :name => PokeAccess.clean(nm), :n => pos + 1, :tot => pages.length)
      else
        PokeAccess.clean(nm)
      end
    end
  end
end

# The per-option description the screen writes into its speech box on every selection change; stored on
# the info key, matching how option help reads everywhere else in the mod.
PokeAccess::Hooks.after_hook("UI::OptionsVisuals", :refresh_selected_option, :optional => true) do |vis, _r, _a|
  box = (PokeAccess.ivar(vis, :@sprites) || {})[:speech_box]
  t = (box.text rescue nil)
  PokeAccess::Info.set_info(:text, (t.nil? || t.to_s.strip.empty?) ? nil : PokeAccess.clean(t.to_s))
end
