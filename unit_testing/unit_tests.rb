require "test/unit"
require "fileutils"

# in this case this file does not to be included, since we are not directly referencing its methods for the js test.
# however generally we'll want to require files that we're testing, and this can serve as a reminder to do it next time.
require_relative "../epubmaker_postprocessing.rb"
require_relative "../metadata_preprocessing.rb"

class AddonsTests < Test::Unit::TestCase

  #################### VARIABLES
  @@test_html_good = File.join(File.dirname(__FILE__), "test_html_good.html")
  @@test_html_bad = File.join(File.dirname(__FILE__), "test_html_bad.html")
  @@test_html_bad_tmp = File.join(File.dirname(__FILE__), "test_html_bad_tmp.html")
  @@test_html_good_tmp = File.join(File.dirname(__FILE__), "test_html_good_tmp.html")

  #################### METHODS
  def self.getHTMLfileContents(html_file)
    filecontents = File.read(html_file)
    return filecontents
  rescue => e
    return e.inspect
  end

  def self.overwriteFile(path,filecontents)
    File.open(path, 'w') do |output|
      output.write filecontents
    end
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


  #################### SETUP for Unit Testing
  # read in external html for tests, set HTML contents as class vars so they are accessbile in test methods
  @@html_contents_fixed = getHTMLfileContents(@@test_html_good)
  @@html_contents_broken = getHTMLfileContents(@@test_html_bad)

puts @@html_contents_fixed

  # reset node_html
  overwriteFile(@@test_html_bad_tmp, @@html_contents_broken)
  overwriteFile(@@test_html_good_tmp, @@html_contents_fixed)


  ################### BEGIN Unit Testing!!

  def testEpubmakerPostprocessingJS
    # define our js file (path relative to this script)
    epubmaker_postprocessing_js = File.join(File.expand_path("..", File.dirname(__FILE__)), "epubmaker_postprocessing.js")

    # run our js tests
    self.class.localRunNode(epubmaker_postprocessing_js, @@test_html_bad_tmp)
    self.class.localRunNode(epubmaker_postprocessing_js, @@test_html_good_tmp)

    # read the updated html
    html_contents_bad_tmp = self.class.getHTMLfileContents(@@test_html_bad_tmp)
    html_contents_good_tmp = self.class.getHTMLfileContents(@@test_html_good_tmp)

    # assertions
    assert_equal(html_contents_bad_tmp, @@html_contents_fixed)
    assert_equal(html_contents_good_tmp, @@html_contents_fixed)
  end

  # reset node_html
  overwriteFile(@@test_html_bad_tmp, @@html_contents_broken)
  overwriteFile(@@test_html_good_tmp, @@html_contents_broken)


  def testMetadataPreprocessing
    # read the updated html contents
    # (no longer necessary for these tests, as the function being tested was updated to take a file as an argument..
    #   but good to have as an example for future tests)
    html_contents_bad_tmp = self.class.getHTMLfileContents(@@test_html_bad_tmp)
    html_contents_good_tmp = self.class.getHTMLfileContents(@@test_html_good_tmp)

    ### Assertions:
    # method: setAuthorInfo
    assert_equal(setAuthorInfo({}, @@test_html_bad_tmp), "Alva Noë, Keenan Tester, Linda Tester")
    assert_equal(setAuthorInfo({}, @@test_html_good_tmp), "Alva Noë, Keenan Tester, Linda Tester")
    assert_equal(setAuthorInfo({}, ''), "")
    # method: setBookSubtitle
    assert_equal(setBookSubtitle({}, @@test_html_bad_tmp), "Art and Human Nature Or, How I Became an Artist")
    assert_equal(setBookSubtitle({}, @@test_html_good_tmp), "Art and Human Nature Or, How I Became an Artist")
    assert_equal(setBookSubtitle({}, ''), "")
    # method: setBookTitle
    assert_equal(setBookTitle({}, @@test_html_bad_tmp), "Strange Tools")
    assert_equal(setBookTitle({}, @@test_html_good_tmp), "Strange Tools")
    assert_equal(setBookTitle({}, ''), "")

  end

end
