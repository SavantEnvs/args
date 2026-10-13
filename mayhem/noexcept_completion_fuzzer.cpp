// Completion under ARGS_NOEXCEPT: the first input byte picks cword (1..10), the rest is split on '\n'
// into the argv tokens that follow "--completion bash <cword> prog".
#define ARGS_NOEXCEPT
#include <cstdint>
#include <string>
#include <vector>

#include <args.hxx>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 1)
    {
        return -1;
    }

    args::ArgumentParser parser("noexcept_completion_fuzzer");
    args::HelpFlag help(parser, "help", "Displays this help menu", {'h', "help"});
    args::CompletionFlag completion(parser, {"completion"});
    args::Flag test(parser, "test", "Test flag", {'t', "test"});
    args::MapFlag<std::string, int> map(parser, "mappos", "Mapped value", {'m', "map"},
                                        {{"alpha", 1}, {"beta", 2}});
    args::ValueFlag<std::string> value(parser, "value", "Plain value", {'v', "value"});
    args::ValueFlagList<std::string> list(parser, "list", "Value list", {'l', "list"});
    args::Positional<std::string> pos(parser, "pos", "Positional");

    std::vector<std::string> arguments{"--completion", "bash", std::to_string(1 + data[0] % 10), "prog"};
    std::string token;
    for (size_t i = 1; i < size; ++i)
    {
        if (data[i] == '\n')
        {
            arguments.push_back(token);
            token.clear();
        } else
        {
            token.push_back(static_cast<char>(data[i]));
        }
    }
    arguments.push_back(token);

    parser.ParseArgs(arguments);
    return 0;
}
