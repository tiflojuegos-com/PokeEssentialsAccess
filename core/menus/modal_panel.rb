# Modal text panels: a hand-built text window blocked on until confirm, outside pbMessage (the engine's is
# pbTopRightWindow, the level-up stat panels). Declared by function name; the battle path mutes them for its call.
module PokeAccess
  module ModalPanel
    # Runs the block with the panels silent, for a caller that has already said what they show.
    def self.muted
      @mute = true
      begin
        yield
      ensure
        @mute = false
      end
    end

    # Speaks one panel's text, queued, unless muted.
    def self.say(text)
      return if @mute
      PokeAccess.speak_clean(PokeAccess::KeyHints.localize(PokeAccess.clean(text.to_s), nil, true), false)
    end

    # Declares a function of this shape: the text is its first argument and it blocks, so it is read on the
    # way in. A name the game lacks lands in Hooks.fn_absent and is skipped.
    def self.watch(fname)
      PokeAccess::Hooks.wrap_kernel(fname, "modal_panel_#{fname}", :before) do |args, _r|
        PokeAccess::ModalPanel.say(args[0])
      end
    end
  end
end

PokeAccess::ModalPanel.watch("pbTopRightWindow")
