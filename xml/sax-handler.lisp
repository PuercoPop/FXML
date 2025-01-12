;;; -*- Mode: Lisp; Syntax: Common-Lisp; Package: SAX; readtable: runes; Encoding: utf-8; -*-
;;; ---------------------------------------------------------------------------
;;;     Title: A SAX2-like API for the xml parser
;;;   Created: 2003-06-30
;;;    Author: Henrik Motakef <hmot@henrik-motakef.de>
;;;    Author: David Lichteblau
;;;   License: BSD
;;; ---------------------------------------------------------------------------
;;;  (c) copyright 2003 by Henrik Motakef
;;;  (c) copyright 2004 knowledgeTools Int. GmbH
;;;  (c) copyright 2005-2007 David Lichteblau
;;;  (c) copyright 2014 Paul M. Rodriguez

;;; Redistribution and use  in source and binary   forms, with or  without
;;; modification, are permitted provided that the following conditions are
;;; met:
;;;
;;; 1. Redistributions  of  source  code  must retain  the above copyright
;;;    notice, this list of conditions and the following disclaimer.
;;;
;;; 2. Redistributions in  binary form must reproduce  the above copyright
;;;    notice, this list of conditions and the following disclaimer in the
;;;    documentation and/or other materials provided with the distribution
;;;
;;; THIS  SOFTWARE   IS PROVIDED ``AS  IS''   AND ANY  EXPRESS  OR IMPLIED
;;; WARRANTIES, INCLUDING, BUT NOT LIMITED  TO, THE IMPLIED WARRANTIES  OF
;;; MERCHANTABILITY  AND FITNESS FOR A  PARTICULAR PURPOSE ARE DISCLAIMED.
;;; IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
;;; INDIRECT,  INCIDENTAL,  SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL  DAMAGES
;;; (INCLUDING, BUT NOT LIMITED TO,   PROCUREMENT OF SUBSTITUTE GOODS   OR
;;; SERVICES;  LOSS OF  USE,  DATA, OR  PROFITS; OR BUSINESS INTERRUPTION)
;;; HOWEVER  CAUSED AND ON ANY THEORY  OF LIABILITY,  WHETHER IN CONTRACT,
;;; STRICT LIABILITY, OR  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
;;; IN ANY WAY  OUT OF THE  USE OF THIS SOFTWARE,  EVEN IF ADVISED OF  THE
;;; POSSIBILITY OF SUCH DAMAGE.

;;; TODO/ Open Questions:

;; o Missing stuff from Java SAX2:
;;   * ignorable-whitespace
;;   * skipped-entity
;;   * The whole ErrorHandler class, this is better handled using
;;     conditions (but isn't yet)

(defpackage :fxml.sax
  (:use :common-lisp :named-readtables)
  (:export #:*namespace-processing*
           #:*include-xmlns-attributes*
           #:*use-xmlns-namespace*

           #:abstract-handler
           #:content-handler
           #:default-handler

           #:callback-handler
           #:make-callback-handler

           #:make-attribute
           #:find-attribute
           #:find-attribute-ns
           #:attribute-namespace-uri
           #:attribute-local-name
           #:attribute-qname
           #:attribute-value
           #:attribute-specified-p

           #:start-document
           #:start-prefix-mapping
           #:start-element
           #:characters
           #:unescaped
           #:processing-instruction
           #:end-element
           #:end-prefix-mapping
           #:end-document
           #:comment
           #:start-cdata
           #:end-cdata
           #:start-dtd
           #:end-dtd
           #:start-internal-subset
           #:unparsed-internal-subset
           #:end-internal-subset
           #:unparsed-entity-declaration
           #:external-entity-declaration
           #:internal-entity-declaration
           #:notation-declaration
           #:element-declaration
           #:attribute-declaration
           #:entity-resolver

           #:sax-parser
           #:sax-parser-mixin
           #:register-sax-parser
           #:line-number
           #:column-number
           #:system-id
           #:xml-base
           #:standard-attribute
           
           #:sax-condition
           #:sax-condition.handler
           #:sax-condition.event
           #:deprecated-sax-default-method
           #:not-implemented
           #:dtd))

(in-package :fxml.sax)
(in-readtable :runes)


;;;; SAX-PARSER interface

(defclass sax-parser () ())

(defclass sax-parser-mixin ()		;deprecated
    ((sax-parser :initform nil :reader sax-parser)))

(defgeneric line-number (sax-parser)
  (:documentation
   "Return an approximation of the current line number, or NIL.")
  (:method ((handler sax-parser-mixin))
    (if (sax-parser handler)
        (line-number (sax-parser handler))
        nil)))

(defgeneric column-number (sax-parser)
  (:documentation
   "Return an approximation of the current column number, or NIL.")
  (:method ((handler sax-parser-mixin))
    (if (sax-parser handler)
        (column-number (sax-parser handler))
        nil)))

(defgeneric system-id (sax-parser)
  (:documentation
   "Return the URI of the document being parsed.  This is either the
    main document, or the entity's system ID while contents of a parsed
    general external entity are being processed.")
  (:method ((handler sax-parser-mixin))
    (if (sax-parser handler)
        (system-id (sax-parser handler))
        nil)))

(defgeneric xml-base (sax-parser)
  (:documentation
   "Return the [Base URI] of the current element.  This URI can differ from
   the value returned by FXML.SAX:SYSTEM-ID if xml:base attributes are present.")
  (:method ((handler sax-parser-mixin))
    (if (sax-parser handler)
        (xml-base (sax-parser handler))
        nil)))


;;;; Configuration variables

;; The http://xml.org/sax/features/namespaces property
(defvar *namespace-processing* t
  "If non-nil (the default), namespace processing is enabled.

See also `start-element' and `end-element' for a detailed description
of the consequences of modifying this variable, and
`*include-xmlns-attributes*' and `*use-xmlns-namespace*' for further
related options.")

;; The http://xml.org/sax/features/namespace-prefixes property.
(defvar *include-xmlns-attributes* t
  "If non-nil, namespace declarations are reported as normal
attributes.

This variable has no effect unless `*namespace-processing*' is
non-nil.

See also `*use-xmlns-namespace*', and `start-element' for a detailed
description of the consequences of setting this variable.")

(defvar *use-xmlns-namespace* t
  "If this variable is nil (the default), attributes with a name like
'xmlns:x' are not considered to be in a namespace, following the
'Namespaces in XML' specification.

If it is non-nil, such attributes are considered to be in a namespace
with the URI 'http://www.w3.org/2000/xmlns/', following an
incompatible change silently introduced in the errata to that spec,
and adopted by some W3C standards.

For example, an attribute like xmlns:ex='http://example.com' would be
reported like this:

*use-xmlns-namespace*: nil
namespace-uri:         nil
local-name:            nil
qname:                 #\"xmlns:ex\"

*use-xmlns-namespace*: t
namespace-uri:         #\"http://www.w3.org/2000/xmlns/\"
local-name:            #\"ex\"
qname:                 #\"xmlns:ex\"

Setting this variable has no effect unless both
`*namespace-processing*' and `*include-xmlns-attributes*' are non-nil.")


;;;; ATTRIBUTE

(defstruct (standard-attribute (:constructor make-attribute))
  namespace-uri
  local-name
  qname
  value
  specified-p)

(defmethod (setf attribute-namespace-uri)
    (newval (attribute standard-attribute))
  (setf (standard-attribute-namespace-uri attribute) newval))

(defmethod (setf attribute-local-name)
    (newval (attribute standard-attribute))
  (setf (standard-attribute-local-name attribute) newval))

(defmethod (setf attribute-qname)
    (newval (attribute standard-attribute))
  (setf (standard-attribute-qname attribute) newval))

(defmethod (setf attribute-value)
    (newval (attribute standard-attribute))
  (setf (standard-attribute-value attribute) newval))

(defmethod (setf attribute-specified-p)
    (newval (attribute standard-attribute))
  (setf (standard-attribute-specified-p attribute) newval))

(defgeneric attribute-namespace-uri (attribute)
  (:method ((attribute standard-attribute))
    (standard-attribute-namespace-uri attribute)))

(defgeneric attribute-local-name (attribute)
  (:method ((attribute standard-attribute))
    (standard-attribute-local-name attribute)))

(defgeneric attribute-qname (attribute)
  (:method ((attribute standard-attribute))
    (standard-attribute-qname attribute)))

(defgeneric attribute-value (attribute)
  (:method ((attribute standard-attribute))
    (standard-attribute-value attribute)))

(defgeneric attribute-specified-p (attribute)
  (:method ((attribute standard-attribute))
    (standard-attribute-specified-p attribute)))

(defun %rod= (x y)
  ;; allow rods *and* strings *and* null
  (cond
    ((zerop (length x)) (zerop (length y)))
    ((zerop (length y)) nil)
    ((stringp x) (string= x y))
    (t (fxml.runes:rod= x y))))

(defun find-attribute (qname attrs)
  (find qname attrs :key #'attribute-qname :test #'%rod=))

(defun find-attribute-ns (uri lname attrs)
  (find-if (lambda (attr)
             (and (%rod= uri (fxml.sax:attribute-namespace-uri attr))
                  (%rod= lname (fxml.sax:attribute-local-name attr))))
           attrs))


;;;; ABSTRACT-HANDLER and DEFAULT-HANDLER

(defclass abstract-handler (sax-parser-mixin) ())
(defclass content-handler (abstract-handler) ())
(defclass default-handler (content-handler) ())

;;;; CONDITIONS

(define-condition sax-condition ()
  ((handler
    :initarg :handler
    :reader sax-condition.handler)
   (event
    :initarg :event
    :reader sax-condition.event)))

(define-condition deprecated-sax-default-method (warning sax-condition)
  ()
  (:report (lambda (c s)
             (format s "Deprecated SAX default method used by handler ~
             ~a, which is not a subclass of ~
             FXML.SAX:ABSTRACT-HANDLER"
                     (sax-condition.handler c)))))

(defgeneric deprecated-sax-default-method (handler event)
  (:method (handler event)
    (warn 'deprecated-sax-default-method
          :handler handler
          :event event)))

(define-condition not-implemented (error sax-condition)
  ()
  (:report (lambda (c s)
             (format s "SAX event ~a not implemented by ~a"
                     (sax-condition.event c)
                     (sax-condition.handler c)))))

;;;; EVENTS

(defmacro define-event ((name default-handler-class)
                        (&rest args))
  `(defgeneric ,name (handler ,@args)
     (:method ((handler null) ,@args)
       (declare (ignore ,@args))
       nil)
     (:method ((handler t) ,@args)
       (declare (ignore ,@args))
       (deprecated-sax-default-method handler ',name)
       nil)
     (:method ((handler abstract-handler) ,@args)
       (declare (ignore ,@args))
       (error 'not-implemented
              :handler handler
              :event ',name))
     (:method ((handler ,default-handler-class) ,@args)
       (declare (ignore ,@args))
       nil)))

(define-event (start-document default-handler)
    ())

(define-event (start-element default-handler)
    (namespace-uri local-name qname attributes))

(define-event (start-prefix-mapping content-handler)
    (prefix uri))

(define-event (characters default-handler)
    (data))

(define-event (unescaped default-handler)
    (data))

(define-event (processing-instruction default-handler)
    (target data))

(define-event (end-prefix-mapping content-handler)
    (prefix))

(define-event (end-element default-handler)
    (namespace-uri local-name qname))

(define-event (end-document default-handler)
    ())

(define-event (comment content-handler)
    (data))

(define-event (start-cdata content-handler)
    ())

(define-event (end-cdata content-handler)
    ())

(define-event (start-dtd content-handler)
    (name public-id system-id))

(define-event (end-dtd content-handler)
    ())

(define-event (start-internal-subset content-handler)
    ())

(define-event (end-internal-subset content-handler)
    ())

(define-event (unparsed-internal-subset content-handler)
    (str))

(define-event (unparsed-entity-declaration content-handler)
    (name public-id system-id notation-name))

(define-event (external-entity-declaration content-handler)
    (kind name public-id system-id))

(define-event (internal-entity-declaration content-handler)
    (kind name value))

(define-event (notation-declaration content-handler)
    (name public-id system-id))

(define-event (element-declaration content-handler)
    (name model))

(define-event (attribute-declaration content-handler)
    (element-name attribute-name type default))

(define-event (entity-resolver content-handler)
    (resolver))

(define-event (dtd content-handler)
    (dtd))

;;; special case: this method is defined on abstract-handler through
;;; sax-parser-mixin
(defgeneric register-sax-parser (handler sax-parser)
  (:documentation "Set the SAX-PARSER instance of this handler.")
  (:method ((handler null) sax-parser)
    (declare (ignore sax-parser))
    nil)
  (:method ((handler sax-parser-mixin) sax-parser)
    (setf (slot-value handler 'sax-parser) sax-parser))
  (:method ((handler t) sax-parser)
    (declare (ignore sax-parser))
    (deprecated-sax-default-method handler 'register-sax-parser)
    nil))

;;;; Callback handlers.

(defun void (&rest args)
  "Do nothing and return nil."
  (declare (ignore args)))

(defclass callback-handler (content-handler)
  ((start-element :initarg :start-element :type function)
   (end-element :initarg :end-element :type function)
   (start-document :initarg :start-document :type function)
   (end-document :initarg :end-document :type function)
   (characters :initarg :characters :type function)
   (unescaped :initarg :unescaped :type function)
   (comment :initarg :comment :type function)
   (processing-instruction :initarg :processing-instruction :type function))
  (:default-initargs
   :start-element #'void
   :end-element #'void
   :start-document #'void
   :end-document #'void
   :characters #'void
   :comment #'void
   :unescaped #'void
   :processing-instruction #'void))

(macrolet ((defcallback (name args)
               (let ((self (gensym (string 'self))))
                 `(defmethod ,name ((,self callback-handler) ,@args)
                    (funcall (slot-value ,self ',name) ,@args)))))
  (defcallback start-element (ns lname qname attrs))
  (defcallback end-element (ns lname qname))
  (defcallback start-document ())
  (defcallback end-document ())
  (defcallback characters (data))
  (defcallback unescaped (data))
  (defcallback comment (data))
  (defcallback processing-instruction (target data)))

(declaim (inline make-callback-handler))
(defun make-callback-handler (&rest args)
  (apply #'make-instance 'callback-handler args))

;;;; Documentation

(setf (documentation 'start-document 'function)
      "Called at the beginning of the parsing process,
before any element, processing instruction or comment is reported.

Handlers that need to maintain internal state may use this to perform
any neccessary initializations.")

(setf (documentation 'start-element 'function)
      "Called to report the beginning of an element.

There will always be a corresponding call to end-element, even in the
case of an empty element (i.e. <foo/>).

If the value of *namespaces* is non-nil, namespace-uri, local-name and
qname are rods. If it is nil, namespace-uri and local-name are always
nil, and it is not an error if the qname is not a well-formed
qualified element name (for example, if it contains more than one
colon).

The attributes parameter is a list (in arbitrary order) of instances
of the `attribute' structure class. The for their namespace-uri and
local-name properties, the same rules as for the element name
apply. Additionally, namespace-declaring attributes (those whose name
is \"xmlns\" or starts with \"xmlns:\") are only included if
*include-xmlns-attributes* is non-nil.")

(setf (documentation 'start-prefix-mapping 'function)
      "Called when the scope of a new prefix -> namespace-uri mapping begins.

This will always be called immediatly before the `start-element' event
for the element on which the namespaces are declared.

Clients don't usually have to implement this except under special
circumstances, for example when they have to deal with qualified names
in textual content. The parser will handle namespaces of elements and
attributes on its own.")

(setf (documentation 'characters 'function)
      "Called for textual element content.

The data is passed as a rod, with all entity references resolved.
It is possible that the character content of an element is reported
via multiple subsequent calls to this generic function.")

(setf (documentation 'unescaped 'function)
      "Called for unescaped element content.  Beware dragons.")

(setf (documentation 'processing-instruction 'function)
      "Called when a processing instruction is read.

Both target and data are rods.")

(setf (documentation 'end-prefix-mapping 'function)
      "Called when a prefix -> namespace-uri mapping goes out of scope.

This will always be called immediatly after the `end-element' event
for the element on which the namespace is declared. The order of the
end-prefix-mapping events is otherwise not guaranteed.

Clients don't usually have to implement this except under special
circumstances, for example when they have to deal with qualified names
in textual content. The parser will handle namespaces of elements and
attributes on its own.")

(setf (documentation 'end-element 'function)
      "Called to report the end of an element.

See the documentation for `start-element' for a description of the
parameters.")

(setf (documentation 'end-document 'function)
      "Called at the end of parsing a document.
This is always the last function called in the parsing process.

In contrast to all of the other methods, the return value of this gf
is significant, it will be returned by the parse-file/stream/string function.")

(setf (documentation 'start-cdata 'function)
      "Called at the beginning of parsing a CDATA section.

Handlers only have to implement this if they are interested in the
lexical structure of the parsed document. The content of the CDATA
section is reported via the `characters' generic function like all
other textual content.")

(setf (documentation 'end-cdata 'function)
      "Called at the end of parsing a CDATA section.

Handlers only have to implement this if they are interested in the
lexical structure of the parsed document. The content of the CDATA
section is reported via the `characters' generic function like all
other textual content.")

(setf (documentation 'start-dtd 'function)
      "Called at the beginning of parsing a DTD.")

(setf (documentation 'end-dtd 'function)
      "Called at the end of parsing a DTD.")

(setf (documentation 'start-internal-subset 'function)
      "Reports that an internal subset is present.  Called before
any definition from the internal subset is reported.")

(setf (documentation 'end-internal-subset 'function)
      "Called after processing of the internal subset has
finished, if present.")

(setf (documentation 'unparsed-internal-subset 'function)
      "Reports that an internal subset is present, but has not
been parsed and is available as a string.")

(setf (documentation 'unparsed-entity-declaration 'function)
      "Called when an unparsed entity declaration is seen in a DTD.")

(setf (documentation 'external-entity-declaration 'function)
      "Called when a parsed external entity declaration is seen in a DTD.")

(setf (documentation 'internal-entity-declaration 'function)
      "Called when an internal entity declaration is seen in a DTD.")

(setf (documentation 'notation-declaration 'function)
      "Called when a notation declaration is seen while parsing a DTD.")

(setf (documentation 'element-declaration 'function)
      "Called when a element declaration is seen in a DTD.  Model is not a string,
    but a nested list, with *, ?, +, OR, and AND being the operators, rods
    as names, :EMPTY and :PCDATA as special tokens.  (AND represents
    sequences.)")

(setf (documentation 'attribute-declaration 'function)
      "Called when an attribute declaration is seen in a DTD.
    type        one of :CDATA, :ID, :IDREF, :IDREFS,
                :ENTITY, :ENTITIES, :NMTOKEN, :NMTOKENS,
                (:NOTATION <name>*), or (:ENUMERATION <name>*)
    default     :REQUIRED, :IMPLIED, (:FIXED content), or (:DEFAULT content)")

(setf (documentation 'entity-resolver 'function)
      "Called between fxml.sax:end-dtd and fxml.sax:end-document to register an entity
    resolver, a function of two arguments: An entity name and SAX handler.
    When called, the resolver function will parse the named entity's data.")


