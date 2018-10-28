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

    union {
        std::size_t bracket_count;
        std::size_t variable_reference_depth;
    };

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

    void increment_position(std::size_t length) {
        full_current_position += full_token_length;
        full_token_length = length;

        current_position = full_current_position;
        token_length = length;
    }
};
%}

%option reentrant
%option extra-type="shipwright_cmake_lexer_impl_extra_vars"
%option prefix="shipwright_cmake_lexer_impl"
%option noyywrap
%pointer
%x LINE_COMMENT
%x BRACKET
%x BRACKET_CLOSE
%x QUOTE
%x VARIABLE_REFERENCE

escape_identity \\[^A-Za-z0-9;]
escape_encoded \\[trn]
escape_semicolon \\;
escape_sequence {escape_identity}|{escape_encoded}|{escape_semicolon}

quoted_continuation \\\n
quoted_element {escape_sequence}|{quoted_continuation}

%%

[ \t]+ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::space;
    return 1;
}

\n {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::newline;
    return 1;
}

[A-Za-z_][A-Za-z0-9_]* {
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

\" {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::quote;
    BEGIN(QUOTE);
    return 1;
}

<QUOTE>\" {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::quote;
    BEGIN(INITIAL);
    return 1;
}

<QUOTE>([^\\"$]|{escape_sequence}|{quoted_continuation})* {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::quoted_piece;
    return 1;
}

<QUOTE>\$ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::quoted_piece;
    return 1;
}

<INITIAL,QUOTE,VARIABLE_REFERENCE>\$\{ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::variable_reference_open;

    yyextra.start_condition = YY_START;
    if (YY_START == VARIABLE_REFERENCE) {
        yyextra.variable_reference_depth += 1;
    } else {
        yyextra.variable_reference_depth = 0;
    }
    BEGIN(VARIABLE_REFERENCE);
    return 1;
}

<VARIABLE_REFERENCE>({escape_sequence}|[A-Za-z/_\.+-])+ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::variable_reference_piece;
    return 1;
}

<VARIABLE_REFERENCE>\$ {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::variable_reference_piece;
    return 1;
}

<VARIABLE_REFERENCE>\} {
    yyextra.increment_position(yyleng);
    yyextra.type = shipwright::token_type::variable_reference_close;

    if (yyextra.variable_reference_depth == 0) {
        BEGIN(yyextra.start_condition);
    } else {
        yyextra.variable_reference_depth -= 1;
    }

    return 1;
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

    shipwright::token read_token(
        std::string_view input,
        shipwright_cmake_lexer_impl_extra_vars const& extra)
    {
        return shipwright::token {
            input.substr(extra.current_position, extra.token_length),
            extra.type,
            input.substr(extra.full_current_position, extra.full_token_length),
        };
    }
}

namespace shipwright::detail {
    lexer::lexer(std::string_view input)
        : input_{input}
    {
        yylex_init(&lexer_);
        yy_scan_bytes(input.data(), input.size(), lexer_);

        lookahead_result_ = yylex(lexer_) != 0;

        auto const extra = yyget_extra(lexer_);
        lookahead_token_ = token{
            input_.substr(extra.current_position, extra.token_length),
            extra.type,
            input_.substr(extra.full_current_position, extra.full_token_length),
        };
    }

    lexer::~lexer()
    {
        yylex_destroy(lexer_);
        lexer_ = nullptr;
    }

    bool lexer::advance()
    {
        if (!lookahead_result_) return lookahead_result_;

        current_token_ = std::move(lookahead_token_);

        auto const result = std::exchange(lookahead_result_, yylex(lexer_) != 0);
        if (!lookahead_result_) return result;

        auto extra = yyget_extra(lexer_);

        lookahead_token_ = ::read_token(input_, extra);

        while (lookahead_token_.type == current_token_.type
                && (current_token_.type == token_type::variable_reference_piece
                    || current_token_.type == token_type::quoted_piece)) {
            ::join_token(current_token_, lookahead_token_);

            lookahead_result_ = yylex(lexer_) != 0;
            if (!lookahead_result_) {
                return lookahead_result_;
            }

            extra = yyget_extra(lexer_);

            lookahead_token_ = ::read_token(input_, extra);
        }

        return result;
    }

    token lexer::read() const
    {
        return current_token_;
    }
}
