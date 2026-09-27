# Armonia's follower (Bezier's follow script): A and D rotate the party so the Pokemon behind the player changes, a
# battle that ends with the lead fainted puts the first healthy one in front, and Q hides or shows it.
module PokeAccess
  module ArmoniaFollower
    # The party's first Pokemon, or nil.
    def self.lead
      party = ($Trainer.party rescue nil)
      party.is_a?(Array) ? party[0] : nil
    end

    # After changeFollowingSprite(direction, anim): with anim, A or D only queued the turn, which is marked so its
    # announcement interrupts; without it, a turn that changed the lead says the new one (queued after a battle).
    # param before the lead before the call
    def self.changed(args, before)
      dir = args[0]
      return unless dir == 1 || dir == -1
      if args[1]
        @asked = true
        return
      end
      asked = @asked ? true : false
      @asked = false
      now = lead
      return if now.nil? || now.equal?(before)
      name = (now.name rescue nil)
      return if name.nil? || name.to_s.empty?
      PokeAccess.speak_clean(PokeAccess::I18n.t(:arm_follow_lead, :name => name), asked)
    rescue StandardError
      nil
    end

    # Whether the toggle about to run is the one the player asked for with its key (events toggle it too) and will
    # act: toggleFollowingPokemon does nothing while the lead is fainted or an egg.
    def self.toggle_asked?
      return false unless (Input.trigger?(::FOLLOW_KEY_TOGGLE) rescue false)
      pk = lead
      return false if pk.nil? || (pk.hp rescue 0).to_i <= 0
      !(pk.isEgg? rescue false)
    rescue StandardError
      false
    end

    # Says whether the follower is now hidden or shown, after a toggle the player asked for.
    def self.toggled(asked)
      return unless asked
      PokeAccess.speak(PokeAccess::I18n.t($Follow_Hidden ? :arm_follow_hidden : :arm_follow_shown), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("armonia") do
  kernel("changeFollowingSprite", :around) do |args, nxt|
    before = PokeAccess::ArmoniaFollower.lead
    r = nxt.call
    PokeAccess::ArmoniaFollower.changed(args, before)
    r
  end

  kernel("toggleFollowingPokemon", :around) do |_args, nxt|
    asked = PokeAccess::ArmoniaFollower.toggle_asked?
    r = nxt.call
    PokeAccess::ArmoniaFollower.toggled(asked)
    r
  end
end
