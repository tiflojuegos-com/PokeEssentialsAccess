# Xenoverse's title (0208, XenoverseStyle): its START is a picture. When Scene_Intro's loop runs over that style the intro
# is over, and the shared title prompt is said.
PokeAccess::Game.define("xenoverse") do
  before("Scene_Intro", :update) do |scene, _args|
    screen = PokeAccess.ivar(scene, :@screen)
    if defined?(::XenoverseStyle) && screen.is_a?(::XenoverseStyle) && !screen.disposed?
      PokeAccess.speak(PokeAccess::TitleScreen.prompt, true)
    end
  end
end
