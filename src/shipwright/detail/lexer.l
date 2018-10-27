/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

%{
#include <shipwright/detail/lexer.hpp>

#include <iostream>
%}

%option reentrant
%option prefix="shipwright_cmake_lexer_impl"

%option yylineno
%option noyywrap
%pointer

space [ \t]+
identifier [A-Za-z_][A-Za-z0-9_]*

%%

{identifier} std::cout << yytext << '\n';

%%

namespace shipwright::detail {
    lexer::lexer()
    {
        yylex_init(&lexer_);
    }

    lexer::~lexer()
    {
        yylex_destroy(lexer_);
        lexer_ = nullptr;
    }

    bool lexer::advance()
    {
        yylex(lexer_);
    }

    std::string_view lexer::read() const
    {
        return yyget_text(lexer_);
    }
}
