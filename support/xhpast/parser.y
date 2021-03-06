/*
 * Copyright 2011 Facebook, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

%{
/*
 * If you modify this grammar, please update the version number in
 * ./xhpast.cpp and libphutil/src/parser/xhpast/bin/xhpast_parse.php
 */
 
#include "ast.hpp"
#include "node_names.hpp"
// PHP's if/else rules use right reduction rather than left reduction which
// means while parsing nested if/else's the stack grows until it the last
// statement is read. This is annoying, particularly because of a quirk in
// bison.
// http://www.gnu.org/software/bison/manual/html_node/Memory-Management.html
// Apparently if you compile a bison parser with g++ it can no longer grow
// the stack. The work around is to just make your initial stack ridiculously
// large. Unfortunately that increases memory usage while parsing which is
// dumb. Anyway, putting a TODO here to fix PHP's if/else grammar.
#define YYINITDEPTH 500
%}

%{
#undef yyextra
#define yyextra static_cast<yy_extra_type*>(xhpastget_extra(yyscanner))
#undef yylineno
#define yylineno yyextra->first_lineno
#define push_state(s) xhp_new_push_state(s, (struct yyguts_t*) yyscanner)
#define pop_state() xhp_new_pop_state((struct yyguts_t*) yyscanner)
#define set_state(s) xhp_set_state(s, (struct yyguts_t*) yyscanner)

#define NNEW(t) \
  (new xhpast::Node(t))

#define NTYPE(n, type) \
  ((n)->setType(type))

#define NMORE(n, end) \
  ((n)->setEnd(end))

#define NSPAN(n, type, end) \
  (NMORE(NTYPE((n), type), end))

#define NLMORE(n, begin) \
  ((n)->setBegin(begin))

#define NEXPAND(l, n, r) \
  ((n)->setBegin(l)->setEnd(r))

using namespace std;

static void yyerror(void* yyscanner, void* _, const char* error) {
  if (yyextra->terminated) {
    return;
  }
  yyextra->terminated = true;
  yyextra->error = error;
}

/*

TODO: Restore this.

static void replacestr(string &source, const string &find, const string &rep) {
  size_t j;
  while ((j = source.find(find)) != std::string::npos) {
    source.replace(j, find.length(), rep);
  }
}
*/

%}

%expect 9
// 2: PHP's if/else grammar
// 7: expr '[' dim_offset ']' -- shift will default to first grammar
%name-prefix = "xhpast"
%pure-parser
%parse-param { void* yyscanner }
%parse-param { xhpast::Node** root }
%lex-param { void* yyscanner }
%error-verbose

%left T_INCLUDE T_INCLUDE_ONCE T_EVAL T_REQUIRE T_REQUIRE_ONCE
%left ','
%left T_YIELD
%left T_LOGICAL_OR
%left T_LOGICAL_XOR
%left T_LOGICAL_AND
%right T_PRINT
%left '=' T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL
%left '?' ':'
%left T_BOOLEAN_OR
%left T_BOOLEAN_AND
%left '|'
%left '^'
%left '&'
%nonassoc T_IS_EQUAL T_IS_NOT_EQUAL T_IS_IDENTICAL T_IS_NOT_IDENTICAL
%nonassoc '<' T_IS_SMALLER_OR_EQUAL '>' T_IS_GREATER_OR_EQUAL
%left T_SL T_SR
%left '+' '-' '.'
%left '*' '/' '%'
%right '!'
%nonassoc T_INSTANCEOF
%right '~' T_INC T_DEC T_INT_CAST T_DOUBLE_CAST T_STRING_CAST T_UNICODE_CAST T_BINARY_CAST T_ARRAY_CAST T_OBJECT_CAST T_BOOL_CAST T_UNSET_CAST '@'
%right '['
%nonassoc T_NEW T_CLONE
%token T_EXIT
%token T_IF
%left T_ELSEIF
%left T_ELSE
%left T_ENDIF

%token T_LNUMBER
%token T_DNUMBER
%token T_STRING
%token T_STRING_VARNAME /* unused in XHP: `foo` in `"$foo"` */
%token T_VARIABLE
%token T_NUM_STRING /* unused in XHP: `0` in `"$foo[0]"` */
%token T_INLINE_HTML
%token T_CHARACTER /* unused in vanilla PHP */
%token T_BAD_CHARACTER /* unused in vanilla PHP */
%token T_ENCAPSED_AND_WHITESPACE /* unused in XHP: ` ` in `" "` */
%token T_CONSTANT_ENCAPSED_STRING /* overloaded in XHP; replaces '"' encaps_list '"' */
%token T_BACKTICKS_EXPR /* new in XHP; replaces '`' backticks_expr '`' */
%token T_ECHO
%token T_DO
%token T_WHILE
%token T_ENDWHILE
%token T_FOR
%token T_ENDFOR
%token T_FOREACH
%token T_ENDFOREACH
%token T_DECLARE
%token T_ENDDECLARE
%token T_AS
%token T_SWITCH
%token T_ENDSWITCH
%token T_CASE
%token T_DEFAULT
%token T_BREAK
%token T_CONTINUE
%token T_GOTO
%token T_FUNCTION
%token T_CONST
%token T_RETURN
%token T_TRY
%token T_CATCH
%token T_THROW
%token T_USE
%token T_GLOBAL
%right T_STATIC T_ABSTRACT T_FINAL T_PRIVATE T_PROTECTED T_PUBLIC
%token T_VAR
%token T_UNSET
%token T_ISSET
%token T_EMPTY
%token T_HALT_COMPILER
%token T_CLASS
%token T_INTERFACE
%token T_EXTENDS
%token T_IMPLEMENTS
%token T_OBJECT_OPERATOR
%token T_DOUBLE_ARROW
%token T_LIST
%token T_ARRAY
%token T_CLASS_C
%token T_METHOD_C
%token T_FUNC_C
%token T_LINE
%token T_FILE
%token T_COMMENT
%token T_DOC_COMMENT
%token T_OPEN_TAG
%token T_OPEN_TAG_WITH_ECHO
%token T_OPEN_TAG_FAKE
%token T_CLOSE_TAG
%token T_WHITESPACE
%token T_START_HEREDOC /* unused in XHP; replaced with T_HEREDOC */
%token T_END_HEREDOC /* unused in XHP; replaced with T_HEREDOC */
%token T_HEREDOC /* new in XHP; replaces start_heredoc encaps_list T_END_HEREDOC */
%token T_DOLLAR_OPEN_CURLY_BRACES /* unused in XHP: `${` in `"${foo}"` */
%token T_CURLY_OPEN /* unused in XHP: `{$` in `"{$foo}"` */
%token T_PAAMAYIM_NEKUDOTAYIM
%token T_BINARY_DOUBLE /* unsused in XHP: `b"` in `b"foo"` */
%token T_BINARY_HEREDOC /* unsused in XHP: `b<<<` in `b<<<FOO` */
%token T_NAMESPACE
%token T_NS_C
%token T_DIR
%token T_NS_SEPARATOR
%token T_YIELD

%token T_XHP_WHITESPACE
%token T_XHP_TEXT
%token T_XHP_LT_DIV
%token T_XHP_LT_DIV_GT
%token T_XHP_ATTRIBUTE
%token T_XHP_CATEGORY
%token T_XHP_CHILDREN
%token T_XHP_ANY
%token T_XHP_EMPTY
%token T_XHP_PCDATA
%token T_XHP_COLON
%token T_XHP_HYPHEN
%token T_XHP_BOOLEAN
%token T_XHP_NUMBER
%token T_XHP_ARRAY
%token T_XHP_STRING
%token T_XHP_ENUM
%token T_XHP_FLOAT
%token T_XHP_REQUIRED
%token T_XHP_ENTITY

%%

start:
  top_statement_list {
    *root = NNEW(n_PROGRAM)->appendChild($1);
  }
;

top_statement_list:
  top_statement_list top_statement {
    $$ = $1->appendChild($2);
  }
| /* empty */ {
    $$ = NNEW(n_STATEMENT_LIST);
  }
;

namespace_name:
  T_STRING {
    $$ = NTYPE($1, n_SYMBOL_NAME);
  }
| namespace_name T_NS_SEPARATOR T_STRING {
    $$ = NMORE($1, $3);
  }
;

top_statement:
  statement
| function_declaration_statement
| class_declaration_statement
| T_HALT_COMPILER '(' ')' ';' {
    $1 = NSPAN($1, n_HALT_COMPILER, $3);
    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $4);
  }
| T_NAMESPACE namespace_name ';' {
    NSPAN($1, n_NAMESPACE, $2);
    $1->appendChild($2);
    $1->appendChild(NNEW(n_EMPTY));
    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $3);
  }
| T_NAMESPACE namespace_name '{' top_statement_list '}' {
  NSPAN($1, n_NAMESPACE, $5);
  $1->appendChild($2);
  NMORE($4, $5);
  NLMORE($4, $3);
  $1->appendChild($4);
  $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_NAMESPACE '{' top_statement_list '}' {
  NSPAN($1, n_NAMESPACE, $4);
  $1->appendChild(NNEW(n_EMPTY));
  NMORE($3, $4);
  NLMORE($3, $2);
  $1->appendChild($3);
  $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_USE use_declarations ';' {
  NSPAN($1, n_USE, $2);
  $1->appendChild($2);
  $$ = NNEW(n_STATEMENT)->appendChild($1);
  NMORE($$, $3);
  }
| constant_declaration ';' {
  $$ = NNEW(n_STATEMENT)->appendChild($1);
  NMORE($$, $2);
  }
;

use_declarations:
  use_declarations ',' use_declaration {
    $$ = $1->appendChild($3);
  }
| use_declaration {
    $$ = NNEW(n_USE_LIST);
    $$->appendChild($1);
  }
;

use_declaration:
  namespace_name {
    $$ = NNEW(n_USE);
    $$->appendChild($1);
    $$->appendChild(NNEW(n_EMPTY));
  }
| namespace_name T_AS T_STRING {
    $$ = NNEW(n_USE);
    $$->appendChild($1);
    NTYPE($3, n_STRING);
    $$->appendChild($3);
  }
| T_NS_SEPARATOR namespace_name {
    $$ = NNEW(n_USE);
    NLMORE($2, $1);
    $$->appendChild($2);
    $$->appendChild(NNEW(n_EMPTY));
  }
| T_NS_SEPARATOR namespace_name T_AS T_STRING {
    $$ = NNEW(n_USE);
    NLMORE($2, $1);
    $$->appendChild($2);
    NTYPE($4, n_STRING);
    $$->appendChild($4);
  }
;

constant_declaration:
  constant_declaration ',' T_STRING '=' static_scalar {
    NMORE($$, $5);
    $$->appendChild(
      NNEW(n_CONSTANT_DECLARATION)
        ->appendChild(NTYPE($3, n_STRING))
        ->appendChild($5));
  }
| T_CONST T_STRING '=' static_scalar {
    NSPAN($$, n_CONSTANT_DECLARATION_LIST, $4);
    $$->appendChild(
      NNEW(n_CONSTANT_DECLARATION)
        ->appendChild(NTYPE($2, n_STRING))
        ->appendChild($4));
  }
;

inner_statement_list:
  inner_statement_list inner_statement {
    $$ = $1->appendChild($2);
  }
| /* empty */ {
    $$ = NNEW(n_STATEMENT_LIST);
  }
;

inner_statement:
  statement
| function_declaration_statement
| class_declaration_statement
| T_HALT_COMPILER '(' ')' ';' {
  $1 = NSPAN($1, n_HALT_COMPILER, $3);
  $$ = NNEW(n_STATEMENT)->appendChild($1);
  NMORE($$, $4);
  }
;

statement:
  unticked_statement
| T_STRING ':' {
    NTYPE($1, n_STRING);
    $$ = NNEW(n_LABEL);
    $$->appendChild($1);
    NMORE($$, $2);
  }
| T_OPEN_TAG {
    $$ = NTYPE($1, n_OPEN_TAG);
  }
| T_OPEN_TAG_WITH_ECHO {
    $$ = NTYPE($1, n_OPEN_TAG);
  }
| T_CLOSE_TAG {
    $$ = NTYPE($1, n_CLOSE_TAG);
  }
;

unticked_statement:
  '{' inner_statement_list '}' {
    NMORE($2, $3);
    NLMORE($2, $1);
    $$ = $2;
  }
| T_IF '(' expr ')' statement elseif_list else_single {
    $$ = NNEW(n_CONDITION_LIST);

    $1 = NTYPE($1, n_IF);
    $1->appendChild(NSPAN($2, n_CONTROL_CONDITION, $4)->appendChild($3));
    $1->appendChild($5);

    $$->appendChild($1);
    $$->appendChildren($6);

    // Hacks: merge a list of if (x) { } else if (y) { } into a single condition
    // list instead of a condition tree.

    if ($7->type == n_EMPTY) {
      // Ignore.
    } else if ($7->type == n_ELSE) {
      xhpast::Node *stype = $7->firstChild()->firstChild();
      if (stype && stype->type == n_CONDITION_LIST) {
        NTYPE(stype->firstChild(), n_ELSEIF);
        stype->firstChild()->l_tok = $7->l_tok;
        $$->appendChildren(stype);
      } else {
        $$->appendChild($7);
      }
    } else {
      $$->appendChild($7);
    }

    $$ = NNEW(n_STATEMENT)->appendChild($$);
  }
| T_IF '(' expr ')' ':' inner_statement_list new_elseif_list new_else_single T_ENDIF ';' {

    $$ = NNEW(n_CONDITION_LIST);
    NTYPE($1, n_IF);
    $1->appendChild(NSPAN($2, n_CONTROL_CONDITION, $4)->appendChild($3));
    $1->appendChild($6);

    $$->appendChild($1);
    $$->appendChildren($7);
    $$->appendChild($8);
    NMORE($$, $9);

    $$ = NNEW(n_STATEMENT)->appendChild($$);
    NMORE($$, $10);
  }
| T_WHILE '(' expr ')' while_statement {
    NTYPE($1, n_WHILE);
    $1->appendChild(NSPAN($2, n_CONTROL_CONDITION, $4)->appendChild($3));
    $1->appendChild($5);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_DO statement T_WHILE '(' expr ')' ';' {
    NTYPE($1, n_DO_WHILE);
    $1->appendChild($2);
    $1->appendChild(NSPAN($4, n_CONTROL_CONDITION, $6)->appendChild($5));

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $7);
  }
| T_FOR '(' for_expr ';' for_expr ';' for_expr ')' for_statement {
    NTYPE($1, n_FOR);

    NSPAN($2, n_FOR_EXPRESSION, $8)
      ->appendChild($3)
      ->appendChild($5)
      ->appendChild($7);

    $1->appendChild($2);
    $1->appendChild($9);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_SWITCH '(' expr ')' switch_case_list {
    NTYPE($1, n_SWITCH);
    $1->appendChild(NSPAN($2, n_CONTROL_CONDITION, $4)->appendChild($3));
    $1->appendChild($5);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_BREAK ';' {
    NTYPE($1, n_BREAK);
    $1->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $2);
  }
| T_BREAK expr ';' {
    NTYPE($1, n_BREAK);
    $1->appendChild($2);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $3);
  }
| T_CONTINUE ';' {
    NTYPE($1, n_CONTINUE);
    $1->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $2);
  }
| T_CONTINUE expr ';' {
    NTYPE($1, n_CONTINUE);
    $1->appendChild($2);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $3);
  }
| T_RETURN ';' {
    NTYPE($1, n_RETURN);
    $1->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $2);
  }
| T_RETURN expr_without_variable ';' {
    NTYPE($1, n_RETURN);
    $1->appendChild($2);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $3);
  }
| T_RETURN variable ';' {
    NTYPE($1, n_RETURN);
    $1->appendChild($2);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $3);
  }
| T_GLOBAL global_var_list ';' {
    NLMORE($2, $1);
    $$ = NNEW(n_STATEMENT)->appendChild($2);
    NMORE($$, $3);
  }
| T_STATIC static_var_list ';' {
    NLMORE($2, $1);
    $$ = NNEW(n_STATEMENT)->appendChild($2);
    NMORE($$, $3);
  }
| T_ECHO echo_expr_list ';' {
    NLMORE($2, $1);
    $$ = NNEW(n_STATEMENT)->appendChild($2);
    NMORE($$, $3);
  }
| T_INLINE_HTML {
    NTYPE($1, n_INLINE_HTML);
    $$ = $1;
  }
| expr ';' {
    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $2);
  }
| T_UNSET '(' unset_variables ')' ';' {
    NMORE($3, $4);
    NLMORE($3, $1);
    $$ = NNEW(n_STATEMENT)->appendChild($3);
    NMORE($$, $5);
  }
| T_FOREACH '(' variable T_AS foreach_variable foreach_optional_arg ')' foreach_statement {
    NTYPE($1, n_FOREACH);
    NSPAN($2, n_FOREACH_EXPRESSION, $7);
    $2->appendChild($3);
    if ($6->type == n_EMPTY) {
      $2->appendChild($6);
      $2->appendChild($5);
    } else {
      $2->appendChild($5);
      $2->appendChild($6);
    }
    $1->appendChild($2);

    $1->appendChild($8);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_FOREACH '(' expr_without_variable T_AS variable foreach_optional_arg ')' foreach_statement {
    NTYPE($1, n_FOREACH);
    NSPAN($2, n_FOREACH_EXPRESSION, $7);
    $2->appendChild($3);
    if ($6->type == n_EMPTY) {
      $2->appendChild($6);
      $2->appendChild($5);
    } else {
      $2->appendChild($5);
      $2->appendChild($6);
    }
    $1->appendChild($2);
    $1->appendChild($8);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_DECLARE '(' declare_list ')' declare_statement {
    NTYPE($1, n_DECLARE);
    $1->appendChild($3);
    $1->appendChild($5);
    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| ';' /* empty statement */ {
    $$ = NNEW(n_STATEMENT)->appendChild(NNEW(n_EMPTY));
    NMORE($$, $1);
  }
| T_TRY '{' inner_statement_list '}' T_CATCH '(' fully_qualified_class_name T_VARIABLE ')' '{' inner_statement_list '}' additional_catches {
    NTYPE($1, n_TRY);
    $1->appendChild($3);

    NTYPE($5, n_CATCH);
    $5->appendChild($7);
    $5->appendChild(NTYPE($8, n_VARIABLE));
    $5->appendChild($11);

    $1->appendChild(NNEW(n_CATCH_LIST)->appendChild($5)->appendChildren($13));

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
| T_THROW expr ';' {
  NTYPE($1, n_THROW);
  $1->appendChild($2);

  $$ = NNEW(n_STATEMENT)->appendChild($1);
  NMORE($$, $3);

  }
| T_GOTO T_STRING ';' {
  NTYPE($1, n_GOTO);
  NTYPE($2, n_STRING);
  $1->appendChild($2);

  $$ = NNEW(n_STATEMENT)->appendChild($1);
  NMORE($$, $3);
  }
;

additional_catches:
  non_empty_additional_catches
| /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
;

non_empty_additional_catches:
  additional_catch {
    $$ = NNEW(n_CATCH_LIST);
    $$->appendChild($1);
  }
| non_empty_additional_catches additional_catch {
    $1->appendChild($2);
    $$ = $1;
  }
;

additional_catch:
  T_CATCH '(' fully_qualified_class_name T_VARIABLE ')' '{' inner_statement_list '}' {
    NTYPE($1, n_CATCH);
    $1->appendChild($3);
    $1->appendChild(NTYPE($4, n_VARIABLE));
    $1->appendChild($7);
    NMORE($1, $8);
    $$ = $1;
  }
;

unset_variables:
  unset_variable {
    $$ = NNEW(n_UNSET_LIST);
    $$->appendChild($1);
  }
| unset_variables ',' unset_variable {
    $1->appendChild($3);
    $$ = $1;
  }
;

unset_variable:
  variable
;

function_declaration_statement:
  unticked_function_declaration_statement
;

class_declaration_statement:
  unticked_class_declaration_statement
;

is_reference:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| '&' {
    $$ = NTYPE($1, n_REFERENCE);
  }
;

unticked_function_declaration_statement:
  function is_reference T_STRING '(' parameter_list ')' '{' inner_statement_list '}' {
    NSPAN($1, n_FUNCTION_DECLARATION, $9);
    $1->appendChild(NNEW(n_EMPTY));
    $1->appendChild($2);
    $1->appendChild(NTYPE($3, n_STRING));
    $1->appendChild(NEXPAND($4, $5, $6));
    $$->appendChild(NNEW(n_EMPTY));
    $1->appendChild($8);

    $$ = NNEW(n_STATEMENT)->appendChild($1);
  }
;

unticked_class_declaration_statement:
  class_entry_type T_STRING extends_from implements_list '{' class_statement_list '}' {
    $$ = NNEW(n_CLASS_DECLARATION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_CLASS_NAME));
    $$->appendChild($3);
    $$->appendChild($4);
    $$->appendChild($6);
    NMORE($$, $7);

    $$ = NNEW(n_STATEMENT)->appendChild($$);
  }
| interface_entry T_STRING interface_extends_list '{' class_statement_list '}' {
    $$ = NNEW(n_INTERFACE_DECLARATION);
    $$->appendChild(NNEW(n_EMPTY));
    NLMORE($$, $1);
    $$->appendChild(NTYPE($2, n_CLASS_NAME));
    $$->appendChild($3);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($5);
    NMORE($$, $6);

    $$ = NNEW(n_STATEMENT)->appendChild($$);
  }
;

class_entry_type:
  T_CLASS {
    NTYPE($1, n_CLASS_ATTRIBUTES);
    $1->appendChild(NNEW(n_EMPTY));
    $$ = $1;
  }
| T_ABSTRACT T_CLASS {
    NTYPE($2, n_CLASS_ATTRIBUTES);
    NLMORE($2, $1);
    $2->appendChild(NTYPE($1, n_STRING));

    $$ = $1;
  }
| T_FINAL T_CLASS {
    NTYPE($2, n_CLASS_ATTRIBUTES);
    NLMORE($2, $1);
    $2->appendChild(NTYPE($1, n_STRING));

    $$ = $1;
  }
;

extends_from:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_EXTENDS fully_qualified_class_name {
    $$ = NTYPE($1, n_EXTENDS_LIST)->appendChild($2);
  }
;

interface_entry:
  T_INTERFACE
;

interface_extends_list:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_EXTENDS interface_list {
    NTYPE($1, n_EXTENDS_LIST);
    $1->appendChildren($2);
    $$ = $1;
  }
;

implements_list:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_IMPLEMENTS interface_list {
    NTYPE($1, n_IMPLEMENTS_LIST);
    $1->appendChildren($2);
    $$ = $1;
  }
;

interface_list:
  fully_qualified_class_name {
    $$ = NNEW(n_IMPLEMENTS_LIST)->appendChild($1);
  }
| interface_list ',' fully_qualified_class_name {
    $$ = $1->appendChild($3);
  }
;

foreach_optional_arg:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_DOUBLE_ARROW foreach_variable {
    $$ = $2;
  }
;

foreach_variable:
  variable
| '&' variable {
    NTYPE($1, n_VARIABLE_REFERENCE);
    $1->appendChild($2);
    $$ = $1;
  }
;

for_statement:
  statement
| ':' inner_statement_list T_ENDFOR ';' {
  NLMORE($2, $1);
  NMORE($2, $4);
  $$ = $2;
  }
;

foreach_statement:
  statement
| ':' inner_statement_list T_ENDFOREACH ';' {
  NLMORE($2, $1);
  NMORE($2, $4);
  $$ = $2;
  }
;

declare_statement:
  statement
| ':' inner_statement_list T_ENDDECLARE ';' {
  NLMORE($2, $1);
  NMORE($2, $4);
  $$ = $2;
  }
;

declare_list:
  T_STRING '=' static_scalar {
    $$ = NNEW(n_DECLARE_DECLARATION);
    $$->appendChild(NTYPE($1, n_STRING));
    $$->appendChild($3);
    $$ = NNEW(n_DECLARE_DECLARATION_LIST)->appendChild($$);
  }
| declare_list ',' T_STRING '=' static_scalar {
    $$ = NNEW(n_DECLARE_DECLARATION);
    $$->appendChild(NTYPE($3, n_STRING));
    $$->appendChild($5);

    $1->appendChild($$);
    $$ = $1;
  }
;

switch_case_list:
  '{' case_list '}' {
    NMORE($2, $3);
    NLMORE($2, $1);
    $$ = $2;
  }
| '{' ';' case_list '}' {
    // ...why does this rule exist?

    NTYPE($2, n_STATEMENT);
    $1->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATEMENT_LIST)->appendChild($2);
    $$->appendChildren($3);
    NMORE($$, $4);
    NLMORE($$, $1);
  }
| ':' case_list T_ENDSWITCH ';' {
    NMORE($2, $4);
    NLMORE($2, $1);
    $$ = $2;
  }
| ':' ';' case_list T_ENDSWITCH ';' {
    NTYPE($2, n_STATEMENT);
    $1->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATEMENT_LIST)->appendChild($2);
    $$->appendChildren($3);
    NMORE($$, $5);
    NLMORE($$, $1);
  }
;

case_list:
  /* empty */ {
    $$ = NNEW(n_STATEMENT_LIST);
  }
| case_list T_CASE expr case_separator inner_statement_list {
    NTYPE($2, n_CASE);
    $2->appendChild($3);
    $2->appendChild($5);

    $1->appendChild($2);
    $$ = $1;
  }
| case_list T_DEFAULT case_separator inner_statement_list {
    NTYPE($2, n_DEFAULT);
    $2->appendChild($4);

    $1->appendChild($2);
    $$ = $1;
  }
;

case_separator:
  ':'
| ';'
;

while_statement:
  statement
| ':' inner_statement_list T_ENDWHILE ';' {
  NMORE($2, $4);
  NLMORE($2, $1);
  $$ = $2;
  }
;

elseif_list:
  /* empty */ {
    $$ = NNEW(n_CONDITION_LIST);
  }
| elseif_list T_ELSEIF '(' expr ')' statement {
    NTYPE($2, n_ELSEIF);
    $2->appendChild(NSPAN($3, n_CONTROL_CONDITION, $5)->appendChild($4));
    $2->appendChild($6);

    $$ = $1->appendChild($2);
  }
;

new_elseif_list:
  /* empty */ {
    $$ = NNEW(n_CONDITION_LIST);
  }
| new_elseif_list T_ELSEIF '(' expr ')' ':' inner_statement_list {
    NTYPE($2, n_ELSEIF);
    $2->appendChild($4);
    $2->appendChild($7);

    $$ = $1->appendChild($2);
  }
;

else_single:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_ELSE statement {
    NTYPE($1, n_ELSE);
    $1->appendChild($2);
    $$ = $1;
  }
;

new_else_single:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_ELSE ':' inner_statement_list {
    NTYPE($1, n_ELSE);
    $1->appendChild($3);
    $$ = $1;
  }
;

parameter_list:
  non_empty_parameter_list
| /* empty */ {
    $$ = NNEW(n_DECLARATION_PARAMETER_LIST);
  }
;

non_empty_parameter_list:
  optional_class_type T_VARIABLE {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_DECLARATION_PARAMETER_LIST)->appendChild($$);
  }
| optional_class_type '&' T_VARIABLE {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_VARIABLE_REFERENCE));
      $2->appendChild(NTYPE($3, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_DECLARATION_PARAMETER_LIST)->appendChild($$);
  }
| optional_class_type '&' T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_VARIABLE_REFERENCE));
      $2->appendChild(NTYPE($3, n_VARIABLE));
    $$->appendChild($5);

    $$ = NNEW(n_DECLARATION_PARAMETER_LIST)->appendChild($$);
  }
| optional_class_type T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_VARIABLE));
    $$->appendChild($4);

    $$ = NNEW(n_DECLARATION_PARAMETER_LIST)->appendChild($$);
  }
| non_empty_parameter_list ',' optional_class_type T_VARIABLE {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($3);
    $$->appendChild(NTYPE($4, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = $1->appendChild($$);
  }
| non_empty_parameter_list ',' optional_class_type '&' T_VARIABLE {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($3);
    $$->appendChild(NTYPE($4, n_VARIABLE_REFERENCE));
      $4->appendChild(NTYPE($5, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = $1->appendChild($$);
  }
| non_empty_parameter_list ',' optional_class_type '&' T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($3);
    $$->appendChild(NTYPE($4, n_VARIABLE_REFERENCE));
      $4->appendChild(NTYPE($5, n_VARIABLE));
    $$->appendChild($7);

    $$ = $1->appendChild($$);
  }
| non_empty_parameter_list ',' optional_class_type T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_DECLARATION_PARAMETER);
    $$->appendChild($3);
    $$->appendChild(NTYPE($4, n_VARIABLE));
    $$->appendChild($6);

    $$ = $1->appendChild($$);
  }
;

optional_class_type:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| fully_qualified_class_name {
    $$ = $1;
  }
| T_ARRAY {
    $$ = NTYPE($1, n_TYPE_NAME);
  }
;

function_call_parameter_list:
  non_empty_function_call_parameter_list
| /* empty */ {
    $$ = NNEW(n_CALL_PARAMETER_LIST);
  }
;

non_empty_function_call_parameter_list:
  expr_without_variable {
    $$ = NNEW(n_CALL_PARAMETER_LIST)->appendChild($1);
  }
| variable {
    $$ = NNEW(n_CALL_PARAMETER_LIST)->appendChild($1);
  }
| '&' w_variable {
    NTYPE($1, n_VARIABLE_REFERENCE);
    $1->appendChild($2);
    $$ = NNEW(n_CALL_PARAMETER_LIST)->appendChild($1);
  }
| non_empty_function_call_parameter_list ',' expr_without_variable {
    $$ = $1->appendChild($3);
  }
| non_empty_function_call_parameter_list ',' variable {
    $$ = $1->appendChild($3);
  }
| non_empty_function_call_parameter_list ',' '&' w_variable {
    $$ = $1->appendChild($3);
  }
;

global_var_list:
  global_var_list ',' global_var {
    $1->appendChild($3);
    $$ = $1;
  }
| global_var {
    $$ = NNEW(n_GLOBAL_DECLARATION_LIST);
    $$->appendChild($1);
  }
;

global_var:
  T_VARIABLE {
    $$ = NTYPE($1, n_VARIABLE);
  }
| '$' r_variable {
    $$ = NTYPE($1, n_VARIABLE_VARIABLE);
    $$->appendChild($2);
  }
| '$' '{' expr '}' {
    $$ = NTYPE($1, n_VARIABLE_VARIABLE);
    $$->appendChild($3);
  }
;

static_var_list:
  static_var_list ',' T_VARIABLE {
    NTYPE($3, n_VARIABLE);
    $$ = NNEW(n_STATIC_DECLARATION);
    $$->appendChild($3);
    $$->appendChild(NNEW(n_EMPTY));

    $$ = $1->appendChild($$);
  }
| static_var_list ',' T_VARIABLE '=' static_scalar {
    NTYPE($3, n_VARIABLE);
    $$ = NNEW(n_STATIC_DECLARATION);
    $$->appendChild($3);
    $$->appendChild($5);

    $$ = $1->appendChild($$);
  }
| T_VARIABLE {
    NTYPE($1, n_VARIABLE);
    $$ = NNEW(n_STATIC_DECLARATION);
    $$->appendChild($1);
    $$->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_STATIC_DECLARATION_LIST)->appendChild($$);
  }
| T_VARIABLE '=' static_scalar {
    NTYPE($1, n_VARIABLE);
    $$ = NNEW(n_STATIC_DECLARATION);
    $$->appendChild($1);
    $$->appendChild($3);

    $$ = NNEW(n_STATIC_DECLARATION_LIST)->appendChild($$);
  }
;

class_statement_list:
  class_statement_list class_statement {
    $$ = $1->appendChild($2);
  }
| /* empty */ {
    $$ = NNEW(n_STATEMENT_LIST);
  }
;

class_statement:
  variable_modifiers class_variable_declaration ';' {
    $$ = NNEW(n_CLASS_MEMBER_DECLARATION_LIST);
    $$->appendChild($1);
    $$->appendChildren($2);

    $$ = NNEW(n_STATEMENT)->appendChild($$);
    NMORE($$, $3);
  }
| class_constant_declaration ';' {
    $$ = NNEW(n_STATEMENT)->appendChild($1);
    NMORE($$, $2);
  }
| method_modifiers function {
    yyextra->old_expecting_xhp_class_statements = yyextra->expecting_xhp_class_statements;
    yyextra->expecting_xhp_class_statements = false;
  } is_reference T_STRING '(' parameter_list ')' method_body {
    yyextra->expecting_xhp_class_statements = yyextra->old_expecting_xhp_class_statements;

    $$ = NNEW(n_METHOD_DECLARATION);
    $$->appendChild($1);
    $$->appendChild($4);
    $$->appendChild(NTYPE($5, n_STRING));
    $$->appendChild(NEXPAND($6, $7, $8));
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($9);

    $$ = NNEW(n_STATEMENT)->appendChild($$);
  }
;

method_body:
  ';' /* abstract method */ {
    $$ = NNEW(n_EMPTY);
  }
| '{' inner_statement_list '}' {
    NMORE($2, $3);
    NLMORE($2, $1);
    $$ = $2;
  }
;

variable_modifiers:
  non_empty_member_modifiers
| T_VAR {
    $$ = NNEW(n_CLASS_MEMBER_MODIFIER_LIST);
    $$->appendChild(NTYPE($1, n_STRING));
  }
;

method_modifiers:
  /* empty */ {
    $$ = NNEW(n_METHOD_MODIFIER_LIST);
  }
| non_empty_member_modifiers {
    NTYPE($1, n_METHOD_MODIFIER_LIST);
    $$ = $1;
  }
;

non_empty_member_modifiers:
  member_modifier {
    $$ = NNEW(n_CLASS_MEMBER_MODIFIER_LIST);
    $$->appendChild(NTYPE($1, n_STRING));
  }
| non_empty_member_modifiers member_modifier {
    $$ = $1->appendChild(NTYPE($2, n_STRING));
  }
;

member_modifier:
  T_PUBLIC
| T_PROTECTED
| T_PRIVATE
| T_STATIC
| T_ABSTRACT
| T_FINAL
;

class_variable_declaration:
  class_variable_declaration ',' T_VARIABLE {
    $$ = NNEW(n_CLASS_MEMBER_DECLARATION);
    $$->appendChild(NTYPE($3, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = $1->appendChild($$);
  }
| class_variable_declaration ',' T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_CLASS_MEMBER_DECLARATION);
    $$->appendChild(NTYPE($3, n_VARIABLE));
    $$->appendChild($5);

    $$ = $1->appendChild($$);
  }
| T_VARIABLE {
    $$ = NNEW(n_CLASS_MEMBER_DECLARATION);
    $$->appendChild(NTYPE($1, n_VARIABLE));
    $$->appendChild(NNEW(n_EMPTY));

    $$ = NNEW(n_CLASS_MEMBER_DECLARATION_LIST)->appendChild($$);
  }
| T_VARIABLE '=' static_scalar {
    $$ = NNEW(n_CLASS_MEMBER_DECLARATION);
    $$->appendChild(NTYPE($1, n_VARIABLE));
    $$->appendChild($3);

    $$ = NNEW(n_CLASS_MEMBER_DECLARATION_LIST)->appendChild($$);
  }
;

class_constant_declaration:
  class_constant_declaration ',' T_STRING '=' static_scalar {
    $$ = NNEW(n_CLASS_CONSTANT_DECLARATION);
    $$->appendChild(NTYPE($3, n_STRING));
    $$->appendChild($5);

    $1->appendChild($$);

    $$ = $1;
  }
| T_CONST T_STRING '=' static_scalar {
    NTYPE($1, n_CLASS_CONSTANT_DECLARATION_LIST);
    $$ = NNEW(n_CLASS_CONSTANT_DECLARATION);
    $$->appendChild(NTYPE($2, n_STRING));
    $$->appendChild($4);
    $1->appendChild($$);

    $$ = $1;
  }
;

echo_expr_list:
  echo_expr_list ',' expr {
    $1->appendChild($3);
  }
| expr {
    $$ = NNEW(n_ECHO_LIST);
    $$->appendChild($1);
  }
;

for_expr:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| non_empty_for_expr
;


non_empty_for_expr:
  non_empty_for_expr ',' expr {
    $1->appendChild($3);
  }
| expr {
    $$ = NNEW(n_EXPRESSION_LIST);
    $$->appendChild($1);
  }
;

expr_without_variable:
  T_LIST '(' assignment_list ')' '=' expr {
    NTYPE($1, n_LIST);
    $1->appendChild(NEXPAND($2, $3, $4));
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($5, n_OPERATOR));
    $$->appendChild($6);
  }
| variable '=' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable '=' '&' variable {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));

    NTYPE($3, n_VARIABLE_REFERENCE);
    $3->appendChild($4);

    $$->appendChild($3);
  }
| variable '=' '&' T_NEW class_name_reference ctor_arguments {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));

    NTYPE($4, n_NEW);
    $4->appendChild($5);
    $4->appendChild($6);

    NTYPE($3, n_VARIABLE_REFERENCE);
    $3->appendChild($4);

    $$->appendChild($3);
  }
| T_NEW class_name_reference ctor_arguments {
    NTYPE($1, n_NEW);
    $1->appendChild($2);
    $1->appendChild($3);
    $$ = $1;
  }
| T_CLONE expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| variable T_PLUS_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_MINUS_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_MUL_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_DIV_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_CONCAT_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_MOD_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_AND_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_OR_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_XOR_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_SL_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| variable T_SR_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| rw_variable T_INC {
    $$ = NNEW(n_UNARY_POSTFIX_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
  }
| T_INC rw_variable {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| rw_variable T_DEC {
    $$ = NNEW(n_UNARY_POSTFIX_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
  }
| T_DEC rw_variable {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| expr T_BOOLEAN_OR expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_BOOLEAN_AND expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_LOGICAL_OR expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_LOGICAL_AND expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_LOGICAL_XOR expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '|' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '&' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '^' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '.' expr {

    /* The concatenation operator generates n_CONCATENATION_LIST instead of
       n_BINARY_EXPRESSION because we tend to run into stack depth issues in a
       lot of real-world cases otherwise (e.g., in PHP and JSON decoders). */

    if ($1->type == n_CONCATENATION_LIST && $3->type == n_CONCATENATION_LIST) {
      $1->appendChild(NTYPE($2, n_OPERATOR));
      $1->appendChildren($3);
      $$ = $1;
    } else if ($1->type == n_CONCATENATION_LIST) {
      $1->appendChild(NTYPE($2, n_OPERATOR));
      $1->appendChild($3);
      $$ = $1;
    } else if ($3->type == n_CONCATENATION_LIST) {
      $$ = NNEW(n_CONCATENATION_LIST);
      $$->appendChild($1);
      $$->appendChild(NTYPE($2, n_OPERATOR));
      $$->appendChildren($3);
    } else {
      $$ = NNEW(n_CONCATENATION_LIST);
      $$->appendChild($1);
      $$->appendChild(NTYPE($2, n_OPERATOR));
      $$->appendChild($3);
    }
  }
| expr '+' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '-' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '*' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '/' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '%' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_SL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_SR expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| '+' expr %prec T_INC {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| '-' expr %prec T_INC {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| '!' expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| '~' expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| expr T_IS_IDENTICAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_IS_NOT_IDENTICAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_IS_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_IS_NOT_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '<' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_IS_SMALLER_OR_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr '>' expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_IS_GREATER_OR_EQUAL expr {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| expr T_INSTANCEOF class_name_reference {
    $$ = NNEW(n_BINARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NTYPE($2, n_OPERATOR));
    $$->appendChild($3);
  }
| '(' expr ')' {
    NSPAN($1, n_PARENTHETICAL_EXPRESSION, $3);
    $1->appendChild($2);
    $$ = $1;
  }
| expr '?' expr ':' expr {
    $$ = NNEW(n_TERNARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild($3);
    $$->appendChild($5);
  }
| expr '?' ':' expr {
    $$ = NNEW(n_TERNARY_EXPRESSION);
    $$->appendChild($1);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($4);
  }
| internal_functions_in_yacc
| T_INT_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_DOUBLE_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_STRING_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_UNICODE_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_BINARY_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_ARRAY_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_OBJECT_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_BOOL_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_UNSET_CAST expr {
    $$ = NNEW(n_CAST_EXPRESSION);
    $$->appendChild(NTYPE($1, n_CAST));
    $$->appendChild($2);
  }
| T_EXIT exit_expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| '@' expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| T_ARRAY '(' array_pair_list ')' {
    NTYPE($1, n_ARRAY_LITERAL);
    $1->appendChild($3);
    NMORE($1, $4);
    $$ = $1;
  }
| T_BACKTICKS_EXPR {
    NTYPE($1, n_BACKTICKS_EXPRESSION);
    $$ = $1;
  }
| scalar
| T_PRINT expr {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| function is_reference '(' parameter_list ')' lexical_vars '{' inner_statement_list '}' {
    NSPAN($1, n_FUNCTION_DECLARATION, $9);
    $1->appendChild(NNEW(n_EMPTY));
    $1->appendChild($2);
    $1->appendChild(NNEW(n_EMPTY));
    $1->appendChild(NEXPAND($3, $4, $5));
    $$->appendChild($6);
    $1->appendChild($8);

    $$ = $1;
  }
| T_STATIC function is_reference '(' parameter_list ')' lexical_vars '{' inner_statement_list '}' {
    NSPAN($2, n_FUNCTION_DECLARATION, $10);
    NLMORE($2, $1);

    $$ = NNEW(n_FUNCTION_MODIFIER_LIST);
    $$->appendChild(NTYPE($1, n_STRING));
    $2->appendChild($1);

    $2->appendChild(NNEW(n_EMPTY));
    $2->appendChild($3);
    $2->appendChild(NNEW(n_EMPTY));
    $2->appendChild(NEXPAND($4, $5, $6));
    $2->appendChild($7);
    $2->appendChild($9);

    $$ = $2;
  }
| T_YIELD T_BREAK {
    $$ = NNEW(n_YIELD_EXPRESSION);
    $$->appendChild(NTYPE($1, n_YIELD));
    $$->appendChild(NTYPE($2, n_BREAK));
  }
| T_YIELD expr {
    $$ = NNEW(n_YIELD_EXPRESSION);
    $$->appendChild(NTYPE($1, n_YIELD));
    $$->appendChild($2);
  }
;

function:
  T_FUNCTION
;

lexical_vars:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| T_USE '(' lexical_var_list ')' {
    NTYPE($1, n_LEXICAL_VARIABLE_LIST);
    $1->appendChildren($3);
    $$ = $1;
  }
;

lexical_var_list:
  lexical_var_list ',' T_VARIABLE {
    $$ = $1->appendChild(NTYPE($3, n_VARIABLE));
  }
| lexical_var_list ',' '&' T_VARIABLE {
    NTYPE($3, n_VARIABLE_REFERENCE);
    $3->appendChild(NTYPE($4, n_VARIABLE));
    $$ = $1->appendChild($3);
  }
| T_VARIABLE {
    $$ = NNEW(n_LEXICAL_VARIABLE_LIST);
    $$->appendChild(NTYPE($1, n_VARIABLE));
  }
| '&' T_VARIABLE {
    NTYPE($1, n_VARIABLE_REFERENCE);
    $1->appendChild(NTYPE($2, n_VARIABLE));
    $$ = NNEW(n_LEXICAL_VARIABLE_LIST);
    $$->appendChild($1);
  }
;

function_call:
  namespace_name '(' function_call_parameter_list ')' {
    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($1);
    $$->appendChild(NEXPAND($2, $3, $4));
  }
| T_NAMESPACE T_NS_SEPARATOR namespace_name '(' function_call_parameter_list ')' {
    NLMORE($3, $1);
    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($3);
    $$->appendChild(NEXPAND($4, $5, $6));
  }
| T_NS_SEPARATOR namespace_name '(' function_call_parameter_list ')' {
    NLMORE($2, $1);
    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($2);
    $$->appendChild(NEXPAND($3, $4, $5));
  }
| class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING '(' function_call_parameter_list ')' {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));

    $$ = NNEW(n_FUNCTION_CALL)->appendChild($$);
    $$->appendChild(NEXPAND($4, $5, $6));
  }
| variable_class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING '(' function_call_parameter_list ')' {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));

    $$ = NNEW(n_FUNCTION_CALL)->appendChild($$);
    $$->appendChild(NEXPAND($4, $5, $6));
  }
| variable_class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects '(' function_call_parameter_list ')' {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));

    $$ = NNEW(n_FUNCTION_CALL)->appendChild($$);
    $$->appendChild(NEXPAND($4, $5, $6));
  }
| class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects '(' function_call_parameter_list ')' {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));

    $$ = NNEW(n_FUNCTION_CALL)->appendChild($$);
    $$->appendChild(NEXPAND($4, $5, $6));
  }
| variable_without_objects '(' function_call_parameter_list ')' {
    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($1);
    $$->appendChild(NEXPAND($2, $3, $4));
  }
;

class_name:
  T_STATIC {
    $$ = NTYPE($1, n_CLASS_NAME);
  }
| namespace_name {
    $$ = NTYPE($1, n_CLASS_NAME);
  }
| T_NAMESPACE T_NS_SEPARATOR namespace_name {
    NLMORE($3, $1);
    $$ = NTYPE($3, n_CLASS_NAME);
  }
| T_NS_SEPARATOR namespace_name {
    NLMORE($2, $1);
    $$ = NTYPE($2, n_CLASS_NAME);
  }
;

fully_qualified_class_name:
  namespace_name {
    $$ = NTYPE($1, n_CLASS_NAME);
  }
| T_NAMESPACE T_NS_SEPARATOR namespace_name {
    NLMORE($3, $1);
    $$ = NTYPE($3, n_CLASS_NAME);
  }
| T_NS_SEPARATOR namespace_name {
    NLMORE($2, $1);
    $$ = NTYPE($2, n_CLASS_NAME);
  }
;

class_name_reference:
  class_name
| dynamic_class_name_reference
;

dynamic_class_name_reference:
  base_variable T_OBJECT_OPERATOR object_property dynamic_class_name_variable_properties {
    $$ = NNEW(n_OBJECT_PROPERTY_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    for (xhpast::node_list_t::iterator ii = $4->children.begin(); ii != $4->children.end(); ++ii) {
      $$ = NNEW(n_OBJECT_PROPERTY_ACCESS)->appendChild($$);
      $$->appendChild(*ii);
    }
  }
| base_variable
;

dynamic_class_name_variable_properties:
  dynamic_class_name_variable_properties dynamic_class_name_variable_property {
    $$ = $1->appendChild($2);
  }
| /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
;

dynamic_class_name_variable_property:
  T_OBJECT_OPERATOR object_property {
    $$ = $2;
  }
;

exit_expr:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| '(' ')' {
    NSPAN($1, n_EMPTY, $2);
    $$ = $1;
  }
| '(' expr ')' {
    NSPAN($1, n_PARENTHETICAL_EXPRESSION, $3);
    $1->appendChild($2);
    $$ = $1;
  }
;

ctor_arguments:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| '(' function_call_parameter_list ')' {
    $$ = NEXPAND($1, $2, $3);
  }
;

common_scalar:
  T_LNUMBER {
    $$ = NTYPE($1, n_NUMERIC_SCALAR);
  }
| T_DNUMBER {
    $$ = NTYPE($1, n_NUMERIC_SCALAR);
  }
| T_CONSTANT_ENCAPSED_STRING {
    $$ = NTYPE($1, n_STRING_SCALAR);
  }
| T_LINE {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_FILE {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_DIR {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_CLASS_C {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_METHOD_C {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_FUNC_C {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_NS_C {
    $$ = NTYPE($1, n_MAGIC_SCALAR);
  }
| T_HEREDOC {
    $$ = NTYPE($1, n_HEREDOC);
  }
;

static_scalar: /* compile-time evaluated scalars */
  common_scalar
| namespace_name
| T_NAMESPACE T_NS_SEPARATOR namespace_name {
    NLMORE($3, $1);
    $$ = $3;
  }
| T_NS_SEPARATOR namespace_name {
    NLMORE($2, $1);
    $$ = $2;
  }
| '+' static_scalar {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| '-' static_scalar {
    $$ = NNEW(n_UNARY_PREFIX_EXPRESSION);
    $$->appendChild(NTYPE($1, n_OPERATOR));
    $$->appendChild($2);
  }
| T_ARRAY '(' static_array_pair_list ')' {
    NTYPE($1, n_ARRAY_LITERAL);
    $1->appendChild($3);
    NMORE($1, $4);
    $$ = $1;
  }
| static_class_constant
;

static_class_constant:
  class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));
  }
;

scalar:
  T_STRING_VARNAME
| class_constant
| namespace_name
| T_NAMESPACE T_NS_SEPARATOR namespace_name {
    $$ = NLMORE($3, $1);
  }
| T_NS_SEPARATOR namespace_name {
    $$ = NLMORE($2, $1);
  }
| common_scalar
;

static_array_pair_list:
  /* empty */ {
    $$ = NNEW(n_ARRAY_VALUE_LIST);
  }
| non_empty_static_array_pair_list possible_comma {
    $$ = NMORE($1, $2);
  }
;

possible_comma:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| ','
;

non_empty_static_array_pair_list:
  non_empty_static_array_pair_list ',' static_scalar T_DOUBLE_ARROW static_scalar {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($3);
    $$->appendChild($5);

    $$ = $1->appendChild($$);
  }
| non_empty_static_array_pair_list ',' static_scalar {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($3);

    $$ = $1->appendChild($$);
  }
| static_scalar T_DOUBLE_ARROW static_scalar {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($1);
    $$->appendChild($3);
  }
| static_scalar {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($1);
  }
;

expr:
  r_variable
| expr_without_variable
;

r_variable:
  variable
;

w_variable:
  variable
;

rw_variable:
  variable
;

variable:
  base_variable_with_function_calls T_OBJECT_OPERATOR object_property method_or_not variable_properties {
    $$ = NNEW(n_OBJECT_PROPERTY_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);

    if ($4->type != n_EMPTY) {
      $$ = NNEW(n_METHOD_CALL)->appendChild($$);
      $$->appendChild($4);
    }

    for (xhpast::node_list_t::iterator ii = $5->children.begin(); ii != $5->children.end(); ++ii) {
      if ((*ii)->type == n_CALL_PARAMETER_LIST) {
        $$ = NNEW(n_METHOD_CALL)->appendChild($$);
        $$->appendChild((*ii));
      } else {
        $$ = NNEW(n_OBJECT_PROPERTY_ACCESS)->appendChild($$);
        $$->appendChild((*ii));
      }
    }
  }
| base_variable_with_function_calls
;

variable_properties:
  variable_properties variable_property {
    $$ = $1->appendChildren($2);
  }
| /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
;

variable_property:
  T_OBJECT_OPERATOR object_property method_or_not {
    $$ = NNEW(n_EMPTY);
    $$->appendChild($2);
    if ($3->type != n_EMPTY) {
      $$->appendChild($3);
    }
  }
;

method_or_not:
  '(' function_call_parameter_list ')' {
    $$ = NEXPAND($1, $2, $3);
  }
| /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
;

variable_without_objects:
  reference_variable
| simple_indirect_reference reference_variable {
    xhpast::Node *last = $1;
    NMORE($1, $2);
    while (last->firstChild() &&
           last->firstChild()->type == n_VARIABLE_VARIABLE) {
      NMORE(last, $2);
      last = last->firstChild();
    }
    last->appendChild($2);

    $$ = $1;
  }
;

static_member:
  class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
  }
| variable_class_name T_PAAMAYIM_NEKUDOTAYIM variable_without_objects {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
  }
;

variable_class_name:
  reference_variable
;

base_variable_with_function_calls:
  base_variable
| function_call
;

base_variable:
  reference_variable
| simple_indirect_reference reference_variable {
    xhpast::Node *last = $1;
    NMORE($1, $2);
    while (last->firstChild() &&
           last->firstChild()->type == n_VARIABLE_VARIABLE) {
      NMORE(last, $2);
      last = last->firstChild();
    }
    last->appendChild($2);

    $$ = $1;
  }
| static_member
;

reference_variable:
  reference_variable '[' dim_offset ']' {
    $$ = NNEW(n_INDEX_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    NMORE($$, $4);
  }
| reference_variable '{' expr '}' {
    $$ = NNEW(n_INDEX_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    NMORE($$, $4);
  }
| compound_variable
;

compound_variable:
  T_VARIABLE {
    NTYPE($1, n_VARIABLE);
  }
| '$' '{' expr '}' {
    NSPAN($1, n_VARIABLE_EXPRESSION, $4);
    $1->appendChild($3);
    $$ = $1;
  }
;

dim_offset:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| expr {
    $$ = $1;
  }
;

object_property:
  object_dim_list
| variable_without_objects
;

object_dim_list:
  object_dim_list '[' dim_offset ']' {
    $$ = NNEW(n_INDEX_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    NMORE($$, $4)
  }
| object_dim_list '{' expr '}' {
    $$ = NNEW(n_INDEX_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    NMORE($$, $4);
  }
| variable_name
;

variable_name:
  T_STRING {
    NTYPE($1, n_STRING);
    $$ = $1;
  }
| '{' expr '}' {
  $$ = NEXPAND($1, $2, $3);
  }
;

simple_indirect_reference:
  '$' {
    $$ = NTYPE($1, n_VARIABLE_VARIABLE);
  }
| simple_indirect_reference '$' {
    $2 = NTYPE($2, n_VARIABLE_VARIABLE);

    xhpast::Node *last = $1;
    while (last->firstChild() &&
           last->firstChild()->type == n_VARIABLE_VARIABLE) {
      last = last->firstChild();
    }
    last->appendChild($2);

    $$ = $1;
  }
;

assignment_list:
  assignment_list ',' assignment_list_element {
    $$ = $1->appendChild($3);
  }
| assignment_list_element {
    $$ = NNEW(n_ASSIGNMENT_LIST);
    $$->appendChild($1);
  }
;

assignment_list_element:
  variable
| T_LIST '(' assignment_list ')' {
    $$ = NNEW(n_LIST);
    $$->appendChild($3);
    NMORE($$, $4);
  }
| /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
;

array_pair_list:
  /* empty */ {
    $$ = NNEW(n_ARRAY_VALUE_LIST);
  }
| non_empty_array_pair_list possible_comma {
    $$ = NMORE($1, $2);
  }
;

non_empty_array_pair_list:
  non_empty_array_pair_list ',' expr T_DOUBLE_ARROW expr {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($3);
    $$->appendChild($5);

    $$ = $1->appendChild($$);
  }
| non_empty_array_pair_list ',' expr {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($3);

    $$ = $1->appendChild($$);
  }
| expr T_DOUBLE_ARROW expr {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($1);
    $$->appendChild($3);

    $$ = NNEW(n_ARRAY_VALUE_LIST)->appendChild($$);
  }
| expr {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild($1);

    $$ = NNEW(n_ARRAY_VALUE_LIST)->appendChild($$);
  }
| non_empty_array_pair_list ',' expr T_DOUBLE_ARROW '&' w_variable {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($3);
    $$->appendChild(NTYPE($5, n_VARIABLE_REFERENCE)->appendChild($6));

    $$ = $1->appendChild($$);
  }
| non_empty_array_pair_list ',' '&' w_variable {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild(NTYPE($3, n_VARIABLE_REFERENCE)->appendChild($4));

    $$ = $1->appendChild($$);
  }
| expr T_DOUBLE_ARROW '&' w_variable {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_VARIABLE_REFERENCE)->appendChild($4));

    $$ = NNEW(n_ARRAY_VALUE_LIST)->appendChild($$);
  }
| '&' w_variable {
    $$ = NNEW(n_ARRAY_VALUE);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild(NTYPE($1, n_VARIABLE_REFERENCE)->appendChild($2));

    $$ = NNEW(n_ARRAY_VALUE_LIST)->appendChild($$);
  }
;

internal_functions_in_yacc:
  T_ISSET '(' isset_variables ')' {
    NTYPE($1, n_SYMBOL_NAME);

    NSPAN($2, n_CALL_PARAMETER_LIST, $4);
    $2->appendChildren($3);

    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($1);
    $$->appendChild($2);
  }
| T_EMPTY '(' variable ')' {
    NTYPE($1, n_SYMBOL_NAME);

    NSPAN($2, n_CALL_PARAMETER_LIST, $4);
    $2->appendChild($3);

    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($1);
    $$->appendChild($2);
  }
| T_INCLUDE expr {
    $$ = NTYPE($1, n_INCLUDE_FILE)->appendChild($2);
  }
| T_INCLUDE_ONCE expr {
    $$ = NTYPE($1, n_INCLUDE_FILE)->appendChild($2);
  }
| T_EVAL '(' expr ')' {
    NTYPE($1, n_SYMBOL_NAME);

    NSPAN($2, n_CALL_PARAMETER_LIST, $4);
    $2->appendChild($3);

    $$ = NNEW(n_FUNCTION_CALL);
    $$->appendChild($1);
    $$->appendChild($2);
  }
| T_REQUIRE expr {
    $$ = NTYPE($1, n_INCLUDE_FILE)->appendChild($2);
  }
| T_REQUIRE_ONCE expr {
    $$ = NTYPE($1, n_INCLUDE_FILE)->appendChild($2);
  }
;

isset_variables:
  variable {
    $$ = NNEW(n_EMPTY);
    $$->appendChild($1);
  }
| isset_variables ',' variable {
    $$ = $1->appendChild($3);
  }
;

class_constant:
  class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));
  }
| variable_class_name T_PAAMAYIM_NEKUDOTAYIM T_STRING {
    $$ = NNEW(n_CLASS_STATIC_ACCESS);
    $$->appendChild($1);
    $$->appendChild(NTYPE($3, n_STRING));
  }
;

//
// XHP Extensions

// Tags
expr_without_variable:
  xhp_tag_expression {
    yyextra->used = true;
    $$ = $1;
  }
;

xhp_tag_expression:
  xhp_singleton
| xhp_tag_open xhp_children xhp_tag_close {
    $$ = NNEW(n_XHP_TAG);
    $$->appendChild($1);
    $$->appendChild($2);
    $$->appendChild($3);
  }
;

xhp_singleton:
  xhp_tag_start xhp_attributes '/' '>' {
    pop_state(); // XHP_ATTRS

    $1->appendChild($2);
    NMORE($$, $4);

    $$ = NNEW(n_XHP_TAG)->appendChild($1);
    $$->appendChild(NNEW(n_EMPTY));
    $$->appendChild(NNEW(n_EMPTY));
  }
;

xhp_tag_open:
  xhp_tag_start xhp_attributes '>' {
    pop_state(); // XHP_ATTRS
    push_state(XHP_CHILD_START);
/* TODO: RESTORE THIS
    yyextra->pushTag((*($1->l_tok))->value.c_str());
*/
    yyextra->pushTag("TODO");

    $$ = $1->appendChild($2);
    NMORE($1, $3);
  }
;

xhp_tag_close:
  T_XHP_LT_DIV xhp_label_no_space '>' {
    pop_state(); // XHP_CHILD_START
/* TOOD: RESTORE THIS
    if (yyextra->peekTag() != (*($2->l_tok))->value.c_str()) {
      string e1 = (*($2->l_tok))->value.c_str();
      string e2 = yyextra->peekTag();
      replacestr(e1, "__", ":");
      replacestr(e1, "_", "-");
      replacestr(e2, "__", ":");
      replacestr(e2, "_", "-");
      string e = "syntax error, mismatched tag </" + e1 + ">, expecting </" + e2 +">";
      yyerror(yyscanner, NULL, e.c_str());
      yyextra->terminated = true;
    }
*/
    yyextra->popTag();
    if (yyextra->haveTag()) {
      set_state(XHP_CHILD_START);
    }

    $$ = NSPAN($1, n_XHP_TAG_CLOSE, $3);
  }
| T_XHP_LT_DIV_GT {
    // empty end tag -- SGML SHORTTAG
    pop_state(); // XHP_CHILD_START
    yyextra->popTag();
    if (yyextra->haveTag()) {
      set_state(XHP_CHILD_START);
    }
    $$ = NTYPE($1, n_XHP_TAG_CLOSE);
  }
;

xhp_tag_start:
  '<' xhp_label_immediate {
    $$ = NTYPE($1, n_XHP_TAG_OPEN);
    $$->appendChild($2);
  }
;

// Children
xhp_literal_text:
  T_XHP_TEXT {
    $$ = NTYPE($1, n_XHP_TEXT);
  }
| T_XHP_ENTITY {
    $$ = NTYPE($1, n_XHP_TEXT);
  }
| xhp_literal_text T_XHP_TEXT {
    $$ = NMORE($1, $2);
  }
| xhp_literal_text T_XHP_ENTITY {
    $$ = NMORE($1, $2);
  }
;

xhp_children:
  /* empty */ {
    $$ = NNEW(n_XHP_NODE_LIST);
  }
| xhp_literal_text {
    set_state(XHP_CHILD_START);
    $$ = NNEW(n_XHP_NODE_LIST)->appendChild($1);
  }
| xhp_children xhp_child {
    set_state(XHP_CHILD_START);
    $$ = $1->appendChild($2);
  }
| xhp_children xhp_child xhp_literal_text {
    set_state(XHP_CHILD_START);
    $$ = $1->appendChild($2)->appendChild($3);
  }
;

xhp_child:
  xhp_tag_expression
| '{' {
    push_state(PHP);
    yyextra->pushStack();
  } expr '}' {
    pop_state();
    yyextra->popStack();
  } {
    set_state(XHP_CHILD_START);
    $$ = NNEW(n_XHP_EXPRESSION);
    $$->appendChild($3);
    NEXPAND($1, $$, $4);
  }
;

// Attributes
xhp_attributes:
  /* empty */ {
    push_state(XHP_ATTRS);
    $$ = NNEW(n_XHP_ATTRIBUTE_LIST);
  }
| xhp_attributes xhp_attribute {
    $$ = $1->appendChild($2);
  }
;

xhp_attribute:
  xhp_label_pass '=' xhp_attribute_value {
    $$ = NNEW(n_XHP_ATTRIBUTE);
    $$->appendChild($1);
    $$->appendChild($3);
  }
;

xhp_attribute_value:
  '"' { push_state(XHP_ATTR_VAL); } xhp_attribute_quoted_value '"' {
    $$ = NSPAN($1, n_XHP_ATTRIBUTE_LITERAL, $4);
    $$->appendChild($3);
  }
| '{' { push_state(PHP); } expr { pop_state(); } '}' {
    $$ = NSPAN($1, n_XHP_ATTRIBUTE_EXPRESSION, $5);
    $$->appendChild($3);
  }
;

xhp_attribute_quoted_value:
  /* empty */ {
    $$ = NNEW(n_EMPTY);
  }
| xhp_literal_text {
    $$ = NTYPE($1, n_XHP_LITERAL);
  }
;

// Misc
xhp_label_immediate:
  { push_state(XHP_LABEL); } xhp_label_ xhp_whitespace_hack {
    pop_state();
    $$ = $2;
  }
;

xhp_label_no_space:
  { push_state(XHP_LABEL); } xhp_label_ {
    pop_state();
    $$ = $2;
  }
;

xhp_label_pass:
  { push_state(XHP_LABEL_WHITESPACE); } xhp_label_pass_ xhp_whitespace_hack {
    pop_state();
    $$ = $2;
  }
;

xhp_label_pass_immediate:
  { push_state(XHP_LABEL); } xhp_label_pass_ xhp_whitespace_hack {
    pop_state();
    $$ = $2;
  }
;

xhp_label:
  { push_state(XHP_LABEL_WHITESPACE); } xhp_label_ xhp_whitespace_hack {
    pop_state();
    $$ = $2;
  }
;

xhp_label_:
  T_STRING {
    // XHP_LABEL is popped in the scanner on " ", ">", "/", or "="
    push_state(XHP_LABEL);
    $$ = NTYPE($1, n_XHP_LITERAL);
  }
| xhp_label_ T_XHP_COLON T_STRING {
    $$ = NMORE($1, $3);
  }
| xhp_label_ T_XHP_HYPHEN T_STRING {
    $$ = NMORE($1, $3);
  }
;

xhp_label_pass_:
  T_STRING {
    // XHP_LABEL is popped in the scanner on " ", ">", "/", or "="
    push_state(XHP_LABEL);
    $$ = NTYPE($1, n_XHP_LITERAL);
  }
| xhp_label_pass_ T_XHP_COLON T_STRING {
    $$ = NMORE($1, $3);
  }
| xhp_label_pass_ T_XHP_HYPHEN T_STRING {
    $$ = NMORE($1, $3);
  }
;

xhp_whitespace_hack:
  T_XHP_WHITESPACE
| /* empty */
;

// Elements
class_declaration_statement:
  class_entry_type ':' xhp_label_immediate extends_from implements_list '{' {
    yyextra->expecting_xhp_class_statements = true;
    yyextra->used_attributes = false;
  } class_statement_list {
    yyextra->expecting_xhp_class_statements = false;
  } '}' {
    $$ = NNEW(n_CLASS_DECLARATION);
    $$->appendChild($1);
    $$->appendChild(NSPAN($2, n_STRING, $3));
    $$->appendChild($4);
    $$->appendChild($5);
    $$->appendChild($8);
    NMORE($$, $10);

    $$ = NNEW(n_STATEMENT)->appendChild($$);


//!    $$ = $1 + " xhp_" + $3 + $4 + $5 + $6 + $8;
//!    if (yyextra->used_attributes) {
//!      $$ = $$ +
//!        "protected static function &__xhpAttributeDeclaration() {" +
//!          "static $_ = -1;" +
//!          "if ($_ === -1) {" +
//!            "$_ = array_merge(parent::__xhpAttributeDeclaration(), " +
//!              yyextra->attribute_inherit +
//!              "array(" + yyextra->attribute_decls + "));" +
//!          "}" +
//!          "return $_;"
//!        "}";
//!    }
//!    $$ = $$ + $10;
    yyextra->used = true;
  }
;

// Element attribute declaration
class_statement:
  T_XHP_ATTRIBUTE { push_state(XHP_ATTR_TYPE_DECL); } xhp_attribute_decls ';' {
    pop_state();
    yyextra->used = true;
    yyextra->used_attributes = true;
//!    $$ = ""; // this will be injected when the class closes
  }
;

xhp_attribute_decls:
  xhp_attribute_decl {}
| xhp_attribute_decls ',' xhp_attribute_decl {}
;

xhp_attribute_decl:
  xhp_attribute_decl_type xhp_label_pass xhp_attribute_default xhp_attribute_is_required {
//!    $2.strip_lines();
//!    yyextra->attribute_decls = yyextra->attribute_decls +
//!      "'" + $2 + "'=>array(" + $1 + "," + $3 + ", " + $4 + "),"
  }
| T_XHP_COLON xhp_label_immediate {
//!    $2.strip_lines();
//!    yyextra->attribute_inherit = yyextra->attribute_inherit +
//!      "xhp_" + $2 + "::__xhpAttributeDeclaration(),";
  }
;

xhp_attribute_decl_type:
  T_XHP_STRING {
//!    $$ = "1, null";
  }
| T_XHP_BOOLEAN {
//!    $$ = "2, null";
  }
| T_XHP_NUMBER {
//!    $$ = "3, null";
  }
| T_XHP_ARRAY {
//!    $$ = "4, null";
  }
| class_name {
//!    $$ = "5, '" + $1 + "'";
  }
| T_VAR {
//!    $$ = "6, null";
  }
| T_XHP_ENUM '{' { push_state(PHP); } xhp_attribute_enum { pop_state(); } '}' {
//!    $$ = "7, array(" + $4 + ")";
  }
| T_XHP_FLOAT {
//! ...
}
;

xhp_attribute_enum:
  common_scalar {
//!    $1.strip_lines();
//!    $$ = $1;
  }
| xhp_attribute_enum ',' common_scalar {
//!    $3.strip_lines();
//!    $$ = $1 + ", " + $3;
  }
;

xhp_attribute_default:
  '=' static_scalar {
//!    $2.strip_lines();
//!    $$ = $2;
  }
| /* empty */ {
//!    $$ = "null";
  }
;

xhp_attribute_is_required:
  T_XHP_REQUIRED {
//!    $$ = "1";
  }
| /* empty */ {
//!    $$ = "0";
  }
;

// Element category declaration
class_statement:
  T_XHP_CATEGORY { push_state(PHP_NO_RESERVED_WORDS_PERSIST); } xhp_category_list ';' {
    pop_state();
    yyextra->used = true;
//!    $$ =
//!      "protected function &__xhpCategoryDeclaration() { \  !!!
//!         static $_ = array(" + $3 + ");" +
//!        "return $_;" +
//!      "}";
  }
;

xhp_category_list:
  '%' xhp_label_pass_immediate {
//!    $$ = "'" + $2 + "' => 1";
  }
| xhp_category_list ',' '%' xhp_label_pass_immediate {
//!    $$ = $1 + ",'" + $4 + "' => 1";
  }
;

// Element child list
class_statement:
  T_XHP_CHILDREN { push_state(XHP_CHILDREN_DECL); } xhp_children_decl ';' {
    // XHP_CHILDREN_DECL is popped in the scanner on ';'
    yyextra->used = true;
//!    $$ = "protected function &__xhpChildrenDeclaration() {" + $3 + "}";
  }
;

xhp_children_decl:
  xhp_children_paren_expr {
//!    $$ = "static $_ = " + $1 + "; return $_;";
  }
| T_XHP_ANY {
//!    $$ = "static $_ = 1; return $_;";
  }
| T_XHP_EMPTY {
//!    $$ = "static $_ = 0; return $_;";
  }
;

xhp_children_paren_expr:
  '(' xhp_children_decl_expr ')' {
//!    $$ = "array(0, 5, " + $2 + ")";
  }
| '(' xhp_children_decl_expr ')' '*' {
//!    $$ = "array(1, 5, " + $2 + ")";
  }
| '(' xhp_children_decl_expr ')' '?' {
//!    $$ = "array(2, 5, " + $2 + ")";
  }
| '(' xhp_children_decl_expr ')' '+' {
//!    $$ = "array(3, 5, " + $2 + ")";
  }
;

xhp_children_decl_expr:
  xhp_children_paren_expr
| xhp_children_decl_tag {
//!    $$ = "array(0, " + $1 + ")";
  }
| xhp_children_decl_tag '*' {
//!    $$ = "array(1, " + $1 + ")";
  }
| xhp_children_decl_tag '?' {
//!    $$ = "array(2, " + $1 + ")";
  }
| xhp_children_decl_tag '+' {
//!    $$ = "array(3, " + $1 + ")";
  }
| xhp_children_decl_expr ',' xhp_children_decl_expr {
//!    $$ = "array(4, " + $1 + "," + $3 + ")"
  }
| xhp_children_decl_expr '|' xhp_children_decl_expr {
//!    $$ = "array(5, " + $1 + "," + $3 + ")"
  }
;

xhp_children_decl_tag:
  T_XHP_ANY {
//!    $$ = "1, null";
  }
| T_XHP_PCDATA {
//!    $$ = "2, null";
  }
| T_XHP_COLON xhp_label {
//!    $$ = "3, \'xhp_" + $2 + "\'";
  }
| '%' xhp_label {
//!    $$ = "4, \'" + $2 + "\'";
  }
;

// Make XHP classes usable anywhere you see a real class
class_name:
  T_XHP_COLON xhp_label_immediate {
    pop_state();
    push_state(PHP);
    yyextra->used = true;
    NTYPE($1, n_CLASS_NAME);
    NMORE($1, $2);
    $$ = $1;
  }
;

fully_qualified_class_name:
  T_XHP_COLON xhp_label_immediate {
    pop_state();
    push_state(PHP);
    yyextra->used = true;
    NTYPE($1, n_CLASS_NAME);
    NMORE($1, $2);
    $$ = $1;
  }
;

// Fix the "bug" in PHP's grammar where you can't chain the [] operator on a
// function call.
// This introduces some shift/reduce conflicts. We want the shift here to fall
// back to regular PHP grammar. In the case where it's an extension of the PHP
// grammar our code gets picked up.
expr_without_variable:
  expr '[' dim_offset ']' {
    if (yyextra->idx_expr) {
      yyextra->used = true;
    }
    $$ = NNEW(n_INDEX_ACCESS);
    $$->appendChild($1);
    $$->appendChild($3);
    NMORE($$, $4);
  }
;


%%

const char* yytokname(int tok) {
  if (tok < 255) {
    return NULL;
  }
  return yytname[YYTRANSLATE(tok)];
}
