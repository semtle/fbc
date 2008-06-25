''  fbchkdoc - FreeBASIC Wiki Management Tools
''	Copyright (C) 2008 Jeffery R. Marshall (coder[at]execulink[dot]com)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.

'' getindex.bas - gets "PageIndex" from wiki and saves as "PageIndex.txt"

'' chng: written [jeffm]

'' fbdoc headers
#include once "CWikiCon.bi"
#include once "COptions.bi"

'' fbchkdoc headers
#include once "fbchkdoc.bi"

'' libs
#inclib "pcre"
#inclib "curl"

using fb
using fbdoc

'' temporary files
const def_html_file = "PageIndex.html"
const def_text_file = "PageIndex0.txt"


'' --------------------------------------------------------
'' MAIN
'' --------------------------------------------------------

dim as string wiki_url, web_wiki_url, dev_wiki_url
dim as string sPage, sBody
dim as integer i = 1

sPage = "PageIndex"

if( command(i) = "" ) then
	print "getindex {server}"
	print
	print "server:"
	print "   -web       get index from the web server (in " + default_optFile + ")"
	print "   -dev       get index from the development server (in " + default_optFile + ")"
	print "   -url URL   get index from URL"
	print
	end 0
end if

'' read defaults from the configuration file (if it exists)
scope
	dim as COptions ptr opts = new COptions( default_optFile )
	if( opts <> NULL ) then
		web_wiki_url = opts->Get( "web_wiki_url" )
		dev_wiki_url = opts->Get( "dev_wiki_url" )
		delete opts
	else
		'' print "Warning: unable to load options file '" + default_optFile + "'"
		'' end 1
	end if
end scope

while( command(i) > "" )
	if( left( command(i), 1 ) = "-" ) then
		select case lcase(command(i))
		case "-web", "-web+"
			wiki_url = web_wiki_url
		case "-dev", "-dev+"
			wiki_url = dev_wiki_url
		case "-url"
			i += 1
			wiki_url = command(i)
		case else
			print "Unrecognized option '" + command(i) + "'"
			end 1
		end select
	else
		print "Unexpected option '" + command(i) + "'"
		end 1
	end if
	i += 1
wend

if( len( wiki_url ) = 0 ) then
	print "wiki_url not set."
	end 1
end if

'' connect to the wiki and get PageIndex as HTML
scope
	dim as CWikiCon ptr wikicon = NULL

	wikicon = new CWikiCon( wiki_url )
	if wikicon = NULL then
		print "Unable to create connection " + wiki_url
		end 1
	end if

	print "URL: "; wiki_url

	print "Loading '" + sPage + "': ";
	if( wikicon->LoadPage( sPage, FALSE, FALSE, sBody ) = FALSE ) then
		print "Error"
	else
		print "OK"
/'
		'' DEBUG
		dim as integer h = freefile
		open def_html_file for output as #h
		print #h, sBody
		close #h
'/
	end if

	delete wikicon
end scope

'' remove HTML tags	
scope
	dim as string txt, html
	dim as integer n, b = 0, j = 1, atag = 0
	n = len(sBody)
	txt = ""

	print "Removing html tags"
	while( i <= n )

		if( lcase(mid( sBody, i, 4 )) = "&lt;" ) then
			txt += "<"
			i += 4
		elseif( lcase(mid( sBody, i, 4 )) = "&gt;" ) then
			txt += ">"
			i += 4
		elseif( lcase(mid( sBody, i, 5 )) = "&amp;" ) then
			txt += "&"
			i += 5
		elseif( lcase(mid( sBody, i, 6 )) = "&nbsp;" ) then
			txt += " "
			i += 6
		elseif( mid( sBody, i, 4 ) = "All<" and atag = 1 ) then
			txt += "All" + crlf + "----" + crlf
			i += 3
		elseif( mid( sBody, i, 5 ) = "All <" and atag = 1 ) then
			txt += "All " + crlf + "----" + crlf
			i += 3
		elseif( lcase(mid( sBody, i, 1 )) = "<" ) then
			atag = 0
			b = 1
			j = i + 1
			while( j <= n and b > 0 )
				select case ( mid( sBody, j, 1 ))
				case "<"
					b += 1
					j += 1
				case ">"
					b -= 1
					j += 1
				case chr(34)
					j += 1
					while( j <= n )
						select case ( mid( sBody, j, 1 ))
						case chr(34)
							j += 1
							exit while
						case else
							j += 1
						end select
					wend
				case else
					j += 1
				end select
			wend 

			html = mid( sBody, i, j - i )
			select case lcase( html )
			case "<br>","<br />"
				txt += crlf
			case "<hr>","<hr />"
				txt += "----"
			case else
				if left( html, 3 ) = "<a " then
					atag = 2
				end if
			end select
			i = j

		else
			txt += mid( sBody, i, 1 )
			i += 1
		end if

		if( atag = 2 ) then
			atag = 1
		else
			atag = 0
		end if

	wend

	dim as integer h = freefile
	open def_text_file for output as #h
	print #h, txt
	close #h

end scope

'' Extract page names and write final output
scope
	dim as integer b = 0, i, h1, h2
	dim as string x

	print "Writing '" + def_index_file + "'"

	h1 = freefile
	open def_text_file for input as #h1
	h2 = freefile
	open def_index_file for output as #h2
	while( eof(h1) = 0 )
		line input #h1, x
		if( b ) then
			if x = "----" then
				b = 0
				exit while
			elseif( len(x) > 2 ) then
				for i = 1 to len(x)
					select case mid(x,i,1)
					case "A" to "Z", "a" to "z", "0" to "9", "_"
					case else
					  exit for
					end select
				next
				if i > 1 then
					print #h2, left(x, i - 1)
				end if
			end if
		else
			if x = "----" then
				b = 1
			end if
		end if
	wend
	close #h2
	close #h1

	kill def_text_file

end scope

print "Done."
