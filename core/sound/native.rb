module PokeAccess
  module Sound
    # The positional engine's entry points in PA3D_steam.dll (Steam Audio HRTF through miniaudio), bound on first use.
    # A shadow, anything answering has?(name) and call(name, *args), takes the dll's place in the tests.
    module Native
      DLL = "PA3D_steam.dll"
      # Entry point => [the dll's name for it, argument types, return type].
      SIGS = {
        :init => ["PA3D_Init", [], "i"], :channel => ["PA3D_Channel", ["p", "i"], "i"],
        :listener => ["PA3D_Listener", ["i", "i"], "v"], :set => ["PA3D_Set", ["i", "i", "i", "i", "i"], "v"],
        :master => ["PA3D_Master", ["i"], "v"], :rate => ["PA3D_Rate", [], "i"], :latency => ["PA3D_Latency", [], "i"],
        :occl => ["PA3D_Occl", ["i", "i"], "v"], :air => ["PA3D_Air", ["i"], "v"],
        :pitch => ["PA3D_Pitch", ["i", "i"], "v"], :range => ["PA3D_Range", ["i"], "v"]
      }
      # The entry points the engine cannot run without.
      NEEDED = [:init, :channel, :listener, :set, :master]

      @fns = nil
      @shadow = nil

      class << self
        attr_accessor :shadow
      end

      # The entry points, bound once; nil for one the dll lacks.
      def self.fns
        return @fns if @fns
        @fns = {}
        SIGS.each { |name, sig| @fns[name] = (Win32API.new(DLL, sig[0], sig[1], sig[2]) rescue nil) }
        @fns
      end

      # Whether an entry point is there (as the shadow says, with one).
      def self.has?(name); @shadow ? @shadow.has?(name) : !fns[name].nil?; end

      # Whether the engine can run: every entry point it needs is there.
      def self.available?; NEEDED.all? { |n| has?(n) }; end

      # Calls an entry point, nil when it is not there.
      def self.call(name, *args)
        return @shadow.call(name, *args) if @shadow
        f = fns[name]
        f ? f.call(*args) : nil
      end
    end
  end
end
