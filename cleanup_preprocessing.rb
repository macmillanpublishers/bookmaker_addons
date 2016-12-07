require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

uploaded_image_log = "#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt"


# ---------------------- METHODS
## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile

def localCheckFileExist(file, logkey='')
  fileexist = Mcmlln::Tools.checkFileExist(file)
  logstring = fileexist
  return fileexist
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def localCheckFileEmpty(file, logkey='')
  fileempty = Mcmlln::Tools.checkFileEmpty(file)
  logstring = fileempty
  return fileempty
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

#wrapping ftp class method in its own separate method: to write to jsonlog here and leave class methods more general.
def ftpDeleteDir(parentfolder, childfolder, logkey='')
  Ftpfunctions.deleteFTP("#{Metadata.project_dir}_#{Metadata.stage_dir}", Metadata.pisbn)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES
# clean up the ftp site if files were uploaded
fileexist = localCheckFileExist(uploaded_image_log, 'ftp_upload_image_log_exist?')
fileempty = localCheckFileEmpty(uploaded_image_log, 'ftp_upload_image_log_empty?')

ftpDeleteDir("#{Metadata.project_dir}_#{Metadata.stage_dir}", Metadata.pisbn, 'delete_images_off_ftp')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
