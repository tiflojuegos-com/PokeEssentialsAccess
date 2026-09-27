module PokeAccess
  # Insurgence's sponsorship screen (SponsorScene, on the older move relearner): each repaint says the focused
  # company's panel, led the first time by the question and the heading, and again after a declined question.
  module InsurgenceSponsor
    # The panel's lines as painted (the heading only with_heading); for CANCEL, whose panel is the heading alone, the
    # list's own caption.
    def self.panel_text(scene, with_heading)
      raw = (PokeAccess.sprite(scene, "info").text rescue nil).to_s
      lines = raw.split(/\r?\n/).map { |l| PokeAccess.clean(l) }.reject { |l| l.empty? }
      head = lines.shift
      if lines.empty?
        list = PokeAccess.sprite(scene, "list")
        lines = [list ? PokeAccess::Menus.focused_text(list) : nil]
      end
      PokeAccess.sentences((with_heading ? [head] : []) + lines)
    end

    # Says the panel just painted; the first time queued, after the question and the heading.
    def self.refreshed(scene)
      first = !PokeAccess.ivar(scene, :@access_sponsor_asked)
      text = panel_text(scene, first)
      if first
        scene.instance_variable_set(:@access_sponsor_asked, true)
        ask = (PokeAccess.sprite(scene, "msgwindow").text rescue nil)
        text = PokeAccess.sentences([PokeAccess.clean(ask.to_s), text])
      end
      PokeAccess.speak_clean(text, !first, :menu) unless text.empty?
    rescue StandardError
      nil
    end

    # Notes a return to the list (pbChooseMove again after a declined question); the first run is not one.
    def self.choosing(scene)
      if PokeAccess.ivar(scene, :@access_sponsor_chosen)
        scene.instance_variable_set(:@access_sponsor_asked, nil)
        @back = scene
      else
        scene.instance_variable_set(:@access_sponsor_chosen, true)
      end
    end

    # On the first frame back on the list, once: the question (rewritten by then) and the panel.
    def self.poll
      scene = @back
      return unless scene
      @back = nil
      refreshed(scene)
    end
  end
end

# A container: pbStartScene paints the first panel, whose hook speaks the opening read.
PokeAccess::Game.define("insurgence") do
  after("SponsorScene", :pbStartScene, :hook_container => true) do |s, _r, _a|
    PokeAccess.dedicate(PokeAccess.sprite(s, "list"))
  end
  after("SponsorScene", :pbRefreshInfo) { |s, _r, _a| PokeAccess::InsurgenceSponsor.refreshed(s) }
  before("SponsorScene", :pbChooseMove) { |s, _a| PokeAccess::InsurgenceSponsor.choosing(s) }
  poll_each_frame { PokeAccess::InsurgenceSponsor.poll }
end
