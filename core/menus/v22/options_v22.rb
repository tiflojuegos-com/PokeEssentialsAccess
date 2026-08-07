module PokeAccess
  # v22 options screen (UI::OptionsVisualsList, a Window_DrawableCommand whose entries are option HASHES,
  # not strings, so the generic reader gets nothing). The class is VANILLA v22, declared in
  # Data/Scripts/016_UI/015_UI_Options.rb of the stock engine and not in La Base de Sky's: filing this
  # reader under skyflyer/ would lose it for every other v22 game.
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
      return if key == win.instance_variable_get(:@access_opt_key)
      win.instance_variable_set(:@access_opt_key, key)
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
