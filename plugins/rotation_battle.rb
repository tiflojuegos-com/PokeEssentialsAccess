# Skyflyer's rotation battles (Combates rotatorios): a triple battle where only the centre Pokemon fight. In the
# command menu D, or the rotation button the menu shows, turns the player's three, and the menu's question is painted
# anew for the one now in the centre: that question is said as it changes, and the key once as the menu opens while
# hints are said. The rotation's reset of the hidden fight menu is kept quiet.
module PokeAccess
  module RotationBattle
    @before = nil
    @hint_due = false

    # The command menu's question as painted, its line break a space; nil without one.
    def self.question(cw)
      box = PokeAccess.ivar(cw, :@msgBox)
      t = box ? (box.text rescue nil) : nil
      (t.nil? || t.to_s.strip.empty?) ? nil : PokeAccess.clean(t.to_s.gsub(/\s*\n\s*/, " "))
    end

    # Keeps the question a frame's rotation check starts from.
    def self.note(cw)
      @before = question(cw)
    end

    # The command menu opened with the rotation button: its key is due once the menu has been read.
    def self.opened
      @hint_due = true
    end

    # After a frame's rotation check: the question again, cutting in, when a rotation painted a new one, and the key,
    # queued, the first frame of an opening on which a rotation can be made.
    def self.checked(scene, cw)
      now = question(cw)
      PokeAccess.speak(now, true) if now && @before && now != @before
      say_key(scene) if @hint_due
    end

    # Says the rotation key while hints are said, when the player's side can rotate.
    def self.say_key(scene)
      @hint_due = false
      battle = PokeAccess.ivar(scene, :@battle)
      idx = PokeAccess.ivar(scene, :@rotation_button_idxBattler)
      return unless battle && idx.is_a?(Integer) && (battle.pbCanRotate?(idx & 1) rescue false)
      return unless PokeAccess::Verbosity.hints?
      label = PokeAccess::I18n.t(:rot_rotate)
      PokeAccess.speak(PokeAccess::I18n.t(:hint_label_key, :label => label, :key => "D"), false)
    end
  end
end

PokeAccess::Hooks.after_hook("Battle::Scene", :pbShowRotationButton, :optional => true) do |_scene, _r, _a|
  PokeAccess::RotationBattle.opened
end
PokeAccess::Hooks.before_hook("Battle::Scene", :pbCheckRotationInput, :optional => true) do |_scene, args|
  PokeAccess::RotationBattle.note(args[0])
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbCheckRotationInput, :optional => true) do |scene, _r, args|
  PokeAccess::RotationBattle.checked(scene, args[0])
end
