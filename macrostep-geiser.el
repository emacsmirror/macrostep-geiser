;;; macrostep-geiser.el --- Macrostep for `geiser' -*- lexical-binding: t -*-

;; Copyright (C) 2021  Nikita Bloshchanevich <nikblos@outlook.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Author: Nikita Bloshchanevich
;; URL: https://github.com/nbfalcon/macrostep-geiser
;; Keywords: languages, scheme
;; Version: 0.9
;; Package-Requires: ((emacs "24.4") (macrostep "0.9") (geiser "0.12"))

;;; Commentary:

;; Provides `macrostep' support for scheme by leveraging `geiser'.
;;
;; To enable `macrostep' in `geiser-mode' buffer, execute
;; `macrostep-geiser-setup'. The latter function can be added to
;; `geiser-mode-hook' and `geiser-repl-mode-hook':
;;
;; (eval-after-load 'geiser-mode '(add-hook 'geiser-mode-hook #'macrostep-geiser-setup))
;; (eval-after-load 'geiser-repl '(add-hook 'geiser-repl-mode-hook #'macrostep-geiser-setup))
;;
;; Or, using `use-package':
;;
;; (use-package macrostep-geiser
;;   :after geiser-mode
;;   :config (add-hook 'geiser-mode-hook #'macrostep-geiser-setup))

;; (use-package macrostep-geiser
;;   :after geiser-repl
;;   :config (add-hook 'geiser-repl-mode-hook #'macrostep-geiser-setup))

;;; Code:

(require 'subr-x)

(require 'geiser-eval)

;;; declarations

(declare-function macrostep-expand "macrostep" (&optional arg))

(defvar macrostep-macro-form-p-function)
(defvar macrostep-sexp-at-point-function)
(defvar macrostep-expand-1-function)
(defvar macrostep-print-function)
(defvar macrostep-environment-at-point-function)

;;; macrostep functions

(defun macrostep-geiser-macro-form-p (_sexp _env)
  "`macrostep-macro-form-p' for `geiser'."
  ;; `geiser' doesn't expose a way to check if a form is macro; the macroexpand
  ;; command expands even non-macro forms, yielding (%app ...).
  t)

(defun macrostep-geiser-sexp-at-point (&optional start end)
  "`macrostep-sexp-at-point-function' for `geiser'.
START and END are the bounds returned by
`macrostep-sexp-bounds', defaulting to the sexp after `point'."
  (buffer-substring-no-properties (or start (point)) (or end (scan-lists (point) 1 0))))

(define-minor-mode macrostep-geiser-expand-all-mode
  "Make `macrostep-geiser' expand macros recursively."
  :init-value nil
  :lighter nil)

(defun macrostep-geiser-expand-1 (str &optional _env)
  "Expand one level of STR using `geiser'.
STR is the macro form as a string."
  (let* ((ret (geiser-eval--send/wait
               `(:eval (:ge macroexpand (quote (:scm ,str))
                        ,(if macrostep-geiser-expand-all-mode :t :f)))))
         (err (geiser-eval--retort-error ret))
         (res (geiser-eval--retort-result ret)))
    (when err
      (user-error "Macro expansion failed: %s" err))
    (let* ((res (string-remove-prefix "'" (string-trim-right res)))
           ;; Adjust indentation: for each line, unindent by a space, since
           ;; we've removed a quote; then indent by how far away we are from the
           ;; start of the line.
           (res (replace-regexp-in-string
                 "^ " (make-string (current-column) ?\ ) res t t)))
      (when (string= str res)
        (user-error "Final macro expansion"))
      res)))

(defun macrostep-geiser-expand-all (&optional arg)
  "Recursively expand the macro at `point'.
Only works with `geiser'. ARG is passed to `macrostep-expand'."
  (interactive "P")
  (let ((macrostep-geiser-expand-all-mode t))
    (macrostep-expand arg)))

(defface macrostep-geiser-expanded-text-face '((t :inherit macrostep-expand-text))
  "Face used for `macrostep-geiser' expansions."
  :group 'macrostep-geiser)

(defun macrostep-geiser-print (expanded &rest _)
  "`macrostep-print-function' for `geiser'.
EXPANDED is the return value of `macrostep-geiser-expand-1'."
  (insert (propertize expanded 'face 'macrostep-geiser-expanded-text-face)))


;;;###autoload
(defun macrostep-geiser-setup ()
  "Set-up `macrostep' to use `geiser'."
  (interactive)
  (setq-local macrostep-macro-form-p-function #'macrostep-geiser-macro-form-p
              macrostep-sexp-at-point-function #'macrostep-geiser-sexp-at-point
              macrostep-expand-1-function #'macrostep-geiser-expand-1
              macrostep-print-function #'macrostep-geiser-print
              macrostep-environment-at-point-function #'ignore))

(provide 'macrostep-geiser)
;;; macrostep-geiser.el ends here
