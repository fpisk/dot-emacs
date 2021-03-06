;;; init-eshell.el --- Initialize eshell
;; -----------------------------------------------------------------------------

(add-to-list 'Info-directory-list
             (expand-file-name "~/.emacs.d/packages/eshell/doc") t)

;; -----------------------------------------------------------------------------
;;; Support for multiple shells and convenient switching
(require 'multi-eshell)

;;;  Function to create an multi-eshell in a new frame
(defun multi-eshell-frame ()
  "Create a new eshell in a new frame."
  (interactive)
  (select-frame (make-frame))
  (multi-eshell 1))

;; -----------------------------------------------------------------------------
;;; Apply elisp sexp editing sugar
;(require 'highlight-parentheses)
;(require 'paredit)

;; -----------------------------------------------------------------------------
;;; Set the list of modules to be loaded
(setq eshell-modules-list
      '(eshell-alias
        eshell-basic
        eshell-cmpl
        eshell-dirs
        eshell-glob
        eshell-hist
        eshell-ls
        eshell-pred
        eshell-prompt
        eshell-script
        eshell-smart
        eshell-term
        eshell-unix
        eshell-last
        eshell-xtra
        ))

;;;  Pre-load the modules
(require 'em-alias)
(require 'em-basic)
(require 'em-cmpl)
(require 'em-dirs)
(require 'em-glob)
(require 'em-hist)
(require 'em-ls)
(require 'em-pred)
(require 'em-prompt)
(require 'em-script)
(require 'em-term)
(require 'em-unix)
(require 'esh-opt)

;;;  Provides the plan9 style scrolling
(require 'em-smart)

;;;  Additional module which provides access to
;;  previous command arguments using `C-c .', or `M-.'
(require 'em-last)

;;;  Extra alias functions
(require 'em-xtra)

;; -----------------------------------------------------------------------------
;;; Configure pcomplete for various completions
(require 'pcomplete)

(setq multi-eshell-shell-function '(eshell)
      multi-eshell-name "*eshell*"
      eshell-directory-name (expand-file-name "~/Emacs/Eshell/")
      eshell-aliases-file (concat eshell-directory-name "alias")
      eshell-history-file-name (concat eshell-directory-name "history")
      eshell-save-history-on-exit t
      eshell-hist-ignoredups t
      eshell-prefer-lisp-functions t
      eshell-scroll-to-bottom-on-input t
      eshell-buffer-shorthand t

      eshell-show-lisp-completions nil
      eshell-cmpl-expand-before-complete t
      eshell-cmpl-cycle-completions t
      eshell-cmpl-cycle-cutoff-length 5

      shell-prompt-pattern "^[^)>]*[)>] "
      eshell-prompt-regexp shell-prompt-pattern
      eshell-prompt-function
      (lambda ()
        (if (or (= (user-uid) 0)
                (string-match "^/su\\(do\\)?:" default-directory))
            (format "MrBig<%d> " (ring-length eshell-history-ring))
          (format "%s(%d) "
                  (getenv "HOSTNAME") (ring-length eshell-history-ring))
          ))
      )

;; -----------------------------------------------------------------------------
;;; Add support for easy switching between edit and eshell windows
(require 'esh-toggle)
(global-set-key [(control meta ?1)] 'eshell-toggle-cd)

;; -----------------------------------------------------------------------------
;;; Setup tooltip-help for the eshell (for elisp expressions only)
(require 'tooltip-help)
(setq th-max-tooltip-lines 30)

(defun th-eshell-mode-handler ()
  "Set the tooltip-help handler for the eshell mode to that for elisp."
  (th-emacs-lisp-mode-handler))

;; -----------------------------------------------------------------------------
;;; Set eshell-mode hook
(defun my-eshell-mode-hook ()
  "Hook to apply my setting to the lisp and elisp modes"

  (turn-on-eldoc-mode)
  (defadvice eldoc-fnsym-in-current-sexp
    (around eldoc-fnsym-in-current-sexp-or-command activate)
    ad-do-it
    (if (and (not ad-return-value)
             (eq major-mode 'eshell-mode))
        (save-excursion
          (goto-char eshell-last-output-end)
          (setq ad-return-value (eldoc-current-symbol)))))

  (local-set-key (kbd "C-z") 'bury-buffer)
  (local-set-key (kbd "C-a") 'eshell-bol)
  (local-set-key [end] 'eshell-show-maximum-output)
  (local-set-key [home] 'eshell-previous-prompt)
  (local-set-key [up] 'previous-line)
  (local-set-key [down] 'next-line)
  (local-set-key [f1] 'th-show-help)
  (local-set-key [S-f1] 'describe-variable-or-function)
  (local-set-key [(meta ?.)] 'eshell-insert-previous-argument)

  ;; Switch on the completion selection mode
  ;; and set the default completion-selection to pcomplete
  (completion-selection-mode t)
  (completion-selection-set 'complete-pcomplete)

  (local-set-key [(control ?\.)]
   (lambda ()
     "Call `completion-selection-select-complete' for the
`pcomplete' completion mechanism."
     (interactive)
     (completion-selection-set-complete 'complete-pcomplete)))

  (define-key completion-overlay-map [(control ?c)]
    (lambda ()
      "For eshell-mode call the `eshell-interrupt-process' command
  after rejecting the completion"
      (interactive)
      (completion-reject)
      (if (eq major-mode 'eshell-mode)
          (eshell-interrupt-process))))

  ;(show-matching-paren)
  ;(highlight-parentheses-mode t)
  ;(paredit-mode +1)
  ;(setq paredit-add-space-for-delimiter nil)
  )

(add-hook 'eshell-mode-hook 'my-eshell-mode-hook)

;; -----------------------------------------------------------------------------
;;; Generally useful additional functions
(defun eshell/dired ()
  "Display `dired' on the current directory"
  (dired (eshell/pwd)))

(defun eshell/clear ()
  "Clear the eshell buffer."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)))

(defun eshell/tsh (machine)
  "Create an ssh connection to MACHINE in the current directory using `tramp'."
  (eshell/cd
   (concat "/" machine ":" (car (last (split-string (eshell/pwd) ":"))))))

(defun eshell/sb (&rest args)
  "Switch to given buffer."
  (funcall 'switch-to-buffer (apply 'eshell-flatten-and-stringify args)))

(defun pcomplete/sb ()
  "Completion for sb (switch-to-buffer)."
  (while (pcomplete-here (mapcar 'buffer-name (buffer-list)))))

(defun eshell/ec (&rest args)
  "Use `compile' to do background makes."
  (if (eshell-interactive-output-p)
      (let ((compilation-process-setup-function
             (list 'lambda nil
                   (list 'setq 'process-environment
                         (list 'quote (eshell-copy-environment))))))
        (compile (eshell-flatten-and-stringify args))
        (pop-to-buffer compilation-last-buffer))
    (throw 'eshell-replace-command
           (let ((l (eshell-stringify-list (eshell-flatten-list args))))
             (eshell-parse-command (car l) (cdr l))))))
(put 'eshell/ec 'eshell-no-numeric-conversions t)

(defun eshell-view-file (file)
  "A version of `view-file' which properly respects the eshell prompt."
  (interactive "fView file: ")
  (unless (file-exists-p file) (error "%s does not exist" file))
  (let ((had-a-buf (get-file-buffer file))
        (buffer (find-file-noselect file)))
    (if (eq (with-current-buffer buffer (get major-mode 'mode-class))
            'special)
        (progn
          (switch-to-buffer buffer)
          (message "Not using View mode because the major mode is special"))
      (let ((undo-window (list (window-buffer) (window-start)
                               (+ (window-point)
                                  (length (funcall eshell-prompt-function))))))
        (switch-to-buffer buffer)
        (view-mode-enter (cons (selected-window) (cons nil undo-window))
                         'kill-buffer)))))

(defun eshell/less (&rest args)
  "Invoke `view-file' on a file. \"less +42 foo\" will go to line 42 in
the buffer for foo."
  (while args
    (if (string-match "\\`\\+\\([0-9]+\\)\\'" (car args))
        (let* ((line (string-to-number (match-string 1 (pop args))))
               (file (pop args)))
          (eshell-view-file file)
          (goto-line line))
      (eshell-view-file (pop args)))))

(defalias 'eshell/more 'eshell/less)

(eval-after-load "em-ls"
  '(progn
     (let ((map (make-sparse-keymap)))
       (define-key map (kbd "<return>") 'find-file-at-point)
       (define-key map (kbd "<mouse-2>") 'ffap-at-mouse)
       (defvar eshell-ls-keymap map))

     (defadvice eshell-ls-decorated-name (after electrify-ls activate)
       "Eshell's `ls' now lets you click or RET on file names to open them."
       (add-text-properties 0 (length ad-return-value)
                            (list 'help-echo "RET, mouse-2: visit this file"
                                  'mouse-face 'highlight
                                  'keymap eshell-ls-keymap)
                            ad-return-value)
       ad-return-value)))

(defun pcomplete/eshell-mode/bmk ()
  "Completion for `bmk'"
  (pcomplete-here (bookmark-all-names)))

(defun eshell/bmk (&rest args)
  "Integration between EShell and bookmarks.
For usage, execute without arguments."
  (setq args (eshell-flatten-list args))
  (let ((bookmark (car args))
        filename name)
    (cond
     ((eq nil args)
      (format "Usage: bmk BOOKMARK to change directory pointed to by BOOKMARK
    or bmk . BOOKMARK to bookmark current directory in BOOKMARK.
Completion is available."))
     ((string= "." bookmark)
      ;; Store current path in EShell as a bookmark
      (if (setq name (car (cdr args)))
          (progn
            (bookmark-set name)
            (bookmark-set-filename name (eshell/pwd))
            (format "Saved current directory in bookmark %s" name))
        (error "You must enter a bookmark name")))
     (t
      ;; Assume the user wants to go to the path pointed out by a bookmark.
      (if (setq filename (cdr (car (bookmark-get-bookmark-record bookmark))))
          (if (file-directory-p filename)
              (eshell/cd filename)
            ;; TODO: Handle this better and offer to go to directory
            ;; where the file is located.
            (error "Bookmark %s points to %s which is not a directory"
                   bookmark filename))
        (error "%s is not a bookmark" bookmark))))))

(defun my-eshell-execute-current-line ()
  "Insert text of current line in eshell and execute."
  (interactive)
  (require 'eshell)
  (let ((command
         (buffer-substring
          (save-excursion (beginning-of-line) (point))
          (save-excursion (end-of-line)(point)))))
    (let ((buf (current-buffer)))
      (unless (get-buffer eshell-buffer-name)
        (eshell))
      (display-buffer eshell-buffer-name t)
      (switch-to-buffer-other-window eshell-buffer-name)
      (goto-char (point-max))
      (eshell-kill-input)
      (insert command)
      (eshell-send-input)
      (goto-char (point-max))
      (switch-to-buffer-other-window buf))))

;;(global-set-key [f2] 'my-eshell-execute-current-line)

(defun eshell/deb (&rest args)
  (eshell-eval-using-options
   "deb" args
   '((?f "find" t find "list available packages matching a pattern")
     (?i "installed" t installed "list installed debs matching a pattern")
     (?l "list-files" t list-files "list files of a package")
     (?s "show" t show "show an available package")
     (?v "version" t version "show the version of an installed package")
     (?w "where" t where "find the package containing the given file")
     (nil "help" nil nil "show this usage information")
     :show-usage)
   (eshell-do-eval
    (eshell-parse-command
     (cond
      (find
       (format "apt-cache search %s" find))
      (installed
       (format "dlocate -l %s | grep '^.i'" installed))
      (list-files
       (format "dlocate -L %s | sort" list-files))
      (show
       (format "apt-cache show %s" show))
      (version
       (format "dlocate -s %s | egrep '^(Package|Status|Version):'" version))
      (where
       (format "dlocate %s" where))))
    t)))

;; -----------------------------------------------------------------------------
;;; init-eshell.el ends here
