Red[]

#include %../../../quick-test/quick-test.red

~~~start-file~~~ "stylize-test"

do [


; TODO: Add deep options
object-diff: func [
	o1 [object!]
	o2 [object!]
	/only words
	/omit ignored
	/local get-value
][
	get-value: func [object word][
		either error? try [object/:word][()][object/:word]
	]
	words: any [
		words 
		union words-of o1 words-of o2
	]
	if omit [words: difference words ignored]
	collect [
		foreach word words [
			unless equal? get-value o1 word get-value o2 word [
				keep reduce [word get-value o1 word get-value o2 word]
			]
		]
	]
]

make-style: func [style /with facets][
	with: make face! select system/view/VID/styles/:style 'template
	if facets [with: make with facets]
	with
]

first-face: func [vid][
	first select layout vid 'pane
]

do-test: func [
	vid
	/local ignored-words s t
][
	; TODO: in options I need to ignore just `style`
	ignored-words: [parent options on-change* on-deep-change*]
	all reduce [
		empty? object-diff/omit
			first-face vid
			first-face compose [style t: (vid) t]
			ignored-words
		do [
			s: stylize compose [t: (vid)]
			empty? object-diff/omit
				first-face vid
				first-face [styles s t]
				ignored-words
		]
	]
]

pick-face: func [face index][
	pick face/pane index
]

same-faces?: func [f1 f2][
	empty? object-diff/omit f1 f2 [offset options parent on-chage* on-deep-change*]
]

===start-group=== "group #1"

--test-- "modify style in place"
	--assert same-faces? pick-face layout [base] 1 make-style 'base
	--assert same-faces? pick-face layout [base 100x100] 1 make-style/with 'base [size: 100x100]
	--assert same-faces? pick-face layout [base red] 1 make-style/with 'base [color: red]
	--assert same-faces? pick-face layout [base red 100x100] 1 make-style/with 'base [color: red size: 100x100]

--test-- "modify style with `style`"
	--assert same-faces? pick-face layout [style b: base b] 1 make-style 'base
	--assert same-faces? pick-face layout [style b: base 100x100 b] 1 make-style/with 'base [size: 100x100]
	--assert same-faces? pick-face layout [style b: base red b] 1 make-style/with 'base [color: red]
	--assert same-faces? pick-face layout [style b: base red 100x100 b] 1 make-style/with 'base [color: red size: 100x100]

--test-- "modify style with `stylize`"
	styles: stylize [
		b: base
		b-size: base 100x100
		b-size-color: base 100x100 red
		b-b: b
		b-b-size: b-b 200x200
		b-size-size: b-size 200x200
		b-size-b: b 250x250
		b-size-b-color: b-size-b red
	]
	lay: layout [
		styles styles
		b b-size b-size-color
		b-b b-b-size b-size-size
		b-size-b b-size-b-color
	]
	--assert same-faces? pick-face lay 1 make-style 'base
	--assert same-faces? pick-face lay 2 make-style/with 'base [size: 100x100]
	--assert same-faces? pick-face lay 3 make-style/with 'base [size: 100x100 color: red]
	--assert same-faces? pick-face lay 4 make-style/with 'base []
	--assert same-faces? pick-face lay 5 make-style/with 'base [size: 200x200]
	--assert same-faces? pick-face lay 6 make-style/with 'base [size: 200x200]
	--assert same-faces? pick-face lay 7 make-style/with 'base [size: 250x250]
	--assert same-faces? pick-face lay 8 make-style/with 'base [size: 250x250 color: red]

--test-- "modify style with `stylize/master`"
	styles: stylize/master [
		b: base
		b-size: base 100x100
		b-size-color: base 100x100 red
		b-b: b
		b-b-size: b-b 200x200
		b-size-size: b-size 200x200
		b-size-b: b 250x250
		b-size-b-color: b-size-b red
	]
	lay: layout [
		b b-size b-size-color
		b-b b-b-size b-size-size
		b-size-b b-size-b-color
	]
	--assert same-faces? pick-face lay 1 make-style 'base
	--assert same-faces? pick-face lay 2 make-style/with 'base [size: 100x100]
	--assert same-faces? pick-face lay 3 make-style/with 'base [size: 100x100 color: red]
	--assert same-faces? pick-face lay 4 make-style/with 'base []
	--assert same-faces? pick-face lay 5 make-style/with 'base [size: 200x200]
	--assert same-faces? pick-face lay 6 make-style/with 'base [size: 200x200]
	--assert same-faces? pick-face lay 7 make-style/with 'base [size: 250x250]
	--assert same-faces? pick-face lay 8 make-style/with 'base [size: 250x250 color: red]

--test-- "modify style with `stylize/styles`"
	; TODO: Global styles are now poluted by previous test, add a way to cleanup
	styles1: stylize [
		_b: base
		_b-size: base 100x100
		_b-size-color: base 100x100 red
	]
	styles: stylize/styles [
		_b-b: b
		_b-b-size: b-b 200x200
		_b-size-b: b-size 200x200
	] styles1
	lay: layout [
		styles styles
		_b _b-size _b-size-color
		_b-b _b-b-size _b-size-b
	]
	--assert same-faces? pick-face lay 1 make-style 'base
	--assert same-faces? pick-face lay 2 make-style/with 'base [size: 100x100]
	--assert same-faces? pick-face lay 3 make-style/with 'base [size: 100x100 color: red]
	--assert same-faces? pick-face lay 4 make-style/with 'base []
	--assert same-faces? pick-face lay 5 make-style/with 'base [size: 200x200]
	--assert same-faces? pick-face lay 6 make-style/with 'base [size: 200x200]

===end-group===


] ; --- end of do [

~~~end-file~~~

