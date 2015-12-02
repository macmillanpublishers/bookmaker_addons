require 'net/ftp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

data_hash = Bkmkr::Tools.readjson(Metadata.configfile)
project_dir = data_hash['project']
stage_dir = data_hash['stage']

# clean up the ftp site if files were uploaded
uploaded_image_log = "#{Bkmkr::Paths.project_tmp_dir_img}/uploaded_image_log.txt"
fileexist = Bkmkr::Tools.checkFileExist(uploaded_image_log)
fileempty = Bkmkr::Tools.checkFileEmpty(uploaded_image_log)

ftp_username = Bkmkr::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_username.txt")
ftp_password = Bkmkr::Tools.readFile("#{$scripts_dir}/bookmaker_authkeys/ftp_pass.txt")

def checkFTP(parentfolder, childfolder)
  ftp = Net::FTP.new('142.54.232.104')
  ftp.login(user = "#{ftp_username}", passwd = "#{ftp_password}")
  files = ftp.chdir("/files/html/bookmaker/bookmakerimg/#{parentfolder}/#{childfolder}")
  filenames = ftp.nlst()
  filenames
end

def deleteFTP(parentfolder, childfolder)
  ftp = Net::FTP.new('142.54.232.104')
  ftp.login(user = "#{ftp_username}", passwd = "#{ftp_password}")
  files = ftp.chdir("/files/html/bookmaker/bookmakerimg/#{parentfolder}/#{childfolder}")
  filenames = ftp.nlst()
  puts filenames #for testing
  filenames.each do |d|
    file = ftp.delete(d)
  end
  files = ftp.nlst()
  ftp.close
  files
  puts files #for testing
end

ftpstatus = checkFTP("#{project_dir}_#{stage_dir}", Metadata.pisbn)

unless ftpstatus.empty?
  deleteFTP("#{project_dir}_#{stage_dir}", Metadata.pisbn)
end