;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Package: CLIM-INTERNALS; Base: 10; Lowercase: Yes -*-

;; $fiHeader: default-application.lisp,v 1.4 91/03/26 12:47:50 cer Exp $

(in-package :clim-internals)

"Copyright (c) 1990, 1991, 1992 Symbolics, Inc.  All rights reserved.
 Portions copyright (c) 1989, 1990 International Lisp Associates."

(define-application-frame default-application () ()
  (:command-definer nil))

;;; These are DEFVARs in clim-defs.lisp
(setq *default-application* (make-application-frame 'default-application))

;;--- Is it really necessary for this to have a global value?
(setq *application-frame* *default-application*)

(defmethod frame-input-context-button-press-handler
	   ((frame standard-application-frame) stream button-press-event)
  (declare (ignore stream))
  (let* ((window (event-window button-press-event))
	 (x (pointer-event-x button-press-event))
	 (y (pointer-event-y button-press-event))
	 (highlighted-presentation (highlighted-presentation window nil))
	 (input-context *input-context*))
    (when highlighted-presentation
      ;; Unhighlight on the way out.
      ;; But only unhighlight the window that the click is from. 
      (unhighlight-highlighted-presentation window nil))
    (throw-highlighted-presentation 
      (or (and (output-recording-stream-p window)
	       (frame-find-innermost-applicable-presentation
		 frame input-context window x y))
	  *null-presentation*)
      input-context
      button-press-event)))

;;; The contract of this is to find an "appropriate" presentation; i.e., one
;;; satisfying the input context specified by TYPE.  Everything that looks for a
;;; presentation goes through this so that applications can specialize it.
(defmethod frame-find-innermost-applicable-presentation
	   ((frame standard-application-frame) input-context stream x y)
  (find-innermost-applicable-presentation input-context stream x y))

;;; The contract of this is to replay the contents of STREAM within the region.
(defmethod frame-replay ((frame standard-application-frame) stream &optional region)
  (stream-replay stream region)
  (force-output stream))


(defvar *pointer-documentation-interval*
	(max (floor (* 1/10 internal-time-units-per-second)) 1))
(defvar *last-pointer-documentation-time* 0)

#+Genera
(defvar *pointer-documentation-buffer*
	(make-array 80 :element-type 'string-char :fill-pointer 0 :adjustable t))

;;; Produce pointer documentation
(defmethod frame-document-highlighted-presentation
	   ((frame standard-application-frame) presentation input-context window x y stream)
  (let (#+Genera (documentation-window (mouse-documentation-window window)))
    ;; The documentation should never say anything if we're not over a presentation
    (when (null presentation) 
      #+Genera (if documentation-window
		   (scl:send documentation-window :clear-window)
		   (window-clear stream))
      #-Genera (window-clear stream))
    ;; Cheap test to not do this work too often
    (let ((old-modifier-state *last-pointer-documentation-modifier-state*)
	  (modifier-state (window-modifier-state window))
	  (last-time *last-pointer-documentation-time*)
	  (time (get-internal-real-time)))
      (setq *last-pointer-documentation-modifier-state* modifier-state)
      (when (and (< time (+ last-time *pointer-documentation-interval*))
		 (= modifier-state old-modifier-state))
	(return-from frame-document-highlighted-presentation nil))
      (setq *last-pointer-documentation-time* time))
    (when presentation
      #+Genera
      (when documentation-window
	(setf (fill-pointer *pointer-documentation-buffer*) 0)
	(with-output-to-string (stream *pointer-documentation-buffer*)
	  (scl:send documentation-window :clear-window)
	  (when (null (frame-document-highlighted-presentation-1
			frame presentation input-context window x y stream))
	    (setq *last-pointer-documentation-time* 0))
	  (scl:send documentation-window :string-out *pointer-documentation-buffer*))
	(return-from frame-document-highlighted-presentation nil))
      (with-output-recording-options (stream :record nil)
	(with-end-of-line-action (stream :allow)
	  (with-end-of-page-action (stream :allow)
	    (window-clear stream)
	    (when (null (frame-document-highlighted-presentation-1
			  frame presentation input-context window x y stream))
	      (setq *last-pointer-documentation-time* 0))
	    (force-output stream)))))))

(defun frame-document-highlighted-presentation-1
       (frame presentation input-context window x y stream)
  (let ((modifier-state (window-modifier-state window)))
    (declare (fixnum modifier-state))
    (multiple-value-bind (left left-context middle middle-context right right-context)
	(find-applicable-translators-for-documentation presentation input-context
						       frame window x y modifier-state)
      (let* ((*print-length* 3)
	     (*print-level* 2)
	     (*print-circle* nil)
	     (*print-array* nil)
	     (*print-readably* nil)
	     (*print-pretty* nil))
	(flet ((document-translator (translator context-type button-name separator)
		 ;; Assumes 5 modifier keys and the reverse ordering of *MODIFIER-KEYS*
		 (let ((bit #o20)
		       (shift-name '("h-" "s-" "m-" "c-" "sh-")))
		   (declare (fixnum bit))
		   (dotimes (i 5)
		     #-(or Allegro Minima) (declare (ignore i))
		     (unless (zerop (logand bit modifier-state))
		       (write-string (car shift-name) stream))
		     (pop shift-name)
		     (setq bit (the fixnum (ash bit -1)))))
		 (write-string button-name stream)
		 (document-presentation-translator translator presentation context-type
						   frame nil window x y
						   :stream stream
						   :documentation-type :pointer)
		 (write-string separator stream)))
	  (declare (dynamic-extent #'document-translator))
	  (when left
	    (let ((button-name (cond ((and (eql left middle)
					   (eql left right))
				      (setq middle nil
					    right nil)
				      "L,M,R: ")
				     ((eql left middle) 
				      (setq middle nil)
				      "L,M: ")
				     (t "L: "))))
	      (document-translator left left-context button-name
				   (if (or middle right) "; " "."))))
	  (when middle
	    (let ((button-name (cond ((eql middle right)
				      (setq right nil)
				      "M,R: ")
				     (t "M: "))))
	      (document-translator middle middle-context button-name
				   (if right "; " "."))))
	  (when right
	    (document-translator right right-context "R: " "."))
	  ;; Return non-NIL if any pointer documentation was produced
	  (or left middle right))))))

;; This is derived directly from FIND-APPLICABLE-TRANSLATORS
(defun find-applicable-translators-for-documentation
       (presentation input-context frame window x y modifier-state)
  ;; Assume a maximum of three pointer buttons
  (let ((left nil)   (left-context nil)
	(middle nil) (middle-context nil)
	(right nil)  (right-context nil))
    (macrolet ((match (translator context-type button)
		 (let ((button-translator (intern (symbol-name button)))
		       (button-context (fintern "~A-~A" (symbol-name button) 'context)))
		   `(when (and (or (null ,button-translator)
				   (> (presentation-translator-priority ,translator)
				      (presentation-translator-priority ,button-translator)))
			       (button-and-modifier-state-matches-gesture-name
				 (button-index ,button) modifier-state
				 (presentation-translator-gesture-name ,translator)))
		      (setq ,button-translator ,translator
			    ,button-context ,context-type)))))
      (do ((presentation presentation
			 (parent-presentation-with-shared-box presentation window)))
	  ((null presentation))
	(let ((from-type (presentation-type presentation)))
	  (dolist (context input-context)
	    (let ((context-type (pop context)))	;input-context-type = first
	      (let ((translators (find-presentation-translators 
				   from-type context-type (frame-command-table frame))))
		(when translators
		  (dolist (translator translators)
		    (when (test-presentation-translator translator
							presentation context-type
							frame window x y
							:modifier-state modifier-state)
		      (match translator context-type :left)
		      (match translator context-type :middle)
		      (match translator context-type :right)))))
	      (when (and (or left middle right)
			 *presentation-menu-translator*
			 (test-presentation-translator *presentation-menu-translator*
						       presentation context-type
						       frame window x y
						       :modifier-state modifier-state))
		(match *presentation-menu-translator* context-type :left)
		(match *presentation-menu-translator* context-type :middle)
		(match *presentation-menu-translator* context-type :right)))))))
    (values left   left-context
	    middle middle-context
	    right  right-context)))

#+Genera
(defmethod mouse-documentation-window ((window window-stream)) nil)
