module PokeAccess
  # The title a list screen paints in its corner (@sprites["header"], a frameless text window over the background),
  # which the generic readers leave unsaid: said once per screen, queued, ahead of the list's first row.
  module ScreenTitle
    # Says scene's header the first time it has text; nothing on later calls, nor where the scene paints none.
    def self.say(scene)
      PokeAccess::Cursor.announce(scene, :screen_title, 0, false) do
        win = PokeAccess.sprite(scene, "header")
        win ? win.text : nil
      end
    end
  end
end

# The Pokegear's jukebox in both builds: gen6's Scene_Jukebox (xLeD's, "Radio" in some games; main loops over update)
# and v19+'s PokemonJukebox_Scene. Its tracks are a command window the generic reader says.
[["Scene_Jukebox", :update], ["PokemonJukebox_Scene", :pbUpdate]].each do |cname, meth|
  PokeAccess::Hooks.before_hook(cname, meth, :optional => true) { |scene, _a| PokeAccess::ScreenTitle.say(scene) }
end
