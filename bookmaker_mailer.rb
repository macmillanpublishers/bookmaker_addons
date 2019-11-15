# require 'net/smtp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'


# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

finalpdf = File.join(Metadata.final_dir, "#{Metadata.pisbn}_POD.pdf")
firstpass_epub = File.join(Metadata.final_dir, "#{Metadata.pisbn}_EPUBfirstpass.epub")
final_epub = File.join(Metadata.final_dir, "#{Metadata.pisbn}_EPUB.epub")
errfiles_regexp = File.join(final_dir, "*_ERROR.txt")
message_txtfile = File.join(final_dir, "user_email.txt")
sendmail_py = File.join(scripts_dir, "utilities", "python_utils", "sendmail.py")
workflows_email = 'workflows@macmillan.com'
attachment_quota = 20.0
staging_file = File.join("C:", "staging.txt")

# ---------------------- METHODS
def readJson(jsonfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(jsonfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def addAttachment(file, attachment_quota, attachments, toolarge_files, logkey='')
  if File.exists?(file)
    if attachment_quota - File.size(file) / 1024000.0 > 0  # test if this fits with size quota
      attachments.push(file)
      attachment_quota -= File.size(file) / 1024000.0  # reduce tot. attachment quota by errfile size (MB)
      logstring = 'added to attachment array'
    else
      toolarge_files.push(file)
      logstring = 'too large to attach'
    end
  end
  return attachment_quota, attachments, toolarge_files
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getErrMessage(firstname, title, isbn, workflows_email, logkey='')
  message = "Subject: Bookmaker update: \"#{title}\"\n\n"
  message += "Hello #{firstname},\n\n"
  message += "Bookmaker encountered an error while processing your file, \"#{title}\" (#{isbn}).\n"
  message += "The workflows team has been notified of this error.\n\n"
  message += "If you don't hear from us within 2 hours, please email \"#{workflows_email}\" for further assistance."
  return message
rescue => logstring
  return ""
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def messageBuilder(firstname, title, isbn, errfiles, err_attached, good_attached, toolarge_files, logkey='')
  message = "Subject: Bookmaker completed for \"#{title}\"\n\n"
  message += "Hello #{firstname},\n\n"
  message += "Bookmaker processing has completed for \"#{title}\" (#{isbn}).\n\n"
  message += "You can retrieve Bookmaker epub and pdf output in RSuite, in the ‘Interior/Bookmaker/Done’ folder for\
   the WIP impression of this edition (#{isbn}).\n"
  if errfiles == true
    message += "\nPLEASE NOTE:\nSome alerts were encountered while processing your file. See attached .txt files for details:\n"
    errfilelist = err_attached.map {|file| " - #{File.basename(file)}\n"}.compact
    for errfile in errfilelist
      message += errfile
    end
  end
  if !good_attached.empty?
    message += "\nFor your convenience, these bookmaker output files are also attached to this email:\n"
    goodfilelist = good_attached.map {|file| " - #{File.basename(file)}\n"}.compact
    for goodfile in goodfilelist
      message += goodfile
    end
  end
  if !toolarge_files.empty?
    message += "(The following bookmaker output files were too large to attach here, but are available in RSuite)\n"
    toolargefilelist = toolarge_files.map {|file| " - #{File.basename(file)}\n"}.compact
    for toolargefile in toolargefilelist
      message += toolargefile
    end
  end
  return message
rescue => logstring
  return ""
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeFile(contents, file, logkey='')
  File.open(file, "w") do |f|
    f.puts(contents)
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runpython in a new method for this script; to return a result for json_logfile
def localRunPython(py_script, args, logkey='')
	results = Bkmkr::Tools.runpython(py_script, args)
  return results
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


#
# def rescuemail(orig_to,orig_ccs,orig_header,from_email)
#   message = <<MESSAGE_END
# From: Workflows <#{from_email}>
# To: Workflows <#{from_email}>
# Subject: ALERT: automated mail failed to send!
# This mail is an alert that an automated mail failed to send.
# Original addressee was: #{orig_to}
# Original cc addresses were: #{orig_ccs}
# Original header was: #{orig_header}
# MESSAGE_END
#   message
# end
#
# def sendrescue_mail(orig_to,orig_ccs,orig_header,from_email, logkey='')
#   logstring = "\"sendmail\" failed, attempting new alertmail to workflows"
#   message = rescuemail(orig_to,orig_ccs,orig_header)
#   Net::SMTP.start(smtp_address) do |smtp|
#     smtp.send_message message, from_email,
#                                 from_email
# end
# rescue => logstring
# ensure
#   Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
# end
#
# def sendmail(message, to_email, cc_emails, from_email, logkey='')
#   if cc_emails.empty?
#       Net::SMTP.start(smtp_address) do |smtp|
#         smtp.send_message message, from_email,
#                                   to_email
#       end
#   else
#       Net::SMTP.start(smtp_address) do |smtp|
#         smtp.send_message message, from_email,
#                                   to_email, cc_emails
#       end
#   end
# rescue => logstring
#   sendrescue_mail(to_email,cc_emails,message.lines[0..3],from_email, 'send_email-rescue_mail')
# ensure
#   Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
# end



# ---------------------- PROCESSES
# default values for local vars
submittermail = workflows_email
firstname = "Unknown"
title = 'title unavailable'
isbn = ''
bookmaker_send_result = ''
output_ok = ''
in_rsuite = ''
errfiles = ''
err_attached = []
good_attached = []
all_attachments = []
toolarge_files = []

# read in jsons
data_hash = readJson(Metadata.configfile, 'read_config_json')
rsmetadata_hash = readJson(Bkmkr::Paths.fromrsuite_Metadata_json, 'read_rsuite_metadata_json')
jsonlog_hash = readJson(Bkmkr::Paths.json_log, 'read_jsonlog')

# conditional local definition(s) based on config.json
submittermail = rsmetadata_hash["submitter_email"] if rsmetadata_hash.key?("submitter_email")
title = rsmetadata_hash["work_cover_title"] if rsmetadata_hash.key?("work_cover_title")
isbn = rsmetadata_hash["edition_eanisbn13"] if rsmetadata_hash.key?("edition_eanisbn13")
firstname = submittermail.to_s.partition(/[@.]/)[0].capitalize if !submittermail.empty?
if jsonlog_hash.key?("bookmaker_to_rsuite.rb") && jsonlog_hash["bookmaker_to_rsuite.rb"].key?("api_POST_result")
  bookmaker_send_result = jsonlog_hash["bookmaker_to_rsuite.rb"]["api_POST_result"]
else
  bookmaker_send_result = 'value not present'
end

# Check errfiles, attach if present
if Dir.glob(errfiles_regexp).empty?
  errfiles = false
else
  errfiles = true
  for errfile in Dir.glob(errfiles_regexp)
    attachment_quota, err_attached, toolarge_files = addAttachment(errfile, attachment_quota, err_attached, toolarge_files, "attach_#{File.basename(errfile)}")
  end
end

# Check output file(s), attach if present (and not too big)
if File.exists?(finalpdf) && (File.exists?(firstpass_epub) || File.exists?(final_epub))
  output_ok = true
  if File.exists?(final_epub)
    attachment_quota, good_attached, toolarge_files = addAttachment(final_epub, attachment_quota, good_attached, toolarge_files, "attach_#{File.basename(final_epub)}")
  elsif File.exists?(firstpass_epub)
    attachment_quota, good_attached, toolarge_files = addAttachment(firstpass_epub, attachment_quota, good_attached, toolarge_files, "attach_#{File.basename(firstpass_epub)}")
  end
  if File.exists?(finalpdf)
    attachment_quota, good_attached, toolarge_files = addAttachment(finalpdf, attachment_quota, good_attached, toolarge_files, "attach_#{File.basename(finalpdf)}")
  end
end

if bookmaker_send_result.match(/^success/)
  in_rsuite = true
end

if output_ok == true && in_rsuite == true #&& errfiles == false
  message = messageBuilder(firstname, title, isbn, errfiles, err_attached, good_attached, toolarge_files, 'build_success_message')
else
  message = getErrMessage(firstname, title, isbn, workflows_email, 'build_error_message')
end

if File.exist?(staging_file)
  message += "\n\n --- This automated message was sent from TESTING SERVER ---"
end

writeFile(message, message_txtfile, "write_emailtxt_to_file")

# consolidate attachments
all_attachments = good_attached + err_attached
# prepare arglist for python call
attachments_argstring = '\"' + all_attachments.join('\" \"') + '\"'

# send our notification
results = localRunPython(sendmail_py, "\"#{submittermail}\" \"#{workflows_email}\" \"#{message_txtfile}\" #{attachments_argstring}", "invoke_sendmail-py")
# sendmail(message, submittermail, [workflows_email], workflows_email, "send_email--#{mail_logkey}")


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
