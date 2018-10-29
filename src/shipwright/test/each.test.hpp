/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

#pragma once

#include <cstddef>
#include <iterator>
#include <memory>
#include <type_traits>
#include <utility>

#include <catch2/catch.hpp>

namespace shipwright::test {
    template <typename Range>
    using range_iterator_t
        = std::decay_t<decltype(std::begin(std::declval<Range>()))>;

    template <typename Range,
        typename T = decltype(*std::declval<range_iterator_t<Range const&>>())>
    class Each : public Catch::Generators::IGenerator<T>
    {
        Range const& range;

    public:
        Each(Range const& range)
            : range{range}
        {}

        T get(std::size_t index) const override
        {
            return *std::next(std::begin(range), index);
        }
    };

    template <typename Range>
    auto each(Range const& range)
    {
        return Catch::Generators::Generator<decltype(
            *std::declval<range_iterator_t<Range const&>>())>{
            static_cast<std::size_t>(std::size(range)),
            std::make_unique<Each<Range>>(range),
        };
    }
}
