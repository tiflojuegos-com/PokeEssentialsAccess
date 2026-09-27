# Armonia's text-less sequences: the two pictures cyclePics fades in before the title, whose text is drawn in them
# (Graphics/Titles/intro1 and intro2), and the frames playVideo shows at the end of the story, with no sound.
module PokeAccess
  module ArmoniaCutscenes
    # The i18n key of each intro picture's transcription, by the name Scene_Intro is given.
    PICTURES = [["intro1", :arm_intro_fans], ["intro2", :arm_intro_studio]]

    # The pictures' text, once per Scene_Intro, while its pictures show (the title not built yet): the toolkit loads
    # on the first frame of cyclePics, so no hook on it would run the first time.
    def self.intro(scene)
      return unless defined?(::Scene_Intro) && scene.is_a?(::Scene_Intro)
      return if PokeAccess.ivar(scene, :@access_intro_said) || PokeAccess.ivar(scene, :@screen)
      scene.instance_variable_set(:@access_intro_said, true)
      Array(PokeAccess.ivar(scene, :@pics)).each do |name|
        row = PICTURES.assoc(name.to_s)
        PokeAccess.speak(PokeAccess::I18n.t(row[1]), false) if row
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("armonia") do
  poll_each_frame { PokeAccess::ArmoniaCutscenes.intro($scene) }
  kernel("playVideo", :before) { |_args, _r| PokeAccess.speak(PokeAccess::I18n.t(:arm_video_start), false) }
  kernel("playVideo", :after) { |_args, _r| PokeAccess.speak(PokeAccess::I18n.t(:arm_video_end), false) }
end
