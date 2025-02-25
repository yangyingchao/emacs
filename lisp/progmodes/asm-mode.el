;;; asm-mode.el --- mode for editing assembler code  -*- lexical-binding: t; -*-

;; Copyright (C) 1991, 2001-2025 Free Software Foundation, Inc.

;; Author: Eric S. Raymond <esr@thyrsus.com>
;; Maintainer: emacs-devel@gnu.org
;; Keywords: languages

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

;;; Commentary:

;; This mode was written by Eric S. Raymond <esr@thyrsus.com>,
;; inspired by an earlier `asm-mode' by Martin Neitzel.

;; This major mode is based on `prog-mode'.  It defines a private
;; abbrev table that can be used to save abbrevs for assembler
;; mnemonics.  It binds just five keys:
;;
;;	TAB		tab to next tab stop
;;	:		outdent preceding label, tab to tab stop
;;	comment char	place or move comment
;;			`asm-comment-char' specifies which character this is;
;;			you can use a different character in different
;;			Asm mode buffers.
;;	C-j, C-m	newline and tab to tab stop
;;
;; Code is indented to the first tab stop level.

;; This mode runs two hooks:
;;   1) `asm-mode-set-comment-hook' before the part of the initialization
;;      depending on `asm-comment-char', and
;;   2) `asm-mode-hook' at the end of initialization.

;;; Code:

(defgroup asm nil
  "Mode for editing assembler code."
  :link '(custom-group-link :tag "Font Lock Faces group" font-lock-faces)
  :group 'languages)

(defun asm--safe-comment-char-p (char)
  (memq char '(?\; ?# ?@)))

(defcustom asm-comment-char ?\;
  "The `comment-start' character assumed by Asm mode."
  :type 'character
  :safe #'asm--safe-comment-char-p)

(defvar asm-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?/  ". 124b" st)
    (modify-syntax-entry ?*  ". 23" st)
    st)
  "Syntax table used while in Asm mode.")

(defvar asm-mode-abbrev-table nil
  "Abbrev table used while in Asm mode.")
(define-abbrev-table 'asm-mode-abbrev-table ())

(defvar-keymap asm-mode-map
  :doc "Keymap for Asm mode."
  ;; Note that the comment character isn't set up until asm-mode is called.
  ":"     #'asm-colon
  "C-c ;" #'comment-region)

(easy-menu-define asm-mode-menu asm-mode-map
  "Menu for Asm mode."
  '("Asm"
    ["Insert Colon" asm-colon
     :help "Insert a colon; if it follows a label, delete the label's indentation"]
    ["Insert Newline and Indent" newline-and-indent
     :help "Insert a newline, then indent according to major mode"]
    ["Comment Region" comment-region
     :help "Comment or uncomment each line in the region"]))

(defconst asm-font-lock-keywords
  (append
   '(("^\\(\\(\\sw\\|\\s_\\)+\\)\\>:?[ \t]*\\(\\sw+\\(\\.\\sw+\\)*\\)?"
      (1 font-lock-function-name-face) (3 font-lock-keyword-face nil t))
     ;; label started from ".".
     ("^\\(\\.\\(\\sw\\|\\s_\\)+\\)\\>:"
      1 font-lock-function-name-face)
     ("^\\((\\sw+)\\)?\\s +\\(\\(\\.?\\sw\\|\\s_\\)+\\(\\.\\sw+\\)*\\)"
      2 font-lock-keyword-face)
     ;; directive started from ".".
     ("^\\(\\.\\(\\sw\\|\\s_\\)+\\)\\>[^:]?"
      1 font-lock-keyword-face)
     ;; %register
     ("%\\sw+" . font-lock-variable-name-face))
   cpp-font-lock-keywords)
  "Additional expressions to highlight in Assembler mode.")

;;;###autoload
(define-derived-mode asm-mode prog-mode "Assembler"
  "Major mode for editing typical assembler code.
Features a private abbrev table and the following bindings:

\\[asm-colon]\toutdent a preceding label, tab to next tab stop.
\\[tab-to-tab-stop]\ttab to next tab stop.
\\[newline-and-indent]\tnewline, then tab to next tab stop.
\\[asm-comment]\tsmart placement of assembler comments.

The character used for making comments is set by the variable
`asm-comment-char' (which defaults to `?\\;').

Alternatively, you may set this variable in `asm-mode-set-comment-hook',
which is called near the beginning of mode initialization.

Turning on Asm mode runs the hook `asm-mode-hook' at the end of initialization.

Special commands:
\\{asm-mode-map}"
  (setq local-abbrev-table asm-mode-abbrev-table)
  (setq-local font-lock-defaults '(asm-font-lock-keywords))
  (setq-local indent-line-function #'asm-indent-line)
  ;; Stay closer to the old TAB behavior (was tab-to-tab-stop).
  (setq-local tab-always-indent nil)

  (run-hooks 'asm-mode-set-comment-hook)
  ;; Make our own local child of `asm-mode-map'
  ;; so we can define our own comment character.
  (use-local-map (nconc (make-sparse-keymap) asm-mode-map))
  (local-set-key (vector asm-comment-char) #'asm-comment)
  (set-syntax-table (make-syntax-table asm-mode-syntax-table))
  (modify-syntax-entry	asm-comment-char "< b")

  (setq-local comment-start (string asm-comment-char))
  (setq-local comment-add 1)
  (setq-local comment-start-skip "\\(?:\\s<+\\|/[/*]+\\)[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(\\s>\\|\\*+/\\)")
  (setq-local comment-end ""))

(defun asm-indent-line ()
  "Auto-indent the current line."
  (interactive)
  (let* ((savep (point))
	 (indent (condition-case nil
		     (save-excursion
		       (forward-line 0)
		       (skip-chars-forward " \t")
		       (if (>= (point) savep) (setq savep nil))
		       (max (asm-calculate-indentation) 0))
		   (error 0))))
    (if savep
	(save-excursion (indent-line-to indent))
      (indent-line-to indent))))

(defun asm-calculate-indentation ()
  (or
   ;; Flush labels to the left margin.
   (and (looking-at "\\(\\sw\\|\\s_\\)+:") 0)
   ;; Same thing for `;;;' comments.
   (and (looking-at "\\s<\\s<\\s<") 0)
   ;; Simple `;' comments go to the comment-column.
   (and (looking-at "\\s<\\(\\S<\\|\\'\\)") comment-column)
   ;; The rest goes at the first tab stop.
   (indent-next-tab-stop 0)))

(defun asm-colon ()
  "Insert a colon; if it follows a label, delete the label's indentation."
  (interactive)
  (let ((labelp nil))
    (save-excursion
      (skip-syntax-backward "w_")
      (skip-syntax-backward " ")
      (if (setq labelp (bolp)) (delete-horizontal-space)))
    (call-interactively 'self-insert-command)
    (when labelp
      (delete-horizontal-space)
      (tab-to-tab-stop))))

(define-obsolete-function-alias 'asm-newline #'newline-and-indent "27.1")

(defun asm-comment ()
  "Convert an empty comment to a `larger' kind, or start a new one.
These are the known comment classes:

   1 -- comment to the right of the code (at the `comment-column')
   2 -- comment on its own line, indented like code
   3 -- comment on its own line, beginning at the left-most column.

Suggested usage:  while writing your code, trigger asm-comment
repeatedly until you are satisfied with the kind of comment."
  (interactive)
  (comment-normalize-vars)
  (let (comempty comment)
    (save-excursion
      (beginning-of-line)
      (with-no-warnings
	(setq comment (comment-search-forward (line-end-position) t)))
      (setq comempty (looking-at "[ \t]*$")))

  (cond

   ;; Blank line?  Then start comment at code indent level.
   ;; Just like `comment-dwim'.  -stef
   ((save-excursion (beginning-of-line) (looking-at "^[ \t]*$"))
    (indent-according-to-mode)
    (insert asm-comment-char asm-comment-char ?\ ))

   ;; Nonblank line without comment => start a comment at comment-column.
   ;; Also: point before the comment => jump inside.
   ((or (null comment) (< (point) comment))
    (indent-for-comment))

   ;; Flush-left or non-empty comment present => just insert character.
   ((or (not comempty) (save-excursion (goto-char comment) (bolp)))
    (insert asm-comment-char))

   ;; Empty code-level comment => upgrade to next comment level.
   ((save-excursion (goto-char comment) (skip-chars-backward " \t") (bolp))
    (goto-char comment)
    (insert asm-comment-char)
    (indent-for-comment))

   ;; Empty comment ends non-empty code line => new comment above.
   (t
    (goto-char comment)
    (skip-chars-backward " \t")
    (delete-region (point) (line-end-position))
    (beginning-of-line) (insert "\n") (backward-char)
    (asm-comment)))))

(provide 'asm-mode)

;;; asm-mode.el ends here
