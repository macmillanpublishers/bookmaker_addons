require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# The locations to check for images
imagedir = Bkmkr::Paths.submitted_images

final_dir_images = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

final_cover = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "cover", Metadata.frontcover)

# full path to the image error file
image_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "IMAGE_ERROR.txt")

# path to placeholder image
missing_jpg = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "pdfmaker", "images", "generic", "missing.jpg")

# ---------------------- METHODS

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def getFilesinDir(path, logkey='')
  files = Mcmlln::Tools.dirListFiles(path)
  return files
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def readOutputHtml(logkey='')
  filecontents = File.read(Bkmkr::Paths.outputtmp_html)
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# If an image_error file exists, delete it
def checkErrorFile(file, logkey='')
  if File.file?(file)
    Mcmlln::Tools.deleteFile(file)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def listImages(html, logkey='')
  # An array of all the image files referenced in the source html file
  imgarr = html.scan(/img src=".*?"/)
  # remove duplicate image names from source array
  imgarr = imgarr.uniq
  imgarr
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkImages(imglist, inputdirlist, finaldirlist, inputdir, logkey='')
  # An empty array to store the list of any missing images
  missing = []
  # An empty array to store filenames with bad types
  format = []
  supported = []

  # Checks to see if image format is supported
  imglist.each do |m|
    match = m.split("/").pop.gsub(/"/,'')
    matched_file = File.join(inputdir, match)
  	imgformat = match.split(".").pop.downcase
    unless imgformat == "jpg" or imgformat == "jpeg" or imgformat == "png" or imgformat == "pdf" or imgformat == "ai"
      format << match
      Mcmlln::Tools.deleteFile(matched_file)
    else
      supported << match
    end
    if !inputdirlist.include?("#{match}") and match != Metadata.frontcover and !finaldirlist.include?("#{match}")
      missing << match
    end
  end
  return format, supported, missing
rescue => logstring
  return [],[],[]
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def convertImages(arr, dir, logkey='')
  corrupt = []
  converted = []
  if arr.any?
    arr.each do |c|
      filename = c.split(".").shift
      imgformat = c.split(".").pop.downcase
      imgpath = File.join(dir, c)
      finaljpg = File.join(dir, "#{filename}.jpg")
      if imgformat == "jpeg" or imgformat == "png"
        puts "converting #{c} to jpg"
        myres = `identify -format "%y" "#{imgpath}"`
        if myres.nil? or myres.empty? or !myres
          corrupt << c
        else
          `convert "#{imgpath}" -density #{myres} -quality 100 "#{finaljpg}"`
          Mcmlln::Tools.deleteFile(imgpath)
          converted << c
        end
      elsif imgformat == "ai" or imgformat == "pdf"
        puts "converting #{c} to jpg"
        `convert "#{imgpath}" -density 300x300 -quality 100 "#{finaljpg}"`
        Mcmlln::Tools.deleteFile(imgpath)
        converted << c
      end
    end
  end
  return corrupt, converted
rescue => logstring
  return [],[]
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# replace bad images with placeholder
def insertPlaceholders(arr, html, placeholder, dest, logkey='')
  filecontents = html
  if arr.any?
    arr.each do |r|
      filecontents = filecontents.gsub(/#{r}/,"missing.jpg")
    end
    Mcmlln::Tools.copyFile(placeholder, dest)
  else
    logstring = 'n-a'
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# replace image references with jpg file format
def replaceFormats(arr, html, logkey='')
  filecontents = html
  if arr.any?
    arr.each do |r|
      imgfilename = r.split(".").shift
      filecontents = filecontents.gsub(/#{r}/,"#{imgfilename}.jpg\"")
    end
  else
    'n-a'
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeTypeErrors(arr, file, logkey='')
  # Writes an error text file in the done\pisbn\ folder that lists all low res image files as stored in the resolution array
  if arr.any?
    File.open(file, 'a+') do |output|
      output.puts "IMAGE FORMAT ERRORS:"
      output.puts "Images should use one of the following image formats: .jpg, .jpeg, .png, .ai, .pdf."
      output.puts "The following images have unsupported image types:"
      arr.each do |r|
        output.puts r
      end
    end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteFile(path, filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

filecontents = readOutputHtml('read_outputtmp-html')

images = getFilesinDir(Bkmkr::Paths.project_tmp_dir_img, 'get_files_in_tmpImgDir')

finalimages = getFilesinDir(final_dir_images, 'get_files_in_finalImgDir')

checkErrorFile(image_error, 'delete_image_error_file')

# run method: list unique images referenced in html
imgarr = listImages(filecontents, 'list_images')

# run method: checkImages
format, supported, missing = checkImages(imgarr, images, finalimages, Bkmkr::Paths.project_tmp_dir_img, 'check_images')

# print a list of any unsupported image types to std log & json log
unless format.nil? or format.empty? or !format
  puts "UNSUPPORTED IMAGE TYPES:"
  puts format
  @log_hash['unsupported_image_types'] = format
end

# run method: convertImages
corrupt, converted = convertImages(supported, Bkmkr::Paths.project_tmp_dir_img, 'convert_images')

# print a list of converted and or corrupt images to json_logfile
@log_hash['corrupt_images'] = corrupt
@log_hash['converted_images'] = converted

# run method: insertPlaceholders for format
filecontents = insertPlaceholders(format, filecontents, missing_jpg, Bkmkr::Paths.project_tmp_dir_img, 'insert_placeholders_for_bad_formats')

# run method: insertPlaceholders for missing
filecontents = insertPlaceholders(missing, filecontents, missing_jpg, Bkmkr::Paths.project_tmp_dir_img, 'insert_placeholders_for_missing')

# run method: writeTypeErrors
writeTypeErrors(format, image_error, 'write_img_err_file')

# run method: replaceFormats
filecontents = replaceFormats(imgarr, filecontents, 'replace_img-refs_with_jpg-format_refs')

# overwrite outputtmp_html
overwriteFile(Bkmkr::Paths.outputtmp_html, filecontents, 'overwrite_output_html')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
