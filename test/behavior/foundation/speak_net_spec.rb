# The net that fails the run when a reader hands speak an uncleaned text. It guards every suite, so it is
# the one piece nothing else guards: these probes prove it fires for each family clean() strips, and that
# clear() -- which specs call freely between assertions -- cannot wash the evidence away.
Suite.define("runner: la red anti-codigos dispara y sobrevive a clear") do
  base = SpeakCapture.raw_offenders.length
  PokeAccess.speak("\\c[3]sonda", true)
  eq("un codigo de barra queda registrado", SpeakCapture.raw_offenders.length, base + 1)
  SpeakCapture.clear
  eq("clear no lava a los infractores", SpeakCapture.raw_offenders.length, base + 1)
  PokeAccess.speak("<b>sonda</b>", true)
  PokeAccess.speak("sonda|sonda", true)
  PokeAccess.speak("sonda" + 7.chr, true)
  eq("marcado, pipe y byte de control tambien disparan", SpeakCapture.raw_offenders.length, base + 4)
  SpeakCapture.raw_offenders.slice!(base, 4)
  eq("sondas retiradas del registro", SpeakCapture.raw_offenders.length, base)
end
