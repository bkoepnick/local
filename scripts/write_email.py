#!/bin/python

def write_email( team, attachments ):
    recipients = ",".join( team[4] )
    subject = "CASP11 " + args.target + " - Puzzle " + args.puzzle + " - " + team[5]
    body = EMAIL_BODY.format( team[5], args.puzzle, args.target, args.due )
    if args.note:
        body += "\n" + args.note


    content = "To: " + recipients + "\n"
    content += "From: " + EMAIL_SEND_ADDRESS + "\n"
    content += "Subject: " + subject + "\n"
    content += ("MIME-Version: 1.0\n"
        "Content-Type: multipart/mixed; boundary=\"EMAILBOUNDARY\"\n"
        "--EMAILBOUNDARY\n"
        "Content-Type: text/html\n"
        "Content-Disposition: inline\n")
    content += body + "\n"

    for attachment in attachments:
        zip_attachment = attachment[0]
        attachment_info = attachment[1]
        #encode_out = subprocess.Popen( ['uuencode', '-m', zip_attachment, os.path.basename( zip_attachment )], stdout=subprocess.PIPE, stderr=subprocess.STDOUT ).communicate()

        # check for stderr output; if none, append encoded file to email with info attachment; else print error
        content += "--EMAILBOUNDARY\n"
        content += "Content-Type: application\n"
        content += "Content-Transfer-Encoding: base64\n"
        content += "Content-Disposition: attachment; filename=" + os.path.basename( zip_attachment ) + "\n"
        content += "{0}\n"

        content += "--EMAILBOUNDARY\n"
        content += "Content-Type: text/plain\n"
        content += "Content-Disposition: attachment; filename=\"info_" + os.path.basename( zip_attachment ) + "\"\n"
        content += "\n".join( attachment_info )

    content += "--EMAILBOUNDARY--\n"

    efile = open( "email" + team[0], 'w' )
    efile.write( content )
    efile.close()
