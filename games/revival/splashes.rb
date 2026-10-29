# Revival's title (Luka's animated title over its own Scene_Intro) first fades in two credit pictures, splash1 and
# splash2 (IntroEventScene::SPLASH_IMAGES), whose text is said from transcriptions, queued, once per Scene_Intro while
# its title is not built: the toolkit loads on the first frame of those pictures, so no hook on them would run then.
module PokeAccess
  module RevivalSplashes
    # Says the credit pictures' text once for a Scene_Intro whose title screen is not up yet.
    def self.intro(scene)
      return unless defined?(::Scene_Intro) && scene.is_a?(::Scene_Intro)
      return if PokeAccess.ivar(scene, :@access_rv_splash) || PokeAccess.ivar(scene, :@screen)
      scene.instance_variable_set(:@access_rv_splash, true)
      PokeAccess::TitleScreen.splash(PokeAccess.const_at("IntroEventScene::SPLASH_IMAGES"))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("revival") do
  picture_texts("splash1" => "Pokémon Revival. Creado por Rors. LA BASE DE SKY. Creada por Skyflyer y DPertierra",
                "splash2" => "Pokémon Essentials. 2011-2023 Maruno. 2007-2010 Peter O. Based on work by Flameguru. " \
                             "mkxp-z. Roza. Based on mkxp by Ancurio et al.")
  poll_each_frame { PokeAccess::RevivalSplashes.intro($scene) }
end
