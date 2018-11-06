/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#include "./lexer.hpp"

#include <shipwright/token.test.hpp>

#include <catch2/catch.hpp>
#include <shipwright/test/each.test.hpp>

#include <initializer_list>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using shipwright::lexer;
using shipwright::token;
using shipwright::token_type;

TEST_CASE("Empty lexer iterator equal to sentinel", "[lexer]")
{
    CHECK(lexer::iterator{} == lexer::sentinel{});
    CHECK(lexer::sentinel{} == lexer::iterator{});
    CHECK_FALSE(lexer::iterator{} != lexer::sentinel{});
    CHECK_FALSE(lexer::sentinel{} != lexer::iterator{});
}

TEST_CASE("Can parse individual tokens", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, token>({
        {" ", token{" ", token_type::space, " "}},
        {"\t", token{"\t", token_type::space, "\t"}},
        {"\t \t", token{"\t \t", token_type::space, "\t \t"}},
        {"\n", token{"", token_type::newline, "\n"}},
        {"(", token{"", token_type::lparen, "("}},
        {")", token{"", token_type::rparen, ")"}},
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
    }));

    CAPTURE(input, expected);

    lexer lex{input};

    auto begin = lex.begin();
    auto const end = lex.end();

    REQUIRE(begin != end);

    auto result = *begin;

    CHECK(result == expected);

    ++begin;
    REQUIRE(begin == end);
}

TEST_CASE("Can parse multiple tokens", "[lexer]")
{
    static auto const test_values
        = std::vector<std::tuple<std::string, token, std::set<token_type>>>({
            {" ", token{" ", token_type::space, " "},
                std::set{token_type::space}},
            {"\n", token{"", token_type::newline, "\n"}, {}},
            {"(", token{"", token_type::lparen, "("}, {}},
            {")", token{"", token_type::rparen, ")"}, {}},
            {
                "# some comment",
                token{" some comment", token_type::line_comment,
                    "# some comment"},
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
        });

    auto [first, first_expected, ignore_succeeding]
        = GENERATE(shipwright::test::each(test_values));
    auto [second, second_expected, ignore]
        = GENERATE(shipwright::test::each(test_values));
    (void)ignore;

    if (ignore_succeeding.count(second_expected.type)) {
        SUCCEED();
    } else {
        auto const input = first + second;
        CAPTURE(input, first_expected, second_expected);

        lexer lex{input};

        auto begin = lex.begin();
        auto const end = lex.end();

        REQUIRE(begin != end);
        auto const first_r = *begin;

        CHECK(first_r == first_expected);

        ++begin;
        REQUIRE(begin != end);
        auto const second_r = *begin;

        CHECK(second_r == second_expected);

        ++begin;
        REQUIRE(begin == end);
    }
}

TEST_CASE("Can parse quoted arguments", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, std::vector<token>>({
        {
            "\"some quote\"",
            {
                token{"some quote", token_type::quoted_argument,
                    "\"some quote\""},
            },
        },
        {
            "\"some quote with a $ sign\"",
            {
                token{"some quote with a $ sign", token_type::quoted_argument,
                    "\"some quote with a $ sign\""},
            },
        },
        {
            R"("some quote with \\ \" escape sequences")",
            {
                token{R"(some quote with \\ \" escape sequences)",
                    token_type::quoted_argument,
                    R"("some quote with \\ \" escape sequences")"},
            },
        },
        {
            "\"some quote with a"
            R"(\\\)"
            "\n quoted continuation\"",
            {
                token{
                    "some quote with a"
                    R"(\\\)"
                    "\n quoted continuation",
                    token_type::quoted_argument,
                    "\"some quote with a"
                    R"(\\\)"
                    "\n quoted continuation\"",
                },
            },
        },
        {
            "\"${reference}\"",
            {
                token{"${reference}", token_type::quoted_argument,
                    "\"${reference}\""},
            },
        },
        {
            "\"some quote ${with} a variable reference\"",
            {
                token{
                    "some quote ${with} a variable reference",
                    token_type::quoted_argument,
                    "\"some quote ${with} a variable reference\"",
                },
            },
        },
    }));

    CAPTURE(input);

    lexer lex{input};

    std::vector<token> result{lex.begin(), lex.end()};

    CHECK(result == expected);
}

TEST_CASE("Can parse unquoted arguments without legacy", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, token>({
        {
            "some-unquoted.ar\\ gument",
            token{"some-unquoted.ar\\ gument", token_type::unquoted_argument,
                "some-unquoted.ar\\ gument"},
        },
        {"\\t", token{"\\t", token_type::unquoted_argument, "\\t"}},
        {"&", token{"&", token_type::unquoted_argument, "&"}},
        {"$abc", token{"$abc", token_type::unquoted_argument, "$abc"}},
        {"[=abc[=", token{"[=abc[=", token_type::unquoted_argument, "[=abc[="}},
        {
            "~`!1@23$4%5^6&7*890_-+=QqWwEeRrTtYyUuIiOoPp{[}]|"
            "AaSsDdFfGgHhJjKkLl:;'ZzXxCcVvBbNnMm<,>.?/",
            token{"~`!1@23$4%5^6&7*890_-+=QqWwEeRrTtYyUuIiOoPp{[}]|"
                  "AaSsDdFfGgHhJjKkLl:;'ZzXxCcVvBbNnMm<,>.?/",
                token_type::unquoted_argument,
                "~`!1@23$4%5^6&7*890_-+=QqWwEeRrTtYyUuIiOoPp{[}]|"
                "AaSsDdFfGgHhJjKkLl:;'ZzXxCcVvBbNnMm<,>.?/"},
        },
    }));

    CAPTURE(input);

    lexer lex{input};

    std::vector<token> result{lex.begin(), lex.end()};
    CHECK(result == std::vector<token>{expected});
}

TEST_CASE("Can parse variable references in unquoted arguments", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, std::vector<token>>({
        {
            "${simple}",
            {
                token{"${simple}", token_type::unquoted_argument, "${simple}"},
            },
        },
        {
            R"===(${/_.+-\ \$\}$\{\n$})===",
            {
                token{
                    R"===(${/_.+-\ \$\}$\{\n$})===",
                    token_type::unquoted_argument,
                    R"===(${/_.+-\ \$\}$\{\n$})===",
                },
            },
        },
        {
            "${variable_${nested_${reference}_expansion}}",
            {
                token{
                    "${variable_${nested_${reference}_expansion}}",
                    token_type::unquoted_argument,
                    "${variable_${nested_${reference}_expansion}}",
                },
            },
        },
    }));

    CAPTURE(input);

    lexer lex{input};

    std::vector<token> result{lex.begin(), lex.end()};

    CHECK(result == expected);
}

TEST_CASE("Can parse legacy unquoted arguments", "[lexer]")
{
    auto [input, expected] = GENERATE(table<std::string, token>({
        {"$(abc)", token{"$(abc)", token_type::unquoted_argument, "$(abc)"}},
        {
            "some_arg\"with a\"quote",
            token{"some_arg\"with a\"quote", token_type::unquoted_argument,
                "some_arg\"with a\"quote"},
        },
    }));

    CAPTURE(input);

    lexer lex{input};

    std::vector<token> result{lex.begin(), lex.end()};
    CHECK(result == std::vector<token>{expected});
}
