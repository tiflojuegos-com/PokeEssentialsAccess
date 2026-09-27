module PokeAccess
  module Util
    # A play time in seconds as [hours, minutes]; nil for nil.
    def self.playtime_parts(secs)
      return nil if secs.nil?
      s = secs.to_i
      [s / 3600, (s % 3600) / 60]
    end

    # Seconds of play time from a screen's play-time argument: a stats object's play_time, or a raw frame count
    # (Infinite Fusion's older pbStartScene signature) divided by the frame rate.
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

    # Seconds of play time: $stats.play_time, else Graphics.frame_count over the frame rate (gen-6 keeps no
    # counter); nil when neither answers.
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

    # A start date as day, month and year in the language's order, the month named by the game (full name, else
    # abbreviation, else its number); nil with no date.
    def self.start_date_text(t)
      return nil unless t
      mon = (pbGetMonthName(t.mon) rescue nil)
      mon = (pbGetAbbrevMonthName(t.mon) rescue nil) if mon.nil? || mon.to_s.empty?
      mon = t.mon.to_s if mon.nil? || mon.to_s.empty?
      PokeAccess::I18n.t(:tcard_date, :d => t.day, :m => mon, :y => t.year)
    rescue StandardError
      nil
    end

    # The start-day line of a trainer card, or nil when the save carries no start time.
    def self.started_line
      d = start_date_text(($PokemonGlobal.startTime rescue nil))
      d ? PokeAccess::I18n.t(:tcard_started, :date => d) : nil
    end

    # Whether the player has seen (or owns) a species: true/false, or nil when no Pokedex source answers.
    def self.dex_seen?(sp);  dex_flag(sp, :seen?, :seen);   end
    def self.dex_owned?(sp); dex_flag(sp, :owned?, :owned); end

    # Shared probe for dex_seen?/dex_owned?: the predicate first (player, then its pokedex), the array, and last the
    # species row an engine's data provider keeps (a Hash keyed by the predicate's name).
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
      row = PokeAccess::Data.optional(:dex_row, sp)
      row ? (row[pred] ? true : false) : nil
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
