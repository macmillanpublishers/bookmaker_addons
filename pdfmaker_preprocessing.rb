# encoding: utf-8

require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES

# ---------------------- METHODS

# ---------------------- PROCESSES

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']
stage_dir = data_hash['stage']

# ftp url
ftp_dir = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg/#{project_dir}_#{stage_dir}/#{Metadata.pisbn}"

pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "pdfmaker")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker")
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

# create pdf tmp directory
unless File.exist?(pdftmp_dir)
	Dir.mkdir(pdftmp_dir)
end

FileUtils.cp(Bkmkr::Paths.outputtmp_html, pdf_tmp_html)

unless Metadata.podtitlepage == "Unknown"
  puts "found a pod titlepage image"
  tpfilename = Metadata.podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  podfiletype = tpfilename.split(".").pop
  podtitlepagearc = File.join(finalimagedir, tpfilename)
  podtitlepagetmp = File.join(Bkmkr::Paths.project_tmp_dir_img, "titlepage_fullpage.jpg")
  if podfiletype == "jpg"
  	FileUtils.cp(podtitlepagearc, podtitlepagetmp)
  else
    `convert "#{podtitlepagearc}" "#{podtitlepagetmp}"`
  end
  # insert titlepage image
  filecontents = File.read(pdf_tmp_html).gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
  File.open(pdf_tmp_html, 'w') do |output| 
    output.write filecontents
  end
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
			myheightininches = (myheight / myres)
			mywidth = `identify -format "%w" "#{pdfimage}"`
			mywidth = mywidth.to_f
			mywidthininches = (mywidth / myres)
			if mywidthininches > 3.5 or myheightininches > 5.5 then
				targetheight = 5.5 * myres
				targetwidth = 3.5 * myres
				`convert "#{pdfimage}" -density #{myres} -resize "#{targetwidth}x#{targetheight}>" -quality 100 "#{pdfimage}"`
			end
			myheight = `identify -format "%h" "#{pdfimage}"`
			myheight = myheight.to_f
			myheightininches = (myheight / myres)
			mymultiple = ((myheight / myres) * 72.0) / 16.0
			if mymultiple <= 1
				`convert "#{pdfimage}" -density #{myres} -colorspace gray "#{pdfimage}"`
			else 
				newheight = ((mymultiple.floor * 16.0) / 72.0) * myres
				`convert "#{pdfimage}" -density #{myres} -resize "x#{newheight}" -quality 100 -colorspace gray "#{pdfimage}"`
			end
		end
	end
end

# copy assets to tmp upload dir and upload to ftp
FileUtils.cp Dir["#{assets_dir}/images/#{project_dir}/*"].select {|f| test ?f, f}, pdftmp_dir

uploadfiles = Mcmlln::Tools.dirListFiles(pdftmp_dir)

ftp_username = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_password = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
ftp_url = "142.54.232.104"

ftp = Net::FTP.new("#{url}")
ftp.login(user = "#{ftp_username}", passwd = "#{ftp_password}")
files = ftp.binary(true)
files = ftp.chdir("/files/html/bookmaker/bookmakerimg")
files = ftp.mkdir("#{project_dir}_#{stage_dir}")
files = ftp.chdir("#{project_dir}_#{stage_dir}")
files = ftp.mkdir("#{Metadata.pisbn}")
files = ftp.chdir("#{Metadata.pisbn}")

uploadfiles.each do |p|
  this = ftp.put(p)
end

files = ftp.nlst()
ftp.close

puts "Uploaded these files to ftp: #{files}"

# if Bkmkr::Tools.os == "mac" or Bkmkr::Tools.os == "unix"
# 	ftpfile = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_ftpupload", "imageupload.sh")
# 	ftpcmd = "#{ftpfile} #{pdftmp_dir} #{project_dir}_#{stage_dir} #{Metadata.pisbn}>> #{Bkmkr::Paths.log_file}"
# 	puts ftpcmd
# 	`#{ftpfile} #{pdftmp_dir} #{project_dir}_#{stage_dir} "#{Metadata.pisbn}">> #{Bkmkr::Paths.log_file}`
# elsif Bkmkr::Tools.os == "windows"
# 	ftpfile = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_ftpupload", "imageupload.bat")
# 	`#{ftpfile} #{pdftmp_dir} #{Bkmkr::Paths.project_tmp_dir_img} #{project_dir}_#{stage_dir} #{Metadata.pisbn}`
# end

# run content conversions
pdfmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "pdfmaker_preprocessing.js")
args = "\"#{pdf_tmp_html}\" \"#{Metadata.booktitle}\" \"#{Metadata.bookauthor}\" \"#{Metadata.pisbn}\" \"#{Metadata.imprint}\" \"#{Metadata.publisher}\""
Bkmkr::Tools.runnode(pdfmakerpreprocessingjs, args)

# fixes images in html, keep final words and ellipses from breaking
# .gsub(/([a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>")
filecontents = File.read(pdf_tmp_html).gsub(/src="images\//,"src=\"#{ftp_dir}/").gsub(/([a-zA-Z0-9]?[a-zA-Z0-9]?[a-zA-Z0-9]?\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>").gsub(/(\s)(\w\w\w*?\.)(<\/p>)/,"\\1<span class=\"bookmakerkeeptogetherkt\">\\2</span>\\3")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# fixes em dash breaks (requires UTF 8 encoding)
filecontents = File.read(pdf_tmp_html, :encoding=>"UTF-8").gsub(/(.)?(—\??\.?!?”?’?)(.)?/,"\\1\\2&\#8203;\\3").gsub(/(<p class="FrontSalesQuotefsq">“)(A)/,"\\1&\#8202;\\2")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# ---------------------- LOGGING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
	f.puts "----- PDFMAKER-PREPROCESSING PROCESSES"
end
