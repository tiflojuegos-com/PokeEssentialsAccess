module PokeAccess
  # Soulstones' quick save (Marin's, pasted into its Scene_Map#update, 0066_Scene_Map.rb): Q on the map calls pbSave and
  # starts a disk animation (@mode from nil to 0) with no message or sound, so the save's result is said instead.
  module Soulstones1QuickSave
    # Watches one map update: whether the animation was idle as it began, and what a pbSave inside it answers.
    def self.arm(scene)
      @idle = PokeAccess.ivar(scene, :@mode).nil?
      @result = nil
      @armed = true
    end

    # Keeps what pbSave answered while an update is watched (true saved, false failed).
    def self.saved(result)
      @result = result if @armed
    end

    # Says the save once the update that started the animation returns: saved, or not when pbSave said it failed.
    def self.check(scene)
      @armed = false
      return unless @idle && !PokeAccess.ivar(scene, :@mode).nil?
      PokeAccess.speak(PokeAccess::I18n.t(@result == false ? :ss1_quicksave_failed : :ss1_quicksaved), true)
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  around("Scene_Map", :update) do |scene, nxt, _a|
    PokeAccess::Soulstones1QuickSave.arm(scene)
    begin
      nxt.call
    ensure
      PokeAccess::Soulstones1QuickSave.check(scene)
    end
  end
  kernel("pbSave", :after) { |_args, result| PokeAccess::Soulstones1QuickSave.saved(result) }
end
