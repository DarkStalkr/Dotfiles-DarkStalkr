;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Diego D.")
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-dracula)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Documentos/org/")

(after! org
  (setq org-agenda-files (list org-directory)))

;; Quick access to your new cheatsheet
(map! :leader
      :desc "Open Cheat Sheet" "o c" (lambda () (interactive) (find-file (expand-file-name "cheatsheet.org" org-directory))))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;(setq doom-font (font-spec :family "MesloLGMNerdFont" :size 18)
;;      doom-variable-pitch-font (font-spec :family "Ubuntu" :size 18)
;;      doom-big-font (font-spec :familiy "MesloLGMNerdFont" :size 32))


(setq doom-font (font-spec :family "Iosevka Nerd Font Mono" :size 20)
      doom-variable-pitch-font (font-spec :family "Iosevka Nerd Font Propo" :size 20)
      doom-big-font (font-spec :familiy "MesloLGMNerdFont" :size 32))



;; Adding Programming Languages Org Mode Support
(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python . t)
   (C . t)
   (shell . t)
   (go . t)
   (mermaid . t))) ;; Add this line here


;;Configure default shell for runnign code blocks
(setq org-babel-sh-command "/bin/bash")

;; Org-roam configuration
(after! org-roam
  (setq org-roam-directory "~/RoamNotes")

  ;; This adds the "Obsidian Graph" sync features
  (use-package! org-roam-ui
    :after org-roam
    :config
    (setq org-roam-ui-sync-theme t
          org-roam-ui-follow t
          org-roam-ui-update-on-save t
          org-roam-ui-open-on-start t))

  ;; Your existing bindings
  (map! :leader
        (:prefix ("n r" . "roam")
         :desc "Toggle buffer" "l" #'org-roam-buffer-toggle
         :desc "Find node" "f" #'org-roam-node-find
         :desc "Insert node" "i" #'org-roam-node-insert
         :desc "Open UI"     "u" #'org-roam-ui-mode)) ;; Added a shortcut for the Graph!

  (org-roam-db-autosync-mode))


;; Auto-render LaTeX fragments when cursor leaves
(use-package! org-fragtog
  :after org
  :hook (org-mode . org-fragtog-mode))

;; Obsidian-style hiding of markup (e.g. *bold* or _italics_)
(use-package! org-appear
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autoemphasis t
        org-appear-autolinks t
        org-appear-autosubmarkers t))

;; Make the rendered LaTeX larger and clearer on your Meslo font
(setq org-format-latex-options (plist-put org-format-latex-options :scale 1.5))

(after! org-pomodoro
  (setq org-pomodoro-length 15
        org-pomodoro-short-break-length 5))

;;; Atmosphere/Audio for Deep Focus
(defvar my/atmosphere-dir "/home/sohighman/.config/doom/media/audio/"
  "Directory where atmosphere sounds are stored.")

(defvar my/atmosphere-process nil
  "Holds the process of the currently playing sound.")

(defvar my/atmosphere-current-track nil
  "Currently playing track filename.")

(defun my/atmosphere-get-tracks ()
  "Get list of audio files in the atmosphere directory."
  (directory-files my/atmosphere-dir nil "\\.\\(mp3\\|wav\\|m4a\\|ogg\\)$"))

(defun my/play-atmosphere (sound)
  "Play a SOUND from the atmosphere directory on loop."
  (interactive
   (list (completing-read "Select sound: " (my/atmosphere-get-tracks))))
  (when (and my/atmosphere-process (process-live-p my/atmosphere-process))
    (kill-process my/atmosphere-process))
  (setq my/atmosphere-current-track sound)
  (let ((sound-file (expand-file-name sound my/atmosphere-dir)))
    (if (file-exists-p sound-file)
        (progn
          (setq my/atmosphere-process
                (start-process "mpv-atmosphere" nil "mpv" "--loop" "--no-video" sound-file))
          (message "Playing: %s" sound))
      (message "Sound file not found: %s" sound-file))))

(defun my/atmosphere-toggle ()
  "Toggle (Play/Pause) the atmosphere sound."
  (interactive)
  (if (and my/atmosphere-process (process-live-p my/atmosphere-process))
      (progn
        (process-send-string my/atmosphere-process "p") ;; mpv pause toggle
        (message "Atmosphere toggled (Play/Pause)"))
    (if my/atmosphere-current-track
        (my/play-atmosphere my/atmosphere-current-track)
      (call-interactively #'my/play-atmosphere))))

(defun my/atmosphere-next ()
  "Play the next track in the atmosphere directory."
  (interactive)
  (let* ((tracks (my/atmosphere-get-tracks))
         (current-index (cl-position my/atmosphere-current-track tracks :test #'string=))
         (next-index (if (and current-index (< (1+ current-index) (length tracks)))
                         (1+ current-index)
                       0)))
    (my/play-atmosphere (nth next-index tracks))))

(defun my/atmosphere-prev ()
  "Play the previous track in the atmosphere directory."
  (interactive)
  (let* ((tracks (my/atmosphere-get-tracks))
         (current-index (cl-position my/atmosphere-current-track tracks :test #'string=))
         (prev-index (if (and current-index (> current-index 0))
                         (1- current-index)
                       (1- (length tracks)))))
    (my/play-atmosphere (nth prev-index tracks))))

(defun my/stop-atmosphere ()
  "Stop the atmosphere sound completely."
  (interactive)
  (when (and my/atmosphere-process (process-live-p my/atmosphere-process))
    (kill-process my/atmosphere-process)
    (setq my/atmosphere-process nil)
    (message "Atmosphere sound stopped.")))

;; Keybindings for Atmosphere
(map! :leader
      (:prefix ("m" . "atmosphere")
       :desc "Play/Pause"  "SPC" #'my/atmosphere-toggle
       :desc "Next Track"  "n"   #'my/atmosphere-next
       :desc "Prev Track"  "p"   #'my/atmosphere-prev
       :desc "Select Track" "l"  #'my/play-atmosphere
       :desc "Stop"        "s"   #'my/stop-atmosphere))

;; EMMS configuration for cover art
(after! emms
  (require 'emms-setup)
  (emms-setup)
  (setq emms-player-list '(emms-player-simple))
  (setq emms-player-simple-command "mpv"))

(after! org
  ;; Register a custom file template for new Org-mode files
  ;; Use the "key" from the snippet file (org-template), not the filename
  (set-file-template! "\\.org$" :trigger "org-template" :mode 'org-mode))

;;; --- THEME CONFIGURATION ---
(setq catppuccin-flavor 'mocha) ;; 'mocha, 'macchiato, 'frappe, or 'latte

;; Quick Theme Picker Menu (SPC t t)
(map! :leader
      (:prefix ("t" . "theme")
       :desc "Load Theme (Vertico)" "t" #'load-theme ;; Standard theme picker for Vertico
       :desc "Catppuccin Mocha" "m" (lambda () (interactive) (setq catppuccin-flavor 'mocha) (load-theme 'catppuccin t))
       :desc "Catppuccin Latte" "l" (lambda () (interactive) (setq catppuccin-flavor 'latte) (load-theme 'catppuccin t))
       :desc "Dracula" "d" (lambda () (interactive) (load-theme 'doom-dracula t))))

(defun my/panic-save-all ()
  "Emergency save of all open buffers without prompting."
  (interactive)
  (save-some-buffers t)
  (message "PANIC: All buffers saved!"))

(map! :leader
      (:prefix ("q" . "quit/session")
       :desc "Panic Save All" "P" #'my/panic-save-all))

;;; --- KEYBINDINGS (Leader only: SPC y, SPC p, SPC x) ---
(map! :leader
      :desc "Copy" "y" #'evil-yank
      :desc "Paste" "p" #'evil-paste-after
      :desc "Cut" "x" #'evil-delete)

;;; --- Voice Notes / Audio Recording ---
(defvar my/recording-process nil "Current recording process.")
(defvar my/recording-file nil "Current recording file path.")

(defun my/org-record-toggle ()
  "Toggle audio recording using ffmpeg. Inserts a link at point when started."
  (interactive)
  (if (and my/recording-process (process-live-p my/recording-process))
      (progn
        ;; Gracefully stop ffmpeg by sending 'q'
        (process-send-string my/recording-process "q")
        ;; Wait a moment for it to finish writing
        (run-at-time "0.5 sec" nil (lambda () (setq my/recording-process nil)))
        (message "🔴 Recording stopped: %s" (file-name-nondirectory my/recording-file))
        (setq my/recording-file nil)
        (force-mode-line-update t))
    (let* ((dir (file-truename (expand-file-name "recordings/" org-directory)))
           (name (format-time-string "REC_%Y-%m-%d_%H%M%S.mp3"))
           (file (expand-file-name name dir))
           (source "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source"))
      (unless (file-exists-p dir) (make-directory dir t))
      (setq my/recording-file file)
      ;; Use a buffer (*ffmpeg-recording*) to catch errors
      (setq my/recording-process
            (start-process "ffmpeg-recording" "*ffmpeg-recording*"
                           "ffmpeg" "-y" "-f" "pulse" "-i" source
                           "-ac" "1" "-acodec" "libmp3lame" "-ab" "128k" (file-truename file)))
      (insert (format "[[file:%s][󰍬 Audio: %s]]" file name))
      (message "󰍬 Recording started... (Check *ffmpeg-recording* if it fails)")
      (force-mode-line-update t))))

;; Add a clickable Mic segment to the modeline
(after! doom-modeline
  (doom-modeline-def-segment my-recorder
    "Display a recording indicator. Clickable toggle."
    (let* ((active (and my/recording-process (process-live-p my/recording-process)))
           (icon (if active
                     (propertize " 󰍬 REC " 'face 'error)
                   (propertize " 󰍬 " 'face 'shadow))))
      (propertize icon
                  'help-echo "Click to Toggle Recording"
                  'mouse-face 'highlight
                  'local-map (let ((map (make-sparse-keymap)))
                               (define-key map [mode-line mouse-1] #'my/org-record-toggle)
                               map))))

  (doom-modeline-def-segment my-roam-ui-toggle
    "Display a graph icon to toggle org-roam-ui."
    (let* ((active (bound-and-true-p org-roam-ui-mode))
           (icon (if active
                     (propertize " 󱁉 " 'face 'success)
                   (propertize " 󱁉 " 'face 'shadow))))
      (propertize icon
                  'help-echo "Toggle Org-Roam Graph UI"
                  'mouse-face 'highlight
                  'local-map (let ((map (make-sparse-keymap)))
                               (define-key map [mode-line mouse-1] #'org-roam-ui-mode)
                               map))))

  (doom-modeline-def-segment my-spell-lang
    "Display current spellcheck language and click to toggle."
    (let* ((lang ispell-current-dictionary)
           (display-lang (if (string-match-p "es" (or lang "es")) " ES " " EN ")))
      (propertize (concat " 󰗊" display-lang)
                  'face (if (string-match-p "es" (or lang "es")) 'warning 'info)
                  'help-echo (format "Current Dict: %s. Click to toggle ES/EN" (or lang "es"))
                  'mouse-face 'highlight
                  'local-map (let ((map (make-sparse-keymap)))
                               (define-key map [mode-line mouse-1] #'my/toggle-spell-lang)
                               map))))

  ;; Redefine the 'main' modeline to include our new indicators
  (doom-modeline-def-modeline 'main
    '(bar window-number modals matches buffer-info remote-host buffer-position word-count parrot selection-info)
    '(my-spell-lang my-roam-ui-toggle my-recorder objed-state misc-info battery grip debug repl lsp minor-modes input-method indent-info buffer-encoding major-mode process vcs check)))

;; --- Spellcheck Language Toggle ---
(setq ispell-dictionary "es") ;; Default to Spanish

(defun my/toggle-spell-lang ()
  "Toggle between English and Spanish dictionaries for spellcheck."
  (interactive)
  (let* ((current ispell-current-dictionary)
         (new-dict (if (string-match-p "es" (or current "es")) "en_US" "es")))
    (ispell-change-dictionary new-dict)
    (message "Spellcheck language: %s" new-dict)
    (force-mode-line-update t)))

(map! :leader
      :desc "Toggle Spell Language" "t l" #'my/toggle-spell-lang)

;; Ensure Org-mode links for MP3s open in mpv (no video)
(after! org
  (add-to-list 'org-file-apps '("\\.mp3\\'" . "mpv --no-video %s")))

;; Binding for recording
(map! :leader
      :desc "Toggle Audio Recording" "n r r" #'my/org-record-toggle)


;;Org-Modern Config
;;(modify-all-frames-parameters
;; '((right-divider-width . 40)
 ;;  (internal-border-width . 40)))

;; Esto hace que los divisores sean invisibles (del mismo color que el fondo)
(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))

(set-face-background 'fringe (face-attribute 'default :background))

(after! org
  (setq org-auto-align-tags nil
        org-tags-column 0
        org-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t
        org-insert-heading-respect-content t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-ellipsis "…")) ; Usa el carácter de puntos suspensivos elegante


(use-package! org-modern
  :hook (org-mode . org-modern-mode)
  :config
  (setq org-modern-tag nil  ; Desactivado: el cursor desborda el highlight sobre todos los tags del heading
        org-modern-label-border 1
        org-auto-align-tags nil
        org-tags-column 0
        org-modern-todo t
        org-modern-keyword t)
  (global-org-modern-mode))

;; Fix: cursor de evil (bloque) desborda visualmente sobre los badges de TODO
;; Solución: cursor de barra en org-mode para evitar el overlap
(add-hook 'org-mode-hook
          (lambda ()
            (hl-line-mode -1)
            (setq-local evil-normal-state-cursor '(bar . 2))
            (setq-local evil-insert-state-cursor '(bar . 2))))
