# FL's Day-Care Checker Item (DayCareChecker::Scene): a static screen with the Pokemon in the Day-Care, each painted with its
# name, level and sex sign, and an egg picture when one is waiting; said as it opens, and kept on the info key until it closes.
module PokeAccess
  module FLDayCare
    # The Pokemon the screen painted, one entry each: its name and level text and the sex sign painted after it, in screen
    # order.
    def self.pokemon(pairs)
      groups = []
      PokeAccess::PaintCapture.laid_out(pairs).each do |raw|
        t = PokeAccess.clean(raw)
        next if t.empty?
        if PokeAccess::Party::SIGNS.include?(t) && !groups.empty?
          groups.last.push(t)
        else
          groups.push([t])
        end
      end
      groups.map { |g| g.join(" ") }
    end

    # What the screen shows as one line: each Pokemon, then the egg; or that the Day-Care holds nothing.
    def self.text(scene, pairs)
      parts = pokemon(pairs)
      parts.push(PokeAccess::I18n.t(:dcheck_egg)) if PokeAccess.sprite(scene, "egg")
      parts.empty? ? PokeAccess::I18n.t(:dcheck_empty) : PokeAccess.sentences(parts)
    end

    # Says the screen as it opened, queued behind whatever brought it up, and keeps it for the info key.
    def self.opened(scene, pairs)
      t = text(scene, pairs)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# start_scene paints the whole screen, then fades it in; the egg is a sprite with no text, found among the sprites.
PokeAccess::Hooks.around_hook("DayCareChecker::Scene", :start_scene, :optional => true) do |scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLDayCare.opened(scene, pairs)
  r
end

PokeAccess::Hooks.before_hook("DayCareChecker::Scene", :end_scene, :optional => true) { |_scene, _a| PokeAccess::Info.clear_text }
