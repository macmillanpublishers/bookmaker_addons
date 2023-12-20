require 'fileutils'
require 'htmlentities'
require 'nokogiri'

unless (ENV['TRAVIS_TEST']) == 'true'
  require_relative '../bookmaker/core/header.rb'
  require_relative '../bookmaker/core/metadata.rb'
  require_relative '../utilities/oraclequery.rb'
  require_relative '../utilities/isbn_finder.rb'
else
  puts " --- testing mode:  running travis build"
  require_relative './unit_testing/for_travis-bookmaker_submodule/bookmaker/core/header.rb'
end


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift

stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

xml_file = File.join(Bkmkr::Paths.project_tmp_dir, "#{Bkmkr::Project.filename}.xml")

title_js = File.join(Bkmkr::Paths.core_dir, "htmlmaker", "title.js")

check_for_element_js = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "check_for_element.js")

bookmaker_assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets")

# full path of lookup error file
dw_lookup_errfile = File.join(Metadata.final_dir, "ISBN_LOOKUP_ERROR.txt")
testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def readFile(file, logkey='')
	filecontents = File.read(file)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findBookISBNs_metadataPreprocessing(config_hash, isbn_stylename, logkey='')
  eisbn = ''
  allworks = []
  querystatus = ''
  # if we already have a printid or productid in config.json, use that for pisbn
  if config_hash.has_key?('printid') && config_hash['printid'] != 'TK'
    pisbn = config_hash['printid']
  # else do a lookup
  else
    pisbn, eisbn, allworks, querystatus = findBookISBNs(Bkmkr::Paths.outputtmp_html, Bkmkr::Project.filename, isbn_stylename)
  end
  # if we already have an ebookid in config.json, use that for eisbn
  if config_hash.has_key?('ebookid') && (config_hash['ebookid'] != 'TK' && !config_hash['ebookid'].empty?)
    eisbn = config_hash['ebookid']
  # if we didn't already have an eisbn from config.json or pisbn lookup, lookup from DW here
  elsif eisbn == '' and (querystatus == '' or querystatus == 'success')
    eisbn, allworks, querystatus = getEbookIsbn(pisbn)
    # we need something for eisbn for lookups/naming in epubmaker, and we encounterd an old reprint where no ebook product existed.
    if eisbn.empty?
      eisbn = pisbn
    end
  end
  if allworks.empty?
    allworks.push(pisbn, eisbn)
  end
  if querystatus != '' and querystatus != 'success'
    logstring = querystatus
  end
  return pisbn, eisbn, allworks, querystatus
rescue => logstring
  return '','','',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findTitlepageImages(allimg, finalimg, logkey='')
  #get images matching name from dir
  etparr1 = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
  ptparr1 = Dir[allimg].select { |f| f.include?('titlepage.')}
  etparr2 = Dir[finalimg].select { |f| f.include?('epubtitlepage.')}
  ptparr2 = Dir[finalimg].select { |f| f.include?('titlepage.')}

  #find epubtitlepage image matching name exactly, in order of precedence:
  # (files named epubtitlepage > new submittedimage > images from previous runs)
  if etparr1.any?
    epubtitlepage = etparr1.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  elsif etparr2.any?
    epubtitlepage = etparr2.find { |e| /[\/|\\]epubtitlepage\./ =~ e }
  elsif ptparr1.any?
    epubtitlepage = ptparr1.find { |e| /[\/|\\]titlepage\./ =~ e }
  elsif ptparr2.any?
    epubtitlepage = ptparr2.find { |e| /[\/|\\]titlepage\./ =~ e }
  else
    epubtitlepage = ""
  end

  # find podtitlepage matching name 'titlepage' exactly, prefer submitted images to those from prior runs
  podtitlepage = ""
  if ptparr1.any?
    podtitlepage = ptparr1.find { |e| /[\/|\\]titlepage\./ =~ e }
  elsif ptparr2.any?
    podtitlepage = ptparr2.find { |e| /[\/|\\]titlepage\./ =~ e }
  end
  if !podtitlepage
    podtitlepage = ""
  end

  return epubtitlepage, podtitlepage
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def findFrontCover(final_dir, allimg, allworks, logkey='')
  coverdir = File.join(final_dir, "cover")
  allcover = File.join(coverdir, "*")
  # first find any cover files in the submitted images dir
  fcarr1 = Dir[allimg].select { |f| f.include?('_FC.')}

  # now narrow down the list of found covers to only include files that match the book isbns
  fcarr2 = []
  if fcarr1.any?
    fcarr1.each do |c|
      cisbn = c.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop.split("_").shift
      if allworks.include?(cisbn)
        fcarr2.push(c)
      end
    end
  end

  # now let's see if there are any old covers in the done dir
  if File.exist?(coverdir)
    fcarr3 = Dir[allcover].select { |f| f.include?('_FC.')}
  else
    fcarr3 = []
  end

  # priority is given to any newly submitted cover images
  if fcarr2.any?
    mycover = fcarr2.max_by(&File.method(:ctime))
    frontcover = mycover.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  elsif fcarr3.any?
    mycover = fcarr3.max_by(&File.method(:ctime))
    frontcover = mycover.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  else
    frontcover = ""
  end

  return frontcover
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def databaseLookup(pisbn, eisbn, logkey='')
  # validate 13 digit isbn
  test_pisbn_chars = pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_pisbn_length = pisbn.split(%r{\s*})
  test_eisbn_chars = eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_eisbn_length = eisbn.split(%r{\s*})

  # get a hash of edition information, attempt pisbn first, use eisbn as backup
  if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
    thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
    myhash, querystatus = runQuery(thissql)
    if querystatus == 'success' and (myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] and test_eisbn_length.length == 13 and test_eisbn_chars.length != 0)
      thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
      myhash, querystatus = runQuery(thissql)
    end
  elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
    thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    myhash, querystatus = runQuery(thissql)
  else
    myhash = {}
  end
  #  setup logstring based on query returns
  logstring = querystatus
  if querystatus == 'success' and (myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'])
    logstring = "No DB record found; removing author links for addons"
  elsif querystatus == 'success'
    logstring = "DB Connection SUCCESS: Found an author record"
  end

  return myhash, querystatus
rescue => logstring
  return {}, ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setAuthorInfo(config_hash, myhash, htmlfile, author_selector, logkey='')
  if config_hash.has_key?('author') && config_hash['author'] != 'TK'
    authorname = config_hash['author']
  else
    # get the page tree via nokogiri
    page = Nokogiri::HTML(open(htmlfile))
    # get meta info from html if it exists
    metabookauthor = page.xpath('//meta[@name="author"]/@content')
    # Finding book title
    if !metabookauthor.empty?
      puts "Getting book AUTHOR from meta element"
      authorname = HTMLEntities.new.decode(metabookauthor).encode('utf-8')
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
      puts "Getting book AUTHOR from titlepage"
      names = []
      authorname = page.css(author_selector)
      authorname.each do |t|
        names << t.text
      end
      authorname = names.join(", ")
      authorname = HTMLEntities.new.decode(authorname).encode('utf-8')
    else
      puts "Getting book AUTHOR from config"
      authorname = myhash['book']['WORK_COVERAUTHOR']
      authorname = authorname.encode('utf-8')
    end
  end
  return authorname
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setBookTitle(config_hash, myhash, htmlfile, title_selector, logkey='')
  if config_hash.has_key?('title') && config_hash['title'] != 'TK'
    booktitle = config_hash['title']
  else
    # get the page tree via nokogiri
    page = Nokogiri::HTML(open(htmlfile))
    # get meta info from html if it exists
    metabooktitle = page.xpath('//meta[@name="title"]/@content')
    # Finding book title
    if !metabooktitle.empty?
      puts "Getting book TITLE from meta element"
      booktitle = HTMLEntities.new.decode(metabooktitle).encode('utf-8')
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
      puts "Getting book TITLE from titlepage"
      titles = []
      booktitle = page.css(title_selector)
      booktitle.each do |t|
        titles << t.text
      end
      booktitle = titles.join(" ")
      booktitle = HTMLEntities.new.decode(booktitle).encode('utf-8')
    else
      puts "Getting book TITLE from config"
      booktitle = myhash["book"]["WORK_COVERTITLE"]
      booktitle = booktitle.encode('utf-8')
    end
  end
  return booktitle
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setBookSubtitle(config_hash, myhash, htmlfile, subtitle_selector, logkey='')
  if config_hash.has_key?('subtitle') && config_hash['subtitle'] != 'TK'
    booksubtitle = config_hash['subtitle']
  else
    # get the page tree via nokogiri
    page = Nokogiri::HTML(open(htmlfile))
    # get meta info from html if it exists
    metabooksubtitle = page.xpath('//meta[@name="subtitle"]/@content')
    # Finding book title
    if !metabooksubtitle.empty?
      puts "Getting book SUBTITLE from meta element"
      booksubtitle = HTMLEntities.new.decode(metabooksubtitle).encode('utf-8')
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
      puts "Getting book SUBTITLE from titlepage"
      subtitles = []
      booksubtitle = page.css(subtitle_selector)
      booksubtitle.each do |t|
        subtitles << t.text
      end
      booksubtitle = subtitles.join(" ")
      booksubtitle = HTMLEntities.new.decode(booksubtitle).encode('utf-8')
    else
      puts "Getting book SUBTITLE from config"
      booksubtitle = myhash["book"]["WORK_SUBTITLE"]
      booksubtitle = booksubtitle.encode('utf-8')
    end
  end
  return booksubtitle
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# find the publisher imprint based on the imprints.json database
# only called (by the following method) if biblio data & html metadata unavailable
def getImprint(projectdir, json, logkey='')
  data_hash = Mcmlln::Tools.readjson(json)
  arr = []
  # loop through each json record to see if imprint name matches formalname
  data_hash['imprints'].each do |p|
    if p['shortname'] == projectdir
      arr << p['formalname']
    end
  end
  # in case of multiples, grab just the last entry and return it
  if arr.nil? or arr.empty?
    path = "Macmillan"
  else
    path = arr.pop
  end
  return path
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setImprint(config_hash, myhash, htmlfile, project_dir, imprint_json, logkey='')
  if config_hash.has_key?('imprint') && config_hash['imprint'] != 'TK'
    imprint = config_hash['imprint']
  else
    # get the page tree via nokogiri
    page = Nokogiri::HTML(open(htmlfile))
    # get meta info from html if it exists
    metaimprint = page.xpath('//meta[@name="imprint"]/@content')
    # Finding imprint name
    if !metaimprint.empty?
      puts "Getting book IMPRINT from meta element"
      imprint = HTMLEntities.new.decode(metaimprint)
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["IMPRINT_DESC"].nil? or myhash["book"]["IMPRINT_DESC"].empty? or !myhash["book"]["IMPRINT_DESC"]
      puts "Getting book IMPRINT from config json"
      imprint = getImprint(project_dir, imprint_json, 'get_imprint_from_json')
    else
      puts "Getting book IMPRINT from database"
      imprint = myhash["book"]["IMPRINT_DESC"]
      imprint = imprint.encode('utf-8')
    end
  end
  return imprint
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPublisher(config_hash, myhash, htmlfile, imprint, logkey='')
  if config_hash.has_key?('publisher') && config_hash['publisher'] != 'TK'
    publisher = config_hash['publisher']
  else
    # get the page tree via nokogiri
    page = Nokogiri::HTML(open(htmlfile))
    # get meta info from html if it exists
    metapublisher = page.xpath('//meta[@name="publisher"]/@content')
    # Finding publisher
    if !metapublisher.empty?
      puts "Getting book PUBLISHER from meta element"
      publisher = HTMLEntities.new.decode(metapublisher)
    else
      puts "Getting book PUBLISHER from imprint"
      publisher = imprint
    end
  end
  return publisher
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getPImetatag(htmlfile, metakey, logkey='')
  # get the page tree via nokogiri
  page = Nokogiri::HTML(open(htmlfile))
  # get meta info from html if it exists
  metaresult = page.xpath("//meta[@name=\"#{metakey}\"]/@content")
  if !metaresult.empty?
    value = HTMLEntities.new.decode(metaresult)
    logstring = "#{value}"
  else
    value = ""
    logstring = "default"
  end
  puts "#{metakey}: #{logstring}"
  return metaresult, value
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# determine directory name for assets e.g. css, js, logo images
def getResourceDir(imprint, json, logkey='')
  data_hash = Mcmlln::Tools.readjson(json)
  arr = []
  # loop through each json record to see if imprint name matches formalname
  data_hash['imprints'].each do |p|
    if p['formalname'] == imprint
      arr << p['shortname']
    end
  end
  # in case of multiples, grab just the last entry and return it
  if arr.nil? or arr.empty?
    path = "generic"
  else
    path = arr.pop
  end
  return path
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setRSuiteTemplate(template, resource_dir, logkey='')
  if template.include?('__')
    resource_dir, template = template.split('__')
    resource_dir = resource_dir.downcase()
    logstring = "set pdf_resourcedir to #{resource_dir}, template to #{template}"
  else
    logstring = 'n-a'
  end
  return resource_dir, template
rescue => logstring
  return '', ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPdfScssFile(metatemplate, template, pdf_css_dir, stage_dir, resource_dir, pdf_resource_dir, logkey='')
  if !metatemplate.nil? and File.file?("#{pdf_css_dir}/#{pdf_resource_dir}/#{template}.scss")
    pdf_scss_file = "#{pdf_css_dir}/#{pdf_resource_dir}/#{template}.scss"
  # if !metatemplate.nil? and File.file?("#{pdf_css_dir}/global_templates/#{template}.css")
  #   pdf_scss_file = "#{pdf_css_dir}/global_templates/#{template}.css"
  elsif File.file?("#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.scss")
    pdf_scss_file = "#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.scss"
  elsif File.file?("#{pdf_css_dir}/#{resource_dir}/pdf.scss")
    pdf_scss_file = "#{pdf_css_dir}/#{resource_dir}/pdf.scss"
  else
    pdf_scss_file = "#{pdf_css_dir}/generic/pdf.scss"
  end
  return pdf_scss_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setEpubCssFile(metatemplate, template, epub_css_dir, stage_dir, resource_dir, logkey='')
  if !metatemplate.nil? and File.file?("#{epub_css_dir}/#{resource_dir}/#{template}.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{template}.css"
  elsif File.file?("#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css"
  elsif File.file?("#{epub_css_dir}/#{resource_dir}/epub.css")
    epub_css_file = "#{epub_css_dir}/#{resource_dir}/epub.css"
  else
    epub_css_file = "#{epub_css_dir}/generic/epub.css"
  end
  return epub_css_file
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def moveOverridePdfJS(submitted_override_js, existing_override_js, override_js_file, logkey='')
  if File.file?(submitted_override_js)
    Mcmlln::Tools.moveFile(submitted_override_js, override_js_file)
  elsif File.file?(existing_override_js)
    Mcmlln::Tools.moveFile(existing_override_js, override_js_file)
  else
    logstring = "n=a"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# get JS file for pdf and edit title info to match our book
def setupPdfJSfile(override_js_file, proj_js_file, fallback_js_file, pdf_js_file, booktitle, authorname, logkey='')
  if File.file?(override_js_file)
    js_file = override_js_file
    logstring = "override_pdf.js found, using that for pdf.js"
  elsif File.file?(proj_js_file)
    js_file = proj_js_file
  elsif File.file?(fallback_js_file)
    js_file = fallback_js_file
  else
    js_file = " "
  end
  if File.file?(js_file)
    FileUtils.cp(js_file, pdf_js_file)
    jscontents = File.read(pdf_js_file).gsub(/BKMKRINSERTBKTITLE/,"\"#{booktitle}\"").gsub(/BKMKRINSERTBKAUTHOR/,"\"#{authorname}\"")
    File.open(pdf_js_file, 'w') do |output|
      output.write jscontents
    end
  else
    logstring = 'neither proj_js nor fallback_js_file found'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
	Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setTOCvalFromHTML(check_for_element_js, logkey='')
  target_el = 'section'
  target_class = 'texttoc'
  toc_value = localRunNode(check_for_element_js, "#{Bkmkr::Paths.outputtmp_html} #{target_el} #{target_class}", 'run-check_for_element_js-for_TOC')
  toc_value = toc_value.strip
  return toc_value
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setTOCvalFromXml(xml_file, logkey='')
  if Mcmlln::Tools.checkFileExist(xml_file)
    check_tocbody = File.read(xml_file).scan(/w:pStyle w:val\="TOC/)
    check_tochead = File.read(Bkmkr::Paths.outputtmp_html).scan(/class=".*?texttoc.*?"/)
    if check_tocbody.any? or check_tochead.any?
      toc_value = "true"
    else
      toc_value = "false"
    end
  else
    toc_value = "false"
  end
  return toc_value
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def handleSqlQueryError(querystatus, data_hash, dw_lookup_errfile, testing_value_file, logkey='')
  # write errfile
  msg = "Data warehouse lookup for ISBN encountered errors. \n"
  msg += "Customizations based on imprint may be missing (logo(s), custom formatting from CSS, newsletter links, etc)"
  msg += "\n \n(detailed output:)\n "
  msg += querystatus
  Mcmlln::Tools.overwriteFile(dw_lookup_errfile, msg)
  logstring = "not the first sql err this run, (re)wrote err textfile"

  # if this is the first dw lookup failure on this run, write to cfg.json & send email alert
  if !data_hash.has_key?('dw_sql_err')
    # not writing to cfg in this iteration of this function; that's handled elsewhere in this module
    # data_hash['dw_sql_err'] = querystatus
    # Mcmlln::Tools.write_json(data_hash, Metadata.configfile)
    # send mail
    Mcmlln::Tools.sendAlertMailtoWF('dw_isbn_lookup', msg, testing_value_file, Bkmkr::Project.filename_normalized, Bkmkr::Keys.smtp_address)
    logstring = "sql err, first this run; logging to cfg.json and sending alert-mail"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeConfigJson(hash, json, logkey='')
  Mcmlln::Tools.write_json(hash, json)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES
# for logging purposes
puts "RUNNING METADATA_PREPROCESSING"

prev_cfg_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
doctemplatetype = prev_cfg_hash['doctemplatetype']
# set bookmaker_assets path based on presence of rsuite styles
if doctemplatetype == "rsuite"
  bookmaker_assets_dir = File.join(bookmaker_assets_dir, "rsuite_assets")
  isbn_stylename = "cs-isbnisbn"
  author_selector = 'section[data-type="titlepage"] > .Author1Au1'
  title_selector = 'section[data-type="titlepage"] > .TitleTtl'
  subtitle_selector = 'section[data-type="titlepage"] > .SubtitleSttl'
else
  isbn_stylename = "spanISBNisbn"
  author_selector = ".TitlepageAuthorNameau"
  title_selector = ".TitlepageBookTitletit"
  subtitle_selector = ".TitlepageBookSubtitlestit"
end

pisbn, eisbn, allworks, querystatus = findBookISBNs_metadataPreprocessing(prev_cfg_hash, isbn_stylename, 'find_book_ISBNs')

# this all depends on the ISBN; must follow the isbn_finder
final_dir, @log_hash = Metadata.setupFinalDir(Bkmkr::Paths.project_tmp_dir, Bkmkr::Paths.done_dir, pisbn, Bkmkr::Paths.unique_run_id, @log_hash, 'metadata.rb-setup_final_dir')

allimg = File.join(Bkmkr::Paths.project_tmp_dir_submitted, "*")
finalimg = File.join(final_dir, "images", "*")

# find titlepage images
epubtitlepage, podtitlepage = findTitlepageImages(allimg, finalimg, 'find_titlepage_images')
@log_hash['epubtitlepage'] = epubtitlepage
@log_hash['podtitlepage'] = podtitlepage

# Find front cover
frontcover = findFrontCover(final_dir, allimg, allworks, 'find_frontcover')
@log_hash['frontcover'] = frontcover

# connect to DB for all other metadata, unless we're coming from RSuite
if prev_cfg_hash.has_key?('from_rsuite') and prev_cfg_hash['from_rsuite'] == true
  authorname = prev_cfg_hash['author']
  booktitle = prev_cfg_hash['title']
  booksubtitle = prev_cfg_hash['subtitle']
  imprint = prev_cfg_hash['imprint']
  publisher = prev_cfg_hash['publisher']
  mdlookup_status = 'RSuite->bookmaker run, skipping DB lookup for book metadata'
  puts mdlookup_status
  querystatus2 = ''
else
  if querystatus == 'success' or querystatus == ''
    myhash, querystatus = databaseLookup(pisbn, eisbn, 'get_Biblio_metadata')
    mdlookup_status = querystatus
  else
    myhash = {}
    mdlookup_status = "skipping dw lookup due to previous dw_lookup errors"
  end
  # Setting metadata vars for config.json:
  # Prioritize metainfo from html, then edition info from biblio, then scan html for tagged data
  authorname = setAuthorInfo(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, author_selector, 'set_author_info')
  booktitle = setBookTitle(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, title_selector, 'set_book_title')
  booksubtitle = setBookSubtitle(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, subtitle_selector, 'set_book_subtitle')
  imprint = setImprint(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, project_dir, imprint_json, 'set_imprint')
  publisher = setPublisher(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, imprint, 'set_publisher')
end

@log_hash['mdlookup_status'] = mdlookup_status
@log_hash['author_name'] = authorname
@log_hash['book_title'] = booktitle
@log_hash['book_subtitle'] = booksubtitle
@log_hash['imprint'] = imprint
@log_hash['publisher'] = publisher

metatemplate, template = getPImetatag(Bkmkr::Paths.outputtmp_html, 'template', 'set_design_template')
metapitstop, pitstop_value = getPImetatag(Bkmkr::Paths.outputtmp_html, 'pitstop', 'set_design_template')

# print and epub css files
epub_css_dir = File.join(bookmaker_assets_dir, "epubmaker", "css")
pdf_css_dir = File.join(bookmaker_assets_dir, "pdfmaker", "css")

resource_dir = getResourceDir(imprint, imprint_json, 'get_resource_dir')
@log_hash['resource_dir'] = resource_dir
puts "Resource dir: #{resource_dir}"

pdf_resource_dir, template = setRSuiteTemplate(template, resource_dir, 'RS-recheck_template_and_resourcedir_values')

pdf_scss_file = setPdfScssFile(metatemplate, template, pdf_css_dir, stage_dir, resource_dir, pdf_resource_dir, 'set_pdf_scss_file')
@log_hash['pdf_scss_file'] = pdf_scss_file
puts "PDF SCSS file: #{pdf_scss_file}"

epub_css_file = setEpubCssFile(metatemplate, template, epub_css_dir, stage_dir, resource_dir, 'set_epub_CSS_file')
@log_hash['epub_css_file'] = epub_css_file
puts "Epub CSS file: #{epub_css_file}"

submitted_override_js = File.join(Bkmkr::Paths.project_tmp_dir_submitted, "override_pdf.js")
existing_override_js = File.join(final_dir, "layout", "override_pdf.js")
override_js_file = File.join(Bkmkr::Paths.project_tmp_dir, "override_pdf.js")
proj_js_file = File.join(bookmaker_assets_dir, "pdfmaker", "scripts", pdf_resource_dir, "pdf.js")
fallback_js_file = File.join(bookmaker_assets_dir, "pdfmaker", "scripts", "generic", "pdf.js")
pdf_js_file = File.join(Bkmkr::Paths.project_tmp_dir, "pdf.js")

# put override js file in tmp if it exists
moveOverridePdfJS(submitted_override_js, existing_override_js, override_js_file, 'move_override_jsfile')

# get JS file for pdf and edit title info to match our book
setupPdfJSfile(override_js_file, proj_js_file, fallback_js_file, pdf_js_file, booktitle, authorname, 'setup_pdf_JS_file')

# check the html or xml for toc_value depending on doctemplatetype
if doctemplatetype == 'pre-sectionstart'
  toc_value = setTOCvalFromXml(xml_file, 'set_TOC_value_From_xml')
else
  toc_value = setTOCvalFromHTML(check_for_element_js, 'set_TOC_value_From_html')
end

# Generating the json metadata

if frontcover.empty? && (stage_dir == "firstpass" || stage_dir.include?("galley") || stage_dir.include?("arc-") || stage_dir == "RBM" \
  || stage_dir == "tests" || (project_dir == 'validator' && stage_dir == 'direct'))
  frontcoverval = "#{pisbn}_FC.jpg"
else
  frontcoverval = frontcover
end

datahash = {}
datahash.merge!(title: booktitle)
datahash.merge!(subtitle: booksubtitle)
datahash.merge!(author: authorname)
datahash.merge!(productid: pisbn)
datahash.merge!(printid: pisbn)
datahash.merge!(ebookid: eisbn)
datahash.merge!(imprint: imprint)
datahash.merge!(publisher: publisher)
datahash.merge!(project: project_dir)
datahash.merge!(stage: stage_dir)
datahash.merge!(resourcedir: resource_dir)
datahash.merge!(pdf_resourcedir: pdf_resource_dir)
datahash.merge!(design_template: template)
datahash.merge!(pitstop_dir: pitstop_value)
datahash.merge!(printcss: pdf_scss_file)
datahash.merge!(printjs: pdf_js_file)
datahash.merge!(ebookcss: epub_css_file)
datahash.merge!(pod_toc: toc_value)
datahash.merge!(frontcover: frontcoverval)
unless epubtitlepage.nil?
  datahash.merge!(epubtitlepage: epubtitlepage)
end
unless podtitlepage.nil?
  datahash.merge!(podtitlepage: podtitlepage)
end
datahash.merge!(doctemplate_version: prev_cfg_hash['doctemplate_version'])
datahash.merge!(doctemplatetype: doctemplatetype)
datahash.merge!(from_rsuite: prev_cfg_hash['from_rsuite'])
if prev_cfg_hash.has_key?('dw_sql_err')
  datahash.merge!('dw_sql_err': prev_cfg_hash['dw_sql_err'])
elsif querystatus != 'success' and querystatus != ''
  datahash.merge!('dw_sql_err': querystatus)
  handleSqlQueryError(querystatus, prev_cfg_hash, dw_lookup_errfile, testing_value_file, 'handle_sql_query_err')
end

# write to config.json file
writeConfigJson(datahash, configfile, 'write_config_jsonfile')

# set html title to match JSON
if booktitle.nil? or booktitle.empty? or !booktitle
  booktitle = Bkmkr::Project.filename
end

# replace html book title with ours
localRunNode(title_js, "#{Bkmkr::Paths.outputtmp_html} \"#{booktitle}\"", 'run_node_title_js')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
