# Well Temple Hall (map 688, Case Seventeen): the arrival (event 1) wakes the Unown spelling MORDECAI (events 2 to 9),
# which chase him; a touch sends him to the temple (map 686, 23, 6) and resets the hall. Ahead, 21 Unown D, I and E
# (events 10 to 30) go with action: E (12), I (14), E (21), E (24), or I (26), I (29) on the left, open the way to 31.
module PokeAccess
  module AshenTempleHall
    MAP = 688
    CHASERS = (2..9).to_a
    ZAPS = (10..30).to_a
    DUE = [12, 14, 21, 24, 29, nil]
    DONE = 280
    LETTER = /-\s*([A-Z])\s*\z/

    # Whether an Unown ahead is zapped: its self switch A.
    def self.zapped?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # Whether any of these is zapped.
    def self.any?(ids)
      ids.any? { |id| zapped?(id) }
    end

    # The Unown to zap next on the way the assist keeps to, or nil once a way is open to the finish.
    def self.next_zap
      return 12 unless any?([11, 12])
      return 14 unless any?([14, 15, 16, 17])
      return 29 if any?([25, 26]) && !any?([20, 21]) && !any?([28, 29])
      return 21 unless any?([20, 21, 25, 26])
      return nil if any?([25, 26]) && any?([28, 29])
      any?([22, 23, 24]) ? nil : 24
    end

    # An Unown's letter, from its name in the editor ("Zap - D").
    def self.letter(ev)
      ev.name.to_s =~ LETTER ? $1 : ""
    end

    # The name of an Unown standing in the way, marked as due to the assist.
    def self.zap_label(ev)
      name = [:afc_hall_zap, { :letter => letter(ev) }]
      due = PokeAccess::Puzzles.assist? && open? && next_zap == ev.id
      due ? [:afc_due, { :name => PokeAccess::Puzzles.label_of(name) }] : name
    end

    # The assist's line for an Unown due next, by its letter, or for the way to the finish once none is.
    def self.hint(id)
      ev = id && $game_map.events[id]
      ev ? [:afc_hall_next, { :letter => letter(ev) }] : :afc_hall_go
    end

    # Whether the assist is on, the hall still to cross and this Unown (or none) due next.
    def self.due?(id)
      PokeAccess::Puzzles.assist? && open? && next_zap == id
    end

    # Whether the hall is still to cross.
    def self.open?
      !$game_switches[DONE]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  hall = PokeAccess::AshenTempleHall
  mechanic(:state, hall::MAP, :part => :escape) do
    name hall::ZAPS, lambda { |ev| PokeAccess::AshenTempleHall.zap_label(ev) },
         :when => lambda { |ev| !PokeAccess::AshenTempleHall.zapped?(ev.id) }
    obstacle({ :events => hall::CHASERS }, :moving => true, :label => :afc_hall_chaser)
    arrival_hint :afc_hall_rule, :once => true
    hall::DUE.each do |id|
      phase lambda { PokeAccess::AshenTempleHall.due?(id) },
            :hint => lambda { PokeAccess::AshenTempleHall.hint(id) }
    end
    solved(nil, :quiet => true) { !PokeAccess::AshenTempleHall.open? }
  end
  mechanic(:state, 686, :part => :hall) do
    sent_back :afc_hall_caught, :maps => [hall::MAP], :to => [23, 6]
  end
end
