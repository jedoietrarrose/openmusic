;=========================================================================
;  OpenMusic: Visual Programming Language for Music Composition
;
;  Copyright (c) 1997-... IRCAM-Centre Georges Pompidou, Paris, France.
; 
;    This file is part of the OpenMusic environment sources
;
;    OpenMusic is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    OpenMusic is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with OpenMusic.  If not, see <http://www.gnu.org/licenses/>.
;
;=========================================================================

(in-package :om)


;;;=====================================
;;; COLLECT
;;;=====================================

(defclass ReactiveCollBox (OMBoxcall) 
  ((memory :initform nil :accessor memory)))

(defmethod omNG-box-value ((self ReactiveCollBox) &optional (numout nil))
  (current-box-value self numout))

(defmethod current-box-value ((self ReactiveCollBox) &optional (numout nil))
  (reverse (memory self)))


;;; NOTIFY ONLY IF PUSH
(defmethod OMR-Notify ((self ReactiveCollBox))
 ;(print (list "NOTIFIED BOX" (name self)))
 ;(box-color self *notify-color*)  
 (unless (push-tag self)
   (setf (push-tag self) t)
   (let ((listeners (remove-if-not 'active (listeners self))))
     ;(print (list "INPUTS" inputs))
     (let ((push? (process-input self (inputs self))))
     ;(print (list self (memory self)))
       (when (and (active self) listeners push?)
         (setf (state-lock self) t)
         (mapcar 'omr-notify listeners)
         (setf (state-lock self) nil)
         )
       )))
 ;(box-color self *inactive-color*)
 )

(defmethod process-input ((self ReactiveCollBox) inputs)
 (let ((init (omNG-box-value (nth 2 inputs)))      
       (push (omNG-box-value (nth 1 inputs))))
  (if init (setf (memory self) nil)
    (let ((in (omNG-box-value (nth 0 inputs))))
      (when in (push in (memory self)))))
  ;;; return value determines if the notification propagates
  push))

(defmethod get-boxcallclass-fun ((self (eql 'coll))) 'ReactiveCollBox)

(defmethod! coll (data push init) 
   :icon '(649)
   (values data push init))


;;;=====================================
;;; GROUP

(defclass ReactiveGroupBox (ReactiveCollBox) 
  ((tt :initform nil :accessor tt)))

(defmethod process-input ((self ReactiveGroupBox) inputs)
  (let ((in (omng-box-value (car inputs)))
        (delta (omng-box-value (cadr inputs))))
    (if (or (null (tt self))  ;;; fresh memory
            (> (clock-time) (+ delta (tt self)))) ;;; time out
        (setf (tt self) (clock-time)
              (memory self) (if in (list in) nil))
      (when in (push in (memory self))))
    in))

(defmethod! group-in (in delta) 
   :icon nil :initvals '(nil 100)
   (values in delta))

(defmethod get-boxcallclass-fun ((self (eql 'group-in))) 'ReactiveGroupBox)


;;;=====================================
;;; DELAY / MEMORY

(defclass ReactiveDelayBox (ReactiveCollBox) 
  ())

(defmethod process-input ((self ReactiveDelayBox) inputs)
  (let ((in (omng-box-value (car inputs)))
        (size (omng-box-value (cadr inputs))))
    (setf (memory self)
          (if size
              (list in (first-n (cons (car (memory self)) (list! (cadr (memory self)))) size))
            (list in (car (memory self)))))
    in))

(defmethod! mem (in size) 
   :icon nil :initvals '(nil nil) :numouts 2
   (values in size))

(defmethod current-box-value ((self ReactiveDelayBox) &optional (numout nil))
  (if (and numout (> numout 0))
      (cadr (memory self))
    (car (memory self))))


(defmethod get-boxcallclass-fun ((self (eql 'mem))) 'ReactiveDelayBox)

;;;=====================================
;;; TIMED-COLL 

(defclass ReactiveTimeCollBox (ReactiveCollBox) 
  ((tt :initform nil :accessor tt)
   (t0 :initform nil :accessor t0)
   (timelist :initform nil :accessor timelist)))

(defmethod process-input ((self ReactiveTimeCollBox) inputs)
  (let ((push (omng-box-value (nth 1 inputs)))
        (init (omng-box-value (nth 2 inputs)))
        (delta (omng-box-value (nth 3 inputs))))
    
    (if init
        (setf (memory self) nil 
              (timelist self) nil 
              (tt self) nil
              (t0 self) nil)
      (let ((in (omng-box-value (nth 0 inputs))))
        (when in 
          (let ((curr-t (clock-time)))
            (unless (t0 self) (setf (t0 self) curr-t))
            (if (or (null (tt self))  ;;; fresh memory
                    (> curr-t (+ delta (tt self)))) ;;; time out
                (progn 
                  (setf (tt self) curr-t)
                  (push (list in) (memory self))
                  (push (- (tt self) (t0 self)) (timelist self)))
              (push in (car (memory self)))))))
      )
    
    push))

;(defmethod omNG-box-value ((self ReactiveTimeCollBox) &optional (numout 0)) 
;  (setf (value self) 
;       (list (reverse (memory self))
;             (reverse (timelist self))))
; (nth numout (value self)))

(defmethod current-box-value ((self ReactiveTimeCollBox) &optional (numout 0))
  (if numout
      (nth numout
           (list (reverse (memory self))
                 (reverse (timelist self))))
    (list (reverse (memory self))
          (reverse (timelist self)))))



(defmethod! timed-coll (in push init delta) 
    :icon '(649) 
    :initvals '(nil nil nil 100) 
    :numouts 2
   (values in push init delta))

(defmethod get-boxcallclass-fun ((self (eql 'timed-coll))) 'ReactiveTimeCollBox)




      