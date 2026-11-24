require 'fileutils'
require 'open3'
require 'json'
require 'htmlentities'
require 'nokogiri'

# unless (ENV['TRAVIS_TEST']) == 'true'
require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift

stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

# path to executable in py venv can vary per platform
venv_dir = File.join(Bkmkr::Paths.scripts_dir, "biblio_api_consumer", ".venv")
BIBLIO_API_PYENV = [
  File.join(venv_dir, "Scripts", "python.exe"),
  File.join(venv_dir, "bin", "python.exe"),
  File.join(venv_dir, "bin", "python")
].find { |p| File.exist?(p) } || File.join(venv_dir, "bin", "python")

myhash = {}

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

def biblio_call(env, func, *args)
  out, err, status = Open3.capture3(BIBLIO_API_PYENV, '-m', 'biblio_api_consumer.biblio_api_lib', env, func, *args.map(&:to_s))
  return { 'status' => "python exited #{status.exitstatus}: #{err.lines.last.to_s.strip}", 'result' => {} } unless status.success?
  JSON.parse(out)
rescue JSON::ParserError => e
  { 'status' => "bad JSON from biblio_api_consumer: #{e.message}", 'result' => {} }
end

# find any tagged isbn in an html file
def findAnyISBN(file, isbn_stylename, logkey='')
  # \/ added coverage for encoded emdash & endash
  isbn_basestring = File.read(file).match(/#{isbn_stylename}">\s*97[89]((&#x201[34];|\D?)\d){10}\s*<\/span>/)
  unless isbn_basestring.nil?
    isbn_basestring = isbn_basestring.to_s.gsub(/&#x201[34];/,"").gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  logstring = isbn
  return isbn
rescue => logstring
  return ""
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# find a tagged isbn in an html file that matches a provided book type
def findSpecificISBN(file, string, type, isbn_stylename, logkey='')
  allisbns = File.read(file).scan(/(<span class="#{isbn_stylename}">\s*97[89]((&#x201[34];|\D?)\d){10}\s*<\/span>\s*\(?.*?\)?\s*<\/p>)/)
  pisbn = []
  allisbns.each do |k|
    testisbn = ""
    testisbn = k.to_s.match(/#{string}/)
    case type
    when "include"
      unless testisbn.nil?
        pisbn.push(k)
      end
    when "exclude"
      if testisbn.nil?
        pisbn.push(k)
      end
    end
  end
  isbn_basestring = pisbn.shift
  unless isbn_basestring.nil?
    isbn_basestring = isbn_basestring.to_s.gsub(/&#x201[34];/,"").gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  return isbn
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# find any tagged isbn in an html file
def findAllISBN(file, isbn_stylename, logkey='')
  isbns_raw = File.read(file).scan(/#{isbn_stylename}">\s*(97[89]((&#x201[34];|\D?)\d){10})\s*<\/span>/)
  isbns = []
  unless isbns_raw.nil? or isbns_raw.empty?
    isbns_raw.each do |n|
      isbn = n.to_s.gsub(/&#x201[34];/,"").gsub(/\D/,"")
      isbn = isbn.match(/978(\d{10})/).to_s
      isbns << isbn
    end
  end
  return isbns
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


def getFinalISBNs(config_hash, htmlfile, filename, isbn_stylename, logkey='')
  eisbn = ''
  pisbn = ''
  allworks = []
  querystatus = ''
  looseisbn = ''

  # if we already have a printid or productid in config.json, use that for pisbn
  if config_hash.has_key?('printid') && config_hash['printid'] != 'TK'
    pisbn = config_hash['printid']
  end  
  if config_hash.has_key?('ebookid') && (config_hash['ebookid'] != 'TK' && !config_hash['ebookid'].empty?)
    eisbn = config_hash['ebookid']  
  end  
  # else scan document & perform lookup
  if pisbn == "" || eisbn == ""
    looseisbn = findAnyISBN(htmlfile, isbn_stylename, 'find_any_ISBN')
    if !looseisbn.empty?
      api_response = biblio_call('prod', 'bookmakerCallAllIsbns', looseisbn)
      # record_api_error(status_hash, api_response, logger)
      querystatus = api_response['status'].to_s
      querystatus = 'success' if querystatus.start_with?('ISBN not found')
      if lookup_ok?(api_response)
        isbn_api_result = api_response['result']
        pisbn, eisbn, allworks = getISBNsFromApiResult(isbn_api_result, htmlfile, isbn_stylename, 'get_ISBNs_From_Api_Result')
      else
        pisbn, eisbn = getISBNsFromManuscript(looseisbn, htmlfile, filename, isbn_stylename, 'get_ISBNs_From_Manuscript')
      end
    else
      logstring = "no styled isbns found in document"
    end  
  end

  # we need something for eisbn for lookups/naming in epubmaker, and we encounterd an old reprint where no ebook product existed. 
  if eisbn == ''
    eisbn = pisbn
  end 
  
  if allworks.empty?
    allworks.push(pisbn, eisbn)
  end

  if querystatus != '' and querystatus != 'success'
    logstring = querystatus
  end
  
  return pisbn, eisbn, allworks, querystatus

rescue => logstring
  return '','',[],''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


def getISBNsFromApiResult(isbn_api_result, htmlfile, isbn_stylename, logkey='')
  paperback_isbn = ""
  hardback_isbn = ""
  pisbn = ""
  eisbn = ""

  # we'll use this later to find the cover file
  allworks = Array(isbn_api_result['alt_isbn_list'])
  allisbns = findAllISBN(htmlfile, isbn_stylename, 'find_all_isbns')

  lead_edition    = isbn_api_result['lead_isbn'].to_s
  hardback_isbns  = Array(isbn_api_result['hardback_isbns'])
  paperback_isbns = Array(isbn_api_result['paperback_isbns'])
  ebook_isbns     = Array(isbn_api_result['ebook_isbns'])
  producttype_book_isbns = Array(isbn_api_result['producttype_book_isbns'])   

  # do we have a paperback isbn that matches a styled isbn in the MS?
  paperback_isbns.each do |i|
    if allisbns.include?(i)
      paperback_isbn = i
      break    
    end
  end
  # ditto hardback
  hardback_isbns.each do |i|
    if allisbns.include?(i)
      hardback_isbn = i
      break    
    end
  end
    # and ebook
  ebook_isbns.each do |i|
    if allisbns.include?(i)
      eisbn = i
      break    
    end
  end

  # now we'll assign the final pisbn value based on our rules of precedence.
  # prefer lead_edition, then hardback, then paperback.
  if lead_edition != ""
    pisbn = lead_edition
  elsif hardback_isbn != ""   # this is a hardback isbn that appeared on the copyright page
    pisbn = hardback_isbn
  elsif hardback_isbns.length > 0          # any hardcover
    pisbn = hardback_isbns[0]
  elsif paperback_isbn != ""  # paperback isbn appearing on copyright page
    pisbn = paperback_isbn
  elsif paperback_isbns.length > 0          # any paperback
    pisbn = paperback_isbns[0]    
  # if there was no paperback edition, we fall back to whatever book isbn we could find
  elsif producttype_book_isbns.length > 0          # any paperback
    pisbn = producttype_book_isbns[0]         # any book isbn :( mass market?
  end

  if eisbn == "" && ebook_isbns.length > 0          # any ebook
    eisbn = ebook_isbns[0] 
  end  

  return pisbn, eisbn, allworks
rescue => logstring
  return '','',[]
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def lookup_ok?(r)
  !r.nil? && r['status'] == 'success' && !r['result'].to_h.empty?
end

# # "not found" is a normal answer; anything else that isn't success is an api/system error
# def record_api_error(status_hash, response, logger)
#   s = response['status'].to_s
#   return if s == 'success' || s.start_with?('ISBN not found')
#   status_hash['dw_sql_err'] = s
#   logger.warn {"biblio api error: #{s}"}
# end

def getISBNsFromManuscript(looseisbn, htmlfile, filename, isbn_stylename, logkey='')
  pisbn = ''
  eisbn = ''
  # lookups not working, revert to mining manuscript fields for isbns
  spanisbn = File.read(htmlfile).scan(/#{isbn_stylename}/)

  # determining print isbn
  if spanisbn.length != 0
    psearchstring = "[eE]\\s*-*\\s*[bB]ook"
    pisbn = findSpecificISBN(htmlfile, psearchstring, "exclude", isbn_stylename, 'find_specific_isbn')
    if pisbn.length == 0
      pisbn = looseisbn
    end
    unless pisbn.length == 0
      puts "Found a print isbn: #{pisbn}"
      # allworks.push(pisbn)
    end
    esearchstring = "[eE]\\s*-*\\s*[bB]ook"
    eisbn = findSpecificISBN(htmlfile, esearchstring, "include", isbn_stylename, 'find_specific_isbn')
    if eisbn.length == 0
      eisbn = looseisbn
    end
    unless eisbn.length == 0
      puts "Found an ebook isbn: #{eisbn}"
      # allworks.push(eisbn)
    end
  end

  # just in case no isbn is found, rename based on filename
  if pisbn.length == 0 and eisbn.length != 0
    pisbn = eisbn
  elsif pisbn.length != 0 and eisbn.length == 0
    eisbn = pisbn
  elsif pisbn.length == 0 and eisbn.length == 0
    pisbn = filename
    eisbn = filename
  end

  return pisbn, eisbn
rescue => logstring
  return '',''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


def biblioApiLookupMetadata(env, endpoint_name, pisbn, eisbn, logkey='')
  querystatus = ''
  api_response = {}

  # validate 13 digit isbn
  test_pisbn_chars = pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_pisbn_length = pisbn.split(%r{\s*})
  test_eisbn_chars = eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
  test_eisbn_length = eisbn.split(%r{\s*})

  # get a hash of edition information, attempt pisbn first, use eisbn as backup
  if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
    api_response = biblio_call(env, endpoint_name, pisbn)
    # record_api_error(status_hash, api_response, logger)
    querystatus = api_response['status'].to_s
    querystatus = 'success' if querystatus.start_with?('ISBN not found')
    # if lookup_ok?(api_response)
    #   isbn_api_result = api_response['result']
  elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
    api_response = biblio_call(env, endpoint_name, eisbn)
    # record_api_error(status_hash, api_response, logger)
    querystatus = api_response['status'].to_s
    querystatus = 'success' if querystatus.start_with?('ISBN not found')

    # thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    # myhash, querystatus = runQuery(thissql)
  end

  #  setup logstring based on query returns
  result = api_response['result'].to_h
  if querystatus == 'success' && result.empty?
    logstring = "No DB record found; removing author links for addons"
  elsif querystatus == 'success'
    logstring = "Biblio lookup SUCCESS: found an edition record"
  end

  return api_response, querystatus
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
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['author_name'].nil? or myhash['author_name'].empty? or !myhash['author_name']
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
      authorname = myhash['author_name']
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
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book_title'].nil? or myhash['book_title'].empty? or !myhash['book_title']
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
      booktitle = myhash["book_title"]
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
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['book_subtitle'].nil? or myhash['book_subtitle'].empty? or !myhash['book_subtitle']
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
      booksubtitle = myhash["book_subtitle"]
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
    elsif myhash.nil? or myhash.empty? or !myhash or myhash['imprint'].nil? or myhash['imprint'].empty? or !myhash['imprint']
      puts "Getting book IMPRINT from config json"
      imprint = getImprint(project_dir, imprint_json, 'get_imprint_from_json')
    else
      puts "Getting book IMPRINT from database"
      imprint = myhash["imprint"]
      imprint = imprint.encode('utf-8')
    end
  end
  return imprint
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setPublisher(config_hash, htmlfile, imprint, logkey='')
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

def handleSqlQueryError(querystatus, data_hash, dw_lookup_errfile, testing_value_file, logkey='')
  # write errfile
  msg = "Biblio lookup for ISBN encountered errors. \n"
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
    logstring = "biblio lookup error; logging to cfg.json and sending alert-mail"
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
puts "RUNNING BIBLIO LOOKUP"

prev_cfg_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
doctemplatetype = prev_cfg_hash['doctemplatetype']
# set bookmaker_assets path based on presence of rsuite styles
if doctemplatetype == "rsuite"
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

pisbn, eisbn, allworks, querystatus = getFinalISBNs(prev_cfg_hash, Bkmkr::Paths.outputtmp_html, Bkmkr::Project.filename, isbn_stylename, 'find_book_ISBNs')


if querystatus == 'success' or querystatus == ''
  api_response, querystatus = biblioApiLookupMetadata('prod', 'bookmakerCallLmd', pisbn, eisbn, 'biblio_Api_Lookup_Metadata')
  if lookup_ok?(api_response)
    myhash = api_response['result']
    mdlookup_status = querystatus
  else
    mdlookup_status = querystatus + "; <returned empty result>"
  end  
else
  mdlookup_status = "skipping dw lookup due to previous dw_lookup errors"
end

# Setting metadata vars for config.json:
# Prioritize metainfo from html, then edition info from biblio, then scan html for tagged data
authorname = setAuthorInfo(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, author_selector, 'set_author_info')
booktitle = setBookTitle(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, title_selector, 'set_book_title')
booksubtitle = setBookSubtitle(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, subtitle_selector, 'set_book_subtitle')
imprint = setImprint(prev_cfg_hash, myhash, Bkmkr::Paths.outputtmp_html, project_dir, imprint_json, 'set_imprint')
publisher = setPublisher(prev_cfg_hash, Bkmkr::Paths.outputtmp_html, imprint, 'set_publisher')

@log_hash['mdlookup_status'] = mdlookup_status
@log_hash['author_name'] = authorname
@log_hash['book_title'] = booktitle
@log_hash['book_subtitle'] = booksubtitle
@log_hash['imprint'] = imprint
@log_hash['publisher'] = publisher

resource_dir = getResourceDir(imprint, imprint_json, 'get_resource_dir')
@log_hash['resource_dir'] = resource_dir
puts "Resource dir: #{resource_dir}"


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
datahash.merge!(allworks: allworks)
datahash.merge!(linkauthorarr: myhash['author_realnames'])
datahash.merge!(linkauthorid: myhash['author_partnerids'])
# datahash.merge!(pdf_resourcedir: pdf_resource_dir)
# datahash.merge!(design_template: template)
# datahash.merge!(pitstop_dir: pitstop_value)
# datahash.merge!(printcss: pdf_scss_file)
# datahash.merge!(printjs: pdf_js_file)
# datahash.merge!(ebookcss: epub_css_file)
# datahash.merge!(pod_toc: toc_value)
# datahash.merge!(frontcover: frontcoverval)
# unless epubtitlepage.nil?
#   datahash.merge!(epubtitlepage: epubtitlepage)
# end
# unless podtitlepage.nil?
#   datahash.merge!(podtitlepage: podtitlepage)
# end
datahash.merge!(doctemplate_version: prev_cfg_hash['doctemplate_version'])
# datahash.merge!(doctemplatetype: doctemplatetype)
datahash.merge!(from_rsuite: prev_cfg_hash['from_rsuite'])

if prev_cfg_hash.has_key?('dw_sql_err')
  datahash.merge!('dw_sql_err': prev_cfg_hash['dw_sql_err'])
elsif querystatus != 'success' and querystatus != ''
  datahash.merge!('dw_sql_err': querystatus)
  handleSqlQueryError(querystatus, prev_cfg_hash, dw_lookup_errfile, testing_value_file, 'handle_sql_query_err')
end

# write to config.json file
# writeConfigJson(datahash, configfile, 'write_config_jsonfile')
writeConfigJson(prev_cfg_hash.merge(datahash.transform_keys(&:to_s)), configfile, 'write_config_jsonfile')

# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
