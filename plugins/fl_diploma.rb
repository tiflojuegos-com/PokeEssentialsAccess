# FL's Diploma (DiplomaScene): a full-screen certificate whose text is painted over a picture; what it paints (the player's
# name, the main text, the signature) is said as the scene opens, and kept on the info key until it closes.
module PokeAccess
  module FLDiploma
    # The certificate's painted rows as one line: top to bottom, each cleaned, joined as sentences.
    def self.text(pairs)
      PokeAccess.sentences(PokeAccess::PaintCapture.laid_out(pairs).map { |t| PokeAccess.clean(t) })
    end

    # Says the certificate as it opened, queued behind whatever brought it up, and keeps it for the info key.
    def self.opened(pairs)
      t = text(pairs)
      return if t.empty?
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# pbStartScene paints the certificate, then fades the scene in; what it paints is what is said.
PokeAccess::Hooks.around_hook("DiplomaScene", :pbStartScene, :optional => true) do |_scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLDiploma.opened(pairs)
  r
end

PokeAccess::Hooks.before_hook("DiplomaScene", :pbEndScene, :optional => true) { |_scene, _a| PokeAccess::Info.clear_text }
