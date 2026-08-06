module PokeAccess
  # Number choosers (buy/sell/toss quantity). Both show the amount in a window whose text starts with the
  # quantity marker -- the ASCII "x" ("x005" in the field, "x5<r>$ 200" in the gen-6 mart) or the multiply
  # sign "×" (the v22 mart/BP shop, "×5<r>$200") -- so the amount (and price) is read on change; that
  # leading marker keeps the hook off normal dialogue.
  module NumberEntry
    # Announces the chosen amount (and price) when a number-window text changes. Matches a quantity line
    # only: it starts with "x" (gen-6) or "×" (v22's multiply sign), then digits and an optional price, so
    # ordinary dialogue is ignored.
    def self.on_text(raw)
      t = PokeAccess.clean(raw.to_s)
      # The price carries thousand separators: the mart builds it with to_s_formatted, so a total of a
      # thousand or more arrives as "x5$ 1,000" (or "1.000"). Demanding bare digits made the whole line
      # stop matching there -- so from the first four-figure total the amount went unread TOO, not just
      # the price. Separators are stripped before the number is spoken.
      return unless t =~ /\A(?:x|\303\227)\s*(\d+)\s*(?:\$\s*([\d.,]+))?\z/
      amount = $1.to_i; price = $2
      price = price.gsub(/[.,]/, "") if price
      return if t == @last
      @last = t
      msg = amount.to_s
      msg += ", " + PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => price.to_i) if price
      PokeAccess.speak(msg, true)
    rescue StandardError
      nil
    end

    # Place value (power of ten, 0 = units) => its spoken column name.
    PLACES = [:ne_units, :ne_tens, :ne_hundreds, :ne_thousands, :ne_tenk, :ne_hundredk, :ne_millions]

    # The spoken name of a digit column by its power of ten.
    def self.place_name(pw)
      PLACES[pw] ? PokeAccess::I18n.t(PLACES[pw]) : PokeAccess::I18n.t(:ne_place, :n => (10 ** pw))
    end

    # Reads a multi-digit number entry (Window_InputNumberPokemon) by column: on open the total, left/
    # right says the column and its digit ("hundreds: 0"), up/down says the new total -- so which column
    # you are editing is no longer invisible.
    def self.on_digit_window(win)
      idx = win.instance_variable_get(:@index)
      num = (win.number rescue nil)
      return if idx.nil? || num.nil?
      li = win.instance_variable_get(:@access_lastidx)
      ln = win.instance_variable_get(:@access_lastnum)
      win.instance_variable_set(:@access_lastidx, idx)
      win.instance_variable_set(:@access_lastnum, num)
      if li.nil?
        PokeAccess.speak(num.to_s, true)
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
  PokeAccess::Hooks.after_hook(cn, :text=) do |_w, _r, args|
    PokeAccess::NumberEntry.on_text(args[0])
  end
end

# The quantity selector (Window_InputNumberPokemon, "how many?") draws its digits to a bitmap, with a
# per-digit cursor (left/right) and digit change (up/down), so read the column you land on plus the total.
PokeAccess::Hooks.after_hook("Window_InputNumberPokemon", :update) do |win, _r, _a|
  PokeAccess::NumberEntry.on_digit_window(win) if (win.active rescue false)
end
