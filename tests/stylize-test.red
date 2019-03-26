Red[]

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
	words: any[
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

tests: [
	[
		s: stylize [b: base]
		same-values? [
			first-face [base]
			first-face [styles s base]
		]
	]
	[
		s: stylize [b: base]
		same-values? [
			first-face [base]
			first-face [style b: base b]
		]
	]
]


