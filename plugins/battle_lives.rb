module PokeAccess
  # The boss lives script several games paste (PokeBattle_Battler#lives, PokeBattle_Scene#pbBreakBar): a boss refills its
  # bar instead of fainting while it has lives left, and its box draws an icon for each life past the current bar. The
  # icons are said with its hit points, and the life it loses as its bar breaks.
  module BattleLives
    # The life icons a battler's box draws: one per life past the current bar, 0 for a battler with no lives.
    def self.spare(b)
      n = (b.lives rescue 1).to_i
      n > 1 ? n - 1 : 0
    end

    # The hit points as the box shows them, with its life icons after them when it draws any.
    def self.with_lives(b, hp)
      n = spare(b)
      n > 0 ? "#{hp}, #{PokeAccess::I18n.t(:blv_lives, :n => n)}" : hp
    end

    # Said as the bar breaks (pbBreakBar, after the life is taken): the life lost and the icons left, or that this is
    # the last life.
    def self.life_lost(b)
      n = spare(b)
      rest = n > 0 ? PokeAccess::I18n.t(:blv_lives_left, :n => n) : PokeAccess::I18n.t(:blv_lives_last)
      PokeAccess.speak(PokeAccess::I18n.t(:blv_life_lost, :name => b.name, :rest => rest), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::Battle, :shown_hp, :tag => "battle_lives") do |_mod, original, args|
  PokeAccess::BattleLives.with_lives(args[0], original.call)
end

PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbBreakBar, :optional => true) do |_s, args|
  PokeAccess::BattleLives.life_lost(args[0])
end
