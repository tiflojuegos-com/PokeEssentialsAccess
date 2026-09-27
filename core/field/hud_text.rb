# Kernel.pbDisplayText, a HUD text writer some fangames ship (DisplayText.rb) that paints labels onto a bare
# BitmapSprite. Deduped per screenful, with Kernel.pbClearText as the repaint boundary.
module PokeAccess
  module HudText
    # Distinct labels kept per pass; the cap bounds a screen that never clears.
    MAX_LABELS = 32

    @shown = []
    @batch = []

    # Starts a new pass: what the last one wrote, even nothing, becomes what is on screen.
    def self.cleared
      @shown = @batch
      @batch = []
    end

    def self.reset
      @shown = []
      @batch = []
    end

    # Mutes say for the block (a screen's closing repaint); counted, so a nested hush releases with the outermost.
    def self.hushed
      @hush = @hush.to_i + 1
      yield
    ensure
      @hush = @hush.to_i - 1
    end

    # Speaks a cleaned HUD label the first time this pass writes it, unless the previous pass had it too.
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
