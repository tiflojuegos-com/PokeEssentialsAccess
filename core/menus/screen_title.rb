module PokeAccess
  # The title a list screen paints in its corner (@sprites["header"], a frameless text window over the background),
  # which the generic readers leave unsaid: said once per screen, queued, ahead of the list's first row.
  module ScreenTitle
    # Says scene's title window when it has text and as that text changes, the first queued: a screen can open under its
    # parent's title and paint its own over it. Nothing where the scene paints none.
    # param window the name of the scene's title window
    def self.say(scene, window = "header")
      text = (PokeAccess.sprite(scene, window).text rescue nil)
      PokeAccess::Cursor.announce(scene, :screen_title, text, true, false) { text }
    end
  end
end

# The Pokegear's jukebox in every build: xLeD's Scene_Jukebox ("Radio" in some games) loops over update; the v16.2
# Scene_Jukebox and v19+'s PokemonJukebox_Scene, over pbUpdate (scene_classes keeps the parent of an empty alias).
# Its tracks are a command window the generic reader says.
PokeAccess::Hooks.before_hook("Scene_Jukebox", :update, :optional => true) do |scene, _a|
  PokeAccess::ScreenTitle.say(scene)
end
PokeAccess::Engine.scene_classes("Scene_Jukebox", "PokemonJukebox_Scene").each do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbUpdate, :optional => true) { |scene, _a| PokeAccess::ScreenTitle.say(scene) }
end

# The Options screen in both spellings, whose title is a text window of its own; a before hook, as its pbUpdate drives
# the option window, whose reader says the first row.
PokeAccess::Engine.scene_classes("PokemonOption_Scene", "PokemonOptionScene").each do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbUpdate, :optional => true) do |scene, _a|
    PokeAccess::ScreenTitle.say(scene, "title")
  end
end
