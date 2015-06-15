require 'FileUtils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

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

#if any images are in 'done' dir, grayscale and upload them to macmillan.tools site
images = Dir.entries("#{Bkmkr::Paths.project_tmp_dir_img}").select {|f| !File.directory? f}
image_count = images.count
if image_count > 0
	FileUtils.cp Dir["#{Bkmkr::Paths.project_tmp_dir_img}/*"].select {|f| test ?f, f}, pdftmp_dir
	pdfimages = Dir.entries("#{Bkmkr::Paths.project_tmp_dir_img}/pdftmp").select { |f| !File.directory? f }
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
FileUtils.cp Dir["#{assets_dir}/images/#{Bkmkr::Project.project_dir}/*"].select {|f| test ?f, f}, pdftmp_dir
`#{Bkmkr::Paths.scripts_dir}\\bookmaker_ftpupload\\imageupload.bat #{Bkmkr::Paths.tmp_dir}\\#{Bkmkr::Project.filename}\\images\\pdftmp #{Bkmkr::Paths.tmp_dir}\\#{Bkmkr::Project.filename}\\images`

# fixes images in html
filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/src="images\//,"src=\"#{ftp_dir}/").gsub(/\s[a-zA-Z0-9]+\. \. \./,"<span class=\"bookmakerkeeptogetherkt\">\. \. \.</span>").to_s

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
