/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

%require "3.3.2"
%language "C++"

%define api.namespace {shipwright::_parser}
%define api.value.type variant
%define api.value.automove

%code requires {
#include <shipwright/ast/ast.hpp>
#include <shipwright/lexer.hpp>
}

%parse-param {lexer::iterator first} {lexer::iterator last}
%lex-param {lexer::iterator& first} {lexer::iterator last}

%code {
#include <algorithm>
#include <iostream>
#include <iterator>
#include <string_view>

#include <shipwright/token.hpp>

using shipwright::token_type;
namespace yy = shipwright::_parser;

#include <type_traits>

namespace {
    int as_bison(token_type type);
}

namespace shipwright::_parser {
    int yylex(parser::semantic_type* token_value, lexer::iterator& first, lexer::iterator last) {
        if (first == last) return 0; // EOF

        auto token = *first++;

        if (token.type == token_type::bracket_argument || token.type == token_type::bracket_comment) {
            auto first_bracket = std::find(token.full_text.begin(), token.full_text.end(), '[');
            auto next_bracket = std::find(std::next(first_bracket), token.full_text.end(), '[');

            token_value->emplace<shipwright::ast::bracket_argument>(shipwright::ast::bracket_argument{
                token.text,
                std::distance(first_bracket, next_bracket) - 1,
            });
        } else {
            token_value->emplace<std::string_view>(token.text);
        }

        return as_bison(token.type);
    }

    void yyerror(char const* msg) {
        std::cerr << msg << '\n';
    }
}
}

%token <std::string_view>                   SPACE
%token                                      NEWLINE
%token <std::string_view>                   IDENTIFIER
%token                                      LPAREN  '('
%token                                      RPAREN  ')'

%token <shipwright::ast::bracket_argument>  BRACKET_ARGUMENT


%token <std::string_view>                   QUOTED_ARGUMENT
%token <std::string_view>                   UNQUOTED_ARGUMENT

%token <shipwright::ast::bracket_argument>  BRACKET_COMMENT
%token <std::string_view>                   LINE_COMMENT

%token                                      UNKNOWN
%token                                      UNTERMINATED_BRACKET
%token                                      UNTERMINATED_QUOTE
%token                                      ERROR

%start file
%%

%type <shipwright::ast::file> file;
file:
    file file_element                           { $$ = $1; $$.elements.push_back($2); }
    | %empty                                    { $$ = shipwright::ast::file{}; }
;

%type <shipwright::ast::file_element> file_element;
file_element:
    command_invocation line_ending              { $$ = shipwright::ast::file_element{$1, $2}; }
    | space_or_comment_element line_ending      { $$ = shipwright::ast::file_element{$1, $2}; }
;

%type <shipwright::ast::command_invocation> command_invocation;
command_invocation:
    allow_spaces identifier[id] allow_spaces parenthesized_argument[pargs]
                                                { $$ = shipwright::ast::command_invocation{$id, $pargs.values}; }
;

%type <std::vector<shipwright::ast::bracket_comment>> space_or_comment_element;
space_or_comment_element:
    space_or_comment_element bracket_comment    { $$ = $1; $$.push_back($2); }
    | allow_spaces                              { $$ = {}; }
;

%type <std::optional<shipwright::ast::line_comment>> line_ending;
line_ending:
    line_comment NEWLINE                        { $$ = $1; }
    | NEWLINE                                   { $$ = std::nullopt; }
;

%type <shipwright::ast::argument> normal_argument;
normal_argument:
    bracket_argument                            { $$ = shipwright::ast::argument{$1}; }
    | quoted_argument                           { $$ = shipwright::ast::argument{$1}; }
    | unquoted_argument                         { $$ = shipwright::ast::argument{$1}; }
;

%type <shipwright::ast::argument> argument;
argument:
    normal_argument                             { $$ = $1; }
    | parenthesized_argument                    { $$ = shipwright::ast::argument{$1}; }
    | line_comment                              { $$ = shipwright::ast::argument{$1}; }
    | bracket_comment                           { $$ = shipwright::ast::argument{$1}; }
;

separation:
    SPACE | NEWLINE
;

%type <std::vector<shipwright::ast::argument>> arguments;
arguments:
    arguments argument[arg]                     { $$ = $1; $$.push_back($arg); }
    | arguments separation                      { $$ = $1; }
    | %empty                                    { $$ = {}; }
;

%type <shipwright::ast::parenthesized_argument> parenthesized_argument;
parenthesized_argument:
    '(' arguments[args] ')'                     { $$ = shipwright::ast::parenthesized_argument{$args}; }
;

%type <shipwright::ast::bracket_argument> bracket_argument;
bracket_argument:
    BRACKET_ARGUMENT                            { $$ = $1; }
;

%type <shipwright::ast::quoted_argument> quoted_argument;
quoted_argument:
    QUOTED_ARGUMENT                             { $$ = shipwright::ast::quoted_argument{$1}; }
;

%type <shipwright::ast::unquoted_argument> unquoted_argument;
unquoted_argument:
    UNQUOTED_ARGUMENT                           { $$ = shipwright::ast::unquoted_argument{$1}; }
;

%type <shipwright::ast::line_comment> line_comment;
line_comment:
    LINE_COMMENT                                { $$ = shipwright::ast::line_comment{$1}; }
;

%type <shipwright::ast::bracket_comment> bracket_comment;
bracket_comment:
    BRACKET_COMMENT                             { $$ = shipwright::ast::bracket_comment{$1}; }
;

%type <shipwright::ast::identifier> identifier;
identifier:
    IDENTIFIER                                  { $$ = shipwright::ast::identifier{$1}; }
;

allow_spaces:
    allow_spaces SPACE
    | %empty
;
%%

namespace {
    int as_bison(token_type type) {
        using bison_token = yy::parser::token;

        switch (type) {
        case token_type::unknown: return bison_token::UNKNOWN;
        case token_type::space: return bison_token::SPACE;
        case token_type::newline: return bison_token::NEWLINE;
        case token_type::identifier: return bison_token::IDENTIFIER;
        case token_type::lparen: return bison_token::LPAREN;
        case token_type::rparen: return bison_token::RPAREN;

        case token_type::bracket_argument: return bison_token::BRACKET_ARGUMENT;
        case token_type::quoted_argument: return bison_token::QUOTED_ARGUMENT;
        case token_type::unquoted_argument: return bison_token::UNQUOTED_ARGUMENT;

        case token_type::bracket_comment: return bison_token::BRACKET_COMMENT;
        case token_type::line_comment: return bison_token::LINE_COMMENT;

        case token_type::unterminated_bracket: return bison_token::UNTERMINATED_BRACKET;
        case token_type::unterminated_quote: return bison_token::UNTERMINATED_QUOTE;
        default:
#ifndef NDEBUG
            std::cerr << __FILE__ << ':' << __LINE__ << ": Unhandled token " << shipwright::debug_print(type) << '\n';
#endif
            return bison_token::ERROR;
        }
    }
}
