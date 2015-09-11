# encoding: utf-8

require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']

# ftp url
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg"

pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "pdfmaker")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker")

# create pdf tmp directory
unless File.exist?(pdftmp_dir)
	Dir.mkdir(pdftmp_dir)
end

images = Dir.entries(Bkmkr::Paths.submitted_images)
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")
allimg = File.join(images, "*")
ptparr = Dir[allimg].select { |f| f.include?('titlepage.')}
if ptparr.any?
  podtitlepage = ptparr.find { |e| /(\/?\\?)+titlepage\./ =~ e }
end

unless podtitlepage.nil?
  tpfilename = epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  podtitlepagearc = File.join(finalimagedir, tpfilename)
  podtitlepagejpg = File.join(Bkmkr::Paths.submitted_images, "titlepage_fullpage.jpg")
  podfiletype = etpfilename.split(".").pop
  filecontents = File.read(epub_tmp_html).gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
  File.open(pdf_tmp_html, 'w') do |output| 
    output.write filecontents
  end
  unless etpfiletype == "jpg"
    `convert "#{podtitlepage}" "#{podtitlepagejpg}"`
    FileUtils.mv(podtitlepage, podtitlepagearc)
  end
  FileUtils.cp(podtitlepagejpg, Bkmkr::Paths.project_tmp_dir_img)
  FileUtils.mv(podtitlepagejpg, finalimagedir)
  # insert titlepage image
  pdfmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "pdfmaker_preprocessing.js")
  Bkmkr::Tools.runnode(pdfmakerpreprocessingjs, pdf_tmp_html)
end

#if any images are in 'done' dir, grayscale and upload them to macmillan.tools site
images = Dir.entries("#{Bkmkr::Paths.project_tmp_dir_img}").select {|f| !File.directory? f}
image_count = images.count
if image_count > 0
	FileUtils.cp Dir["#{Bkmkr::Paths.project_tmp_dir_img}/*"].select {|f| test ?f, f}, pdftmp_dir
	pdfimages = Dir.entries(pdftmp_dir).select { |f| !File.directory? f }
	pdfimages.each do |i|
		pdfimage = File.join(pdftmp_dir, "#{i}")
		if i.include?("fullpage")
			#convert command for ImageMagick should work the same on any platform
			`convert "#{pdfimage}" -colorspace gray "#{pdfimage}"`
		elsif i.include?("_FC") or i.include?(".txt") or i.include?(".css") or i.include?(".js")
			FileUtils.rm("#{pdfimage}")
		else
			myres = `identify -format "%y" "#{pdfimage}"`
			myres = myres.to_f
			myheight = `identify -format "%h" "#{pdfimage}"`
			myheight = myheight.to_f
			myheightininches = ((myheight / myres) * 72.0)
			mywidth = `identify -format "%h" "#{pdfimage}"`
			mywidth = mywidth.to_f
			mywidthininches = ((mywidth / myres) * 72.0)
			if mywidthininches > 3.5 or myheightininches > 5.5 then
				targetheight = 5.5 * myres
				targetwidth = 3.5 * myres
				`convert "#{pdfimage}" -resize "#{targetwidth}x#{targetheight}>" "#{pdfimage}"`
			end
			myheight = `identify -format "%h" "#{pdfimage}"`
			myheight = myheight.to_f
			myheightininches = ((myheight / myres) * 72.0)
			mymultiple = ((myheight / myres) * 72.0) / 16.0
			if mymultiple <= 1
				`convert "#{pdfimage}" -colorspace gray "#{pdfimage}"`
			else 
				newheight = ((mymultiple.floor * 16.0) / 72.0) * myres
				`convert "#{pdfimage}" -resize "x#{newheight}" -colorspace gray "#{pdfimage}"`
			end
		end
	end
end

# copy assets to tmp upload dir and upload to ftp
FileUtils.cp Dir["#{assets_dir}/images/#{project_dir}/*"].select {|f| test ?f, f}, pdftmp_dir

if Bkmkr::Tools.os == "mac" or Bkmkr::Tools.os == "unix"
	ftpfile = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_ftpupload", "imageupload.sh")
	pdfimages = Dir.entries(pdftmp_dir).select { |f| !File.directory? f }
	pdfimages.each do |i|
		`#{ftpfile} #{i} #{pdftmp_dir}`
	end
elsif Bkmkr::Tools.os == "windows"
	ftpfile = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_ftpupload", "imageupload.bat")
	`#{ftpfile} #{pdftmp_dir} #{Bkmkr::Paths.project_tmp_dir_img}`
end

# fixes images in html, keep final words and ellipses from breaking
# .gsub(/([a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>")
filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/src="images\//,"src=\"#{ftp_dir}/").gsub(/([a-zA-Z0-9]?[a-zA-Z0-9]?[a-zA-Z0-9]?\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>").gsub(/(\s)(\w\w\w*?\.)(<\/p>)/,"\\1<span class=\"bookmakerkeeptogetherkt\">\\2</span>\\3")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# fixes em dash breaks (requires UTF 8 encoding)
filecontents = File.read(pdf_tmp_html, :encoding=>"UTF-8").gsub(/(.)?(—\??\.?!?”?’?)(.)?/,"\\1\\2&\#8203;\\3").gsub(/(<p class="FrontSalesQuotefsq">“)(A)/,"\\1&\#8202;\\2")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# TESTING

# count, report images in file
if image_count > 0

	# test if sites are up/logins work?

	# verify files were uploaded, and match image array
    upload_report = []
    File.read("#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt").each_line {|line|
          line_b = line.gsub(/\n$/, "")
          upload_report.push line_b}
 	upload_count = upload_report.count
	
	if upload_report.sort == images.sort
		test_image_array_compare = "pass: Images in Done dir match images uploaded to ftp"
	else
		test_image_array_compare = "FAIL: Images in Done dir match images uploaded to ftp"
	end
	
else
	upload_count = 0
	test_image_array_compare = "pass: There are no missing image files"
end

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
	f.puts "----- PDFMAKER-PREPROCESSOR PROCESSES"
	f.puts "----- I found #{image_count} images to be uploaded"
	f.puts "----- I found #{upload_count} files uploaded"
	f.puts "#{test_image_array_compare}"
end
