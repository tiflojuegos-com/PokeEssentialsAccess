# The modal text panel: a Window_AdvancedTextPokemon built by hand and blocked on until the confirm key.
# It never goes through pbMessage, so no message hook sees it. The engine's is pbTopRightWindow, the two
# stat panels of a level-up; games and plugins copy the shape under their own names, so a panel is
# DECLARED by name. The battle path, which already says the level-up better, mutes them for its call.
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

    # One panel, as it was handed the text.
    def self.say(text)
      return if @mute
      PokeAccess.speak_clean(text, false)
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
