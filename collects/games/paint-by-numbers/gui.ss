
  (unit/sig GUI^

    (import mzlib:function^
	    mred^)

    (define UNKNOWN-BRUSH (send the-brush-list find-or-create-brush "GRAY" 'solid))
    (define ON-BRUSH (send the-brush-list find-or-create-brush "BLUE" 'solid))
    (define OFF-BRUSH (send the-brush-list find-or-create-brush "WHITE" 'solid))
    (define LINES/NUMBERS-PEN (send the-pen-list find-or-create-pen "BLACK" 1 'solid))

    (define WHITE-PEN (send the-pen-list find-or-create-pen "WHITE" 1 'solid))
    (define WHITE-BRUSH (send the-brush-list find-or-create-brush "WHITE" 'solid))

    (define paint-by-numbers-canvas%
      (class canvas% (parent row-numbers col-numbers)
	(inherit get-dc get-client-size)
	(private
	  [canvas-width 200]
	  [canvas-height 200]
	  
	  [extra-space-every 5]

	  [grid-x-size (length col-numbers)]
	  [grid-y-size (length row-numbers)]
	  [margin 1]
	  [row-label-width 10]
	  [row-label-height 10]
	  [col-label-width 10]
	  [col-label-height 10]

	  [get-row-label-string
	   (lambda (l)
	     (let ([s (format "~a" l)])
	       (substring s 1 (- (string-length s) 1))))]
	  [get-col-label-strings
	   (lambda (l)
	     (map number->string l))]

	  [grid (build-vector grid-x-size (lambda (i) (make-vector grid-y-size UNKNOWN-BRUSH)))]
	  

	  [get-string-height
	   (lambda (s)
	     (let ([dc (get-dc)])
	       (let-values ([(width height descent ascent) 
			     (send dc get-text-extent s)])
		 height)))]
	  [get-string-ascent
	   (lambda (s)
	     (let ([dc (get-dc)])
	       (let-values ([(width height descent ascent) 
			     (send dc get-text-extent s)])
		 ascent)))]
	  [get-string-width
	   (lambda (s)
	     (let ([dc (get-dc)])
	       (let-values ([(width height descent ascent) 
			     (send dc get-text-extent s)])
		 width)))]

	  [loc->string
	   (lambda (x y)
	     (format "(~a,~a)" x y))]

	  [xy->grid
	   (lambda (x y)
	     (let* ([grid-width (/ (- canvas-width row-label-width) grid-x-size)]
		    [grid-height (/ (- canvas-height col-label-height) grid-y-size)]
		    [xp (- x row-label-width)]
		    [yp (- y col-label-height)]
		    [x (inexact->exact (floor (/ xp grid-width)))]
		    [y (inexact->exact (floor (/ yp grid-height)))])
	       (if (and (<= 0 x grid-x-size)
			(<= 0 y grid-y-size))
		   (cons x y)
		   #f)))]
	  
	  [grid->rect
	   (lambda (x y)
	     (let* ([grid-width (- canvas-width
				   row-label-width
				   (quotient grid-x-size extra-space-every))]
		    [grid-height (- canvas-height
				    col-label-height
				    (quotient grid-y-size extra-space-every))]
		    [left (+ row-label-width
			     (quotient x extra-space-every)
			     (* x (/ grid-width grid-x-size)))]
		    [top (+ col-label-height
			    (quotient y extra-space-every)
			    (* y (/ grid-height grid-y-size)))]
		    [width (/ grid-width grid-x-size)]
		    [height (/ grid-height grid-y-size)])
	       (values left top width height)))])
	
	
	(public
	  ;; int int -> void
	  [paint-rect
	   (lambda (i j)
	     (let ([dc (get-dc)])
	       (let-values ([(left top width height) (grid->rect i j)])
		 (send dc set-pen LINES/NUMBERS-PEN)
		 (send dc set-brush (vector-ref (vector-ref grid i) j))
		 (send dc draw-rectangle left top width height))))]

	  ;; int int -> (union 'on 'off 'unknown)
	  [get-rect
	   (lambda (i j)
	     (let ([res (vector-ref (vector-ref grid i) j)])
	       (cond
		[(eq? res UNKNOWN-BRUSH) 'unknown]
		[(eq? res OFF-BRUSH) 'off]
		[(eq? res ON-BRUSH) 'on])))]

	  ;; int int (union 'on 'off 'unknown) -> void
	  [set-rect
	   (lambda (i j sym)
	     (vector-set! (vector-ref grid i)
			  j
			  (case sym
			    [(unknown) UNKNOWN-BRUSH]
			    [(off) OFF-BRUSH]
			    [(on) ON-BRUSH])))])
	

	(override
	 [on-size
	  (lambda (w h)
	    (set! canvas-width w)
	    (set! canvas-height h)
	    (on-paint))]
	 [on-event
	  (lambda (evt)
	    (let* ([x (send evt get-x)]
		   [y (send evt get-y)]
		   [p (xy->grid x y)])
	      (cond
	       [(or (send evt moving?)
		    (send evt entering?)
		    (send evt leaving?))
		(let ([dc (get-dc)])
		  (send dc set-pen WHITE-PEN)
		  (send dc set-brush WHITE-BRUSH)
		  (send dc draw-rectangle 0 0 row-label-width col-label-height)
		  (when (and (not (send evt leaving?))
			     p)
		    (let* ([i (car p)]
			   [j (cdr p)]
			   [string (loc->string (+ i 1) (+ j 1))]
			   [width (get-string-width string)]
			   [height (get-string-height string)]
			   [sx (- (/ row-label-width 2)
				  (/ width 2))]
			   [sy (- (/ col-label-height 2)
				  (/ height 2))])
		      (send dc draw-text string sx sy))))]
	       [(send evt button-down?)
		(when p
		  (let* ([i (car p)]
			 [j (cdr p)]
			 [prev (vector-ref (vector-ref grid i) j)])
		    (vector-set! (vector-ref grid i) j
				 (cond
				  [(eq? prev UNKNOWN-BRUSH) ON-BRUSH]
				  [(eq? prev ON-BRUSH) OFF-BRUSH]
				  [(eq? prev OFF-BRUSH) UNKNOWN-BRUSH]
				  [else (error 'internal-error "unkown brush in board ~s~n" (vector-ref (vector-ref grid i) j))]))
		    (paint-rect i j)))])))]

	 [on-paint
	  (lambda ()
	    (let ([dc (get-dc)])
	      (let-values ([(width height) (get-client-size)])

		(send dc set-pen LINES/NUMBERS-PEN)
		(let loop ([i grid-x-size])
		  (cond
		   [(zero? i) (void)]
		   [else (let loop ([j grid-y-size])
			   (cond
			    [(zero? j) (void)]
			    [else (paint-rect (- i 1) (- j 1))
				  (loop (- j 1))]))
			 (loop (- i 1))]))

		
		(let ([square-width (/ (- canvas-width row-label-width) grid-x-size)]
		      [longest-strs (apply max (map length col-numbers))])
		  (let loop ([l col-numbers]
			     [n 0])
		    (cond
		     [(null? l) (void)]
		     [else 
		      (let ([strs (get-col-label-strings (car l))])

			(let loop ([ss strs]
				   [line (- longest-strs (length strs))])
			  (cond
			   [(null? ss) (void)]
			   [else
			    (let* ([s (car ss)]
				   [str-width (get-string-width s)]
				   [str-height (get-string-height s)]
				   [x (+ row-label-width
					 (* n square-width)
					 (- (/ square-width 2)
					    (/ str-width 2)))]
				   [y (* line (+ str-height margin))])
			      (send dc draw-text (car ss) x y)
			      (loop (cdr ss)
				    (+ line 1)))])))
		      (loop (cdr l) (+ n 1))])))

		(let ([square-height (/ (- canvas-height col-label-height) grid-y-size)])
		  (let loop ([l row-numbers]
			     [n 0])
		    (cond
		     [(null? l) (void)]
		     [else
		      (let* ([str (get-row-label-string (car l))]
			     [str-height (get-string-height str)]
			     [str-ascent (get-string-ascent str)]
			     [str-width (get-string-width str)]
			     [y (+ col-label-height
				   (* n square-height)
				   (- (/ square-height 2)
				      (/ str-height 2)))]
			     [x (- row-label-width str-width margin)])
			(send dc draw-text str x y))
		      (loop (cdr l)
			    (+ n 1))])))
		
		(void))))])
	
	(inherit min-width min-height)
	(sequence
	  (super-init parent)
	  
	  (let* ([dc (get-dc)])
	    (set! row-label-width
		  (max (get-string-width (loc->string grid-x-size grid-y-size))
		       (apply max (map (lambda (x) (+ margin
						      (get-string-width (get-row-label-string x))
						      margin))
				       row-numbers))))

	    (let-values ([(width height descent ascent) (send dc get-text-extent "0123456789")])
	      (set! row-label-height (+ margin margin height)))

	    (set! col-label-height
		  (apply max
			 (map (lambda (l)
				(let* ([strs (get-col-label-strings l)]
				       [margin (* (- (length strs) 1) margin)]
				       [height (apply + (map get-string-height strs))])
				  (+ margin height)))
			      col-numbers)))
	    (set! col-label-width
		  (apply max
			 (map (lambda (l)
				(apply max (map (lambda (x) (+ margin (get-string-width x) margin))
						(get-col-label-strings l))))
			      col-numbers))))
	  
	  (min-width (inexact->exact (+ row-label-width (* grid-x-size col-label-width))))
	  (min-height (inexact->exact (+ col-label-height (* grid-y-size row-label-height))))))))