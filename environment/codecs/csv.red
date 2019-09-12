Red [
	Title: "CSV codec"
	Author: "Boleslav Březovský"
	Rights:  "Copyright (C) 2015-2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
	Resources: [
		https://tools.ietf.org/html/rfc4180
		https://www.python.org/dev/peps/pep-0305/
	]
	Documentation: https://github.com/red/red/wiki/CSV-codec 
]

do [
put system/codecs 'csv context [
	Title:     "CSV codec"
	Name:      'CSV
	Mime-Type: [text/csv]
	Suffixes:  [%.csv]
	encode: func [data [any-type!] where [file! url! none!]] [
		to-csv data
	]
	decode: func [text [string! binary! file!]] [
		if file? text [text: read text]
		if binary? text [text: to string! text]
		load-csv text
	]
]

context [
	; -- state variables
	ignore-empty?: false ; If line ends with delimiter, do not add empty string
	strict?: true		; Throw error on non-aligned records
	quote-char: #"^""
	double-quote: {""}
	quotable-chars: charset { ",^/}

	; -- internal values
	parsed?: none		; Keep state of parse result (for debugging purposes)
	non-aligned: "Data are not aligned"

	; -- support functions
	to-csv-line: function [
		"Join values as a string and put delimiter between them"
		data		[block!]		"Series to join"
		delimiter	[char! string!]	"Delimiter to put between values"
	][
		collect/into [
			while [not tail? next data][
				keep escape-value first data delimiter
				keep delimiter
				data: next data
			]
			keep escape-value first data delimiter
			keep newline
		] clear ""
	]


	escape-value: function [
		"Escape quotes and when required, enclose value in quotes"
		value		[any-type!]		"Value to escape (is formed)"
		delimiter	[char! string!]	"Delimiter character to be escaped"
		/extern quote-char double-quote quotable-chars
	][
		quot?: false
		unless string? value [value: form value]
		len: length? value
		replace/all value quote-char double-quote
		unless equal? len length? value [quot?: true]
		if find value quotable-chars [quot?: true]
		if quot? [
			insert value quote-char
			append value quote-char
		]
		value
	]

	encode-blocks: function [
		"Convert block of records to CSV string"
		data		[block!] "Block of blocks, each block is one record"
		delimiter	[char! string!] "Delimiter to use in CSV string"
	][
		length: length? first data
		collect/into [
			foreach line data [
				if length <> length? line [return make error! non-aligned]
				csv-line: to-csv-line line delimiter
				keep csv-line
			]
		] make string! 1000
	]

	; -- main functions
	set 'load-csv function [
		"Converts CSV text to a block of rows, where each row is a block of fields."
		data [string!] "Text CSV data to load"
		/with
			delimiter [char! string!] "Delimiter to use (default is comma)"
		/trim		"Ignore spaces between quotes and delimiter"
		/quote
			qt-char [char!] "Use different character for quotes than double quote (^")"
		/extern
			quote-char
	] [
		; -- init local values
		delimiter: any [delimiter comma]
		quote-char: any [qt-char #"^""]
		output: make block! (length? data) / 80
		out-map: make map! []
		line: make block! 20
		value: make string! 200

		; -- parse rules
		newline: [crlf | lf | cr]
		quotchars: charset reduce ['not quote-char]
		valchars: charset reduce ['not append copy "^/^M" delimiter]
		quoted-value: [
			(clear value) [
				quote-char
				any [
					[
						set char quotchars
					|	quote-char quote-char (char: quote-char)
					]
					(append value char)
				]
				quote-char
			]
		]
		normal-value: [s: any valchars e: (value: copy/part s e)]
		single-value: [quoted-value | normal-value]
		values: [any [single-value delimiter add-value] single-value add-value]
		add-value: [(
			if trim [
				value: system/words/trim value
				all [
					quote-char = first value
					quote-char = last value
					take value
					take/last value
				]
			]
			append line copy value
		)]
		add-line: [
			(
				; remove last empty element, when required
				all [
					ignore-empty?
					empty? last line
					take/last line
				]
				append/only output copy line
			)
			init
		]
		line-rule: [values [newline | end] add-line]
		init: [(clear line)]

		; -- main code
		parsed?: parse data [
			[
				init some line-rule
			|	init values add-line
			]
			any newline
		]
		output
	]

	set 'to-csv function [
		"Make CSV data from input value"
		data [block! map! object!] "May be block of fixed size records, block of block records, or map columns"
		/with "Delimiter to use (default is comma)"
			delimiter [char! string!]
		/quote
			qt-char [char!] "Use different character for quotes than double quote (^")"
		/extern
			quote-char double-quote quotable-chars
	][
		; Initialization
		delimiter: any [delimiter comma]
		quote-char: any [qt-char #"^""]
		double-quote: rejoin [quote-char quote-char]
		quotable-chars: charset rejoin [space newline quote-char delimiter]
		unless block? first data [data: reduce [data]] ; Only one line
		encode-blocks data delimiter
	]
]
]
