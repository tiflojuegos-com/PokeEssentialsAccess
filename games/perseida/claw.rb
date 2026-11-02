# Perseida's claw machine (ClawMachine in 0308_PMinigame_Claw, common event 30), all pictures but its count of turns. The
# prize is drawn at random at the bottom of each throw, wherever the claw is; a prize gets the game's own message, a miss
# nothing at all, so the reader says it once the claw is back up.
module PokeAccess
  module PerseidaClaw
    # The height of the hand at rest, which it leaves during a throw.
    REST_Y = 42

    # A throw that came back empty, as [the throw, its line]; nil at any other moment.
    def self.miss(scene)
      thrown = PokeAccess.ivar(scene, :@chance)
      hand = (PokeAccess.ivar(scene, :@claw)["clawhand"] rescue nil)
      return nil unless thrown.is_a?(Integer) && thrown > 0 && hand && hand.y == REST_Y
      PokeAccess.ivar(scene, :@item) ? nil : [thrown, PokeAccess::I18n.t(:perseida_claw_miss)]
    end

    # The screen as it opens: its turns and, while key hints are said, how it is played.
    def self.intro(scene)
      title = PokeAccess::I18n.t(:perseida_claw_title, :max => PokeAccess.ivar(scene, :@chances))
      hint = PokeAccess::I18n.t(:perseida_claw_hint, :key => PokeAccess::KeyHints.key(:c, "C"),
                                                     :back => PokeAccess::KeyHints.key(:b, "X"))
      PokeAccess::Info.set_info(:text, title)
      PokeAccess::Verbosity.with_hint(title, hint, " ")
    end

    # The throw that has just begun, as the count of turns repaints; the count painted before the first says nothing.
    def self.turn(scene)
      thrown = PokeAccess.ivar(scene, :@chance)
      return unless thrown.is_a?(Integer) && thrown > 0
      line = PokeAccess::I18n.t(:perseida_claw_turn, :n => thrown, :max => PokeAccess.ivar(scene, :@chances))
      PokeAccess::Info.set_info(:text, line)
      PokeAccess.speak(line, true)
    end

    READER = PokeAccess::SceneWatcher.reader("ClawMachine", :pbMain, :perseida_claw, :optional => true,
                                             :queued => true) { |scene| PokeAccess::PerseidaClaw.miss(scene) }
  end
end

PokeAccess::Game.define("perseida") do
  read_on_open("ClawMachine", :pbStartScene, :optional => true) { |scene| PokeAccess::PerseidaClaw.intro(scene) }
  after("ClawMachine", :pbDrawText, :optional => true) { |scene, _r, _a| PokeAccess::PerseidaClaw.turn(scene) }
  after("ClawMachine", :pbEndScene, :optional => true) { |_scene, _r, _a| PokeAccess::Info.clear_text }
end
