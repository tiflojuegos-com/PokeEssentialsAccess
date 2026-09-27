module PokeAccess
  # The blessings of Rejuvenation's Xen tower: the pick after a floor (BlessingsScene), up to three painted boxes, each
  # a blessing's name with its rank in Roman numerals over its description, chosen with up and down; and the overlay
  # of those gained (BlessingsOverlay, X on the tower's map or Shift in battle), a grid of icons whose info window
  # names the one under the cursor.
  module RejuvBlessings
    # How many places the pick's arrow stops at: each box, and a third, empty one once there are two, since the
    # arrow wraps at three.
    def self.slots(list)
      list.length > 1 ? 3 : list.length
    end

    # The blessing at i as its box paints it, with its place among the arrow's stops; the empty stop as such.
    def self.text(scene, i)
      list = PokeAccess.ivar(scene, :@blessings)
      n = slots(list)
      b = list[i]
      return PokeAccess::I18n.t(:rj_blessing_empty, :i => i + 1, :n => n) if b.nil?
      rank = PokeAccess.ivar(PokeAccess.sprite(scene, "blessing#{i}"), :@rank)
      PokeAccess::I18n.t(:rj_blessing, :name => PokeAccess.clean(getBlessingName(b)), :rank => rank,
                         :desc => PokeAccess.clean(getBlessingDesc(b, rank)), :i => i + 1, :n => n)
    rescue StandardError
      nil
    end

    # Says the focused blessing when the arrow lands on a new one: the first queued, later moves cutting in.
    def self.follow(scene)
      i = PokeAccess.ivar(scene, :@index)
      return unless i.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :rj_blessing, i, true, false) { text(scene, i) }
    end

    # The blessing under the overlay's cursor as its info window paints it: name, rank and description, then its
    # rules; an empty cell of a short last row as empty.
    def self.overlay_text(ov)
      list = getPlayerBlessings.keys
      i = PokeAccess.ivar(ov, :@index).to_i
      b = list[i]
      return PokeAccess::I18n.t(:row_empty) if b.nil?
      rank = getBlessingRank(b)
      rules = Array(getBlessingRules(b)).map { |r| PokeAccess.clean(r.to_s) }.reject { |r| r.empty? }
      line = PokeAccess::I18n.t(:rj_blessing, :name => PokeAccess.clean(getBlessingName(b)), :rank => rank,
                                :desc => PokeAccess.clean(getBlessingDesc(b, rank, true)), :i => i + 1, :n => list.length)
      PokeAccess.sentences([line] + rules)
    rescue StandardError
      nil
    end

    # The overlay takes the focus: its next read says how many blessings there are first.
    def self.overlay_opened(ov)
      @opening = true
      PokeAccess::Cursor.reset(ov, :rj_bless_ov)
    end

    # Says the blessing under the overlay's cursor while the overlay has the focus: on opening queued, after how many
    # there are; on each move, cutting in.
    def self.follow_overlay(ov)
      return unless PokeAccess.ivar(ov, :@focused)
      opening = @opening
      @opening = false
      PokeAccess::Cursor.announce(ov, :rj_bless_ov, PokeAccess.ivar(ov, :@index).to_i, true, false) do
        t = overlay_text(ov)
        opening ? PokeAccess.sentences([PokeAccess::I18n.t(:rj_blessings_count, :n => getPlayerBlessings.length), t]) : t
      end
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("BlessingsScene", :changeIndex, :optional => true) do |scene, _r, _a|
    PokeAccess::RejuvBlessings.follow(scene)
  end

  before("BlessingsOverlay", :focus, :optional => true) do |ov, _a|
    PokeAccess::RejuvBlessings.overlay_opened(ov)
  end

  after("BlessingsOverlay", :updateInfoWindow, :optional => true) do |ov, _r, _a|
    PokeAccess::RejuvBlessings.follow_overlay(ov)
  end
end
