# Kernel.pbDisplayText: a HUD text writer some fangames ship (a DisplayText.rb addon script). Screens built
# on it paint their labels straight onto a bare BitmapSprite -- no Essentials window is involved -- so
# everything drawn that way was silent: in the games that ship it that is a whole PokeNav (Contacts,
# PokeRadar, Challenges, weather) plus the character creator. Wrapping this one function reaches all of them
# at once, and it no-ops where the function is not defined, so it costs nothing in the other games.
#
# It redraws the same label on many consecutive frames, so the reader speaks only when the text actually
# changes (Cursor on the module-wide table: the caller is Kernel, there is no scene instance to hang state on).
module PokeAccess
  module HudText
    # Speaks a HUD label once per change. Blank or purely decorative strings are dropped, and the text goes
    # through the shared cleaner so colour/markup codes are not spelled out.
    # Two filters, and the order is the point: a HUD redraws the same label for many consecutive frames, so
    # the RAW string is checked first and the clean-up -- a dozen substitutions -- only runs for a label
    # that actually changed. The clean text is still deduped afterwards because two different raw strings
    # (different colour codes, different spacing) can clean down to the same sentence, and dropping that
    # second check would start repeating lines. Both slots live in the same table, so both reset together.
    def self.say(msg)
      raw = msg.to_s
      return unless PokeAccess::Cursor.changed?(nil, :hud_raw, raw)
      t = PokeAccess.clean(raw)
      return if t.nil? || t.strip.empty?
      PokeAccess::Cursor.announce(nil, :hud_text, t, false) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbDisplayText", "hud_text", :after) do |args, _r|
  PokeAccess::HudText.say(args[0])
end
