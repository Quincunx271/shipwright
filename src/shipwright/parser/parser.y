/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

%require "3.3.2"
%language "C++"

%define api.namespace {shipwright::_parser}
%define api.value.type variant

%code requires {
#include <algorithm>
#include <iterator>

#include <shipwright/ast/ast.hpp>
#include <shipwright/lexer.hpp>

namespace ast = shipwright::ast;
}

%parse-param {lexer::iterator first} {lexer::iterator last}
%lex-param {lexer::iterator& first} {lexer::iterator last}

%code {
#include <iostream>
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

            token_value->emplace<ast::bracket_argument>(ast::bracket_argument{
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

%token                              SPACE
%token                              NEWLINE
%token <std::string_view>           IDENTIFIER
%token                              LPAREN
%token                              RPAREN

%token <ast::bracket_argument>      BRACKET_ARGUMENT


%token <std::string_view>           QUOTED_ARGUMENT
%token <std::string_view>           UNQUOTED_ARGUMENT

%token <ast::bracket_argument>      BRACKET_COMMENT
%token <std::string_view>           LINE_COMMENT

%token UNKNOWN
%token UNTERMINATED_BRACKET
%token UNTERMINATED_QUOTE
%token ERROR

%start file
%%

file:;

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
