require 'fileutils'
require 'htmlentities'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../utilities/oraclequery.rb'

# ---------------------- METHODS

# find any tagged isbn in an html file
def findAnyISBN(file)
  isbn_basestring = File.read(file).match(/spanISBNisbn">\s*978(\D?\d?){10}<\/span>/)
  unless isbn_basestring.nil?
    isbn_basestring = isbn_basestring.to_s.gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  return isbn
end

# find a tagged isbn in an html file that matches a provided book type
def findSpecificISBN(file, string, type)
  allisbns = File.read(file).scan(/(<span class="spanISBNisbn">\s*97[89]((\D?\d){10})<\/span>\s*\(?.*?\)?\s*<\/p>)/)
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
    isbn_basestring = isbn_basestring.to_s.gsub(/\D/,"")
    isbn = isbn_basestring.match(/978(\d{10})/).to_s
  else
    isbn = ""
  end
  return isbn
end

# find any tagged isbn in an html file
def findAllISBN(file)
  isbns_raw = File.read(file).scan(/spanISBNisbn">\s*(978(\D?\d?){10})<\/span>/)
  isbns = []
  unless isbns_raw.nil? or isbns_raw.empty?
    isbns_raw.each do |n|
      isbn = n.to_s.gsub(/\D/,"")
      isbn = isbn.match(/978(\d{10})/).to_s
      isbns << isbn
    end
  end
  return isbns
end

# find the publisher imprint based on the imprints.json database
def getImprint(projectdir, json)
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
end

# determine directory name for assets e.g. css, js, logo images
def getResourceDir(imprint, json)
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
end

# ---------------------- PROCESSES
# for logging purposes
puts "RUNNING METADATA_PREPROCESSING"

# search for any isbn
looseisbn = findAnyISBN(Bkmkr::Paths.outputtmp_html)
book_isbn = ""
work_tp = ""
paperback_isbn = ""
work_hc = ""
hardback_isbn = ""
pisbn = ""
work_eb = ""
eisbn = ""
isbnhash = {}

# query biblio, get WORK_ID
if looseisbn.length == 13
  puts "Searching data warehouse for ISBN: #{looseisbn}"
  thissql = exactSearchSingleKey(looseisbn, "EDITION_EAN")
  isbnhash = runQuery(thissql)
end

# we'll use this later to find the cover file
allworks = []
allisbns = findAllISBN(Bkmkr::Paths.outputtmp_html)

# if query returns results, query again to find all book records under the same WORK_ID
unless isbnhash.nil? or isbnhash.empty? or !isbnhash or isbnhash['book'].nil? or isbnhash['book'].empty? or !isbnhash['book']
  puts "DB Connection SUCCESS: Found an isbn record"
  workid = isbnhash['book']['WORK_ID']
  thissql = exactSearchSingleKey(workid, "WORK_ID")
  editionshash = runQuery(thissql)

  unless editionshash.nil? or editionshash.empty? or !editionshash

    # classify the isbns found in the book
    editionshash.each do |k, v|
      allworks.push(v['EDITION_EAN'])

      # first, let's get any book ISBN in the work family, for fallbacks
      if v['PRODUCTTYPE_DESC'] and v['PRODUCTTYPE_DESC'] == "Book" and v['EDITION_EAN'].length == 13
        book_isbn = v['EDITION_EAN']
      end

      # now let's see if we can narrow our book isbn options down
      # to just an isbn included on the copyright page.
      # first, we'll see if there is a paperback isbn in the work family:
      if v['BINDING_SHORTNAME'] and v['BINDING_SHORTNAME'] == "P" and v['EDITION_EAN'].length == 13
        # if so, we'll see if that ISBN is on the book copyright page
        if allisbns.include? v['EDITION_EAN']
          paperback_isbn = v['EDITION_EAN']
          puts "Paperback ISBN on copyright page: #{paperback_isbn}"
        end
      # next we'll see if there is a hardcover isbn in the work family:
      elsif v['BINDING_SHORTNAME'] and v['BINDING_SHORTNAME'] == "C" and v['EDITION_EAN'].length == 13
        # if so, we'll save it for fallback purposes
        work_hc = v['EDITION_EAN']
        # and then we'll see if it's included on the book copyright page
        if allisbns.include? v['EDITION_EAN']
          hardback_isbn = v['EDITION_EAN']
          puts "Hardcover ISBN on copyright page: #{hardback_isbn}"
        end
      # Now let's see if there is an ebook isbn in the work family
      elsif v['PRODUCTTYPE_DESC'] and v['PRODUCTTYPE_DESC'] == "EBook" and v['EDITION_EAN'].length == 13 and 
        # if so, we'll save it for fallback purposes
        work_eb = v['EDITION_EAN']
        # and then we'll see if it's included on the book copyright page
        if allisbns.include? v['EDITION_EAN']
          eisbn = v['EDITION_EAN']
          puts "Ebook ISBN on copyright page: #{eisbn}"
        end
      end
    end

    # no we'll assign the final pisbn value based on our rules of precedence
    # if a paperback isbn is listed in the book, we assume this is the paperback edition
    if paperback_isbn != ""
      pisbn = paperback_isbn
    # else if there is no paperback isbn, but there is a hardback isbn, we assume this is the hardback edition
    elsif hardback_isbn != ""
      pisbn = hardback_isbn
    # if neither is listed, we fall back to the hardback edition
    elsif work_hc != ""
      pisbn = work_hc
    # if there was no hardback edition, we fall back to whatever book isbn we could find
    else
      pisbn = book_isbn
    end

    # if no ebook isbn was listed on the copyright page, we fall back to whatever ebook isbn we could find
    if eisbn == ""
      eisbn = work_eb
    end

  end
else
  puts "No DB record found; retrieving ISBNs from manuscript fields"
  # if not found, revert to mining manuscript fields for isbns
  spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)

  # determining print isbn
  if spanisbn.length != 0
    psearchstring = "[eE]\\s*-*\\s*[bB]ook"
    pisbn = findSpecificISBN(Bkmkr::Paths.outputtmp_html, psearchstring, "exclude")
    if pisbn.length == 0
      pisbn = looseisbn
    end
    unless pisbn.length == 0
      puts "Found a print isbn: #{pisbn}"
      allworks.push(pisbn)
    end
    esearchstring = "[eE]\\s*-*\\s*[bB]ook"
    eisbn = findSpecificISBN(Bkmkr::Paths.outputtmp_html, esearchstring, "include")
    if eisbn.length == 0
      eisbn = looseisbn
    end
    unless eisbn.length == 0
      puts "Found an ebook isbn: #{eisbn}"
      allworks.push(eisbn)
    end
  end
end

# just in case no isbn is found, rename based on filename
if pisbn.length == 0 and eisbn.length != 0
  pisbn = eisbn
elsif pisbn.length == 0 and eisbn.length == 0
  pisbn = Bkmkr::Project.filename
end

if pisbn.length == 0 and eisbn.length != 0
  pisbn = eisbn
elsif pisbn.length != 0 and eisbn.length == 0
  eisbn = pisbn
elsif pisbn.length == 0 and eisbn.length == 0
  pisbn = Bkmkr::Project.filename
  eisbn = Bkmkr::Project.filename
end

puts "Print ISBN: #{pisbn}"
puts "Ebook ISBN: #{eisbn}"

# find titlepage images
allimg = File.join(Bkmkr::Paths.submitted_images, "*")
finalimg = File.join(Bkmkr::Paths.done_dir, pisbn, "images", "*")
etparr1 = Dir[allimg].select { |f| f.include?('epubtitlepage.')}
ptparr1 = Dir[allimg].select { |f| f.include?('titlepage.')}
etparr2 = Dir[finalimg].select { |f| f.include?('epubtitlepage.')}
ptparr2 = Dir[finalimg].select { |f| f.include?('titlepage.')}

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

if ptparr1.any?
  podtitlepage = ptparr1.find { |e| /[\/|\\]titlepage\./ =~ e }
elsif ptparr2.any?
  podtitlepage = ptparr2.find { |e| /[\/|\\]titlepage\./ =~ e }
else
  podtitlepage = ""
end

# Find front cover
coverdir = File.join(Bkmkr::Paths.done_dir, pisbn, "cover")
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

# connect to DB for all other metadata
test_pisbn_chars = pisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_pisbn_length = pisbn.split(%r{\s*})
test_eisbn_chars = eisbn.scan(/\d\d\d\d\d\d\d\d\d\d\d\d\d/)
test_eisbn_length = eisbn.split(%r{\s*})

if test_pisbn_length.length == 13 and test_pisbn_chars.length != 0
  thissql = exactSearchSingleKey(pisbn, "EDITION_EAN")
  myhash = runQuery(thissql)
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] and test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
    thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
    myhash = runQuery(thissql)
  end
elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
  thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
  myhash = runQuery(thissql)
else
  myhash = {}
end

unless myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  puts "DB Connection SUCCESS: Found a book record"
else
  puts "No DB record found; falling back to manuscript fields"
end

metabookauthor = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="author" content=")(.*?)("\/>)/i)
metabooktitle = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="title" content=")(.*?)("\/>)/i)
metabooksubtitle = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="subtitle" content=")(.*?)("\/>)/i)
metapublisher = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="publisher" content=")(.*?)("\/>)/i)
metaimprint = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="imprint" content=")(.*?)("\/>)/i)
metatemplate = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="template" content=")(.*?)("\/>)/i)

# Finding author name(s)
if !metabookauthor.nil?
  authorname = HTMLEntities.new.decode(metabookauthor[2]).encode('utf-8')
elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['WORK_COVERAUTHOR'].nil? or myhash['book']['WORK_COVERAUTHOR'].empty? or !myhash['book']['WORK_COVERAUTHOR']
  authorname = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</).join(", ").gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/</,"").gsub(/\[\]/,"")
  authorname = HTMLEntities.new.decode(authorname).encode('utf-8')
else
  authorname = myhash['book']['WORK_COVERAUTHOR']
  authorname = authorname.encode('utf-8')
end

# Finding book title
if !metabooktitle.nil?
  booktitle = HTMLEntities.new.decode(metabooktitle[2]).encode('utf-8')
elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
  booktitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<h1 class="TitlepageBookTitletit">.*?</).join(", ").gsub(/<h1 class="TitlepageBookTitletit">/,"").gsub(/</,"")
  booktitle = HTMLEntities.new.decode(booktitle).encode('utf-8')
else
  booktitle = myhash["book"]["WORK_COVERTITLE"]
  booktitle = booktitle.encode('utf-8')
end

# Finding book subtitle
if !metabooksubtitle.nil?
  booksubtitle = HTMLEntities.new.decode(metabooksubtitle[2]).encode('utf-8')
elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_SUBTITLE"].nil? or myhash["book"]["WORK_SUBTITLE"].empty? or !myhash["book"]["WORK_SUBTITLE"]
  booksubtitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageBookSubtitlestit">.*?</).join(", ").gsub(/<p class="TitlepageBookSubtitlestit">/,"").gsub(/</,"")
  booksubtitle = HTMLEntities.new.decode(booksubtitle).encode('utf-8')
else
  booksubtitle = myhash["book"]["WORK_SUBTITLE"]
  booksubtitle = booksubtitle.encode('utf-8')
end

# project and stage
project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift
stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop
imprint_json = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "imprints.json")

# Finding imprint name
# imprint = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageImprintLineimp">.*?</).to_s.gsub(/\["<p class=\\"TitlepageImprintLineimp\\">/,"").gsub(/"\]/,"").gsub(/</,"")
# Manually populating for now, until we get the DB set up
if !metaimprint.nil?
  imprint = HTMLEntities.new.decode(metaimprint[2])
elsif myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["IMPRINT_DESC"].nil? or myhash["book"]["IMPRINT_DESC"].empty? or !myhash["book"]["IMPRINT_DESC"]
  imprint = getImprint(project_dir, imprint_json)
else
  imprint = myhash["book"]["IMPRINT_DESC"]
  imprint = imprint.encode('utf-8')
end

if !metapublisher.nil?
  publisher = HTMLEntities.new.decode(metapublisher[2])
else
  publisher = imprint
end

# print and epub css files
epub_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "css")
pdf_css_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "css")
resource_dir = getResourceDir(imprint, imprint_json)
puts "Resource dir: #{resource_dir}"

if !metatemplate.nil?
  template = HTMLEntities.new.decode(metatemplate[2])
  puts "Design template: #{template}"
else
  template = ""
  puts "Design template: default"
end

if !metatemplate.nil? and File.file?("#{pdf_css_dir}/#{resource_dir}/#{template}.css")
  pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/#{template}.css"
elsif File.file?("#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.css")
  pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/#{stage_dir}.css"
elsif File.file?("#{pdf_css_dir}/#{resource_dir}/pdf.css")
  pdf_css_file = "#{pdf_css_dir}/#{resource_dir}/pdf.css"
else
  pdf_css_file = "#{pdf_css_dir}/torDOTcom/pdf.css"
end

puts "PDF CSS file: #{pdf_css_file}"

if !metatemplate.nil? and File.file?("#{epub_css_dir}/#{resource_dir}/#{template}.css")
  epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{template}.css"
elsif File.file?("#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css")
  epub_css_file = "#{epub_css_dir}/#{resource_dir}/#{stage_dir}.css"
elsif File.file?("#{epub_css_dir}/#{resource_dir}/epub.css")
  epub_css_file = "#{epub_css_dir}/#{resource_dir}/epub.css"
else
  epub_css_file = "#{epub_css_dir}/generic/epub.css"
end

proj_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", resource_dir, "pdf.js")
fallback_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", "torDOTcom", "pdf.js")
pdf_js_file = File.join(Bkmkr::Paths.project_tmp_dir, "pdf.js")

if File.file?(proj_js_file)
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
end

xml_file = File.join(Bkmkr::Paths.project_tmp_dir, "#{Bkmkr::Project.filename}.xml")
if Mcmlln::Tools.checkFileExist(xml_file)
  check_tocbody = File.read(xml_file).scan(/w:pStyle w:val\="TOC/)
  check_tochead = File.read(Bkmkr::Paths.outputtmp_html).scan(/class="texttoc"/)
  if check_tocbody.any? or check_tochead.any?
    toc_value = "true"
  else
    toc_value = "false"
  end
else
  toc_value = "false"
end

# Generating the json metadata

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

if stage_dir == "firstpass" or stage_dir == "egalley" or stage_dir == "galley" or stage_dir == "arc-sans" or stage_dir == "arc-serif" or stage_dir == "RBM" or stage_dir == "test" and frontcover.empty?
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
datahash.merge!(printcss: pdf_css_file)
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

finaljson = JSON.generate(datahash)

# Printing the final JSON object
File.open(configfile, 'w+:UTF-8') do |f|
  f.puts finaljson
end

# set html title to match JSON
if booktitle.nil? or booktitle.empty? or !booktitle
  booktitle = Bkmkr::Project.filename
end

title_js = File.join(Bkmkr::Paths.core_dir, "htmlmaker", "title.js")
Bkmkr::Tools.runnode(title_js, "#{Bkmkr::Paths.outputtmp_html} \"#{booktitle}\"")
