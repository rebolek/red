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
	if facets [make with facets]
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

--test-- "basic stylize test #1"
	--assert same-faces? pick-face layout [base] 1 make-style 'base

===end-group===


] ; --- end of do [

~~~end-file~~~

