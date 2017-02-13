require "test/unit"
require "fileutils"

puts "TRAVIS_TEST is: ", ENV['TRAVIS_TEST']

require_relative "../htmlmaker_postprocessing.rb"

class HtmlmakerPostProcessing_Tests < Test::Unit::TestCase

  test_html_good = File.join(File.dirname(__FILE__), "test_html_good.html")
  test_html_bad = File.join(File.dirname(__FILE__), "test_html_bad.html")

  # read in external html for tests
  def self.getHTMLfileContents(html_file)
    filecontents = File.read(html_file)
    return filecontents
  rescue => e
    return e.inspect
  end

  #set external HTML contents as constant
  HTMLfile_fixed = getHTMLfileContents(test_html_good)
  HTMLfile_broken = getHTMLfileContents(test_html_bad)


  ########## Begin unit testing

  def test_fixISBNSpans

    bad_isbn_span1 = '<span class="spanISBNisbn">9780123456789</span><span class="spanISBNisbn"> ^9780123456789 *K</span><span class="spanISBNisbn">9780123456789</span>'
    bad_isbn_span2 = '<span class="spanISBNisbn">9780123456789</span> ^<span class="spanISBNisbn">9780123456789 *K</span><span class="spanISBNisbn">9780123456789</span>'
    bad_isbn_span3 = '<span class="spanISBNisbn">9780123456789</span><span class="spanISBNisbn"> ^9780123456789</span> *K<span class="spanISBNisbn">9780123456789</span>'
    fixed_isbn_span = '<span class="spanISBNisbn">9780123456789</span> ^<span class="spanISBNisbn">9780123456789</span> *K<span class="spanISBNisbn">9780123456789</span>'

    assert_equal(fixISBNSpans(bad_isbn_span1), fixed_isbn_span)
    assert_equal(fixISBNSpans(bad_isbn_span2), fixed_isbn_span)
    assert_equal(fixISBNSpans(bad_isbn_span3), fixed_isbn_span)
    assert_equal(fixISBNSpans(HTMLfile_broken), HTMLfile_fixed)
    assert_equal(fixISBNSpans(HTMLfile_fixed), HTMLfile_fixed)

  end

end
