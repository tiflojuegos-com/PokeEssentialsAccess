module PokeAccess
  # Rejuvenation's Move Tutor app of the CyberNav (Scene_MoveTutor), read by the engine's MoveTutorRV: each focused
  # move's type, PP, whether it is still to be paid for and the party marks follow its name. X sorts the list by name
  # and A by type, rebuilding it from the top with only a sound; a move bought rebuilds it too.
  module RejuvTutor
    # The sort the key just pressed asked for, or nil when the list was rebuilt for a move bought.
    def self.sort_text
      return PokeAccess::I18n.t(:rj_tutor_by_name) if Input.trigger?(Input::X)
      return PokeAccess::I18n.t(:rj_tutor_by_type) if Input.trigger?(Input::A)
      nil
    end
  end
end

# A container: pbUpdate drives the list, whose reader says the name.
PokeAccess::Game.define("rejuvenation") do
  after("Scene_MoveTutor", :pbUpdate, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::MoveTutorRV.describe(scene)
  end

  after("Scene_MoveTutor", :refreshMoveList, :optional => true) do |_scene, _r, _a|
    t = PokeAccess::RejuvTutor.sort_text
    PokeAccess.speak(t, true) if t
  end
end
