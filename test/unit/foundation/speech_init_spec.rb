# The speech-init state machine (F-L08-001): init happens ONCE and honours the result; a failure stays
# failed with no background retry, and retry_init! (the Ctrl+Alt+F8 re-enable gesture) is the only way
# to try again. Under the harness the stub Win32API always constructs and its call returns 0, so PEA_INIT
# is NOT nil: PeaInitialize "runs" and reports failure, which exercises exactly the "init failed" branch
# (not the missing-DLL branch) without extra stubbing.
Suite.define("speech: init attempts once, stays failed, and retry_init! re-arms it") do
  prev_ready = PokeAccess.instance_variable_get(:@ready)
  prev_attempted = PokeAccess.instance_variable_get(:@init_attempted)
  begin
    PokeAccess.instance_variable_set(:@ready, false)
    PokeAccess.instance_variable_set(:@init_attempted, false)

    falsy "init_speech! reports failure when no bridge is available", PokeAccess.init_speech!
    truthy "the attempt is recorded", PokeAccess.instance_variable_get(:@init_attempted)
    falsy "ready stays false after a failed init", PokeAccess.instance_variable_get(:@ready)
    falsy "a second call reports failure again (retry-vs-memo indistinguishable without a DLL)", PokeAccess.init_speech!

    falsy "retry_init! re-attempts (and fails again without a bridge)", PokeAccess.retry_init!
    truthy "retry left the attempt recorded again", PokeAccess.instance_variable_get(:@init_attempted)

    PokeAccess.instance_variable_set(:@ready, true)
    truthy "once ready, init_speech! short-circuits true", PokeAccess.init_speech!
    truthy "retry_init! on a healthy bridge is a no-op true", PokeAccess.retry_init!
  ensure
    PokeAccess.instance_variable_set(:@ready, prev_ready)
    PokeAccess.instance_variable_set(:@init_attempted, prev_attempted)
  end
end

# The prism voice primitives never raise without the bridge: control calls report false, speaking?
# reports nil (unknown -- callers must not read it as silence), and the backend name is empty.
Suite.define("speech: voice primitives degrade safely without a bridge") do
  falsy "stop_speech is a safe false", PokeAccess.stop_speech
  falsy "pause_speech is a safe false", PokeAccess.pause_speech
  falsy "resume_speech is a safe false", PokeAccess.resume_speech
  truthy "speaking? is nil (unknown), not false", PokeAccess.speaking?.nil?
  falsy "braille is a safe false", PokeAccess.braille("abc")
  eq "speech_backend is empty", PokeAccess.speech_backend, ""
end

# codepoints_to_utf8 hand-encodes BMP codepoints (1.8.7 has no Encoding API): ASCII stays 1 byte,
# Latin-1 supplement takes 2, braille patterns (U+28xx) take 3. Compared as byte arrays so the spec
# is immune to string-encoding rules across Ruby versions.
Suite.define("speech: codepoints_to_utf8 encodes ASCII, 2-byte and 3-byte ranges") do
  eq "plain ASCII passes through", PokeAccess.codepoints_to_utf8([0x61, 0x62, 0x63]).unpack("C*"),
     [0x61, 0x62, 0x63]
  eq "2-byte range (U+00F1)", PokeAccess.codepoints_to_utf8([0xF1]).unpack("C*"), [0xC3, 0xB1]
  eq "3-byte braille cell (U+283A)", PokeAccess.codepoints_to_utf8([0x283A]).unpack("C*"),
     [0xE2, 0xA0, 0xBA]
  eq "mixed braille and space", PokeAccess.codepoints_to_utf8([0x2801, 0x20, 0x2803]).unpack("C*"),
     [0xE2, 0xA0, 0x81, 0x20, 0xE2, 0xA0, 0x83]
end
