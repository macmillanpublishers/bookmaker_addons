require 'fileutils'
require 'htmlentities'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../utilities/oraclequery.rb'

# ---------------------- METHODS

def findSpecificISBN(file, string)
  isbn_basestring = File.read(file).match(/<span class="spanISBNisbn">\s*978(\D?\d?){10}<\/span>\s*\(?#{string}\)?/)
  unless isbn_basestring.length == 0
    isbn_basestring = isbn_basestring.shift.gsub(/-/,"").gsub(/\s+/,"")
    isbn = isbn_basestring.match(/\d{13}/).shift
  else
    isbn = ""
  end
  return isbn
end

def findAnyISBN(file)
  isbn_basestring = File.read(file).match(/spanISBNisbn">\s*978(\D?\d?){10}<\/span>/)
  unless isbn_basestring.length == 0
    isbn_basestring = isbn_basestring.shift.gsub(/-/,"").gsub(/\s+/,"")
    isbn = isbn_basestring.match(/\d{13}/).shift
  else
    isbn = ""
  end
  return isbn
end

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
pisbn = ""
eisbn = ""
isbnhash = {}

# query biblio, get WORK_ID
if looseisbn.length == 13
  thissql = exactSearchSingleKey(looseisbn, "EDITION_EAN")
  isbnhash = runQuery(thissql)
end

unless isbnhash.nil? or isbnhash.empty? or !isbnhash or isbnhash['book'].nil? or isbnhash['book'].empty? or !isbnhash['book']
  puts "DB Connection SUCCESS: Found an isbn record"
  workid = isbnhash['book']['WORK_ID']
  thissql = exactSearchSingleKey(workid, "WORK_ID")
  editionshash = runQuery(thissql)
  unless editionshash.nil? or editionshash.empty? or !editionshash
    editionshash['book'].each do |b|
      if b['PRODUCTTYPE_DESC'] and b['PRODUCTTYPE_DESC'] == "Book"
        pisbn = b['EDITION_EAN']
        puts "Found a print product: #{pisbn}"
      elsif b['PRODUCTTYPE_DESC'] and b['PRODUCTTYPE_DESC'] == "EBook"
        eisbn = b['EDITION_EAN']
        puts "Found an ebook product: #{eisbn}"
      end
    end
  end
else
  puts "No DB record found; retrieving ISBNs from manuscript fields"
  # if not found, revert to the old way:
  spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)

  # determining print isbn
  if spanisbn.length != 0
    psearchstring = "(?!(e|E)\s*-*\s*(b|B)ook).*"
    pisbn = findSpecificISBN(Bkmkr::Paths.outputtmp_html, psearchstring)
    if pisbn.length == 0
      pisbn = looseisbn
    end
    unless pisbn.length == 0
      puts "Found a print isbn: #{pisbn}"
    end
    esearchstring = "(e|E)\s*-*\s*(b|B)ook"
    eisbn = findSpecificISBN(Bkmkr::Paths.outputtmp_html, esearchstring)
    if eisbn.length == 0
      eisbn = looseisbn
    end
    unless eisbn.length == 0
      puts "Found an ebook isbn: #{eisbn}"
    end
  end
end

# just in case no isbn is found
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
fcarr1 = Dir[allimg].select { |f| f.include?('_FC.')}

if File.exist?(coverdir)
  fcarr2 = Dir[allcover].select { |f| f.include?('_FC.')}
else
  fcarr2 = []
end

if fcarr1.any?
  mycover = fcarr1.max_by(&File.method(:ctime))
  frontcover = mycover.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
elsif fcarr2.any?
  mycover = fcarr2.max_by(&File.method(:ctime))
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
else
  template = ""
end

puts "Template: #{template}"

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

if stage_dir == "firstpass" or stage_dir == "egalley" or stage_dir == "galley" or stage_dir == "arc-sans" or stage_dir == "arc-serif" or stage_dir == "RBM" and frontcover.empty?
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