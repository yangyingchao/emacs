;;; image-dired-util.el --- util functions for Image-Dired  -*- lexical-binding: t -*-

;; Copyright (C) 2005-2025 Free Software Foundation, Inc.

;; Author: Mathias Dahl <mathias.rem0veth1s.dahl@gmail.com>
;; Maintainer: Stefan Kangas <stefankangas@gmail.com>
;; Package: image-dired

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

;; See the description of the `image-dired' package.

;;; Code:

(require 'xdg)
(eval-when-compile (require 'cl-lib))

(defvar image-dired-dir)
(defvar image-dired-thumb-naming)
(defvar image-dired-thumbnail-storage)

(defconst image-dired--thumbnail-standard-sizes
  '( standard standard-large
     standard-x-large standard-xx-large)
  "List of symbols representing thumbnail sizes in Thumbnail Managing Standard.")

(defvar image-dired-debug nil
  "Non-nil means enable debug messages.")

(defun image-dired-debug (&rest args)
  "Display debug message ARGS when `image-dired-debug' is non-nil."
  (when image-dired-debug
    (apply #'message args)))

(defun image-dired-dir ()
  "Return the current thumbnail directory (from variable `image-dired-dir').
Create the thumbnail directory if it does not exist."
  (let ((image-dired-dir
         (file-name-as-directory
          (expand-file-name image-dired-dir))))
    (unless (file-directory-p image-dired-dir)
      (with-file-modes #o700
        (make-directory image-dired-dir t))
      (message "Thumbnail directory created: %s" image-dired-dir))
    image-dired-dir))

(defun image-dired-contents-sha1 (filename)
  "Compute the SHA-1 of the first 4KiB of FILENAME's contents."
  (with-temp-buffer
    (insert-file-contents-literally filename nil 0 4096)
    (sha1 (current-buffer))))

(defun image-dired-thumb-name (file)
  "Return absolute file name for thumbnail FILE.
Depending on the value of `image-dired-thumbnail-storage' and
`image-dired-thumb-naming', the file name of the thumbnail will
vary:

- If `image-dired-thumbnail-storage' is set to one of the value
  of `image-dired--thumbnail-standard-sizes', produce the file
  name according to the Thumbnail Managing Standard.  Among other
  things, an MD5-hash of the image file's directory name will be
  added to the file name.

- Otherwise `image-dired-thumbnail-storage' is used to set the
  directory where to store the thumbnail.  In this latter case,
  if `image-dired-thumbnail-storage' is set to `image-dired' the
  file name given to the thumbnail depends on the value of
  `image-dired-thumb-naming'.

See also `image-dired-thumbnail-storage' and
`image-dired-thumb-naming'."
  (let ((file (expand-file-name file)))
    (if (memq image-dired-thumbnail-storage
              image-dired--thumbnail-standard-sizes)
        (let ((thumbdir (cl-case image-dired-thumbnail-storage
                          (standard "thumbnails/normal")
                          (standard-large "thumbnails/large")
                          (standard-x-large "thumbnails/x-large")
                          (standard-xx-large "thumbnails/xx-large"))))
          (expand-file-name
           ;; MD5 and PNG is mandated by the Thumbnail Managing
           ;; Standard.
           (concat (md5 (concat "file://" file)) ".png")
           (expand-file-name thumbdir (xdg-cache-home))))
      (let ((name (if (eq 'sha1-contents image-dired-thumb-naming)
                      (image-dired-contents-sha1 file)
                    ;; Defaults to SHA-1 of file name
                    (sha1 file))))
        (cond ((or (eq 'image-dired image-dired-thumbnail-storage)
                   ;; Maintained for backwards compatibility:
                   (eq 'use-image-dired-dir image-dired-thumbnail-storage))
               (expand-file-name (format "%s.jpg" name) (image-dired-dir)))
              ((eq 'per-directory image-dired-thumbnail-storage)
               (expand-file-name (format "%s.thumb.jpg"
                                         (file-name-nondirectory file))
                                 (expand-file-name
                                  ".image-dired"
                                  (file-name-directory file)))))))))

(defvar image-dired-thumbnail-buffer "*image-dired*"
  "Image-Dired's thumbnail buffer.")

(defvar image-dired-display-image-buffer "*image-dired-display-image*"
  "Where larger versions of the images are display.")

(defun image-dired-original-file-name ()
  "Get original file name for thumbnail or display image at point."
  (get-text-property (point) 'original-file-name))

(defun image-dired-file-name-at-point ()
  "Get abbreviated file name for thumbnail or display image at point."
  (when-let ((f (image-dired-original-file-name)))
    (abbreviate-file-name f)))

(defun image-dired-associated-dired-buffer ()
  "Get associated Dired buffer for thumbnail at point."
  (get-text-property (point) 'associated-dired-buffer))

(defmacro image-dired--with-dired-buffer (&rest body)
  "Run BODY in the Dired buffer associated with thumbnail at point.
Should be used by commands in `image-dired-thumbnail-mode'."
  (declare (indent defun) (debug t))
  (let ((file (make-symbol "file"))
        (dired-buf (make-symbol "dired-buf")))
    `(let ((,file (image-dired-original-file-name))
           (,dired-buf (image-dired-associated-dired-buffer)))
       (unless ,file
         (error "No image at point"))
       (unless (and ,dired-buf (buffer-live-p ,dired-buf))
         (error "Cannot find associated Dired buffer for image: %s" ,file))
       (with-current-buffer ,dired-buf
         ,@body))))

(defun image-dired-get-buffer-window (buf)
  "Return window where buffer BUF is."
  (get-window-with-predicate
   (lambda (window)
     (equal (window-buffer window) buf))
   nil t))

(defun image-dired-display-window ()
  "Return window where `image-dired-display-image-buffer' is visible."
  ;; This is obsolete as it is currently unused.  Once the window
  ;; handling gets a rethink, there may or may not be a need to
  ;; un-obsolete it again.
  (declare (obsolete nil "29.1"))
  (get-window-with-predicate
   (lambda (window)
     (equal (buffer-name (window-buffer window)) image-dired-display-image-buffer))
   nil t))

(defun image-dired-thumbnail-window ()
  "Return window where `image-dired-thumbnail-buffer' is visible."
  (get-window-with-predicate
   (lambda (window)
     (equal (buffer-name (window-buffer window)) image-dired-thumbnail-buffer))
   nil t))

(defun image-dired-associated-dired-buffer-window ()
  "Return window where associated Dired buffer is visible."
  ;; This is obsolete as it is currently unused.  Once the window
  ;; handling gets a rethink, there may or may not be a need to
  ;; un-obsolete it again.
  (declare (obsolete nil "29.1"))
  (let (buf)
    (if (image-dired-image-at-point-p)
        (progn
          (setq buf (image-dired-associated-dired-buffer))
          (get-window-with-predicate
           (lambda (window)
             (equal (window-buffer window) buf))))
      (error "No thumbnail image at point"))))

(defun image-dired-image-at-point-p ()
  "Return non-nil if there is an `image-dired' thumbnail at point."
  (get-text-property (point) 'image-dired-thumbnail))

(declare-function clear-image-cache "image.c" (&optional filter))

(defun image-dired-update-thumbnail-at-point ()
  "Update the thumbnail at point if the original image file has been modified.
This function uncaches and removes the thumbnail file under the old name."
  (when (image-dired-image-at-point-p)
    (let* ((file (image-dired-original-file-name))
           (thumb (expand-file-name (image-dired-thumb-name file)))
           (image (get-text-property (point) 'display)))
      (when image
        (let ((old-thumb (plist-get (cdr image) :file)))
          ;; When 'image-dired-thumb-naming' is set to
          ;; 'sha1-contents', 'thumb' and 'old-thumb' could be
          ;; different file names.  Update the thumbnail then.
          (unless (string= thumb old-thumb)
            (setf (plist-get (cdr image) :file) thumb)
            (clear-image-cache old-thumb)
            (delete-file old-thumb)))))))

(defun image-dired-window-width-pixels (window)
  "Calculate WINDOW width in pixels."
  (declare (obsolete window-body-width "29.1"))
  (* (window-width window) (frame-char-width)))

(provide 'image-dired-util)

;;; image-dired-util.el ends here
