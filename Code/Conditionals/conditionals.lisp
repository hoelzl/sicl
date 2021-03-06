;;;; Copyright (c) 2008, 2009, 2010, 2011
;;;;
;;;;     Robert Strandh (strandh@labri.fr)
;;;;
;;;; all rights reserved. 
;;;;
;;;; Permission is hereby granted to use this software for any 
;;;; purpose, including using, modifying, and redistributing it.
;;;;
;;;; The software is provided "as-is" with no warranty.  The user of
;;;; this software assumes any responsibility of the consequences. 

;;;; This file is part of the conditionals module of the SICL project.
;;;; See the file SICL.text for a description of the project. 
;;;; See the file conditionals.text for a description of the module.

;;; This implementation also does not use the format function, and
;;; instead uses print and princ for error reporting.  This makes it
;;; possible for format to use the conditional constructs define here.

(in-package #:sicl-conditionals)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Conditions used at macro-expansion time

;;; This condition is used to mix into other conditions that
;;; will report the construct (function, macro, etc) in which 
;;; the condition was signaled. 
(define-condition name-mixin ()
  ((%name :initarg :name :reader name)))

(define-condition malformed-body (program-error name-mixin)
  ((%body :initarg :body :reader body)))
     
(define-condition malformed-cond-clauses (program-error name-mixin)
  ((%clauses :initarg :clauses :reader clauses)))
     
(define-condition malformed-cond-clause (program-error name-mixin)
  ((%clause :initarg :clause :reader clause)))
     
(define-condition malformed-case-clauses (program-error name-mixin)
  ((%clauses :initarg :clauses :reader clauses)))
     
(define-condition malformed-case-clause (program-error name-mixin)
  ((%clause :initarg :clause :reader clause)))
     
(define-condition otherwise-clause-not-last (program-error name-mixin)
  ((%clauses :initarg :clauses :reader clauses)))

(define-condition malformed-keys (program-error name-mixin)
  ((%keys :initarg :keys :reader keys)))
     
(define-condition malformed-typecase-clauses (program-error name-mixin)
  ((%clauses :initarg :clauses :reader clauses)))
     
(define-condition malformed-typecase-clause (program-error name-mixin)
  ((%clause :initarg :clause :reader clause)))
     
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Conditions used at runtime

(define-condition ecase-type-error (type-error name-mixin)
  ())

(define-condition ccase-type-error (type-error name-mixin)
  ())

(define-condition etypecase-type-error (type-error name-mixin)
  ())

(define-condition ctypecase-type-error (type-error name-mixin)
  ())

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Utilities

;;; Check that an object is a proper list.
;;; We could have used the AND macro here, but
;;; we would have had to move this utility then,
;;; so we expand the AND macro manually.
(eval-when (:compile-toplevel :load-toplevel)

  (defun proper-list-p (object)
    (if (null object)
	t
	(if (consp object)
	    (proper-list-p (cdr object))
	    nil)))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Implementation of the macros

;;; FIXME: This is a bit wasteful because we call proper-list-p for
;;; each sublist of the forms.
(defmacro or (&rest forms)
  (unless (proper-list-p forms)
    (error 'malformed-body :name 'or :body forms))
  (if (null forms)
      nil
      (if (null (cdr forms))
	  (car forms)
	  (let ((temp-var (gensym)))
	    `(let ((,temp-var ,(car forms)))
	       (if ,temp-var
		   ,temp-var
		   (or ,@(cdr forms))))))))

;;; FIXME: This is a bit wasteful because we call proper-list-p for
;;; each sublist of the forms.
(defmacro and (&rest forms)
  (unless (proper-list-p forms)
    (error 'malformed-body :name 'or :body forms))
  (if (null forms)
      t
      (if (null (cdr forms))
	  (car forms)
	  `(if ,(car forms)
	       (and ,@(cdr forms))
	       nil))))

(defmacro when (form &body body)
  (if (not (proper-list-p body))
      (error 'malformed-body :name 'when :body body)
      `(if ,form
	   (progn ,@body)
	   nil)))

(defmacro unless (form &body body)
  (if (not (proper-list-p body))
      (error 'malformed-body :name 'unless :body body)
      `(if ,form
	   nil
	   (progn ,@body))))

(defmacro cond (&rest clauses)
  (if (not (proper-list-p clauses))
      (error 'malformed-cond-clauses :name 'cond :clauses clauses)
      (if (null clauses)
	  nil
	  (let ((clause (car clauses)))
	    (if (not (and (proper-list-p clause)
			  (not (null clause))))
		(error 'malformed-cond-clause
		       :name 'cond
		       :clause clause)
		(if (null (cdr clause))
		    `(or ,(car clause)
			 (cond ,@(cdr clauses)))
		    `(if ,(car clause)
			 (progn ,@(cdr clause))
			 (cond ,@(cdr clauses)))))))))

;;; Take a list of keys (known to be a proper list), and the name of a
;;; variable, and produce a list of forms (eql <variable> key).
(defun eql-ify (keys variable)
  (if (null keys)
      '()
      (cons `(eql ,variable ,(car keys))
	    (eql-ify (cdr keys) variable))))

;;; This function turns a list of CASE clauses into nested IFs.  It
;;; checks that the list of clauses is a proper list and that each
;;; clause is also a proper list.  It also checks that, if there is an
;;; otherwise clause, it is the last one.
(defun expand-case-clauses (clauses variable)
  (if (null clauses)
      'nil
      (if (not (consp clauses))
	  (error 'malformed-case-clauses
		 :name 'case
		 :clauses clauses)
	  (let ((clause (car clauses)))
	    (unless (and (proper-list-p clause)
			 (not (null clause)))
	      (error 'malformed-case-clause
		     :name 'case
		     :clause clause))
	    (if (or (eq (car clause) 'otherwise)
		    (eq (car clause) t))
		(if (null (cdr clauses))
		    `(progn ,@(cdr clause))
		    (error 'otherwise-clause-not-last
			   :name 'case
			   :clauses (cdr clauses)))
		;; it is a normal clause
		(let ((keys (car clause))
		      (forms (cdr clause)))
		  (if (and (atom keys)
			   (not (null keys)))
		      `(if (eql ,variable ,keys)
			   (progn ,@forms)
			   ,(expand-case-clauses (cdr clauses) variable))
		      (if (not (proper-list-p keys))
			  (error 'malformed-keys
				 :name 'case
				 :keys keys)
			  `(if (or ,@(eql-ify keys variable))
			       (progn ,@forms)
			       ,(expand-case-clauses (cdr clauses) variable))))))))))

(defmacro case (keyform &rest clauses)
  (let ((variable (gensym)))
    `(let ((,variable ,keyform))
       ,(expand-case-clauses clauses variable))))

;;; Collect a list of all the keys for ecase or ccase 
;;; to be used as the `exptected type' in error reporting.
(defun collect-e/ccase-keys (clauses name)
  (if (null clauses)
      nil
      (append 
       (let ((keys (caar clauses)))
	 (if (and (atom keys)
		  (not (null keys)))
	     (list keys)
	     (if (not (proper-list-p keys))
		 (error 'malformed-keys
			:name name
			:keys keys)
		 keys)))
       (collect-e/ccase-keys (cdr clauses) name))))

;;; Expand a list of clauses for ECASE or CCASE.  We turn the clauses
;;; into nested IFs, where the innermost form (final) depends on
;;; whether we use ecase or ccase.  We check that the list of clauses
;;; is a proper list, and that each clause is a proper list.
(defun expand-e/ccase-clauses (clauses variable final name)
  (if (null clauses)
      final
      (if (not (consp clauses))
	  (error 'malformed-case-clauses
		 :name name
		 :clauses clauses)
	  (let ((clause (car clauses)))
	    (unless (and (proper-list-p clause)
			 (not (null clause)))
	      (error 'malformed-case-clause
		     :name name
		     :clause clause))
	    (let ((keys (car clause))
		  (forms (cdr clause)))
	      (if (and (atom keys)
		       (not (null keys)))
		  `(if (eql ,variable ,keys)
		       (progn ,@forms)
		       ,(expand-e/ccase-clauses (cdr clauses) variable final name))
		  `(if (or ,@(eql-ify keys variable))
		       (progn ,@forms)
		       ,(expand-e/ccase-clauses (cdr clauses) variable final name))))))))

;;; For ECASE, the default is to signal a type error. 
(defmacro ecase (keyform &rest clauses)
  (let* ((variable (gensym))
	 (keys (collect-e/ccase-keys clauses 'ecase))
	 (final `(error 'ecase-type-error
			:name 'ecase
			:datum ,variable
			:expected-type '(member ,@keys))))
    `(let ((,variable ,keyform))
       ,(expand-e/ccase-clauses clauses variable final 'ecase))))

;;; This function is does the same thing as
;;; (mapcar #'list vars vals), but since we are not
;;; using mapping functions here, we have to 
;;; implement it recursively. 
(defun compute-let*-bindings (vars vals)
  (if (null vars)
      '()
      (cons (list (car vars) (car vals))
	    (compute-let*-bindings (cdr vars) (cdr vals)))))

;;; For CCASE, the default is to signal a correctable
;;; error, allowing a new value to be stored in the
;;; place passed as argument to CCASE, using the restart
;;; STORE-VALUE.  We use GET-SETF-EXPANSION so as to
;;; avoid multiple evaluation of the subforms of the place, 
;;; even though the HyperSpec allows such multiple evaluation. 
(defmacro ccase (keyplace &rest clauses &environment env)
  (multiple-value-bind (vars vals store-vars writer-forms reader-forms)
      (get-setf-expansion keyplace env)
    (let* ((label (gensym))
	   (keys (collect-e/ccase-keys clauses 'ccase))
	   (final `(restart-case (error 'ccase-type-error
					:name 'ccase
					:datum ,(car store-vars)
					:expected-type '(member ,@keys))
				 (store-value (v)
					      :interactive
					      (lambda ()
						(format *query-io*
							"New value: ")
						(list (read *query-io*)))
					      :report "Supply a new value"
					      (setq ,(car store-vars) v)
					      ,writer-forms
					      (go ,label)))))
      `(let* ,(compute-let*-bindings vars vals)
	 (declare (ignorable ,@vars))
	 (multiple-value-bind ,store-vars ,reader-forms
	   (tagbody
	      ,label
	      ,(expand-e/ccase-clauses clauses (car store-vars) final 'ccase)))))))

;;; Turn a list of TYPECASE clauses into nested IFs.  We check that
;;; the list of clauses is a proper list, that each clause is a proper
;;; list as well, and that, if there is an otherwise clause, it is the
;;; last one.
(defun expand-typecase-clauses (clauses variable)
  (if (null clauses)
      'nil
      (if (not (consp clauses))
	  (error 'malformed-typecase-clauses
		 :name 'typecase
		 :clauses clauses)
	  (let ((clause (car clauses)))
	    (unless (and (proper-list-p clause)
			 (not (null clause)))
	      (error 'malformed-typecase-clause
		     :name 'typecase
		     :clause clause))
	    (if (or (eq (car clause) 'otherwise)
		    (eq (car clause) t))
		(if (null (cdr clauses))
		    `(progn ,@(cdr clauses))
		    (error 'otherwise-clause-not-last
			   :name 'typecase
			   :clauses (cdr clauses)))
		;; it is a normal clause
		(let ((type (car clause))
		      (forms (cdr clause)))
		  `(if (typep ,variable ,type)
		       (progn ,@forms)
		       ,(expand-typecase-clauses (cdr clauses) variable))))))))

(defmacro typecase (keyform &rest clauses)
  (let ((variable (gensym)))
    `(let ((,variable ,keyform))
       ,(expand-typecase-clauses clauses variable))))

;;; Collect a list of all the types for etypecase or ctypecase 
;;; to be used as the `exptected type' in error reporting.
(defun collect-e/ctypecase-keys (clauses)
  (if (null clauses)
      nil
      (cons (caar clauses)
	    (collect-e/ctypecase-keys (cdr clauses)))))

;;; Turn a list of clauses for ETYPCASE or CTYPECASE into nested IFs.
;;; We check that the list of clauses is a proper list, and that each
;;; clause is a proper list.  The default case depends on whether we
;;; have a CCTYPECASE or an ETYPECASE, so we pass that as an argument
;;; (final).
(defun expand-e/ctypecase-clauses (clauses variable final name)
  (if (null clauses)
      final
      (if (not (consp clauses))
	  (error 'malformed-typecase-clauses
		 :name name
		 :clauses clauses)
	  (let ((clause (car clauses)))
	    (unless (and (proper-list-p clause)
			 (not (null clause)))
	      (error 'malformed-typecase-clause
		     :name name
		     :clause clause))
	    (let ((type (car clause))
		  (forms (cdr clause)))
	      `(if (typep ,variable ,type)
		   (progn ,@forms)
		   ,(expand-e/ctypecase-clauses (cdr clauses) variable final name)))))))

;;; As with ECASE, the default for ETYPECASE is to signal an error.
(defmacro etypecase (keyform &rest clauses)
  (let* ((variable (gensym))
	 (keys (collect-e/ctypecase-keys clauses))
	 (final `(error 'etypecase-type-error
			:name 'etypecase
			:datum ,variable
			:expected-type '(member ,@keys))))
    `(let ((,variable ,keyform))
       ,(expand-e/ctypecase-clauses clauses variable final 'etypecase))))

;;; As with CCASE, the default for CTYPECASE is is to signal a
;;; correctable error, and to allow the value to be altered by the
;;; STORE-VALUE restart.
(defmacro ctypecase (keyplace &rest clauses &environment env)
  (multiple-value-bind (vars vals store-vars writer-forms reader-forms)
      (get-setf-expansion keyplace env)
    (let* ((label (gensym))
	   (keys (collect-e/ctypecase-keys clauses))
	   (final `(restart-case (error 'ctypecase-type-error
					:name 'ctypecase
					:datum ,(car store-vars)
					:expected-type '(member ,@keys))
				 (store-value (v)
					      :interactive
					      (lambda ()
						(format *query-io*
							"New value: ")
						(list (read *query-io*)))
					      :report "Supply a new value"
					      (setq ,(car store-vars) v)
					      ,writer-forms
					      (go ,label)))))
      `(let* ,(compute-let*-bindings vars vals)
	 (declare (ignorable ,@vars))
	 (multiple-value-bind ,store-vars ,reader-forms
	   (tagbody
	      ,label
	      ,(expand-e/ctypecase-clauses clauses (car store-vars) final 'ctypecase)))))))
