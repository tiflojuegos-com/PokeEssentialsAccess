module PokeAccess
  module Util
    # Splits a play-time in seconds into [hours, minutes], the form every trainer-card / save-slot reader
    # speaks. Centralised because the two equivalent minute formulas ((s%3600)/60 vs (s/60)%60) were copied
    # inconsistently across readers. nil seconds -> nil. 1.8.7-safe.
    def self.playtime_parts(secs)
      return nil if secs.nil?
      s = secs.to_i
      [s / 3600, (s % 3600) / 60]
    end

    # Seconds of play time from whatever a screen was handed in its play-time slot. v19+ passes the stats
    # object; both Infinite Fusion games kept the older signature -- pbStartScene(commands, show_continue,
    # trainer, frame_count, map_id) -- and pass a raw Graphics frame count there, so asking it for play_time
    # answered nothing and the Continue panel never said how long the save had been played.
    def self.playtime_seconds_of(v)
      return nil if v.nil?
      s = (v.play_time rescue nil)
      return s.to_i if s
      return nil unless v.is_a?(Numeric)
      fr = (Graphics.frame_rate rescue 0).to_i
      fr > 0 ? v.to_i / fr : nil
    rescue StandardError
      nil
    end

    # Seconds of play time, asked the way each era actually stores it. v19+ keeps a real counter on $stats;
    # gen-6 keeps none at all and every screen that shows the figure derives it from the saved frame count,
    # which is exactly what all seven gen-6 games do. The reader used to ask $PokemonGlobal for a playTime
    # accessor that exists in NONE of the thirteen, so the guard was never true and the line was simply never
    # spoken on that half of the catalogue. nil when neither source answers.
    def self.playtime_seconds
      s = ($stats.play_time rescue nil)
      return s.to_i if s
      fr = (Graphics.frame_rate rescue 0).to_i
      fc = (Graphics.frame_count rescue nil)
      return nil unless fc && fr > 0
      fc.to_i / fr
    rescue StandardError
      nil
    end

    # Whether the player has seen (or owns) a species, tolerant of how each engine exposes the Pokedex:
    # gen-6 keeps plain seen/owned arrays on the trainer, while v18+ replaced them with seen?/owned?
    # predicates (on the player itself, or on a nested pokedex object -- one fangame's Player::Pokedex
    # routes its custom species through them). Reading only the gen-6 arrays left the dex list silent on v18 games.
    # Returns true/false, or nil when nothing resolves, so a caller can tell "not seen" from "unknown".
    def self.dex_seen?(sp);  dex_flag(sp, :seen?, :seen);   end
    def self.dex_owned?(sp); dex_flag(sp, :owned?, :owned); end

    # Shared probe for dex_seen?/dex_owned?: the predicate first (player, then its pokedex), the array last.
    def self.dex_flag(sp, pred, arr)
      who = PokeAccess::Engine.player
      return nil if who.nil? || sp.nil?
      v = (who.send(pred, sp) rescue nil)
      return (v ? true : false) unless v.nil?
      dex = (who.pokedex rescue nil)
      if dex
        v = (dex.send(pred, sp) rescue nil)
        return (v ? true : false) unless v.nil?
      end
      a = (who.send(arr) rescue nil)
      return (a[sp] ? true : false) unless a.nil?
      nil
    rescue StandardError
      nil
    end

    # The number of badges a player/trainer holds, tolerant of how the engine exposes it: numbadges or
    # badge_count when present, else counting the truthy entries of the badges array. nil when none resolves.
    def self.badge_count(who)
      n = (who.numbadges rescue nil)
      n = (who.badge_count rescue nil) if n.nil?
      if n.nil?
        b = (who.badges rescue nil)
        n = b.count { |x| x } if b.is_a?(Array)
      end
      n
    rescue StandardError
      nil
    end
  end
end
