;; -*- mode: common-lisp; package: tk -*-
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
;; $fiHeader: ol-init.lisp,v 1.8 92/03/24 19:36:17 cer Exp $

;;
;; This file contains compile time only code -- put in clim-debug.fasl.
;;

(in-package :tk)

(def-c-type (ol-callback-struct :no-defuns) :struct
	    (reason :int))

(def-c-type (ol-expose-callback-struct :no-defuns) :struct
	    (reason :int)
	    (event * x11:xevent))


(def-c-type (ol-resize-callback-struct :no-defuns) :struct
	    (reason :int)
	    (x xt-position)
	    (y xt-position)
	    (width xt-dimension)
	    (height xt-dimension))
