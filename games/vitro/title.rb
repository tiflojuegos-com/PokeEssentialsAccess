# Vitro's title (0334_Resource_TitleScreen, Luka's script, in its custom style): the credits picture cyclePics fades in, as it
# is written, and before it the warning SplashMessage paints and waits on (0373_pbSplash), which two map events show too. The
# load screen after it lists the autosaves (selectAutosave, 0377_AutoSave), which core reads, and its language
# entry opens a screen of its own (PokemonLanguageSelection, 0215_Idioma Selector), one row a language under a title.
module PokeAccess
  module VitroLanguage
    # Says the language under the cursor as updateSelection paints it, the first queued after the title and each move cutting in.
    def self.focus(scene)
      index = PokeAccess.ivar(scene, :@index)
      rows = PokeAccess.ivar(scene, :@languages)
      first = PokeAccess::Cursor.pending?(scene, :vitro_language)
      PokeAccess::Cursor.announce(scene, :vitro_language, index, true, false) do
        row = PokeAccess::Verbosity.list_entry(rows[index][0], index + 1, rows.length)
        first ? PokeAccess.sentences([_INTL("IDIOMA / LANGUAGE / LANGUE / SPRACHE"), row]) : row
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("PokemonLanguageSelection", :updateSelection, :optional => true) { |scene, _r, _a| PokeAccess::VitroLanguage.focus(scene) }
  picture_texts(
    "intro1" => "Pokémon Essentials BES. 2011-2024 Maruno, 2001-2009 Peter O., 2020-2024 Pira, 2022-2024 Colaboradores PL. " \
                "Based on work by Flameguru. MKXP-Z, Roza. Based on mkxp by Ancurio et al."
  )
  before("SplashMessage", :initialize, :optional => true) { |_scene, _a| PokeAccess::PaintCapture.arm(:vitro_splash) }
  before("SplashMessage", :pbMain, :optional => true) do |_scene, _a|
    rows = PokeAccess::PaintCapture.take(:vitro_splash) || []
    PokeAccess.speak(PokeAccess.sentences(rows.map { |row| PokeAccess.clean(row) }), false)
  end
end
