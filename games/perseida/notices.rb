# Perseida's notice with no text of its own to read elsewhere: Cometry's banner (0216_Menu_CometryEating), a picture of her
# that slides in when she has eaten enough berries and wants to apologise from the pause menu.
PokeAccess::Game.define("perseida") do
  kernel("cometryNotification") { |_args, _r| PokeAccess.speak(PokeAccess::I18n.t(:perseida_cometry_notice), false) }
end
