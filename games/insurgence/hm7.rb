# MGC H-Mode7 hands RGSS bitmap internals to MGC_Hmode7.dll, which mkxp-z lacks, so its maps kill the game: the switch
# always reads false and they draw flat, a loaded save included. A plain method, not a hook, so no read escapes it.
PokeAccess::Game.define("insurgence") do
  if ::Game_System.method_defined?(:hm7)
    ::Game_System.class_eval do
      def hm7
        false
      end
    end
  end
end
