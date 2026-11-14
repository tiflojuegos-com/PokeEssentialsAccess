PokeAccess::Game.define("xenoverse") do
  # The original intro has finished when Scene_Intro enters this blocking loop.
  # Its START is an image; reuse the shared localized/remappable title prompt.
  before("Scene_Intro", :update) do |scene, _args|
    screen = PokeAccess.ivar(scene, :@screen)
    if defined?(::XenoverseStyle) && screen.is_a?(::XenoverseStyle) && !screen.disposed?
      PokeAccess.speak(PokeAccess::TitleScreen.prompt, true)
    end
  end
end
