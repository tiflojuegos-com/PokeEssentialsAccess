# Kernel.pbDisplayText: a HUD text writer some fangames ship (DisplayText.rb), painting labels straight onto a
# bare BitmapSprite -- a whole PokeNav and the character creator in the games that have it. Wrapping the one
# function reaches all of them. Deduped by SCREENFUL, with Kernel.pbClearText as the repaint boundary: a HUD
# repaints every frame and alternates its labels, so a one-slot dedup would flood the queue.
module PokeAccess
  module HudText
    # Distinct labels kept per pass. A HUD screen paints a handful; the cap is what stops a screen that never
    # clears from growing a list for as long as it is open.
    MAX_LABELS = 32

    @shown = []
    @batch = []

    # Starts a new pass: what the last one wrote becomes what is on screen -- INCLUDING an empty write.
    # An empty pass means the HUD went blank, so whatever paints after it is new to the player.
    def self.cleared
      @shown = @batch
      @batch = []
    end

    def self.reset
      @shown = []
      @batch = []
    end

    # Speaks a HUD label the first time this pass writes it, unless the previous pass had it too. Blank and
    # purely decorative strings are dropped, and the text goes through the shared cleaner so colour codes are
    # not spelled out.
    # Mutes say for the block: a screen whose closing repaint reaches the HUD after it is gone wraps that
    # paint here. Counted, so a nested hush releases only when the outermost block ends.
    def self.hushed
      @hush = @hush.to_i + 1
      yield
    ensure
      @hush = @hush.to_i - 1
    end

    def self.say(msg)
      return if @hush.to_i > 0
      t = PokeAccess.clean(msg.to_s)
      return if t.nil? || t.strip.empty?
      return if @batch.include?(t)
      @batch.push(t)
      @batch.shift while @batch.length > MAX_LABELS
      return if @shown.include?(t)
      PokeAccess.speak(t, false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbDisplayText", "hud_text", :after) do |args, _r|
  PokeAccess::HudText.say(args[0])
end

PokeAccess::Hooks.wrap_kernel("pbClearText", "hud_text_clear", :before) do |_args, _r|
  PokeAccess::HudText.cleared
end

PokeAccess::Caches.register(:hud_text) { PokeAccess::HudText.reset }
