# The CMoon hub (pbDMoon, script 0221) and the screens it opens. This is the front door of the whole Fates
# system -- diary, legendaries, compendium, miscellaneous and the summon creator -- and it was silent, which
# made everything behind it unreachable even though those screens are now covered.
#
# Its cursor is a LOCAL variable (`select`), so no hook can read it. Same situation as the Triple Triad
# pickers in the core, and the same answer: an around-hook holds the screen while its loop runs, and a
# per-frame poll mirrors the very same navigation the loop does (DOWN while select < 4, UP while select > 0,
# no wrap) to know where the focus is. The labels are not hardcoded here either -- the screen paints them
# once at setup with pbDrawOutlineText, so those calls are captured while it is opening and the captured
# strings are what gets spoken. That keeps the conditional first entry ("Diario de D`" vs "Diario de
# Personajes") correct without this file having to know why it varies.
module PokeAccess
  module AwakeningCMoon
    @active = false
    @labels = []
    @sel = 0
    @last = nil

    # Starts mirroring: a fresh label list and the cursor back at the top, as the screen itself does.
    def self.start
      @active = true
      @labels = []
      @sel = 0
      @last = nil
    end

    def self.stop; @active = false; @labels = []; end

    # Collects a label drawn while the hub is opening, in draw order.
    def self.label(text)
      return unless @active
      t = PokeAccess.clean(text.to_s).to_s.strip
      @labels.push(t) unless t.empty?
    rescue StandardError
      nil
    end

    # Mirrors the hub's own navigation and speaks the focused entry when it changes.
    def self.poll
      return unless @active
      @sel += 1 if Input.trigger?(Input::DOWN) && @sel < 4
      @sel -= 1 if Input.trigger?(Input::UP) && @sel > 0
      return if @sel == @last
      @last = @sel
      name = @labels[@sel]
      return if name.nil? || name.empty?
      PokeAccess.speak(PokeAccess::I18n.t(:if2_pokenav, :name => name,
                                          :n => @sel + 1, :tot => 5), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  kernel("pbDMoon", :around) do |_args, nxt|
    PokeAccess::AwakeningCMoon.start
    begin
      nxt.call
    ensure
      PokeAccess::AwakeningCMoon.stop
    end
  end
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningCMoon.label(args[5]) }
  poll_each_frame { PokeAccess::AwakeningCMoon.poll }
end
