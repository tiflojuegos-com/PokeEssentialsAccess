module PokeAccess
  # The credits roll (Scene_Credits), read once, queued, as it starts: get_text (v19+), else the classic CREDIT
  # text, else the per-region text of Infinite Fusion's Hoenn build.
  module Credits
    # The credit lines, cleaned, with the blank spacer lines dropped.
    def self.lines(scene)
      raw = raw_lines(scene)
      return [] unless raw.is_a?(Array)
      raw.map { |l| PokeAccess.clean(l.to_s.split("<s>").join(", ")).strip }.reject { |l| l.empty? }
    rescue StandardError
      []
    end

    # The roll's lines as the game writes them, or nil; a profile whose game picks among several rolls overrides it.
    def self.raw_lines(scene)
      raw = (scene.get_text rescue nil)
      raw = (::CREDIT.split(/\n/) rescue nil) if raw.nil?
      raw = (scene.class::CREDIT.split(/\n/) rescue nil) if raw.nil?
      raw = (region_credit(scene).split(/\n/) rescue nil) if raw.nil?
      raw
    end

    # The Hoenn build's text for the region being played, picked the way its main picks it.
    def self.region_credit(scene)
      scene.class.const_get(::Settings::KANTO ? :CREDIT_KANTO : :CREDIT_HOENN)
    end

    # The whole roll as one reading, one sentence per line.
    def self.text(scene)
      l = lines(scene)
      return nil if l.empty?
      l.map { |x| x =~ /[.!?:]\z/ ? x : "#{x}." }.join(" ")
    end

    # A roll has started; its text is read on the first frame it runs.
    def self.arm; @pending = true; end

    # Speaks the roll on its first frame, after the scene has filled its placeholders (plugin list, sprite artists).
    def self.roll(scene)
      return unless @pending
      @pending = false
      t = text(scene)
      return unless t
      @reading = true
      PokeAccess.speak(t, false)
    end

    # The roll is over, skipped or finished: stops whatever of it is still being read.
    def self.finish
      return unless @reading
      @reading = false
      PokeAccess.stop_speech
    end
  end
end

# main builds the text and runs the whole roll, calling update each frame: armed here, read on the first update.
PokeAccess::Hooks.before_hook("Scene_Credits", :main, :optional => true) do |_scene, _a|
  PokeAccess::Credits.arm
end

PokeAccess::Hooks.before_hook("Scene_Credits", :update, :optional => true) do |scene, _a|
  PokeAccess::Credits.roll(scene)
end

# A container: the roll's own frames run inside main, and a plain after hook would mute their hook.
PokeAccess::Hooks.after_hook("Scene_Credits", :main, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess::Credits.finish
end
