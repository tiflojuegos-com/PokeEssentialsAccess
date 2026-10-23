# The run's net for uncleaned speech (SpeakCapture): a text that reaches speak with a code clean() strips is filed
# against the test that spoke it, plain text and whitespace are not, and only the start of an engine pass empties it.
class SpeakNetTest < PokeAccessTest
  test "files a text with each family of raw code against the test that spoke it" do
    codes = ["\\c[3]sonda", "\\PN gana", "espera\\.", "cierra\\^", "<b>sonda</b>", "</ac>sonda", "sonda|sonda",
             "sonda#{7.chr}", "sonda#{27.chr}"]
    codes.each do |text|
      assert_equal [[PokeAccessTest.current, text]], netted { PokeAccess.speak(text, true) }, "for #{text.inspect}"
    end
  end

  test "lets plain text and whitespace through" do
    ["sonda\tuno", "sonda\nuno", "sonda\r\nuno", "vida <3", "50 \\ 2", "precio: 3$"].each do |text|
      assert_equal [], netted { PokeAccess.speak(text, true) }, "for #{text.inspect}"
    end
  end

  test "keeps the offenders through clear" do
    filed = netted do
      PokeAccess.speak("\\c[3]sonda", true)
      SpeakCapture.clear
    end
    assert_equal [[PokeAccessTest.current, "\\c[3]sonda"]], filed
  end

  test "empties the offenders and the log at the start of an engine pass" do
    net = SpeakCapture.raw_offenders
    saved = net.dup
    PokeAccess.speak("\\c[3]sonda", true)
    SpeakCapture.clear_all
    assert_equal [[], []], [net, SpeakCapture.log]
  ensure
    net.replace(saved) if saved
  end

  private

  # The offenders the block filed, taken back out of the net so the run does not fail on them.
  def netted
    net = SpeakCapture.raw_offenders
    base = net.length
    yield
    net[base..-1]
  ensure
    net.slice!(base..-1) if base
  end
end
