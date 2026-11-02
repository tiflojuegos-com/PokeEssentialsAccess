# The Elite Battle System's scene as Uranium's and Sevii's copies paint it alike: the ability strip
# (showAbilityMessage), and the level-up stat panels its own PokeBattle_Scene#pbTopRightWindow shows, which shadows the
# global one ModalPanel reads.
module PokeAccess
  module EbsScene
    # Runs a pbLevelUp counting the stat panels it shows; the first, the gains, is the one the core says beforehand.
    def self.levelling
      @panels = 0
      yield
    ensure
      @panels = nil
    end

    # A stat panel about to block until confirmed: its lines as written ("Max. HP 45. Attack 30..."), queued; inside a
    # level-up, every panel after the gains.
    def self.panel(text)
      shown = @panels
      @panels += 1 if shown
      return if shown == 0
      lines = text.to_s.split(/\r?\n/).map { |l| PokeAccess.clean(l.gsub(/<r>/i, " ")) }
      PokeAccess.speak(PokeAccess.sentences(lines), false)
    end
  end
end

PokeAccess::Hooks.after_hook("PokeBattle_Scene", :showAbilityMessage, :optional => true,
                             :hook_container => true) do |_s, _r, args|
  PokeAccess::BattleScene.hold_strip(args[0])
end
PokeAccess::Hooks.around_hook("PokeBattle_Scene", :pbLevelUp, :optional => true) do |_s, nxt, _a|
  PokeAccess::EbsScene.levelling { nxt.call }
end
# Only the system's own public scene method: a scene without one inherits the global function, which ModalPanel reads.
ebs_scene_class = PokeAccess.const_at("PokeBattle_Scene")
if ebs_scene_class && ebs_scene_class.public_method_defined?(:pbTopRightWindow)
  PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbTopRightWindow, :optional => true) do |_s, args|
    PokeAccess::EbsScene.panel(args[0])
  end
end
