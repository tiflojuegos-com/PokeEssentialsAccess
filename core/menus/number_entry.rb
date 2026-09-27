module PokeAccess
  # Number choosers: a quantity text window (starting with "x" or v22's "×", which keeps it apart from dialogue) is
  # read on change with its price, and the digit-column entry by column.
  module NumberEntry
    # LAYOUT: the alignment and break tags, turned into spaces. LINE: a quantity line, "x" or "×" and the amount,
    # then an optional price (with separators; "$" before or a unit word after, as the BP shop's "x1<r>100 PB").
    LAYOUT = /<\s*\/?\s*(?:r|br)\s*\/?\s*>/i
    LINE = /\A(?:x|\303\227)\s*(\d+)(?:(?:\s*\$\s*|\s+)([\d.,]+)(?:\s*([A-Za-z]{1,3}))?)?\s*\z/

    # Drops the module-wide last amount, so reopening a prompt on the same amount speaks again.
    def self.forget; @last = nil; end

    # A line the prompt shows beside its amount (the mart's count in the bag), said once, queued, after the next
    # amount; nil drops it.
    def self.aside=(t); @aside = t; end

    # Speaks a quantity line's amount and price, deduped on [window, text] (every prompt builds a fresh window), then
    # the aside the prompt left; the window itself is held, since 1.8.7 recycles object ids.
    def self.on_text(win, raw)
      t = PokeAccess.clean(raw.to_s.gsub(LAYOUT, " "))
      return unless t =~ LINE
      amount = $1.to_i; price = $2; unit = $3
      price = price.gsub(/[.,]/, "") if price
      return if @last && @last[0].equal?(win) && @last[1] == t
      @last = [win, t]
      msg = amount.to_s
      if price
        msg += ", " + (unit ? "#{price.to_i} #{unit}" :
                              PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price.to_i))
      end
      PokeAccess.speak(msg, true)
      return unless @aside
      PokeAccess.speak(@aside, false)
      @aside = nil
    rescue StandardError
      nil
    end

    # Place value (power of ten, 0 = units) => its spoken column name.
    PLACES = [:ne_units, :ne_tens, :ne_hundreds, :ne_thousands, :ne_tenk, :ne_hundredk, :ne_millions]

    # The spoken name of a digit column by its power of ten.
    def self.place_name(pw)
      PLACES[pw] ? PokeAccess::I18n.t(PLACES[pw]) : PokeAccess::I18n.t(:ne_place, :n => (10 ** pw))
    end

    # Reads a digit-column number entry (Window_InputNumberPokemon): the total on open, queued behind its question,
    # the column and its digit ("hundreds: 0") when the cursor moves, the new total when the number changes.
    def self.on_digit_window(win)
      idx = win.instance_variable_get(:@index)
      num = (win.number rescue nil)
      return if idx.nil? || num.nil?
      li = win.instance_variable_get(:@access_lastidx)
      ln = win.instance_variable_get(:@access_lastnum)
      win.instance_variable_set(:@access_lastidx, idx)
      win.instance_variable_set(:@access_lastnum, num)
      if li.nil?
        PokeAccess.speak(num.to_s, false)
      elsif idx != li
        PokeAccess.speak(digit_column_text(win), true)
      elsif num != ln
        PokeAccess.speak(num.to_s, true)
      end
    rescue StandardError
      nil
    end

    # The spoken "<column>: <digit>" for the cursor's slot, or the sign slot ("sign: plus/minus") when
    # the entry is signed and the cursor sits on it.
    def self.digit_column_text(win)
      dmax = win.instance_variable_get(:@digits_max).to_i
      sign = (win.sign rescue false)
      idx  = win.instance_variable_get(:@index).to_i
      digits = dmax + (sign ? 1 : 0)
      if sign && idx == 0
        neg = win.instance_variable_get(:@negative)
        return "#{PokeAccess::I18n.t(:ne_sign)}: #{PokeAccess::I18n.t(neg ? :ne_minus : :ne_plus)}"
      end
      pw = digits - 1 - idx
      digit = ((win.number rescue 0).abs / (10 ** pw)) % 10
      "#{place_name(pw)}: #{digit}"
    end
  end
end

["Window_UnformattedTextPokemon", "Window_AdvancedTextPokemon"].each do |cn|
  PokeAccess::Hooks.after_hook(cn, :text=) do |w, _r, args|
    PokeAccess::NumberEntry.on_text(w, args[0])
  end
end

# The digit-column quantity selector draws its digits to a bitmap: read while active.
PokeAccess::Hooks.after_hook("Window_InputNumberPokemon", :update) do |win, _r, _a|
  PokeAccess::NumberEntry.on_digit_window(win) if (win.active rescue false)
end

# A new selector starts a new prompt: forget the amount spoken last.
PokeAccess::Hooks.after_hook("Window_InputNumberPokemon", :initialize) do |_w, _r, _a|
  PokeAccess::NumberEntry.forget
end
