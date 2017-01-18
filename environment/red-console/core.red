Red [
	Title:	 "Red Console Widget"
	Author:	 "Qingtian Xie"
	File:	 %console.red
	Tabs:	 4
	Rights:  "Copyright (C) 2016 Qingtian Xie. All rights reserved."
]

; #BB: helper func

prober: func [value] [
	probe form reduce value
]

window-face?: func [face] [
	while [not equal? 'window face/type] [
		face: face/parent
	]
	face
]

edit-mode?: func [mode] [
	equal? mode system/console/edit-mode
]
;

terminal!: object [
	lines:		make block! 1000				;-- line buffer
	nlines:		make block! 1000				;-- line count of each line
	heights:	make block! 1000				;-- height of each line
	selects:	make block! 8					;-- selected texts: [start-linenum idx end-linenum idx]

	buffer:		make object! [					;-- #BB: reserve buffer when switching modes
		lines:		make block! 1000
		nlines:		make block! 1000
		heights:	make block! 1000
		line: 		none
	]

	temp-buffer:	make object! [				;-- #BB: temporary switching buffer
		lines:		make block! 1000
		nlines:		make block! 1000
		heights:	make block! 1000
		line: 		none
	]

	max-lines:	1000							;-- maximum size of the line buffer
	full?:		no								;-- is line buffer full?
	ask?:		no								;-- is it in ask loop

	top:		1								;-- index of the first visible line in the line buffer
	line:		none							;-- current editing line
	pos:		0								;-- insert position of the current editing line

	max-pos:	0								;-- BB: maximum insert position for short lines
	scroll-y:	0

	line-y:		0								;-- y offset of editing line
	line-h:		0								;-- average line height
	page-cnt:	0								;-- number of lines in one page
	line-cnt:	0								;-- number of lines in total (include wrapped lines)
	delta-cnt:	0
	screen-cnt: 0

	box:		make text-box! []
	caret:		none
	scroller:	none
	target:		none
	tips:		none

	draw: get 'system/view/platform/draw-face

	print: func [value [any-type!] /local str s cnt][
		if block? value [value: reduce value]
		str: form value
		s: find str lf
		either s [
			cnt: 0
			until [
				add-line copy/part str s
				calc-top
				str: skip s 1
				cnt: cnt + 1
				if cnt = 200 [
					show target
					loop 3 [do-events/no-wait]
					cnt: 0
				]
				not s: find str lf
			]
			either lf = last str [
				add-line ""
			][
				add-line copy str
			]
		][
			add-line str
		]
		calc-top
		show target
		do-events/no-wait
		()				;-- return unset!
	]

	reset-block: func [blk [block!] /advance /local s][
		s: either advance [next blk][blk]
		blk: head blk
		move/part s blk max-lines
		clear s
		blk
	]

	add-line: func [str][
		append lines str
		either full? [
			delta-cnt: first nlines
			line-cnt: line-cnt - delta-cnt
			if top <> 1 [top: top - 1]
			either max-lines = index? lines [
				lines: reset-block/advance lines
				nlines: reset-block nlines
				heights: reset-block heights
			][
				lines: next lines
				nlines: next nlines
				heights: next heights
			]
		][
			full?: max-lines = length? lines
		]
	]

	update-cfg: func [font cfg][
		box/font: font
		max-lines: cfg/buffer-lines
		box/text: "X"
		box/layout
		line-h: box/line-height 1
		caret/size/y: line-h
	]

	resize: func [new-size [pair!] /local y][
		y: new-size/y
		new-size/x: new-size/x - 20
		new-size/y: y + line-h
		box/size: new-size
		if scroller [
			page-cnt: y / line-h
			scroller/page-size: page-cnt
		]
	]

	scroll: func [event /local key n][
		unless ask? [exit]
		key: event/key
		n: switch/default key [ 
			up			[1]
			down		[-1]
			page-up		[scroller/page-size]
			page-down	[0 - scroller/page-size]
			track		[scroller/position - event/picked]
			mouse-wheel [event/picked * 3]
		][0]
		if n <> 0 [
			scroll-lines n
			show target
		]
	]

	update-caret: func [/local p len n s h lh offset][
		prober ["*** update caret"]
		n: top
		h: 0
		p: min pos length? line
		len: either edit-mode? 'console [
			length? skip lines top
		] [
			-1 + index? find/same lines line
		]
		loop len [
			h: h + pick heights n
			n: n + 1
		]
		offset: box/offset? p + index? line
		offset/y: offset/y + h + scroll-y
		if ask? [
			either offset/y < target/size/y [
				caret/offset: offset
				unless caret/visible? [caret/visible?: yes]
			][
				if caret/visible? [caret/visible?: no]
			]
		]
	]

	mouse-down: func [event [event!] /local offset][
		offset: event/offset
		if any [offset/y < line-y offset/y > (line-y + last heights)][exit]
		box/text: head line
		box/layout
		pos: (box/index? offset) - (index? line)
		if pos < 0 [pos: 0]
		update-caret
	]

	move-caret: func [n /local i][
		unless pair? n [n: as-pair n 0]
		if pos > length? line [pos: length? line] ; #BB: make sure, we are not after line end
		pos: pos + n/x
		if negative? pos [pos: 0]
		if pos > length? line [pos: pos - n/x]
		unless zero? n/x [max-pos: pos]
		; y-movement (editor only)
		if all [
			not zero? n/y
			not edit-mode? 'console
		] [
			i: index? find/same lines line
			line: pick lines case [
				all [positive? n/y equal? i length? lines] [
					; move down on last line - put caret to end
					max-pos: pos: length? line
					length? lines
				]
				positive? n/y [min length? lines i + 1] ; move down
				negative? n/y [max 1 i - 1] ; move up
			]
			; fix horizontal caret position
			if max-pos > pos [pos: min length? line max-pos]
		]
	]

	scroll-lines: func [delta /local n len cnt end offset][
		end: scroller/max-size - page-cnt + 1
		offset: scroller/position

		if any [
			all [offset = 1 delta > 0]
			all [offset = end delta < 0]
		][exit]

		offset: offset - delta
		scroller/position: either offset < 1 [1][
			either offset > end [end][offset]
		]

		if zero? delta [exit]

		n: top
		either delta > 0 [						;-- scroll up
			delta: delta + (scroll-y / line-h + pick nlines n)
			scroll-y: 0
			until [
				cnt: pick nlines n
				delta: delta - cnt
				n: n - 1
				any [delta < 1 n < 1]
			]
			if delta <= 0 [
				n: n + 1
				if delta < 0 [
					delta: delta + cnt * line-h
					scroll-y: 0 - delta
				]
			]
			if zero? n [n: 1 scroll-y: 0]
		][										;-- scroll down
			len: length? lines
			delta: scroll-y / line-h + delta
			scroll-y: 0
			until [
				cnt: pick nlines n
				delta: delta + cnt
				n: n + 1
				any [delta >= 0 n > len]
			]
			if delta > 0 [
				n: n - 1
				scroll-y: delta - cnt * line-h
			]
			if n > len [n: len scroll-y: 0]
		]
		top: n
	]

	calc-last-line: func [/local n cnt h num][
		n: length? lines
		box/text: head last lines
		box/layout
		num: line-cnt
		h: box/height
		cnt: box/line-count
		either n > length? nlines [
			append heights h
			append nlines cnt
			line-cnt: line-cnt + cnt
		][
			poke heights n h
			line-cnt: line-cnt + cnt - pick nlines n
			poke nlines n cnt
		]
		n: line-cnt - num - delta-cnt
		delta-cnt: 0
		n
	]

	calc-top: func [/edit /local delta n][
		n: calc-last-line
		if n < 0 [
			delta: scroller/position + n
			scroller/position: either delta < 1 [1][delta]
		]
		if n <> 0 [scroller/max-size: line-cnt - 1 + page-cnt]
		delta: screen-cnt + n - page-cnt

		if delta >= 0 [
			either edit [
				n: line-cnt - page-cnt
				if scroller/position < n [
					top: length? lines
					scroller/position: scroller/max-size - page-cnt + 1
					scroll-lines page-cnt - 1
				]
			][
				scroll-lines -1 - delta
			]
		]
	]

	update-scroller: func [delta /reposition /local n end][
		end: scroller/max-size - page-cnt + 1
		if delta <> 0 [scroller/max-size: line-cnt - 1 + page-cnt]
		if delta < 0 [
			n: scroller/position
			if n <> end [scroller/position: n - delta]
		]
	]

	process-shortcuts: function [event [event!]][
		if find event/flags 'control [
			switch event/key [
				#"C"		[probe "copy"]
			]
		]
	]

	press-key: func [event [event!] /local char l win][
		if process-shortcuts event [exit]
		char: probe event/key
		switch/default char [
			#"^[" [									;-- ESCAPE key
				; TODO: this probably ignores normal ESC function in console
				;		in console, switching should occur only when on start new-line
				;		and when idle
				probe "*** buffer is"
				probe buffer
				; switch to/from editing mode
				switch-buffer
				win: window-face? self/target
				switch system/console/edit-mode [
					console [
						; switch to editor (INSERT mode)
						win/menu: red-console-ctx/editor-menu
						exit-event-loop
						system/console/edit-mode: 'insert
					]
					insert [
						; switch in editor to COMMAND mode
					;	win/menu: red-console-ctx/editor-menu
						system/console/edit-mode: 'command
					]
				]
				paint
			]
			#"^M" [									;-- ENTER key
				caret/visible?: no
				either edit-mode? 'console [
					exit-event-loop
				] [
					l: find/same lines line ; !!!!!!
					add-line copy ""
					if pos < length? line [
					;	unless first next l []
						move/part skip line pos first next l (length? line) - pos
					]
					line: first next l
					max-pos: pos: 0
				]
			]
			#"^H" [									;-- BACKSPACE key
				either zero? pos [
					if all [
						edit-mode? 'insert
						1 < length? lines 
					] [
						l: find/same lines line
						line: first back l
						pos: length? line
						remove l
					]
				] [
					pos: pos - 1 remove skip line pos
				]
				max-pos: pos
			]
			delete [
				if edit-mode? 'insert [
					either equal? pos length? line [
						; line end
						l: find/same lines line
						move/part first next l tail first l length? first next l
						remove next l
					] [
						; normal operation
						remove skip line pos
					]
				]
			]
			left  [move-caret -1]
			right [move-caret 1]
			up	  [probe "up" move-caret 0x-1]
			down  [probe "down" move-caret 0x1]
		][
			insert skip line pos char
			max-pos: pos: pos + 1
		]
		target/rate: 6
		if caret/rate [caret/rate: none caret/color: 0.0.0.1]
		calc-top/edit
		show target
	]

	paint: func [/local str cmds y n h cnt delta num end styles][
		unless line [exit]
		cmds: [text 0x0 text-box]
		cmds/3: box
		styles: box/styles
		end: target/size/y
		y: scroll-y
		n: top
		num: line-cnt
		foreach str at lines top [
			box/text: head str
			highlight/add-styles head str clear styles
			box/layout
			clear styles
			cmds/2/y: y
			draw target cmds

			h: box/height
			cnt: box/line-count
			poke heights n h
			line-cnt: line-cnt + cnt - pick nlines n
			poke nlines n cnt

			n: n + 1
			y: y + h
			if y > end [break]
		]
		line-y: y - h
		screen-cnt: y / line-h

		update-caret
		;update-scroller line-cnt - num
	]

; #BB additions

	switch-buffer: does [
		temp-buffer/lines: lines
		temp-buffer/nlines: nlines
		temp-buffer/heights: heights
		temp-buffer/line: line

		lines: buffer/lines
		nlines: buffer/nlines
		heights: buffer/heights
		line: first buffer/lines ; FIXME: hack, can’t find where line is set

		buffer: make temp-buffer []
	]

; /BB additions

]

console!: make face! [
	type: 'base color: white offset: 0x0 size: 400x400 cursor: 'I-beam
	flags: [Direct2D scrollable]
	menu: [
		"Copy^-Ctrl+C"		 copy
		"Paste^-Ctrl+V"		 paste
		"Select All^-Ctrl+A" select-all
	]
	actors: object [
		on-time: func [face [object!] event [event!]][
			extra/caret/rate: 2
			face/rate: none
		]
		on-draw: func [face [object!] event [event!]][
			probe "on-draw"
			extra/paint
		]
		on-scroll: func [face [object!] event [event!]][
			extra/scroll event
		]
		on-wheel: func [face [object!] event [event!]][
			extra/scroll event
		]
		on-key: func [face [object!] event [event!]][
			extra/press-key event
		]
		on-down: func [face [object!] event [event!]][
			extra/mouse-down event
		]
		on-menu: func [face [object!] event [event!]][
			switch event/picked [
				copy		[probe 'TBD]
				paste		['TBD]
				select-all	['TBD]
			]
		]
	]

	resize: func [new-size][
		self/size: new-size
		extra/resize new-size
	]

	init: func [/local terminal box scroller][
		terminal: extra
		terminal/target: self
		box: terminal/box
		box/fixed?: yes
		box/target: self
		box/styles: make block! 200
		scroller: get-scroller self 'horizontal
		scroller/visible?: no
		scroller: get-scroller self 'vertical
		scroller/position: 1
		scroller/max-size: 2
		terminal/scroller: scroller
		print: get 'terminal/print
	]

	apply-cfg: func [cfg][
		self/font:	make font! [
			name:  cfg/font-name
			size:  cfg/font-size
			color: cfg/font-color
		]
		self/color:	cfg/background
		extra/update-cfg self/font cfg
	]

	extra: make terminal! []
]
