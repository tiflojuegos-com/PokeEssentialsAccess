module PokeAccess
  module KantoTitleInput
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

    def self.after_style_update(style)
      # The game's animation wait acknowledges a key and marks @skip.
      # Scene_Intro updates Input again before checking the title key.
      @pending = PokeAccess.ivar(style, :@skip) == true if @active
    end

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