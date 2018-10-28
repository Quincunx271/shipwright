/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <ostream>
#include <sstream>
#include <type_traits>
#include <utility>

#include <catch2/catch.hpp>

#include <shipwright/debug_print.hpp>

namespace Catch {
    template <typename T>
    struct StringMaker<T,
        std::void_t<decltype(std::declval<std::ostream&>()
            << shipwright::debug_print(std::declval<T const&>()))>>
    {
        static std::string convert(T const& value)
        {
            std::ostringstream out;
            out << shipwright::debug_print(value);
            return out.str();
        }
    };
}
