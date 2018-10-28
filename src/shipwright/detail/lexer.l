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
    std::size_t current_pos = 0;
    std::size_t last_pos = 0;

    shipwright::token_type type = shipwright::token_type::unknown;

    void increment_pos(std::size_t offset) {
        last_pos = std::exchange(current_pos, current_pos + offset);
    }
};

#define YY_USER_ACTION do {                                \
        yyextra.increment_pos(yyleng);                     \
        yyextra.type = shipwright::token_type::unknown;    \
    } while (false);
%}

%option reentrant
%option extra-type="shipwright_cmake_lexer_impl_extra_vars"
%option prefix="shipwright_cmake_lexer_impl"
%option noyywrap
%pointer

space [ \t]+
identifier [A-Za-z_][A-Za-z0-9_]*

%%

\n {
    yyextra.type = shipwright::token_type::newline;
    return 1;
}

{space} {
    yyextra.type = shipwright::token_type::space;
    return 1;
}

{identifier} {
    yyextra.type = shipwright::token_type::identifier;
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
            input_.substr(extra.last_pos, extra.current_pos - extra.last_pos),
            extra.type,
        };
    }
}
