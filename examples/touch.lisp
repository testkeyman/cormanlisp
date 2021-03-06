;;;;	-------------------------------
;;;;	Copyright (c) Corman Technologies Inc.
;;;;	See LICENSE.txt for license information.
;;;;	-------------------------------
;;;;
;;;;	File:		touch.lisp
;;;;	Contents:	Touch utility.
;;;;	History:	7/24/01  RGC  Created.
;;;;
;;;;	To create the console application, load this file and use
;;;;    this command:
;;;;        (save-application "touch" #'main :console t :static t)
;;;;

(defvar *specified-time* nil)
(defvar *descend-subdirectories* nil)
(defvar *display-usage-info* nil)

(defun touch (path &optional time)
	(unless time
		(setf time (get-universal-time)))
	(let ((attrs (ccl::get-file-attributes path))
		  (read-only nil))
		(when (> (logand attrs win:FILE_ATTRIBUTE_READONLY) 0)
			(setf read-only attrs)
			(ccl::set-file-attributes path (logxor attrs win:FILE_ATTRIBUTE_READONLY)))
		(unwind-protect
			(with-open-file (f path :direction :io)
				(multiple-value-bind (creation access modify)
					(cl::get-file-times f)
					(declare (ignore access modify))
					(cl::set-file-times f
						creation
						(cl::universal-time-to-file-time time)
						(cl::universal-time-to-file-time time))))
			(when read-only
				(ccl::set-file-attributes path attrs)))))		

(defun timespec-to-universal-time (timespec)
	(let (year month day hour minute second
		  (len (length timespec)))
		(if (>= len 4)
			(setf year (parse-integer (subseq timespec 0 4))))
		(if (>= len 6)
			(setf month (parse-integer (subseq timespec 4 6))))
		(if (>= len 8)
			(setf day (parse-integer (subseq timespec 6 8))))
		(if (>= len 10)
			(setf hour (parse-integer (subseq timespec 8 10))))
		(if (>= len 12)
			(setf minute (parse-integer (subseq timespec 10 12))))
		(if (>= len 14)
			(setf second (parse-integer (subseq timespec 12 14))))
		(encode-universal-time (or second 0) (or minute 0) 
			(or hour 0) (or day 1) (or month 1) year)))
		
		
(defun display-usage-info () 
	(format t "Usage: touch [-t time] file1 file2 ...~%")
	(format t "~10t-t~20tSet a specific time, specified as YYYYMMDDHHMMSS~%")
	(format t "~10t-recurse~20tDescend subdirectories when expanding wildcards~%")
	(format t "~10t-?~20tDisplay this usage information~%"))

(defun process-command-line-args (args)
	"Filter out and process switches"
	(do* ((a (cdr args) (cdr a))
		  (arg (car a)(car a))
		  (new-args '()))
		((null a)(nreverse new-args))
		(let ((ch (char arg 0)))
			(if (or (char= ch #\/) (char= ch #\-))
				(let ((switch (subseq arg 1)))
					(cond ((equalp switch "t")		
						   (setf *specified-time* 
								(timespec-to-universal-time (second a)))
						   (setf a (cdr a)))
						  ((equalp switch "?")		(setf *display-usage-info* t))
						  ((equalp switch "recurse")(setf *descend-subdirectories* t))
						  (t 						(format t "Unknown switch: ~A" switch))))
				(push arg new-args)))))

(defun flatten (list)
	(let ((new-list '()))
		(dolist (x list (nreverse new-list))
			(if (atom x)
				(push x new-list)
				(dolist (y (flatten x))
					(push y new-list))))))

(defun expand-wildcards (files)
	(let ((new-files '()))
		(dolist (file files (nreverse new-files))
			(if (or (find #\? file) (find #\* file))
				(let ((expanded (flatten (directory file :recurse *descend-subdirectories*))))
					(dolist (x expanded)
						(push x new-files)))
				(push file new-files)))))
		
(defun main ()
	(format t "Touch by Roger Corman      Copyright (c) 2001-2003 Corman Technologies~%")
	(let ((args (ccl:get-command-line-args)))
		(setf args 
			(expand-wildcards 
				(process-command-line-args args)))
		(if (or (null args) *display-usage-info*)
			(display-usage-info)
			(dolist (x args)
				(touch x *specified-time*)))
		(force-output)
		(win:exitprocess 0)))

		