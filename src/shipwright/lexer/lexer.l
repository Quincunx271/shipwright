/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */


/*
Some sections of code are borrowed from the CMake source code itself.
Copied segments will be delimited by comments with the following text:
"Copied with modifications from Source/LexerParser/cmListFileLexer.in.l"
"End of copied CMake source code"
Following is CMake's license (BSD 3-Clause):

--------------------------------------------------------------------------------

CMake - Cross Platform Makefile Generator
Copyright 2000-2018 Kitware, Inc. and Contributors
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name of Kitware, Inc. nor the names of Contributors
  may be used to endorse or promote products derived from this
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

%{
#include <cassert>
#include <cstddef>
#include <iterator>
#include <limits>
#include <optional>
#include <utility>

#include <shipwright/lexer/lexer.hpp>

struct shipwright_cmake_lexer_impl_extra_vars
{
    std::size_t current_position = 0;
    std::size_t token_length = 0;

    std::size_t full_current_position = 0;
    std::size_t full_token_length = 0;

    std::size_t bracket_count = 0;
    std::size_t variable_reference_depth = 0;
    std::size_t make_reference_depth = 0;

    shipwright::token_type type = shipwright::token_type::unknown;

    int start_condition = 0;

    void update_position(std::size_t length, std::size_t submatch_offset,
                         std::size_t submatch_length) {
        increment_position(length);
        current_position += submatch_offset;
        token_length = submatch_length;
    }

    void extend_match(std::size_t length) {
        token_length += length;
        full_token_length += length;
    }

    void extend_full_match(std::size_t length) {
        full_token_length += length;
    }

    void increment_position(std::size_t length) {
        full_current_position += full_token_length;
        full_token_length = length;

        current_position = full_current_position;
        token_length = length;
    }

    void increment_only_full_position(std::size_t length) {
        increment_position(length);
        token_length = 0;
    }
};
%}

%option reentrant
%option extra-type="shipwright_cmake_lexer_impl_extra_vars"
%option prefix="shipwright_cmake_lexer_impl"
%option noyywrap
%option never-interactive
%pointer
%x LINE_COMMENT
%x BRACKET
%x BRACKET_CLOSE
%x QUOTE

escape_identity \\[^A-Za-z0-9;]
escape_encoded \\[trn]
escape_semicolon \\;
escape_sequence {escape_identity}|{escape_encoded}|{escape_semicolon}

quoted_continuation \\\n

/* Copied with modifications from Source/LexerParser/cmListFileLexer.in.l */

unquoted_makevar \$\([A-Za-z0-9_]*\)
unquoted ([^ \0\t\r\n\(\)#\\\"[=]|{escape_sequence})
unquoted_legacy {unquoted_makevar}|{unquoted}|\"({unquoted_makevar}|{unquoted}|[ \t[=])*\"

/* End of copied CMake source code */

%%

[ \t]+ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::space;
    return 1;
}

\n {
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::newline;
    return 1;
}

[A-Za-z_][A-Za-z0-9_]* {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::identifier;
    return 1;
}

\( {
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::lparen;
    return 1;
}

\) {
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::rparen;
    return 1;
}

# {
    // Split in two to lower the precedence of this match
    yyextra.update_position(yyleng, 1, yyleng - 1);
    yyextra.type = shipwright::token_type::line_comment;
    BEGIN(LINE_COMMENT);
}

<LINE_COMMENT>.* {
    yyextra.extend_match(yyleng);
    BEGIN(INITIAL);
    return 1;
}

#?\[=*\[ {
    bool const is_comment = yytext[0] == '#';

    yyextra.type = is_comment ? shipwright::token_type::bracket_comment
                              : shipwright::token_type::bracket_argument;
    yyextra.bracket_count = yyleng - 2;
    if (is_comment) yyextra.bracket_count -= 1;

    yyextra.increment_position(0);
    yyextra.full_token_length += yyleng;
    yyextra.current_position += yyleng;
    BEGIN(BRACKET);
}

<BRACKET>\] {
    yyextra.extend_match(yyleng);
    BEGIN(BRACKET_CLOSE);
}

<BRACKET>[^\]]* {
    yyextra.extend_match(yyleng);
}

<BRACKET_CLOSE>=*\] {
    if (yyextra.bracket_count == static_cast<std::size_t>(yyleng - 1)) {
        yyextra.extend_match(yyleng);
        yyextra.token_length -= yyleng + 1; // Subtract the bracket_close

        BEGIN(INITIAL);
        return 1;
    } else {
        yyextra.extend_match(yyleng);
        BEGIN(BRACKET);
    }
}

<BRACKET_CLOSE>. {
    yyextra.extend_match(yyleng);
    BEGIN(BRACKET);
}

    /* Copied with modifications from Source/LexerParser/cmListFileLexer.in.l */
({unquoted}|=|\[=*{unquoted})({unquoted}|[[=])* {
    /* End of copied CMake source code */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}

    /* Copied with modifications from Source/LexerParser/cmListFileLexer.in.l */
({unquoted_makevar}|{unquoted}|=|\[=*{unquoted_legacy})({unquoted_legacy}|[[=])* {
    /* End of copied CMake source code */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}

    /* Copied with modifications from Source/LexerParser/cmListFileLexer.in.l */
\[ {
    /* End of copied CMake source code */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}

\" {
    yyextra.increment_position(yyleng);
    yyextra.current_position += yyleng;
    yyextra.type = shipwright::token_type::quoted_argument;
    BEGIN(QUOTE);
}

<QUOTE>\" {
    yyextra.extend_full_match(yyleng);
    yyextra.token_length -= yyleng;
    BEGIN(INITIAL);
    return 1;
}

<QUOTE>([^\\"]|{escape_sequence}|{quoted_continuation})* {
    yyextra.extend_match(yyleng);
}

<*>. {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unknown;
    return 1;
}

%%

namespace {
    void join_token(shipwright::token& lhs, shipwright::token const& rhs) {
        lhs.text = std::string_view {
            lhs.text.data(),
            lhs.text.size() + rhs.text.size(),
        };
        lhs.full_text = std::string_view {
            lhs.full_text.data(),
            lhs.full_text.size() + rhs.full_text.size(),
        };
    }

    shipwright::token extract_token(
        std::string_view input,
        shipwright_cmake_lexer_impl_extra_vars const& extra)
    {
        return shipwright::token {
            input.substr(extra.current_position, extra.token_length),
            extra.type,
            input.substr(extra.full_current_position, extra.full_token_length),
        };
    }

    std::optional<shipwright::token>
    read_token(std::string_view input, void* lexer)
    {
        bool success = yylex(lexer) != 0;
        if (!success) return std::nullopt;

        auto const extra = yyget_extra(lexer);
        return ::extract_token(input, extra);
    }
}

namespace shipwright {
    lexer::lexer(std::string_view input)
        : input_{input}
    {
        yylex_init(&lexer_);
        assert(input_.size() < std::numeric_limits<int>::max());
        yy_scan_bytes(input_.data(), static_cast<int>(input_.size()), lexer_);

        advance();
    }

    lexer::~lexer()
    {
        yylex_destroy(lexer_);
        lexer_ = nullptr;
    }

    void lexer::advance()
    {
        current_token_ = ::read_token(input_, lexer_);
    }

    bool lexer::has_next() const
    {
        return current_token_.has_value();
    }

    token const& lexer::read() const
    {
        return *current_token_;
    }
}
