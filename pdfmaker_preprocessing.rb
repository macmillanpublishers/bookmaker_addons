# encoding: utf-8

require 'fileutils'
require 'net/ftp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
data_hash = Mcmlln::Tools.readjson(Metadata.configfile)

project_dir = data_hash['project']
stage_dir = data_hash['stage']

# full path to the image error file
image_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "IMAGE_ERROR.txt")

# specs for image resizing
maxheight = 5.5
maxwidth = 3.5
grid = 16.0

# ftp url
ftpdirext = "http://www.macmillan.tools.vhost.zerolag.com/bookmaker/bookmakerimg/#{project_dir}_#{stage_dir}/#{Metadata.pisbn}"
ftpdirint = "/files/html/bookmaker/bookmakerimg/#{project_dir}_#{stage_dir}/#{Metadata.pisbn}"

pdftmp_dir = File.join(Bkmkr::Paths.project_tmp_dir_img, "pdftmp")
pdfmaker_dir = File.join(Bkmkr::Paths.core_dir, "pdfmaker")
pdf_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "pdf_tmp.html")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker")
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

# ---------------------- METHODS

# gets image conversion specs to fit the images to the grid
def calcImgSizes(res, file, maxheight, maxwidth, grid)
  myres = res.to_f
  myheight = `identify -format "%h" "#{file}"`
  myheight = myheight.to_f
  myheightininches = (myheight / myres)
  mywidth = `identify -format "%w" "#{file}"`
  mywidth = mywidth.to_f
  mywidthininches = (mywidth / myres)
  # if current height or width exceeds max, resize to max, proportionately
  if mywidthininches > maxwidth or myheightininches > maxheight then
    targetheight = maxheight * myres
    targetwidth = maxwidth * myres
    `convert "#{file}" -density #{myres} -resize "#{targetwidth}x#{targetheight}>" -quality 100 "#{file}"`
  end
  myheight = `identify -format "%h" "#{file}"`
  myheight = myheight.to_f
  myheightininches = (myheight / myres)
  mymultiple = ((myheight / myres) * 72.0) / grid
  if mymultiple <= 1
    resizecmd = ""
  else 
    newheight = ((mymultiple.floor * grid) / 72.0) * myres
    resizecmd = "-resize \"x#{newheight}\" "
  end
  return resizecmd
end

def writeImageErrors(arr, file)
  # Writes an error text file in the done\pisbn\ folder that lists all missing image files as stored in the missing array
  if arr.any?
    File.open(file, 'a+') do |output|
      output.puts "IMAGE PROCESSING ERRORS:"
      output.puts "The following images encountered processing errors and may be corrupt:"
      arr.each do |m|
        output.puts m
      end
    end
  end
end

class Ftpfunctions
  @@ftp_username = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_username.txt")
  @@ftp_password = Mcmlln::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_pass.txt")
  @@ftp_url = "142.54.232.104"

  def self.loginFTP(url, uname, pwd)
    ftp = Net::FTP.new("#{url}")
    ftp.login(user = "#{uname}", passwd = "#{pwd}")
    return ftp
    puts "logged into FTP: #{url}"
  end

  def self.createDirs(parentfolder, childfolder)
    ftp = Ftpfunctions.loginFTP(@@ftp_url, @@ftp_username, @@ftp_password)
    files = ftp.chdir("/files/html/bookmaker/bookmakerimg/")
    ls = ftp.nlst()
    unless ls.include?(parentfolder)
      ftp.mkdir(parentfolder)
    end
    ftp.chdir(parentfolder)
    ls = ftp.nlst()
    unless ls.include?(childfolder)
      ftp.mkdir(childfolder)
    end
    ftp.chdir(childfolder)
    files = ftp.nlst()
    ftp.close
    puts files
    return files
  end

  def self.uploadImg(dir, srcdir, filenames)
    ftp = Ftpfunctions.loginFTP(@@ftp_url, @@ftp_username, @@ftp_password)
    files = ftp.chdir(dir)
    filenames.each do |p|
      filepath = File.join(srcdir, p)
      ftp.putbinaryfile(filepath)
    end
    files = ftp.nlst()
    ftp.close
    return files
    puts files
  end
end

# ---------------------- PROCESSES

# create pdf tmp directory
unless File.exist?(pdftmp_dir)
  Dir.mkdir(pdftmp_dir)
end

FileUtils.cp(Bkmkr::Paths.outputtmp_html, pdf_tmp_html)

filecontents = File.read(pdf_tmp_html)

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
  filecontents = filecontents.gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
end

#if any images are in 'done' dir, grayscale and upload them to macmillan.tools site
images = Dir.entries("#{Bkmkr::Paths.project_tmp_dir_img}").select {|f| !File.directory? f}
image_count = images.count
corrupt = []
processed = []
skipped = []

if image_count > 0
  FileUtils.cp Dir["#{Bkmkr::Paths.project_tmp_dir_img}/*"].select {|f| test ?f, f}, pdftmp_dir
  pdfimages = Dir.entries(pdftmp_dir).select { |f| !File.directory? f }
  pdfimages.each do |i|
    puts "converting #{i}"
    pdfimage = File.join(pdftmp_dir, "#{i}")
    if imgformat == "jpg"
      if i.include?("fullpage")
        #convert command for ImageMagick should work the same on any platform
        `convert "#{pdfimage}" -colorspace gray "#{pdfimage}"`
        filecontents = filecontents.gsub(/#{pdfimage}/,jpgimage)
        processed << pdfimage
      else
        myres = `identify -format "%y" "#{pdfimage}"`
        if myres.nil? or myres.empty? or !myres
          corrupt << pdfimage
        else
          resize = calcImgSizes(myres, pdfimage, maxheight, maxwidth, grid)
          `convert "#{pdfimage}" -density #{myres} #{resize}-quality 100 -colorspace gray "#{pdfimage}"`
        end
        processed << pdfimage
      end
    else
      skipped << pdfimage
      FileUtils.rm("#{pdfimage}")
    end
  end
end

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# run method: writeMissingErrors
writeImageErrors(corrupt, image_error)

# copy assets to tmp upload dir and upload to ftp
FileUtils.cp Dir["#{assets_dir}/images/#{project_dir}/*"].select {|f| test ?f, f}, pdftmp_dir

ftplist = Dir.entries(pdftmp_dir).select { |f| !File.directory? f }

ftpsetup = Ftpfunctions.createDirs("#{project_dir}_#{stage_dir}", Metadata.pisbn)
ftpstatus = Ftpfunctions.uploadImg(ftpdirint, pdftmp_dir, ftplist)

# run node.js content conversions
pdfmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "pdfmaker_preprocessing.js")
args = "\"#{pdf_tmp_html}\" \"#{Metadata.booktitle}\" \"#{Metadata.bookauthor}\" \"#{Metadata.pisbn}\" \"#{Metadata.imprint}\" \"#{Metadata.publisher}\""
Bkmkr::Tools.runnode(pdfmakerpreprocessingjs, args)

# fixes images in html, keep final words and ellipses from breaking
# .gsub(/([a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>")
filecontents = File.read(pdf_tmp_html).gsub(/src="images\//,"src=\"#{ftpdirext}/")
                                      .gsub(/([a-zA-Z0-9]?[a-zA-Z0-9]?[a-zA-Z0-9]?\s\. \. \.)/,"<span class=\"bookmakerkeeptogetherkt\">\\0</span>")
                                      .gsub(/(\s)(\w\w\w*?\.)(<\/p>)/,"\\1<span class=\"bookmakerkeeptogetherkt\">\\2</span>\\3")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# fixes em dash breaks (requires UTF 8 encoding)
filecontents = File.read(pdf_tmp_html, :encoding=>"UTF-8").gsub(/(.)?(—\??\.?!?”?’?)(.)?/,"\\1\\2&\#8203;\\3")
                                                          .gsub(/(<p class="FrontSalesQuotefsq">“)(A)/,"\\1&\#8202;\\2")

File.open(pdf_tmp_html, 'w') do |output| 
  output.write filecontents
end

# TESTING

# Printing the test results to the log file
File.open(Bkmkr::Paths.log_file, 'a+') do |f|
  f.puts "----- PDFMAKER-PREPROCESSING PROCESSES"
  f.puts "Processed the following images:"
  f.puts processed
  if corrupt.any?
      f.puts "IMAGE PROCESSING ERRORS:"
      f.puts "The following images encountered processing errors and may be corrupt:"
      f.puts corrupt
  end
  if skipped.any?
    f.puts "Skipped processing the following images:"
    f.puts skipped
  end
  f.puts "Uploaded the following images to the ftp:"
  f.puts ftpstatus
end
