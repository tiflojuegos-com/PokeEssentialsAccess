# The Akigawa Tournament's record screen (AkiEventScene, 0392_Tournament_RecordScreen.rb, opened by Adeku's pbAkiMenu):
# the mode, the ore earned, the trainers beaten and the team of the best run, read whole once painted.
module PokeAccess
  module KeishouAkiRecord
    @armed = false
    @team = []

    # The screen's record rows as painted, then the team under the zden_party words. The team is the screen's own list,
    # members of the same name included; its names are painted first and repeat, as pbDrawParty repaints them with each
    # member.
    def self.line(rows, team)
      names = team.map { |pk| PokeAccess.clean(pk.name.to_s) }
      parts = rows.map { |r| PokeAccess.clean(r.to_s) }.reject { |r| r.empty? || names.include?(r) }
      return nil if parts.empty?
      parts.push(PokeAccess::I18n.t(:zden_party, :list => names.join(", "))) unless names.empty?
      PokeAccess.sentences(parts)
    end

    # Holds the screen's loop (the block), with its paint collected for the first frame.
    def self.showing(team)
      @armed = true
      @team = team || []
      PokeAccess::PaintCapture.arm(:aki_record)
      yield
    ensure
      @armed = false
      PokeAccess::PaintCapture.take(:aki_record)
      PokeAccess::Info.clear_text
    end

    # The loop's first frame: the screen once painted, kept for the info key.
    def self.first_frame
      return unless @armed
      @armed = false
      text = line(PokeAccess::PaintCapture.take_by_source(:aki_record)[:positions] || [], @team)
      return unless text
      PokeAccess::Info.set_info(:text, text, text)
      PokeAccess.speak(text, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("keishou") do
  around("AkiEventScene", :pbAkiRecordScreen) { |_s, nxt, a| PokeAccess::KeishouAkiRecord.showing(a[-1]) { nxt.call } }
  before("AkiEventScene", :pbUpdate) { |_s, _a| PokeAccess::KeishouAkiRecord.first_frame }
end
