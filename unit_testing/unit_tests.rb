require "test/unit"
require "fileutils"

require_relative "../htmlmaker_postprocessing.rb"


class HtmlmakerPostProcessing_Tests < Test::Unit::TestCase

  ########## VARIABLES
  @@test_html_good = File.join(File.dirname(__FILE__), "test_html_good.html")
  @@test_html_bad = File.join(File.dirname(__FILE__), "test_html_bad.html")
  @@test_html_bad_tmp = File.join(File.dirname(__FILE__), "test_html_bad_tmp.html")
  @@test_html_good_tmp = File.join(File.dirname(__FILE__), "test_html_good_tmp.html")

  ########## METHODS
  def self.getHTMLfileContents(html_file)
    filecontents = File.read(html_file)
    return filecontents
  rescue => e
    return e.inspect
  end

  def self.overwriteFile(path,filecontents)
  	Mcmlln::Tools.overwriteFile(path, filecontents)
  rescue => e
    return e.inspect
  end

  def self.localRunNode(js, args)
    if (RUBY_PLATFORM.match('darwin')) || (RUBY_PLATFORM.match('linux'))   # for Mac OS or Unix (Travis)
      `node #{js} #{args}`
    elsif RUBY_PLATFORM.match('mingw')    # for Windows
      nodepath = File.join(Paths.resource_dir, "nodejs", "node.exe")
      `#{nodepath} #{js} #{args}`
    end
  rescue => e
    return e.inspect
  end


  ########## SETUP for Unit Testing
  # read in external html for tests
  # set HTML contents as class vars so they are accessbile in test methods
  @@html_contents_fixed = getHTMLfileContents(@@test_html_good)
  @@html_contents_broken = getHTMLfileContents(@@test_html_bad)

  # reset node_html
  overwriteFile(@@test_html_bad_tmp, @@html_contents_broken)
  overwriteFile(@@test_html_good_tmp, @@html_contents_broken)


  ########## BEGIN Unit Testing!!
  # def test_fixISBNSpans
  #   bad_isbn_span1 = '<span class="spanISBNisbn">9780123456789</span><span class="spanISBNisbn">ISBN 9780123456789 (hardcover)</span><span class="spanISBNisbn">9780123456789</span>'
  #   bad_isbn_span2 = '<span class="spanISBNisbn">9780123456789</span>ISBN <span class="spanISBNisbn">9780123456789 (hardcover)</span><span class="spanISBNisbn">9780123456789</span>'
  #   bad_isbn_span3 = '<span class="spanISBNisbn">9780123456789</span><span class="spanISBNisbn">ISBN 9780123456789</span> (hardcover)<span class="spanISBNisbn">9780123456789</span>'
  #   fixed_isbn_span = '<span class="spanISBNisbn">9780123456789</span>ISBN <span class="spanISBNisbn">9780123456789</span> (hardcover)<span class="spanISBNisbn">9780123456789</span>'
  #
  #   assert_equal(fixISBNSpans(bad_isbn_span1), fixed_isbn_span)
  #   assert_equal(fixISBNSpans(bad_isbn_span2), fixed_isbn_span)
  #   assert_equal(fixISBNSpans(bad_isbn_span3), fixed_isbn_span)
  # end


  def testHTMLpostprocessingJS
    # define our js file
    htmlmakerpostprocessingjs = File.join(File.expand_path("..", File.dirname(__FILE__)), "test.js") #"htmlmaker_postprocessing.js")

    # run our js tests
    self.class.localRunNode(htmlmakerpostprocessingjs, @@test_html_bad_tmp)
    self.class.localRunNode(htmlmakerpostprocessingjs, @@test_html_good_tmp)

    # read the updated html
    html_contents_bad_tmp = self.class.getHTMLfileContents(@@test_html_bad_tmp)
    html_contents_good_tmp = self.class.getHTMLfileContents(@@test_html_good_tmp)

    # make bold assertions! ;)
    assert_equal(html_contents_bad_tmp, @@html_contents_fixed)
    assert_equal(html_contents_good_tmp, @@html_contents_fixed)
  end

end
