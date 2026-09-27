# Royal's date check over the Internet (obtenerFechaInternetConMensaje, from the gacha's daily ticket): its notice is
# written straight into a message window, outside pbMessageDisplay, so it is said as the check starts, through the
# game's _INTL as the build paints it.
PokeAccess::Game.define("royal") do
  kernel("obtenerFechaInternetConMensaje", :before) do |_args, _r|
    PokeAccess.speak_clean(_INTL("Conectándose a Internet para verificar la fecha..."), true)
  end
end
