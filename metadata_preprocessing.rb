require 'fileutils'
require 'htmlentities'

require_relative '../bookmaker/core/header.rb'
require_relative '../utilities/oraclequery.rb'

# formerly in metadata.rb
# testing to see if ISBN style exists
spanisbn = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn/)
multiple_isbns = File.read(Bkmkr::Paths.outputtmp_html).scan(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand)|(e\s*-*\s*book))\)/)

# determining print isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.?on.?demand))\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
	pisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(((hardcover)|(trade\s*paperback)|(mass.market.paperback)|(print.on.demand))\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	pisbn = pisbn_basestring.match(/\d+\(.*\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# determining ebook isbn
if spanisbn.length != 0 && multiple_isbns.length != 0
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/<span class="spanISBNisbn">\s*.+<\/span>\s*\(e\s*-*\s*book\)/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(ebook\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
elsif spanisbn.length != 0 && multiple_isbns.length == 0
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/spanISBNisbn">\s*.+<\/span>/).to_s.gsub(/-/,"").gsub(/<span class="spanISBNisbn">/, "").gsub(/<\/span>/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = pisbn_basestring.match(/\d+/).to_s.gsub(/\["/,"").gsub(/"\]/,"")
else
	eisbn_basestring = File.read(Bkmkr::Paths.outputtmp_html).match(/ISBN\s*.+\s*\(e-*book\)/).to_s.gsub(/-/,"").gsub(/\s+/,"").gsub(/\["/,"").gsub(/"\]/,"")
	eisbn = eisbn_basestring.match(/\d+\(ebook\)/).to_s.gsub(/\(.*\)/,"").gsub(/\["/,"").gsub(/"\]/,"")
end

# just in case no isbn is found
if pisbn.length == 0
	pisbn = Bkmkr::Project.filename
end

if eisbn.length == 0
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
	if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] and test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
		thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
		myhash = runQuery(thissql)
	end
elsif test_eisbn_length.length == 13 and test_eisbn_chars.length != 0
	thissql = exactSearchSingleKey(eisbn, "EDITION_EAN")
	myhash = runQuery(thissql)
else
	myhash = {}
end

unless myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  puts "DB Connection SUCCESS: Found a book record"
else
	puts "No DB record found; falling back to manuscript fields"
end

metabookauthor = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="author" content=")(.*?)("\/>)/i)
metabooktitle = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="title" content=")(.*?)("\/>)/i)
metabooksubtitle = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="subtitle" content=")(.*?)("\/>)/i)
metapublisher = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="publisher" content=")(.*?)("\/>)/i)
metaimprint = File.read(Bkmkr::Paths.outputtmp_html).match(/(<meta name="imprint" content=")(.*?)("\/>)/i)

# Finding author name(s)
if !metabookauthor.nil?
	authorname = HTMLEntities.new.decode(metabookauthor[2])
elsif myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['WORK_COVERAUTHOR'].nil? or myhash['book']['WORK_COVERAUTHOR'].empty? or !myhash['book']['WORK_COVERAUTHOR']
	authorname = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</).join(", ").gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/</,"").gsub(/\[\]/,"")
else
	authorname = myhash['book']['WORK_COVERAUTHOR']
	authorname = authorname.encode('utf-8')
end

# Finding book title
if !metabooktitle.nil?
	booktitle = HTMLEntities.new.decode(metabooktitle[2])
elsif myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_COVERTITLE"].nil? or myhash["book"]["WORK_COVERTITLE"].empty? or !myhash["book"]["WORK_COVERTITLE"]
	booktitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<title>.*?<\/title>/).to_s.gsub(/\["<title>/,"").gsub(/<\/title>"\]/,"").gsub(/\[\]/,"")
else
	booktitle = myhash["book"]["WORK_COVERTITLE"]
	booktitle = booktitle.encode('utf-8')
end

# Finding book subtitle
if !metabooksubtitle.nil?
	booksubtitle = HTMLEntities.new.decode(metabooksubtitle[2])
elsif myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["WORK_SUBTITLE"].nil? or myhash["book"]["WORK_SUBTITLE"].empty? or !myhash["book"]["WORK_SUBTITLE"]
  booksubtitle = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageBookSubtitlestit">.*?</).join(", ").gsub(/<p class="TitlepageBookSubtitlestit">/,"").gsub(/</,"")
else
	booksubtitle = myhash["book"]["WORK_SUBTITLE"]
	booksubtitle = booksubtitle.encode('utf-8')
end

# project and stage
project_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").shift
stage_dir = Bkmkr::Project.input_file.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact))[0...-2].pop.to_s.split("_").pop

# Finding imprint name
# imprint = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageImprintLineimp">.*?</).to_s.gsub(/\["<p class=\\"TitlepageImprintLineimp\\">/,"").gsub(/"\]/,"").gsub(/</,"")
# Manually populating for now, until we get the DB set up
if !metaimprint.nil?
	imprint = HTMLEntities.new.decode(metaimprint[2])
elsif myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash["book"]["IMPRINT_DESC"].nil? or myhash["book"]["IMPRINT_DESC"].empty? or !myhash["book"]["IMPRINT_DESC"]
	if project_dir == "torDOTcom"
		imprint = "Tom Doherty Associates"
	elsif project_dir == "SMP"
		imprint = "St. Martin's Press"
	elsif project_dir == "picador"
		imprint = "Picador"
	else
		imprint = "Macmillan"
	end
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

if File.file?("#{pdf_css_dir}/#{project_dir}/#{stage_dir}.css")
	pdf_css_file = "#{pdf_css_dir}/#{project_dir}/#{stage_dir}.css"
elsif File.file?("#{pdf_css_dir}/#{project_dir}/pdf.css")
	pdf_css_file = "#{pdf_css_dir}/#{project_dir}/pdf.css"
else
 	pdf_css_file = "#{pdf_css_dir}/torDOTcom/pdf.css"
end

if File.file?("#{epub_css_dir}/#{project_dir}/#{stage_dir}.css")
	epub_css_file = "#{epub_css_dir}/#{project_dir}/#{stage_dir}.css"
elsif File.file?("#{epub_css_dir}/#{project_dir}/epub.css")
	epub_css_file = "#{epub_css_dir}/#{project_dir}/epub.css"
else
 	epub_css_file = "#{epub_css_dir}/generic/epub.css"
end

proj_js_file = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "scripts", project_dir, "pdf.js")
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
check_tocbody = File.read(xml_file).scan(/w:pStyle w:val\="TOC/)
check_tochead = File.read(Bkmkr::Paths.outputtmp_html).scan(/class="texttoc"/)
if check_tocbody.any? or check_tochead.any?
	toc_value = "true"
else
	toc_value = "false"
end

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

# Printing the project json
File.open(configfile, 'w+') do |f|
	f.puts '{'
	f.puts '"title":"' + booktitle + '",'
	f.puts '"subtitle":"' + booksubtitle + '",'
	f.puts '"author":"' + authorname + '",'
	f.puts '"productid":"' + pisbn + '",'
	f.puts '"printid":"' + pisbn + '",'
	f.puts '"ebookid":"' + eisbn + '",'
	f.puts '"imprint":"' + imprint + '",'
	f.puts '"publisher":"' + publisher + '",'
	f.puts '"project":"' + project_dir + '",'
	f.puts '"stage":"' + stage_dir + '",'
	f.puts '"printcss":"' + pdf_css_file + '",'
	f.puts '"printjs":"' + pdf_js_file + '",'
	f.puts '"ebookcss":"' + epub_css_file + '",'
	f.puts '"pod_toc":"' + toc_value + '",'
	if stage_dir == "firstpass" and frontcover.empty?
		f.puts '"frontcover":"' + pisbn + '_FC.jpg"'
	elsif stage_dir == "egalley" and frontcover.empty?
		f.puts '"frontcover":"' + pisbn + '_FC.jpg"'
	elsif stage_dir == "arc-sans" or stage_dir == "arc-serif" or stage_dir == "RBM" and frontcover.empty?
		f.puts '"frontcover":"' + pisbn + '_FC.jpg"'
	else
		f.puts '"frontcover":"' + frontcover + '"'
	end
	unless epubtitlepage.nil?
		f.puts ',"epubtitlepage":"' + epubtitlepage + '"'
	end
	unless podtitlepage.nil?
		f.puts ',"podtitlepage":"' + podtitlepage + '"'
	end
	f.puts '}'
end