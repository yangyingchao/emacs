;;; meson-ts-mode.el --- Meson's flying circus support for Emacs -*- lexical-binding: t -*-

;;; Code:

(require 'treesit)
(eval-when-compile
  (require 'rx))

(declare-function treesit-parser-create "treesit.c")
(declare-function treesit-query-capture "treesit.c")
(declare-function treesit-induce-sparse-tree "treesit.c")
(declare-function treesit-node-child "treesit.c")
(declare-function treesit-node-start "treesit.c")
(declare-function treesit-node-type "treesit.c")

(defcustom meson-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `meson-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'meson)

(defvar meson-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?$ "'" table)
    table)
  "Syntax table for `meson-ts-mode'.")

(defvar meson-ts-mode--indent-rules
  `((meson
     ((node-is ")") parent-bol 0)
     ((node-is "else_command") parent-bol 0)
     ((node-is "elseif_command") parent-bol 0)
     ((node-is "endforeach_command") parent-bol 0)
     ((node-is "endfunction_command") parent-bol 0)
     ((node-is "endif_command") parent-bol 0)
     ((parent-is "foreach_loop")
      parent-bol
      meson-ts-mode-indent-offset)
     ((parent-is "function_def")
      parent-bol
      meson-ts-mode-indent-offset)
     ((parent-is "if_condition")
      parent-bol
      meson-ts-mode-indent-offset)
     ((parent-is "normal_command")
      parent-bol
      meson-ts-mode-indent-offset)
     ;;; Release v0.4.0 wraps arguments in an argument_list node.
     ,@
     (ignore-errors
       (treesit-query-capture 'meson '((argument_list) @capture))
       `(((parent-is "argument_list")
          grand-parent
          meson-ts-mode-indent-offset)))
     ;;; Release v0.3.0 wraps the body of commands into a body node.
     ,@
     (ignore-errors
       (treesit-query-capture 'meson '((body) @capture))
       `(((parent-is "body")
          grand-parent
          meson-ts-mode-indent-offset)))))
  "Tree-sitter indent rules for `meson-ts-mode'.")

(defvar meson-ts-mode--constants
  '("1"
    "ON"
    "true"
    "YES"
    "Y"
    "0"
    "OFF"
    "FALSE"
    "NO"
    "N"
    "IGNORE"
    "NOTFOUND")
  "Meson constants for tree-sitter font-locking.")

(defconst meson--ts-builtin-vars '("meson" "build_machine" "host_machine" "target_machine"))

(defvar meson-ts-mode--foreach-options
  '("IN" "ITEMS" "LISTS" "RANGE" "ZIP_LISTS")
  "Meson foreach options for tree-sitter font-locking.")

(defvar meson--treesit-keywords
  '("true" "false" "and" "or" "not" "in" "in";; "continue" ;; "break"
    "if" "else" "elif" "endif" "foreach" "endforeach"))

(defvar meson--treesit-builtin-types
  '("int" "float" "complex" "bool" "list" "tuple" "range" "str"
    "boolean" "bytes" "bytearray" "memoryview" "dict"))

(defvar meson--treesit-type-regex
  (rx-to-string
   `(seq
     bol
     (or ,@meson--treesit-builtin-types
         (seq (?  "_") (any "A-Z") (+ (any "a-zA-Z_0-9"))))
     eol)))

(defvar meson--treesit-builtins
  (append
   meson--treesit-builtin-types
   '("add_global_arguments"
     "add_global_link_arguments"
     "add_languages"
     "add_project_arguments"
     "add_project_link_arguments"
     "add_test_setup"
     "alias_target"
     "assert"
     "benchmark"
     "both_libraries"
     "build_target"
     "configuration_data"
     "configure_file"
     "custom_target"
     "declare_dependency"
     "dependency"
     "disabler"
     "environment"
     "error"
     "executable"
     "files"
     "find_library"
     "find_program"
     "generator"
     "get_option"
     "get_variable"
     "gettext"
     "import"
     "include_directories"
     "install_data"
     "install_emptydir"
     "install_headers"
     "install_man"
     "install_subdir"
     "install_symlink"
     "is_disabler"
     "is_variable"
     "jar"
     "join_paths"
     "library"
     "message"
     "option"
     "project"
     "run_command"
     "run_target"
     "set_variable"
     "shared_library"
     "shared_module"
     "static_library"
     "subdir"
     "subdir_done"
     "subproject"
     "summary"
     "test"
     "vcs_tag"
     "warning")))

(defvar meson--treesit-constants
  '("Ellipsis"
    "False"
    "None"
    "NotImplemented"
    "True"
    "__debug__"
    "copyright"
    "credits"
    "exit"
    "license"
    "quit"))

(defvar meson--treesit-operators
  '("-" "-=" "!=" "*" "**" "**=" "*=" "/" "//" "//=" "/=" "&" "%" "%=" "^" "+"
    "->" "+=" "<" "<<" "<=" "<>" "=" ":=" "==" ">" ">=" ">>" "|" "~" "@" "@="))

(defvar meson--treesit-special-attributes
  '("__annotations__"
    "__closure__"
    "__code__"
    "__defaults__"
    "__dict__"
    "__doc__"
    "__globals__"
    "__kwdefaults__"
    "__name__"
    "__module__"
    "__package__"
    "__qualname__"
    "__all__"))

(defvar meson-ts-mode--font-lock-settings nil  "Vars")
(setq meson-ts-mode--font-lock-settings
  (treesit-font-lock-rules

   :feature 'comment
   :language 'meson
   '((comment) @font-lock-comment-face)

   :feature 'string
   :language 'meson
   '((string) @font-lock-string-face)


   :feature 'keyword
   :language 'meson
   `(([ ,@meson--treesit-keywords ]) @font-lock-keyword-face
     (keyword_break) @font-lock-keyword-face)

   :feature 'builtin
   :language
   'meson
   `(((identifier)
      @font-lock-builtin-face
      (:match
       ,(rx-to-string
         `(seq
           bol
           (or ,@meson--treesit-builtins ,@meson--treesit-special-attributes)
           eol))
       @font-lock-builtin-face)))

   ;; :feature 'decorator
   ;; :language
   ;; 'meson
   ;; '((decorator "@" @font-lock-type-face)
   ;;   (decorator (call function: (identifier) @font-lock-type-face))
   ;;   (decorator (identifier) @font-lock-type-face)
   ;;   (decorator
   ;;    [(attribute) (call (attribute))]
   ;;    @meson--treesit-fontify-dotted-decorator))

   ;; :feature 'function
   ;; :language
   ;; 'meson
   ;; '((call function: (identifier) @font-lock-function-call-face)
   ;;   (call
   ;;    function:
   ;;    (attribute
   ;;     attribute: (identifier) @font-lock-function-call-face)))

   ;; :feature 'constant
   ;; :language
   ;; 'meson
   ;; '([(true) (false) (none)] @font-lock-constant-face)

   :feature 'assignment
   :language
   'meson
   `( ;; Variable names and LHS.
     (operatorunit (identifier) @font-lock-variable-name-face)
     ;; (experession_statement object: (identifier)) @font-lock-variable-name-face
     ;; (assignment left: (identifier) @font-lock-variable-name-face)
     ;; (assignment
     ;;  left:
     ;;  (attribute
     ;;   attribute: (identifier) @font-lock-variable-name-face))
     ;; (augmented_assignment
     ;;  left: (identifier) @font-lock-variable-name-face)
     ;; (named_expression
     ;;  name: (identifier) @font-lock-variable-name-face)
     ;; (pattern_list
     ;;  [(identifier) (list_splat_pattern (identifier))]
     ;;  @font-lock-variable-name-face)
     ;; (tuple_pattern
     ;;  [(identifier) (list_splat_pattern (identifier))]
     ;;  @font-lock-variable-name-face)
     ;; (list_pattern
     ;;  [(identifier) (list_splat_pattern (identifier))]
     ;;  @font-lock-variable-name-face)
     )

   ;; :feature 'escape-sequence
   ;; :language 'meson
   ;; :override
   ;; t
   ;; '((escape_sequence) @font-lock-escape-face)

   ;; :feature 'number
   ;; :language
   ;; 'meson
   ;; '([(integer) (float)] @font-lock-number-face)

   ;; :feature 'property
   ;; :language
   ;; 'meson
   ;; '((attribute attribute: (identifier) @font-lock-property-use-face)
   ;;   (class_definition
   ;;    body:
   ;;    (block
   ;;     (expression_statement
   ;;      (assignment
   ;;       left: (identifier) @font-lock-property-use-face)))))

   ;; :feature 'operator
   ;; :language
   ;; 'meson
   ;; `([,@meson--treesit-operators] @font-lock-operator-face)

   ;; :feature 'bracket
   ;; :language
   ;; 'meson
   ;; '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face)

   ;; :feature 'delimiter
   ;; :language
   ;; 'meson
   ;; '(["," "." ":" ";" (ellipsis)] @font-lock-delimiter-face)

   ;; :feature 'variable
   ;; :language
   ;; 'meson
   ;; '((identifier) @meson--treesit-fontify-variable)

   ;; :language 'meson
   ;; :feature
   ;; 'bracket
   ;; '((["(" ")"]) @font-lock-bracket-face)

   ;; :language 'meson
   ;; :feature
   ;; 'constant
   ;; `(((argument)
   ;;    @font-lock-constant-face
   ;;    (:match
   ;;     ,(rx-to-string
   ;;       `(seq bol (or ,@meson-ts-mode--constants) eol))
   ;;     @font-lock-constant-face)))

   ;; :language 'meson
   ;; :feature
   ;; 'function
   ;; '((normal_command (identifier) @font-lock-function-call-face))

   ;; :language 'meson
   ;; :feature
   ;; 'number
   ;; '(((unquoted_argument)
   ;;    @font-lock-number-face
   ;;    (:match
   ;;     "\\`[[:digit:]]*\\.?[[:digit:]]*\\.?[[:digit:]]+\\'"
   ;;     @font-lock-number-face)))

   ;; :language 'meson
   ;; :feature 'escape-sequence
   ;; :override
   ;; t
   ;; '((escape_sequence) @font-lock-escape-face)

   ;; :language 'meson
   ;; :feature 'misc-punctuation
   ;; ;; Don't override strings.
   ;; :override
   ;; 'nil
   ;; '((["$" "{" "}" "<" ">"]) @font-lock-misc-punctuation-face)

   ;; :language 'meson
   ;; :feature 'variable
   ;; :override
   ;; t
   ;; '((variable) @font-lock-variable-use-face)

   ;; :language 'meson
   ;; :feature 'error
   ;; :override
   ;; t
   ;; '((ERROR) @font-lock-warning-face)
   ))

(defun meson-ts-mode--imenu ()
  "Return Imenu alist for the current buffer."
  (let* ((node (treesit-buffer-root-node))
         (func-tree
          (treesit-induce-sparse-tree node "function_def" nil 1000))
         (func-index (meson-ts-mode--imenu-1 func-tree)))
    (append
     (when func-index
       `(("Function" . ,func-index))))))

(defun meson-ts-mode--imenu-1 (node)
  "Helper for `meson-ts-mode--imenu'.
Find string representation for NODE and set marker, then recurse
the subtrees."
  (let* ((ts-node (car node))
         (children (cdr node))
         (subtrees (mapcan #'meson-ts-mode--imenu-1 children))
         (name
          (when ts-node
            (pcase (treesit-node-type ts-node)
              ("function_def" (treesit-node-text
                (treesit-node-child
                 (treesit-node-child ts-node 0) 2)
                t)))))
         (marker
          (when ts-node
            (set-marker (make-marker) (treesit-node-start ts-node)))))
    (cond
     ((or (null ts-node) (null name))
      subtrees)
     (subtrees
      `((,name ,(cons name marker) ,@subtrees)))
     (t
      `((,name . ,marker))))))

;;;###autoload
(define-derived-mode meson-ts-mode prog-mode  "Meson"
 "Major mode for editing Meson files, powered by tree-sitter."
 :group 'meson
 :syntax-table meson-ts-mode--syntax-table

 (when (treesit-ready-p 'meson)
   (treesit-parser-create 'meson)

   ;; Comments.
   (setq-local comment-start "# ")
   (setq-local comment-end "")
   (setq-local comment-start-skip (rx "#" (* (syntax whitespace))))

   ;; Imenu.
   (setq-local imenu-create-index-function #'meson-ts-mode--imenu)
   (setq-local which-func-functions nil)

   ;; Indent.
   (setq-local treesit-simple-indent-rules
               meson-ts-mode--indent-rules)

   ;; Font-lock.
   (setq-local treesit-font-lock-settings
               meson-ts-mode--font-lock-settings)
   (setq-local treesit-font-lock-feature-list
               '((comment definition)
                 (keyword string type)
                 (builtin constant escape-sequence function number variable
                  assignment decorator string-interpolation)
                 (bracket error misc-punctuation bracket delimiter function
                  operator property)))

   (treesit-major-mode-setup)))

(provide 'meson-ts-mode)

;;; meson-ts-mode.el ends here
