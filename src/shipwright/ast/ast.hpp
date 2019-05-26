/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <cstdint>
#include <optional>
#include <string_view>
#include <variant>
#include <vector>

namespace shipwright::ast {
    struct space
    {
        std::string_view value;
    };

    struct identifier
    {
        std::string_view value;
    };

    struct unquoted_argument
    {
        std::string_view value;
    };

    struct quoted_argument
    {
        std::string_view value;
    };

    struct bracket_argument
    {
        std::string_view value;
        std::int64_t bracket_strength;
    };

    struct argument;

    struct parenthesized_argument
    {
        std::vector<argument> values;
    };

    struct bracket_comment
    {
        bracket_argument value;
    };

    struct line_comment
    {
        std::string_view value;
    };

    struct argument
    {
        std::variant<bracket_argument, quoted_argument, unquoted_argument, parenthesized_argument,
            line_comment, bracket_comment>
            value;
    };

    struct command_invocation
    {
        identifier command_id;
        std::vector<argument> arguments;
    };

    struct file_element
    {
        std::variant<command_invocation, std::vector<bracket_comment>> value;
        std::optional<line_comment> comment;
    };

    struct file
    {
        std::vector<file_element> elements;
    };
}
