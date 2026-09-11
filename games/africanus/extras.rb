# Two things Africanvs shows as pixels only. The badge ceremony (renderBadgeAnimation, 0223) paints the
# badge's name through pbDrawOutlineText, which no capture wraps, over 224 frames of jingle -- and seven of
# the eight badges are never named in the dialogue around it. The team panel marks the member holding the
# game's own Exp. Share flag (pk.expshare, an attribute only this game has) with an icon nothing said.
module PokeAccess
  module AfricanusExtras
    # The badge's name as the ceremony paints it, from the game's own table, or nil.
    def self.badge_name(n)
      names = PokeAccess.const_at("FANCY_BADGE_NAMES")
      names.is_a?(Array) ? names[n.to_i] : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("africanus") do
  kernel("renderBadgeAnimation", :before) do |args, _r|
    t = PokeAccess::AfricanusExtras.badge_name(args[0] || 0)
    PokeAccess.speak_clean(t, false) if t
  end

  override(PokeAccess::Party, :icon_mark_list) do |_mod, original, args|
    marks = original.call
    pk = args[0]
    marks.push("reparte experiencia") if (pk.expshare rescue false) && !PokeAccess::Summary.egg?(pk)
    marks
  end
end
