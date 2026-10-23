# Cable Club 1.11 (mGriffin, Khaikaa, Vendily), its online play: the lines CableClub_Scene writes straight onto its
# message box, never through pbMessage (the question over a menu or a text field too), the waiting dots, and the team
# preview with its countdown. Its option lists are read by the core menu hook.
module PokeAccess
  module CableClub
    # The box shows a line of its own, or none once hidden (nil): the line said queued, before the writer blocks, and
    # the waiting line after it said again even when it repeats, as the box paints it anew.
    def self.written(scene, text = nil)
      PokeAccess::Cursor.reset(scene, :cc_dots)
      PokeAccess.speak_clean(text, false) unless text.nil?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A text field opening under its question, written to the box as any line: the question, then what the field
    # already holds (a rejected entry reopens with it) or that it is empty.
    def self.field(scene, helptext, starttext)
      written(scene)
      start = starttext.to_s
      state = start.strip.empty? ? PokeAccess::I18n.t(:row_empty) : PokeAccess::I18n.t(:nm_current, :t => start)
      PokeAccess.speak(PokeAccess.sentences([PokeAccess.clean(helptext.to_s), state]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The waiting line, said once per text however often the frame update redraws its dots.
    def self.waiting(scene, text)
      PokeAccess::Cursor.announce(scene, :cc_dots, text.to_s, false) { text.to_s }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The team preview before an online battle: each trainer and their team, every member with its sex sign and
    # whether it holds something (the card draws an icon, never the item).
    def self.preview(left_name, right_name, left_party, right_party)
      sides = [[left_name, left_party], [right_name, right_party]].map do |name, party|
        team = (party || []).map { |pk| member(pk) }
        PokeAccess::I18n.t(:cc_preview_team, :trainer => PokeAccess.clean(name.to_s), :team => team.join(", "))
      end
      PokeAccess.speak(sides.join(". "), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A member with the icon under it, the party panel's own: a letter's for mail, the item one otherwise.
    def self.member(pk)
      shown = [PokeAccess.clean(pk.name.to_s), PokeAccess::Party.gender_glyph(pk)].compact.join(" ")
      return shown unless PokeAccess::Party.held_icon(pk)
      PokeAccess::I18n.t((pk.mail rescue nil) ? :cc_preview_mail : :cc_preview_holds, :name => shown)
    end

    # The countdown under the card, said once (keyed without digits) as timer_text gives it.
    def self.countdown(scene)
      t = (PokeAccess.sprite(scene, "timer").text rescue nil).to_s
      return if t.strip.empty?
      PokeAccess::Cursor.announce(scene, :cc_timer, t.gsub(/\d/, ""), false) { timer_text(t) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The countdown as said: as painted; a profile whose card adds to it overrides this.
    def self.timer_text(text)
      text
    end
  end
end

PokeAccess::Hooks.before_hook("CableClub_Scene", :pbShowCommands, :optional => true) do |s, args|
  PokeAccess::CableClub.written(s, args[0])
end
PokeAccess::Hooks.before_hook("CableClub_Scene", :pbDisplay, :optional => true) do |s, args|
  PokeAccess::CableClub.written(s, args[0])
end
PokeAccess::Hooks.before_hook("CableClub_Scene", :pbHideMessageBox, :optional => true) do |s, _a|
  PokeAccess::CableClub.written(s)
end
PokeAccess::Hooks.before_hook("CableClub_Scene", :pbDisplayDots, :optional => true) do |s, args|
  PokeAccess::CableClub.waiting(s, args[0])
end
PokeAccess::Hooks.before_hook("CableClub_Scene", :pbEnterText, :optional => true) do |s, args|
  PokeAccess::CableClub.field(s, args[0], args[1])
end
PokeAccess::Hooks.before_hook("TeamPreview_Scene", :pbDrawTeamPreviewText, :optional => true) do |_s, args|
  PokeAccess::CableClub.preview(*args)
end
PokeAccess::Hooks.after_hook("TeamPreview_Scene", :update, :optional => true) do |s, _r, _a|
  PokeAccess::CableClub.countdown(s)
end
