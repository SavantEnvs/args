/* Copyright (c) Taylor Richberger <taylor@axfive.net>
 * This code is released under the license described in the LICENSE file
 */

#include "test_common.hxx"

#include <args.hxx>

#include "test_helpers.hxx"

void testFailedFlagIsNotRegistered()
{
    args::ArgumentParser parser("This is a test program.");
    args::Flag flag_a(parser, "aone", "test flag", {'a', "aone"});

    const auto children = parser.Children().size();
    test::require_throws_as<args::ParseError>([&]{
        args::Flag flag_b(parser, "atwo", "test flag", {'a', "atwo"});
    });
    test::require(parser.Children().size() == children);
}

void testFailedFlagInGroupIsNotRegistered()
{
    args::ArgumentParser parser("This is a test program.");
    args::Group group(parser, "This is a test group.", args::Group::Validators::DontCare);
    args::Flag flag_a(group, "aone", "test flag", {'a', "aone"});

    const auto children = group.Children().size();
    test::require_throws_as<args::ParseError>([&]{
        args::Flag flag_b(group, "atwo", "test flag", {'a', "atwo"});
    });
    test::require(group.Children().size() == children);
}

void testParserStillUsableAfterCaughtDuplicate()
{
    args::ArgumentParser parser("This is a test program.");
    args::Flag flag_a(parser, "aone", "test flag", {'a', "aone"});
    args::Positional<std::string> pos(parser, "pos", "test positional");

    test::require_throws_as<args::ParseError>([&]{
        args::Flag flag_b(parser, "atwo", "test flag", {'a', "atwo"});
    });

    test::require_nothrow([&]{ parser.ParseArgs(std::vector<std::string>{"-a", "value"}); });
    test::require(bool(flag_a));
    test::require(args::get(pos) == "value");
    test::require_nothrow([&]{ (void)parser.Help(); });
}

void testFailedCompletionFlagIsNotRegistered()
{
    args::ArgumentParser parser("This is a test program.");
    args::Flag flag_a(parser, "aone", "test flag", {'a', "complete"});

    const auto children = parser.Children().size();
    test::require_throws_as<args::ParseError>([&]{
        args::CompletionFlag completion(parser, {"complete"});
    });
    test::require(parser.Children().size() == children);

    // The parser must not be left pointing at the completion flag it rejected.
    test::require_nothrow([&]{ parser.ParseArgs(std::vector<std::string>{"--complete"}); });
    test::require(bool(flag_a));
}

int main()
{
    testFailedFlagIsNotRegistered();
    testFailedFlagInGroupIsNotRegistered();
    testParserStillUsableAfterCaughtDuplicate();
    testFailedCompletionFlagIsNotRegistered();
}
