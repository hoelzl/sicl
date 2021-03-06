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

(in-package #:cl-user)

(asdf:defsystem :sicl-conditionals
    :components
  ((:file "packages" :depends-on ())
   (:file "conditionals" :depends-on ("packages"))
   (:file "condition-reporters-en" :depends-on ("packages" "conditionals"))
   (:file "docstrings-en" :depends-on ("packages"))))

(asdf:defsystem :sicl-conditionals-test
  :depends-on (:sicl-conditionals)
  :components
  ((:file "test" :depends-on ())))
