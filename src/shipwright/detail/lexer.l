/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

%{
#include <cstddef>
#include <utility>

#include <shipwright/detail/lexer.hpp>

struct shipwright_cmake_lexer_impl_extra_vars
{
    std::size_t current_position = 0;
    std::size_t token_length = 0;

    std::size_t full_current_position = 0;
    std::size_t full_token_length = 0;

    std::size_t bracket_count = 0;

    shipwright::token_type type = shipwright::token_type::unknown;

    void update_position(std::size_t length, std::size_t submatch_offset,
                         std::size_t submatch_length) {
        increment_position(length);
        current_position += submatch_offset;
        token_length = submatch_length;
    }

    void increment_position(std::size_t length) {
        current_position += token_length;
        token_length = length;

        full_current_position += full_token_length;
        full_token_length = length;
    }
};
%}

%option reentrant
%option extra-type="shipwright_cmake_lexer_impl_extra_vars"
%option prefix="shipwright_cmake_lexer_impl"
%option noyywrap
%pointer

space [ \t]+
identifier [A-Za-z_][A-Za-z0-9_]*

%%

{space} {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::space;
    return 1;
}

\n {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::newline;
    return 1;
}

{identifier} {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::identifier;
    return 1;
}

\( {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::lparen;
    return 1;
}

\) {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::rparen;
    return 1;
}

#.* {
    yyextra.update_position(yyleng, 1, yyleng - 1);
    yyextra.type = shipwright::token_type::line_comment;
    return 1;
}

%%

namespace shipwright::detail {
    lexer::lexer(std::string_view input)
        : input_{input}
    {
        yylex_init(&lexer_);
        yy_scan_bytes(input.data(), input.size(), lexer_);
    }

    lexer::~lexer()
    {
        yylex_destroy(lexer_);
        lexer_ = nullptr;
    }

    bool lexer::advance()
    {
        return yylex(lexer_) != 0;
    }

    token lexer::read() const
    {
        auto const extra = yyget_extra(lexer_);

        return token{
            input_.substr(extra.current_position, extra.token_length),
            extra.type,
            input_.substr(extra.full_current_position, extra.full_token_length),
        };
    }
}
