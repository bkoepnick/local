#!/usr/bin/python

import sys, os, subprocess
import re, glob
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument( 'emails', type=str, nargs='*', help='email files' )
parser.add_argument( '-note', type=str, help='text to add to email body' )
args = parser.parse_args()

BOUNDARY = "MIMEBOUNDARY"
WORKING_DIR = os.path.abspath( os.getcwd() )

def email_attach( email_filename, email_lines, zip_attachments, text_attachments):
	content = []
	
	# copy over lines from current email, insert line for multipart format
	for line in email_lines:
		match = re.compile( "Content-Type" ).search( line )
		if match:
			content.append( "Content-Type: multipart/mixed; boundary=\"{0}\"\n".format( BOUNDARY ) )
			content.append( "\n--{0}\n".format( BOUNDARY ) )
		
		content.append( line )

	if args.note:
		content.append( "{0}\n".format( args.note ) )

	for attachment in zip_attachments:
		encode_out = subprocess.Popen( ['uuencode', '-m', attachment, os.path.basename( attachment )], 
stdout=subprocess.PIPE, stderr=subprocess.PIPE ).communicate()

		# check for stderr output; if none, append encoded file to email with info attachment; else print error
	  	if encode_out[1]:
			print "Error encoding: " + attachment + "\nERROR: " + encode_out[1]
			continue
		else:
			content.append( "\n--{0}\n".format( BOUNDARY ) )
			content.append( "Content-Type: application\n" )
			content.append( "Content-Transfer-Encoding: base64\n" )
			content.append( "Content-Disposition: attachment; filename=\"{0}\"\n\n".format( os.path.basename( attachment ) ) )

			# remove one-line header of uuencode output
			data = encode_out[0].strip().split("\n")[1:]
			content.append( "\n".join( data ) )


	for attachment in text_attachments:
		a_file = open( attachment, 'r' )
		a_lines = a_file.readlines()
		a_file.close()
		
		content.append( "\n--{0}\n".format( BOUNDARY ) )
		content.append( "Content-Type: text/plain\n" )
		content.append( "Content-Disposition: attachment; filename=\"{0}\"\n\n".format( os.path.basename( attachment ) ) )
		content.extend( a_lines )

	content.append( "\n--{0}--".format( BOUNDARY ) )

	efile = open( email_filename, 'w' )
	efile.writelines( content )
	efile.close()

#if os.getuid() != 0:
#    print "Script not started as root. Running sudo.."
#    args = ['sudo', sys.executable] + sys.argv + [os.environ]
    # the next line replaces the currently-running process with the sudo
#    os.execlpe('sudo', *args)

subprocess.call( ['postfix','start'] )

for email in args.emails:
	key = os.path.splitext( os.path.basename( email ) )[0]
	text_attachments = glob.glob( os.path.join( WORKING_DIR, "*{0}*.txt".format( key ) ) )
	zip_attachments = glob.glob( os.path.join( WORKING_DIR, "*{0}*.zip".format( key ) ) )
	email_filename = email
	
	if not os.path.exists( email ):
		print "Cannot open file: " + email 
		continue

	e_file = open( email, 'r' )
	e_lines = e_file.readlines()
	e_file.close()
	os.remove( email )

	email_attach( email_filename, e_lines, zip_attachments, text_attachments)

#	if os.path.exists( email_filename ):	
#		os.Popen( ['cat', email_filename], stdout=
