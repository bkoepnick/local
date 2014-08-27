#!/bin/sh

export MAILTO=$1
export SUBJECT=$2
export BODY=$3
export ATTACH=$4
(
 echo "To: $MAILTO"
 echo "From: koepnick@uw.edu"
 echo "Subject: $SUBJECT"
 echo "MIME-Version: 1.0"
 echo 'Content-Type: multipart/mixed; boundary="-q1w2e3r4t5"'
 echo
 echo '---q1w2e3r4t5'
 echo "Content-Type: text/html"
 echo "Content-Disposition: inline"
 cat $BODY
 echo '---q1w2e3r4t5'
 echo 'Content-Type: application; name="'$(basename $ATTACH)'"'
 echo "Content-Transfer-Encoding: base64"
 echo 'Content-Disposition: attachment; filename="'$(basename $ATTACH)'"'
 uuencode -m $ATTACH $(basename $ATTACH)
 echo '---q1w2e3r4t5--'
) | sendmail $MAILTO
