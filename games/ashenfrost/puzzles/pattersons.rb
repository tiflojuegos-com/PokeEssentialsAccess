# Patterson's (map 549, Case Twelve): the apprentice (event 1, page 2) wants Mordecai to take the name she blows as a
# raspberry, which passCheck asks typed, nine letters, case ignored. Her word is spelled after her line, read from the
# event's own page; the assist's answer at the entry is assist_answers.rb's.
module PokeAccess
  module AshenApprentice
    MAP = 549
    APPRENTICE = 1
    HER_LINE = /No! <i>([A-Za-z]+)/

    # The first string of the event's page that matches a pattern, as its first group, or nil.
    def self.captured(ev, pattern)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      list.each do |c|
        (c.parameters || []).each { |p| return $1 if p.is_a?(String) && p =~ pattern }
      end
      nil
    end

    # A word as its letters, one by one.
    def self.spelled(word)
      word.to_s.scan(/./).join(", ")
    end

    # The apprentice's word, spelled, as the screen shows it; nil when the page has none.
    def self.her_word(ev)
      word = captured(ev, HER_LINE)
      word ? [:afc_name_spelled, { :letters => spelled(word) }] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  apprentice = PokeAccess::AshenApprentice
  mechanic(:state, apprentice::MAP, :part => :name) do
    auto
    on_reach apprentice::APPRENTICE, { :text => apprentice::HER_LINE }, lambda { |ev| PokeAccess::AshenApprentice.her_word(ev) }
  end
end
