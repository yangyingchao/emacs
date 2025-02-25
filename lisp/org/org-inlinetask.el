;;; org-inlinetask.el --- Tasks Independent of Outline Hierarchy -*- lexical-binding: t; -*-

;; Copyright (C) 2009-2025 Free Software Foundation, Inc.
;;
;; Author: Carsten Dominik <carsten.dominik@gmail.com>
;; Keywords: outlines, hypermedia, calendar, text
;; URL: https://orgmode.org

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify

;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;; This module implements inline tasks in Org mode.  Inline tasks are
;; tasks that have all the properties of normal outline nodes,
;; including the ability to store meta data like scheduling dates,
;; TODO state, tags and properties.  However, these nodes are treated
;; specially by the visibility cycling.
;;
;; Visibility cycling exempts these nodes from cycling.  So whenever
;; their parent is opened, so are these tasks.  This will only work
;; with `org-cycle', so if you are also using other commands to
;; show/hide entries, you will occasionally find these tasks to behave
;; like all other outline nodes, seemingly splitting the text of the
;; parent into children.
;;
;; Special fontification of inline tasks, so that they can be
;; immediately recognized.  From the stars of the headline, only last
;; two will be visible, the others will be hidden using the `org-hide'
;; face.
;;
;; An inline task is identified solely by a minimum outline level,
;; given by the variable `org-inlinetask-min-level', default 15.
;;
;; If you need to have a time planning line (DEADLINE etc), drawers,
;; for example LOGBOOK of PROPERTIES, or even normal text as part of
;; the inline task, you must add an "END" headline with the same
;; number of stars.
;;
;; As an example, here are two valid inline tasks:
;;
;;    **************** TODO A small task
;;
;; and
;;
;;    **************** TODO Another small task
;;                     DEADLINE: <2009-03-30 Mon>
;;                     :PROPERTIES:
;;                     :SOMETHING: another thing
;;                     :END:
;;                     And here is some extra text
;;    **************** END
;;
;; Also, if you want to use refiling and archiving for inline tasks,
;; The END line must be present to make things work properly.
;;
;; Note that you should not try to use inline tasks within plain list,
;; visibility cycling is known to be problematic when doing so.
;;
;; This package installs one new command:
;;
;; C-c C-x t      Insert a new inline task with END line

;;; Code:

(require 'org-macs)
(org-assert-version)

(require 'org)

(defgroup org-inlinetask nil
  "Options concerning inline tasks in Org mode."
  :tag "Org Inline Tasks"
  :group 'org-structure)

(defcustom org-inlinetask-min-level 15
  "Minimum level a headline must have before it is treated as an inline task.
Don't set it to something higher than `29' or clocking will break since this
is the hardcoded maximum number of stars `org-clock-sum' will work with.

It is strongly recommended that you set `org-cycle-max-level' not at all,
or to a number smaller than this one.  See `org-cycle-max-level'
docstring for more details."
  :group 'org-inlinetask
  :type '(choice
	  (const :tag "Off" nil)
	  (integer)))

(defcustom org-inlinetask-show-first-star nil
  "Non-nil means display the first star of an inline task as additional marker.
When nil, the first star is not shown."
  :tag "Org Inline Tasks"
  :group 'org-structure
  :type 'boolean)

(defvar org-odd-levels-only)
(defvar org-keyword-time-regexp)
(defvar org-complex-heading-regexp)
(defvar org-property-end-re)

(defcustom org-inlinetask-default-state nil
  "Non-nil means make inline tasks have a TODO keyword initially.
This should be the state `org-inlinetask-insert-task' should use by
default, or nil if no state should be assigned."
  :group 'org-inlinetask
  :version "24.1"
  :type '(choice
	  (const :tag "No state" nil)
	  (string :tag "Specific state")))

(defun org-inlinetask-insert-task (&optional no-state)
  "Insert an inline task.
If prefix arg NO-STATE is set, ignore `org-inlinetask-default-state'.
If there is a region wrap it inside the inline task."
  (interactive "P")
  ;; Error when inside an inline task, except if point was at its very
  ;; beginning, in which case the new inline task will be inserted
  ;; before this one.
  (when (and (org-inlinetask-in-task-p)
	     (not (and (org-inlinetask-at-task-p) (bolp))))
    (user-error "Cannot nest inline tasks"))
  (or (bolp) (newline))
  (let* ((indent (if org-odd-levels-only
		     (1- (* 2 org-inlinetask-min-level))
		   org-inlinetask-min-level))
	 (indent-string (concat (make-string indent ?*) " "))
	 (rbeg (if (org-region-active-p) (region-beginning) (point)))
	 (rend (if (org-region-active-p) (region-end) (point))))
    (goto-char rend)
    (insert "\n" indent-string "END\n")
    (goto-char rbeg)
    (unless (bolp) (insert "\n"))
    (insert indent-string
	    (if (or no-state (not org-inlinetask-default-state))
		""
	      (concat org-inlinetask-default-state " "))
	    (if (= rend rbeg) "" "\n"))
    (unless (= rend rbeg) (end-of-line 0))))
(define-key org-mode-map "\C-c\C-xt" 'org-inlinetask-insert-task)

(defun org-inlinetask-outline-regexp ()
  "Return string matching an inline task heading.
The number of levels is controlled by `org-inlinetask-min-level'."
  (let ((nstars (if org-odd-levels-only
		    (1- (* org-inlinetask-min-level 2))
		  org-inlinetask-min-level)))
    (format "^\\(\\*\\{%d,\\}\\)[ \t]+" nstars)))

(defun org-inlinetask-end-p ()
  "Return a non-nil value if point is on inline task's END part."
  (let ((case-fold-search t))
    (org-match-line (concat (org-inlinetask-outline-regexp) "END[ \t]*$"))))

(defun org-inlinetask-at-task-p ()
  "Return non-nil if point is at beginning of an inline task."
  (and (org-match-line (concat (org-inlinetask-outline-regexp)  "\\(.*\\)"))
       (not (org-inlinetask-end-p))))

(defun org-inlinetask-in-task-p ()
  "Return non-nil if point is inside an inline task."
  (save-excursion
    (forward-line 0)
    (let ((case-fold-search t))
      (or (looking-at-p (concat (org-inlinetask-outline-regexp) "\\(?:.*\\)"))
	  (and (re-search-forward "^\\*+[ \t]+" nil t)
	       (org-inlinetask-end-p))))))

(defun org-inlinetask-goto-beginning ()
  "Go to the beginning of the inline task at point."
  (end-of-line)
  (let ((case-fold-search t)
	(inlinetask-re (org-inlinetask-outline-regexp)))
    (re-search-backward inlinetask-re nil t)
    (when (org-inlinetask-end-p)
      (re-search-backward inlinetask-re nil t))))

(defun org-inlinetask-goto-end ()
  "Go to the end of the inline task at point.
Return point."
  (save-match-data
    (forward-line 0)
    (let ((case-fold-search t)
	  (inlinetask-re (org-inlinetask-outline-regexp)))
      (cond
       ((org-inlinetask-end-p)
        (forward-line))
       ((looking-at-p inlinetask-re)
        (forward-line)
        (cond
         ((org-inlinetask-end-p) (forward-line))
         ((looking-at-p inlinetask-re))
         ((org-inlinetask-in-task-p)
          (re-search-forward inlinetask-re nil t)
          (forward-line))
         (t nil)))
       (t
        (re-search-forward inlinetask-re nil t)
        (forward-line)))))
  (point))

(defun org-inlinetask-get-task-level ()
  "Get the level of the inline task around.
This assumes the point is inside an inline task."
  (save-excursion
    (end-of-line)
    (re-search-backward (org-inlinetask-outline-regexp) nil t)
    (- (match-end 1) (match-beginning 1))))

(defun org-inlinetask-promote ()
  "Promote the inline task at point.
If the task has an end part, promote it.  Also, prevents level from
going below `org-inlinetask-min-level'."
  (interactive)
  (if (not (org-inlinetask-in-task-p))
      (user-error "Not in an inline task")
    (save-excursion
      (let* ((lvl (org-inlinetask-get-task-level))
	     (next-lvl (org-get-valid-level lvl -1))
	     (diff (- next-lvl lvl))
	     (down-task (concat (make-string next-lvl ?*)))
	     beg)
	(if (< next-lvl org-inlinetask-min-level)
	    (user-error "Cannot promote an inline task at minimum level")
	  (org-inlinetask-goto-beginning)
	  (setq beg (point))
	  (replace-match down-task nil t nil 1)
	  (org-inlinetask-goto-end)
          (if (and (eobp) (looking-back "END\\s-*" (line-beginning-position)))
              (forward-line 0)
            (forward-line -1))
	  (unless (= (point) beg)
            (looking-at (org-inlinetask-outline-regexp))
	    (replace-match down-task nil t nil 1)
	    (when (eq org-adapt-indentation t)
	      (goto-char beg)
	      (org-fixup-indentation diff))))))))

(defun org-inlinetask-demote ()
  "Demote the inline task at point.
If the task has an end part, also demote it."
  (interactive)
  (if (not (org-inlinetask-in-task-p))
      (user-error "Not in an inline task")
    (save-excursion
      (let* ((lvl (org-inlinetask-get-task-level))
	     (next-lvl (org-get-valid-level lvl 1))
	     (diff (- next-lvl lvl))
	     (down-task (concat (make-string next-lvl ?*)))
	     beg)
	(org-inlinetask-goto-beginning)
	(setq beg (point))
	(replace-match down-task nil t nil 1)
	(org-inlinetask-goto-end)
        (if (and (eobp) (looking-back "END\\s-*" (line-beginning-position)))
            (forward-line 0)
          (forward-line -1))
	(unless (= (point) beg)
          (looking-at (org-inlinetask-outline-regexp))
	  (replace-match down-task nil t nil 1)
	  (when (eq org-adapt-indentation t)
	    (goto-char beg)
	    (org-fixup-indentation diff)))))))

(defvar org-indent-indentation-per-level) ; defined in org-indent.el

(defface org-inlinetask '((t :inherit shadow))
  "Face for inlinetask headlines."
  :group 'org-faces)

(defun org-inlinetask-fontify (limit)
  "Fontify the inline tasks down to LIMIT."
  (let* ((nstars (if org-odd-levels-only
		     (1- (* 2 (or org-inlinetask-min-level 200)))
		   (or org-inlinetask-min-level 200)))
	 (re (concat "^\\(\\*\\)\\(\\*\\{"
		     (format "%d" (- nstars 3))
		     ",\\}\\)\\(\\*\\* .*\\)"))
	 ;; Virtual indentation will add the warning face on the first
	 ;; star.  Thus, in that case, only hide it.
	 (start-face (if (and (bound-and-true-p org-indent-mode)
			      (> org-indent-indentation-per-level 1))
			 'org-hide
		       'org-warning)))
    (while (re-search-forward re limit t)
      (if org-inlinetask-show-first-star
	  (add-text-properties (match-beginning 1) (match-end 1)
			       `(face ,start-face font-lock-fontified t)))
      (add-text-properties (match-beginning
			    (if org-inlinetask-show-first-star 2 1))
			   (match-end 2)
			   '(face org-hide font-lock-fontified t))
      (add-text-properties (match-beginning 3) (match-end 3)
			   '(face org-inlinetask font-lock-fontified t)))))

(defun org-inlinetask-toggle-visibility (&optional state)
  "Toggle visibility of inline task at point.
When optional argument STATE is `fold', fold unconditionally.
When STATE is `unfold', unfold unconditionally."
  (let ((end (save-excursion
	       (org-inlinetask-goto-end)
	       (if (bolp) (1- (point)) (point))))
	(start (save-excursion
		 (org-inlinetask-goto-beginning)
                 (line-end-position))))
    (cond
     ;; Nothing to show/hide.
     ((= end start))
     ;; Inlinetask was folded: expand it.
     ((and (not (eq state 'fold))
           (or (eq state 'unfold)
               (org-fold-get-folding-spec 'headline (1+ start))))
      (org-fold-region start end nil 'headline))
     (t (org-fold-region start end t 'headline)))))

(defun org-inlinetask-hide-tasks (state)
  "Hide inline tasks in buffer when STATE is `contents' or `children'.
This function is meant to be used in `org-cycle-hook'."
  (pcase state
    (`contents
     (let ((regexp (org-inlinetask-outline-regexp)))
       (save-excursion
	 (goto-char (point-min))
	 (while (re-search-forward regexp nil t)
	   (org-inlinetask-toggle-visibility 'fold)
	   (org-inlinetask-goto-end)))))
    (`children
     (save-excursion
       (while
	   (or (org-inlinetask-at-task-p)
	       (and (outline-next-heading) (org-inlinetask-at-task-p)))
	 (org-inlinetask-toggle-visibility 'fold)
	 (org-inlinetask-goto-end))))))

(defun org-inlinetask-remove-END-maybe ()
  "Remove an END line when present."
  (when (looking-at (format "\\([ \t]*\n\\)*\\*\\{%d,\\}[ \t]+END[ \t]*$"
			    org-inlinetask-min-level))
    (replace-match "")))

(add-hook 'org-font-lock-hook 'org-inlinetask-fontify)
(add-hook 'org-cycle-hook 'org-inlinetask-hide-tasks)

(provide 'org-inlinetask)

;;; org-inlinetask.el ends here
