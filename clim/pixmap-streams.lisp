;; -*- mode: common-lisp; package: clim-internals -*-
;;
;;				-[]-
;; 
;; copyright (c) 1985, 1986 Franz Inc, Alameda, CA  All rights reserved.
;; copyright (c) 1986-1991 Franz Inc, Berkeley, CA  All rights reserved.
;;
;; The software, data and information contained herein are proprietary
;; to, and comprise valuable trade secrets of, Franz, Inc.  They are
;; given in confidence by Franz, Inc. pursuant to a written license
;; agreement, and may be stored and used only in accordance with the terms
;; of such license.
;;
;; Restricted Rights Legend
;; ------------------------
;; Use, duplication, and disclosure of the software, data and information
;; contained herein by any agency, department or entity of the U.S.
;; Government are subject to restrictions of Restricted Rights for
;; Commercial Software developed at private expense as specified in FAR
;; 52.227-19 or DOD FAR Supplement 252.227-7013 (c) (1) (ii), as
;; applicable.
;;
;; $fiHeader$

(in-package :clim-internals)

(defclass pixmap-stream (input-protocol-mixin
			 output-protocol-mixin
			 sheet-permanently-enabled-mixin
			 mirrored-sheet-mixin
			 permanent-medium-sheet-output-mixin
			 sheet-transformation-mixin
			 sheet)
	  ())

(defmethod realize-mirror ((port port) (stream pixmap-stream))
  nil)

(defmethod silica::update-mirror-transformation ((port port) (sheet pixmap-stream))
  nil)

(defmethod silica::update-mirror-region ((port port) (sheet pixmap-stream))
  nil)

(defmethod initialize-instance :after ((stream pixmap-stream) &key 
							      port
							      pixmap
							      width height)
  (setf (sheet-direct-mirror stream) pixmap
	(sheet-port stream) port
	(sheet-transformation stream) +identity-transformation+
	(sheet-region stream) (make-bounding-rectangle 0 0 width
						       height)))

;; Interface to this stuff

(defmacro with-output-to-pixmap-stream ((stream sheet . options) &body body)
  (clim-utils::default-output-stream stream with-output-to-pixmap-stream)
  `(flet ((with-output-to-pixmap-body (,stream) ,@body))
     (declare (dynamic-extent #'with-output-to-pixmap-body))
     (invoke-with-output-to-pixmap ,sheet
				   #'with-output-to-pixmap-body
				   ,@options)))

(defmethod invoke-with-output-to-pixmap (sheet continuation &key width height)
  (let* ((pixmap (allocate-pixmap sheet width height))
	 (stream (allocate-pixmap-stream sheet pixmap width height)))
    (funcall continuation stream)
    pixmap))


(defmethod allocate-pixmap (sheet width height)
  (port-allocate-pixmap (sheet-port sheet) sheet width height))

(defmethod allocate-pixmap-stream (sheet pixmap width height)
  (make-instance 'pixmap-stream 
		 :default-text-margin width
		 :pixmap pixmap 
		 :width width
		 :height height
		 :port (sheet-port sheet)))

(defun copy-from-pixmap (pixmap pixmap-x pixmap-y width height
			 stream window-x window-y)
  (port-copy-from-pixmap
   (sheet-port stream)
   pixmap pixmap-x pixmap-y width height stream window-x window-y))

(defun copy-to-pixmap (stream
		       window-x window-y width height
		       &optional pixmap (pixmap-x 0) (pixmap-y 0))
  (unless pixmap
    (setf pixmap (allocate-pixmap stream width height)))
  (port-copy-to-pixmap (sheet-port stream)
		       stream
		       window-x window-y width height
		       pixmap pixmap-x pixmap-y)
  pixmap)
