module PokeAccess
  # Item-received popup (Boonzeet's "Item Find" plugin, PokemonItemFind_Scene): shows the name, icon and
  # description of an item the first time it is found -- a notification, not a menu, so nothing reads it.
  # Speaks the name and description of the item being shown.
  #
  # Read from the item pbShow is GIVEN, not from the windows it draws. pbShow fills the two windows and then
  # runs the popup's own blocking loop, and on the keypress that dismisses it calls pbEndScene -- which
  # disposes the whole sprite hash -- BEFORE returning. An after-hook therefore arrived at a torn-down scene
  # every single time and read nothing at all, in all four games that ship this plugin. The item id is the
  # same thing the scene itself resolves its two lines from, and the data layer already answers it in both
  # eras.
  module ItemFindV21
    def self.say(item)
      return if item.nil?
      name = (PokeAccess::Data.item_name(item) rescue nil)
      desc = (PokeAccess::Data.item_description(item) rescue nil)
      parts = [name, desc].reject { |x| x.nil? || x.to_s.strip.empty? }
      PokeAccess.speak_clean(parts.join(". "), false) unless parts.empty?
    rescue StandardError
      nil
    end
  end
end

# Before, not after: by the time pbShow returns its own pbEndScene has already disposed the sprites.
PokeAccess::Hooks.before_hook("PokemonItemFind_Scene", :pbShow, :optional => true) do |_scene, args|
  PokeAccess::ItemFindV21.say(args[0])
end
