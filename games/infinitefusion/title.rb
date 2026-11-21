# Kanto's title screen (GenOneStyle, 052 IntroScreen): its update waits 150 frames to show each fusion, and a confirm key
# pressed in that wait only cuts it short, so Scene_Intro's loop, reading the key again after it, stays on the title.
# That key is handed once to the loop's next check, so the press that cut the wait also leaves the title.
module PokeAccess
  module KantoTitleInput
    # Runs Scene_Intro's title loop with a key carried over by the style, none left once it ends.
    def self.during_title
      @active = true
      @pending = false
      begin
        yield
      ensure
        @active = false
        @pending = false
      end
    end

    # Keeps the key the style's wait took (its @skip), inside the title loop only.
    def self.after_style_update(style)
      @pending = PokeAccess.ivar(style, :@skip) == true if @active
    end

    # The game's continueKeyPressed?, true once more for a key kept by after_style_update.
    def self.continue?(pressed)
      return pressed unless @active && @pending
      @pending = false
      true
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  around("Scene_Intro", :update) do |_scene, proceed, _args|
    PokeAccess::KantoTitleInput.during_title { proceed.call }
  end
  after("GenOneStyle", :update, :hook_container => true) do |style, _result, _args|
    PokeAccess::KantoTitleInput.after_style_update(style)
  end
  kernel("continueKeyPressed?", :around) do |_args, original|
    PokeAccess::KantoTitleInput.continue?(original.call)
  end
end
