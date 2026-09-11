# The controls help of the opening (ButtonEventScene), in its two copies. The modern one, in eight of the
# games, is the one with addLabelForScreen: four screens explaining the keys in six of them (anil and
# royal ship the same scene cut to one screen with no labels at all, so there is nothing to collect), whose
# paragraphs go straight into bitmaps through addLabelForScreen. The gen-6 one, in the other seven, is a
# single screen whose paragraphs go through addLabel from the constructor. Both are collected as the scene
# registers them, keyed by screen, and read when that screen is put up.
module PokeAccess
  module ControlsHelp
    # Collects one paragraph under the screen it belongs to, on the scene itself so two screens open at once
    # (there are none, but the scene is the only thing that outlives the call) cannot mix.
    def self.note(scene, number, text)
      labels = (PokeAccess.ivar(scene, :@access_labels) || {})
      (labels[number] ||= []).push(text.to_s)
      scene.instance_variable_set(:@access_labels, labels)
    rescue StandardError
      nil
    end

    # Reads the paragraphs of the screen being put up. Interrupting: the player pressed a key to get here.
    #
    # A full stop is added only where the paragraph does not already end in one. These are the game's own
    # sentences and they carry their own punctuation; joining them with ". " regardless gave "F1 abre la
    # configuracion.. F8 hace una captura.", which a screen reader says as a stumble.
    def self.say(scene, number)
      labels = PokeAccess.ivar(scene, :@access_labels)
      rows = labels ? labels[number] : nil
      return if rows.nil? || rows.empty?
      out = ""
      rows.each do |r|
        t = r.to_s.strip
        next if t.empty?
        out += (out.empty? ? "" : (out =~ /[.!?:;]\z/ ? " " : ". ")) + t
      end
      PokeAccess.speak_clean(out, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("ButtonEventScene", :addLabelForScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note(scene, args[0], args[4])
end

PokeAccess::Hooks.after_hook("ButtonEventScene", :set_up_screen, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.say(scene, args[0])
end

# The gen-6 copy: addLabel(x, y, width, text) from the constructor, one screen, and no set_up_screen to read
# on. Bound by the seam that copy has and gated on the one it lacks, so the modern copy -- whose
# addLabelForScreen calls addLabel from inside the guarded hook above -- is never read twice. Both hooks
# were absent in those seven games without a trace: optional, so not in Hooks.missing, and Realidea opens
# this screen from its first map. The constructor is wrapped AROUND and not after: an after-hook runs its
# original under the reentrancy guard, which would drop the addLabel hooks as nested, and the page would
# have nothing to say when the constructor returned.
PokeAccess::Hooks.after_hook("ButtonEventScene", :addLabel, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note(scene, 1, args[3]) unless scene.respond_to?(:addLabelForScreen)
end

PokeAccess::Hooks.around_hook("ButtonEventScene", :initialize, :optional => true) do |scene, nxt, _a|
  nxt.call
  PokeAccess::ControlsHelp.say(scene, 1) unless scene.respond_to?(:set_up_screen)
end
