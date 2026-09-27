module PokeAccess
  # Online play setup (Cable Club plugin): the lines CableClub_Scene writes straight onto its message box, never
  # through pbMessage (the label over a text field too), the waiting dots, and the team preview. Its option lists are
  # read by the core menu hook.
  module AnilCableClub
    # Says a line the scene is about to put in the box (before, as the writers then block).
    def self.say(text)
      PokeAccess.speak_clean(text, false)
    rescue StandardError
      nil
    end

    # The waiting line, said once per text however often the frame update redraws its dots.
    def self.waiting(scene, text)
      PokeAccess::Cursor.announce(scene, :cc_dots, text.to_s, false) { text.to_s }
    rescue StandardError
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
    rescue StandardError
      nil
    end

    # A member with the icon under it, the party panel's own: a letter's for mail, the item one otherwise.
    def self.member(pk)
      shown = [PokeAccess.clean(pk.name.to_s), PokeAccess::Party.gender_glyph(pk)].compact.join(" ")
      return shown unless PokeAccess::Party.held_icon(pk)
      PokeAccess::I18n.t((pk.mail rescue nil) ? :cc_preview_mail : :cc_preview_holds, :name => shown)
    end

    # The countdown under the card, said once (keyed without digits), its bracketed key only while hints are said.
    def self.countdown(scene)
      t = (PokeAccess.sprite(scene, "timer").text rescue nil).to_s
      return if t.strip.empty?
      shown = PokeAccess::Verbosity.hints? ? t : t.sub(/\s*\(([^)]*)\)\s*\z/) { |m| $1 =~ PokeAccess::KeyHints::HINT ? "" : m }
      PokeAccess::Cursor.announce(scene, :cc_timer, t.gsub(/\d/, ""), false) { shown }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("anil") do
  before("CableClub_Scene", :pbShowCommands) { |_s, args| PokeAccess::AnilCableClub.say(args[0]) }
  before("CableClub_Scene", :pbDisplay) do |s, args|
    PokeAccess::Cursor.reset(s, :cc_dots)
    PokeAccess::AnilCableClub.say(args[0])
  end
  before("CableClub_Scene", :pbDisplayDots) { |s, args| PokeAccess::AnilCableClub.waiting(s, args[0]) }
  before("CableClub_Scene", :pbEnterText) { |_s, args| PokeAccess::AnilCableClub.say(args[0]) }
  before("TeamPreview_Scene", :pbDrawTeamPreviewText) { |_s, args| PokeAccess::AnilCableClub.preview(*args) }
  after("TeamPreview_Scene", :update) { |s, _r, _a| PokeAccess::AnilCableClub.countdown(s) }
end
