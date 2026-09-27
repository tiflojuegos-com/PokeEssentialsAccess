module PokeAccess
  # What the mod knows about third-party plugin readers (plugins/), filled in by the loader; nothing here loads.
  module Plugins
    # The plugin readers loaded this session.
    def self.loaded; @loaded ||= []; end

    # Records one, called by the loader as it evaluates each declared reader.
    def self.note_loaded(name); loaded.push(name.to_s) unless loaded.include?(name.to_s); end

    # name => the probe that gives that plugin away (from plugins/manifest.rb): a class name or "Class#method".
    def self.table; @table ||= {}; end
    def self.table=(t); @table = t.is_a?(Hash) ? t : {}; end


    # The plugins the game's own PluginManager registers, as "name version", for the diagnostic; nil without a
    # PluginManager (older games paste plugins into their scripts), not an empty list.
    def self.game_plugins
      pm = PokeAccess.const_at("PluginManager")
      return nil unless pm && pm.respond_to?(:plugins)
      names = (pm.plugins rescue nil)
      return nil unless names.is_a?(Array)
      names.map do |n|
        v = (pm.version(n) rescue nil)
        (v && !v.to_s.empty?) ? "#{n} #{v}" : n.to_s
      end.sort
    rescue StandardError
      nil
    end

    # Plugins this game has (by their Engine.has? probe) whose reader was not loaded, so they run mute.
    def self.undeclared
      out = []
      table.each do |name, probe|
        next if loaded.include?(name.to_s)
        next unless (PokeAccess::Engine.has?(probe.to_s) rescue false)
        out.push(name.to_s)
      end
      out.sort
    end
  end
end
