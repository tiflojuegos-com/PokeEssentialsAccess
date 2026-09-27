# Fancy Badges (Luka S.J.): renderBadgeAnimation(n) spins badge n and paints its name under it, from
# FANCY_BADGE_NAMES in the script copies and FancyBadges::NAMES in the v20+ plugin; said as the ceremony starts.
module PokeAccess
  module BadgeCeremony
    # The name the ceremony paints for badge n, or nil.
    def self.badge_name(n)
      names = PokeAccess.const_at("FANCY_BADGE_NAMES") || PokeAccess.const_at("FancyBadges::NAMES")
      names.is_a?(Array) ? names[n.to_i] : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.wrap_kernel("renderBadgeAnimation", "plugin_fancy_badges", :before) do |args, _r|
  t = PokeAccess::BadgeCeremony.badge_name(args[0] || 0)
  PokeAccess.speak_clean(t, false) if t
end
