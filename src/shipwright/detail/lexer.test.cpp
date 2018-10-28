/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./lexer.hpp"

#include <shipwright/token.test.hpp>

#include <catch2/catch.hpp>

#include <initializer_list>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using shipwright::token;
using shipwright::token_type;

TEST_CASE("Can parse individual tokens", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, token>({
        {" ", token{" ", token_type::space, " "}},
        {"\t", token{"\t", token_type::space, "\t"}},
        {"\t \t", token{"\t \t", token_type::space, "\t \t"}},
        {"\n", token{"\n", token_type::newline, "\n"}},
        {"(", token{"(", token_type::lparen, "("}},
        {")", token{")", token_type::rparen, ")"}},
        {"# some comment",
            token{" some comment", token_type::line_comment, "# some comment"}},
        {"[[some bracket argument]]",
            token{"some bracket argument", token_type::bracket_argument,
                "[[some bracket argument]]"}},
        {"[=[some bracket argument]=]",
            token{"some bracket argument", token_type::bracket_argument,
                "[=[some bracket argument]=]"}},
        {"[==[some bracket ]=] argument]==]",
            token{"some bracket ]=] argument", token_type::bracket_argument,
                "[==[some bracket ]=] argument]==]"}},
        {"[==[some bracket ] argument]==]",
            token{"some bracket ] argument", token_type::bracket_argument,
                "[==[some bracket ] argument]==]"}},
        {"[=[some bracket\n argument]=]",
            token{"some bracket\n argument", token_type::bracket_argument,
                "[=[some bracket\n argument]=]"}},
        {"#[=[some bracket\n comment]=]",
            token{"some bracket\n comment", token_type::bracket_comment,
                "#[=[some bracket\n comment]=]"}},
        {"\"", token{"\"", token_type::quote, "\""}},
    }));

    CAPTURE(input, expected);

    shipwright::detail::lexer lex{input};

    REQUIRE(lex.advance());
    auto result = lex.read();

    CHECK(result == expected);

    REQUIRE_FALSE(lex.advance());
}

TEST_CASE("Can parse multiple tokens", "[lexer]")
{
    static auto const test_values = std::initializer_list<
        std::tuple<std::string, token, std::set<token_type>>>{
        {" ", token{" ", token_type::space, " "}, std::set{token_type::space}},
        {"\n", token{"\n", token_type::newline, "\n"}, {}},
        {"(", token{"(", token_type::lparen, "("}, {}},
        {")", token{")", token_type::rparen, ")"}, {}},
        {
            "# some comment",
            token{" some comment", token_type::line_comment, "# some comment"},
            std::set{
                token_type::space,
                token_type::lparen,
                token_type::rparen,
                token_type::line_comment,
                token_type::bracket_argument,
                token_type::bracket_comment,
            },
        },
        {
            "[=[some bracket\n argument]=]",
            token{"some bracket\n argument", token_type::bracket_argument,
                "[=[some bracket\n argument]=]"},
            {},
        },
        {
            "#[=[some bracket\n comment]=]",
            token{"some bracket\n comment", token_type::bracket_comment,
                "#[=[some bracket\n comment]=]"},
            {},
        },
    };

    auto [first, first_expected, ignore_succeeding]
        = GENERATE(values(test_values));
    auto [second, second_expected, ignore] = GENERATE(values(test_values));
    (void)ignore;

    if (ignore_succeeding.count(second_expected.type)) {
        SUCCEED();
    } else {
        auto const input = first + second;
        CAPTURE(input, first_expected, second_expected);

        shipwright::detail::lexer lex{input};

        REQUIRE(lex.advance());
        auto const first_r = lex.read();

        CHECK(first_r == first_expected);

        REQUIRE(lex.advance());
        auto const second_r = lex.read();

        CHECK(second_r == second_expected);

        REQUIRE_FALSE(lex.advance());
    }
}

TEST_CASE("Can parse variable references", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, std::vector<token>>({
        {
            "${simple}",
            {
                token{"${", token_type::variable_reference_open, "${"},
                token{"simple", token_type::variable_reference_piece, "simple"},
                token{"}", token_type::variable_reference_close, "}"},
            },
        },
        {
            R"===(${/_.+-\ \$\}$\{\n$})===",
            {
                token{"${", token_type::variable_reference_open, "${"},
                token{R"===(/_.+-\ \$\}$\{\n$)===",
                    token_type::variable_reference_piece,
                    R"===(/_.+-\ \$\}$\{\n$)==="},
                token{"}", token_type::variable_reference_close, "}"},
            },
        },
        {
            "${variable_${nested_${reference}_expansion}}",
            {
                token{"${", token_type::variable_reference_open, "${"},
                token{"variable_", token_type::variable_reference_piece,
                    "variable_"},
                token{"${", token_type::variable_reference_open, "${"},
                token{
                    "nested_", token_type::variable_reference_piece, "nested_"},
                token{"${", token_type::variable_reference_open, "${"},
                token{"reference", token_type::variable_reference_piece,
                    "reference"},
                token{"}", token_type::variable_reference_close, "}"},
                token{"_expansion", token_type::variable_reference_piece,
                    "_expansion"},
                token{"}", token_type::variable_reference_close, "}"},
                token{"}", token_type::variable_reference_close, "}"},
            },
        },
    }));

    CAPTURE(input);

    shipwright::detail::lexer lex{input};

    std::vector<token> result;
    while (lex.advance()) {
        result.push_back(lex.read());
    }

    CHECK(result == expected);
}

TEST_CASE("Can parse quoted arguments", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, std::vector<token>>({
        {
            "\"some quote\"",
            {
                token{"\"", token_type::quote, "\""},
                token{"some quote", token_type::quoted_piece, "some quote"},
                token{"\"", token_type::quote, "\""},
            },
        },
        {
            "\"some quote with a $ sign\"",
            {
                token{"\"", token_type::quote, "\""},
                token{"some quote with a $ sign", token_type::quoted_piece,
                    "some quote with a $ sign"},
                token{"\"", token_type::quote, "\""},
            },
        },
        {
            R"("some quote with \\ \" escape sequences")",
            {
                token{"\"", token_type::quote, "\""},
                token{R"(some quote with \\ \" escape sequences)",
                    token_type::quoted_piece,
                    R"(some quote with \\ \" escape sequences)"},
                token{"\"", token_type::quote, "\""},
            },
        },
        {
            "\"some quote with a"
            R"(\\\)"
            "\n quoted continuation\"",
            {
                token{"\"", token_type::quote, "\""},
                token{
                    "some quote with a"
                    R"(\\\)"
                    "\n quoted continuation",
                    token_type::quoted_piece,
                    "some quote with a"
                    R"(\\\)"
                    "\n quoted continuation",
                },
                token{"\"", token_type::quote, "\""},
            },
        },
        {
            "\"${reference}\"",
            {
                token{"\"", token_type::quote, "\""},
                token{"${", token_type::variable_reference_open, "${"},
                token{"reference", token_type::variable_reference_piece,
                    "reference"},
                token{"}", token_type::variable_reference_close, "}"},
                token{"\"", token_type::quote, "\""},
            },
        },
        {
            "\"some quote ${with} a variable reference\"",
            {
                token{"\"", token_type::quote, "\""},
                token{"some quote ", token_type::quoted_piece, "some quote "},
                token{"${", token_type::variable_reference_open, "${"},
                token{"with", token_type::variable_reference_piece, "with"},
                token{"}", token_type::variable_reference_close, "}"},
                token{" a variable reference", token_type::quoted_piece,
                    " a variable reference"},
                token{"\"", token_type::quote, "\""},
            },
        },
    }));

    CAPTURE(input);

    shipwright::detail::lexer lex{input};

    std::vector<token> result;
    while (lex.advance()) {
        result.push_back(lex.read());
    }

    CHECK(result == expected);
}
