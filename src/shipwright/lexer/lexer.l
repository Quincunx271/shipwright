/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */


/*
Some sections of code are borrowed from the CMake source code itself.
Most of the regular expressions come from the CMake source, as do the start conditions.
The full region of code from the CMake project will be delimited by comments
with the following text (less the bullet points):

* From CMake source code: Source/LexerParser/cmListFileLexer.in.l
* End of copied CMake source code

Within those comments, any region of code which is *not* CMake code will be
delimited by comments with the following text (less the bullet points):

* Not CMake source code:
* CMake source code:

CMake source code falls under CMake's license: the BSD 3-Clause license:

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
%option nounistd
%pointer

/* From CMake source code: Source/LexerParser/cmListFileLexer.in.l */
%x STRING
%x BRACKET
%x BRACKETEND
%x COMMENT

MAKEVAR \$\([A-Za-z0-9_]*\)
UNQUOTED ([^ \0\t\r\n\(\)#\\\"[=]|\\[^\0\n])
LEGACY {MAKEVAR}|{UNQUOTED}|\"({MAKEVAR}|{UNQUOTED}|[ \t[=])*\"

%%

    /* Not CMake source code: */
\n {
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::newline;
    return 1;
}
    /* CMake source code: */

#?\[=*\[\n? {
    /* Not CMake source code: */
    bool const is_comment = yytext[0] == '#';

    yyextra.type = is_comment ? shipwright::token_type::bracket_comment
                              : shipwright::token_type::bracket_argument;

    // Number of `=`s in the bracket
    yyextra.bracket_count = yyleng - 2;
    if (is_comment) yyextra.bracket_count -= 1;

    // Reset token
    yyextra.increment_position(0);

    // Update token content
    yyextra.full_token_length += yyleng;
    yyextra.current_position += yyleng;

    BEGIN(BRACKET);
}
    /* CMake source code: */

# {
    /* Not CMake source code: */
    yyextra.update_position(yyleng, 1, yyleng - 1);
    yyextra.type = shipwright::token_type::line_comment;
    BEGIN(COMMENT);
}
    /* CMake source code: */

<COMMENT>[^\0\n]* {
    /* Not CMake source code: */
    yyextra.extend_match(yyleng);
    BEGIN(INITIAL);
    return 1;
}
    /* CMake source code: */

\( {
    /* Not CMake source code: */
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::lparen;
    return 1;
}
    /* CMake source code: */

\) {
    /* Not CMake source code: */
    yyextra.increment_only_full_position(yyleng);
    yyextra.type = shipwright::token_type::rparen;
    return 1;
}
    /* CMake source code: */

[A-Za-z_][A-Za-z0-9_]* {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::identifier;
    return 1;
}
    /* Not CMake source code: */

<BRACKET>\] {
    yyextra.extend_match(yyleng);
    BEGIN(BRACKETEND);
}

<BRACKET>[^\]]* {
    yyextra.extend_match(yyleng);
}

<BRACKETEND>=*\] {
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

<BRACKETEND>. {
    yyextra.extend_match(yyleng);
    BEGIN(BRACKET);
}
    /* CMake source code: */

<BRACKET,BRACKETEND><<EOF>> {
    /* Not CMake source code: */
    yyextra.increment_position(0);
    yyextra.type = shipwright::token_type::unterminated_bracket;
    BEGIN(INITIAL);
    return 1;
}
    /* CMake source code: */

({UNQUOTED}|=|\[=*{UNQUOTED})({UNQUOTED}|[[=])* {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}
    /* CMake source code: */

({MAKEVAR}|{UNQUOTED}|=|\[=*{LEGACY})({LEGACY}|[[=])* {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}
    /* CMake source code: */

\[ {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unquoted_argument;
    return 1;
}
    /* CMake source code: */

\" {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.current_position += yyleng;
    yyextra.type = shipwright::token_type::quoted_argument;
    BEGIN(STRING);
}
    /* CMake source code: */

<STRING>([^\\\0\n\"]|\\[^\0\n])+ {
    /* Not CMake source code: */
    yyextra.extend_match(yyleng);
}
    /* CMake source code: */

<STRING>\\\n {
    /* Not CMake source code: */
    yyextra.extend_match(yyleng);
}
    /* CMake source code: */

<STRING>\n {
    /* Not CMake source code: */
    yyextra.extend_match(yyleng);
}
    /* CMake source code: */

<STRING>\" {
    /* Not CMake source code: */
    yyextra.extend_full_match(yyleng);
    yyextra.token_length -= yyleng;
    BEGIN(INITIAL);
    return 1;
}
    /* CMake source code: */

<STRING>[^\0\n] {
    /* Not CMake source code: */
    yyextra.extend_match(yyleng);
}
    /* CMake source code: */

<STRING><<EOF>> {
    /* Not CMake source code: */
    yyextra.increment_position(0);
    yyextra.type = shipwright::token_type::unterminated_quote;
    BEGIN(INITIAL);
    return 1;
}
    /* CMake source code: */

[ \t\r]+ {
    /* Not CMake source code: */
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::space;
    return 1;
}
    /* CMake source code: */

    /* Not CMake source code: */
<*>. {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::unknown;
    return 1;
}
    /* CMake source code: */

<<EOF>> {
    /* Not CMake source code: */
    yyextra.increment_position(0);
    yyextra.type = shipwright::token_type::end_of_file;
    return 0;
}

    /* End of copied CMake source code */
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
