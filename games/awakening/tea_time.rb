# Awakening's tea time (Scene_HoraDelTe): Observe shows the character's portrait full size, moved while an arrow is
# held, and paints no text (its help line is commented out); said as it opens, with its keys while hints are on.
module PokeAccess
  module AwakeningTeaTime
    # The line said as Observe opens: whom, and how to move the portrait and leave.
    def self.observe(scene)
      who = PokeAccess.clean(PokeAccess.ivar(scene, :@personaje_nombre).to_s)
      t = who.empty? ? PokeAccess::I18n.t(:awk_observe_bare) : PokeAccess::I18n.t(:awk_observe, :name => who)
      PokeAccess::Verbosity.with_hint(t, PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:awk_observe_keys)))
    end
  end
end

PokeAccess::Game.define("awakening") do
  before("Scene_HoraDelTe", :observar_personaje) { |s, _a| PokeAccess.speak(PokeAccess::AwakeningTeaTime.observe(s), true) }
end
